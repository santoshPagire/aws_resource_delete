#!/bin/bash

#(ASG, EC2, EFS, ECS)
export AWS_PAGER=""

REGION="us-east-1"
PATTERN=$1

if [ -z "$2" ]; then
    echo "No AWS profile provided"
else
    PROFILE=$2
    echo "Using AWS profile: $PROFILE"
fi


# Function to delete Auto Scaling Groups
delete_asg() {
    
    ASG_NAMES=$(aws autoscaling describe-auto-scaling-groups --region "$REGION" --profile "$PROFILE" --query "AutoScalingGroups[*].AutoScalingGroupName" --output text)

    if [ -z "$ASG_NAMES" ]; then
        echo "No Auto Scaling groups found in region '$REGION'."
        return
    fi

    echo "The following Auto Scaling groups were found in region '$REGION':"
    echo "$ASG_NAMES"

    MATCHING_ASG_NAMES=$(echo "$ASG_NAMES" | tr ' ' '\n' | grep -i "$PATTERN")

    # Check if any matching ASGs were found
    if [ -z "$MATCHING_ASG_NAMES" ]; then
        echo "No Auto Scaling groups found with the name containing '$PATTERN' in region '$REGION'."
        return
    fi

    echo "The following matching Auto Scaling groups were found:"
    echo "$MATCHING_ASG_NAMES"

    read -p "Do you want to delete these Auto Scaling groups? (yes/no): " CONFIRMATION

    if [[ "$CONFIRMATION" != "yes" ]]; then
        echo "Aborting deletion process for Auto Scaling groups."
        return
    fi

    # Loop through each matching Auto Scaling group and delete it
    for ASG_NAME in $MATCHING_ASG_NAMES; do
        echo "Attempting to delete Auto Scaling group: $ASG_NAME"
        
        # Attempt to delete the Auto Scaling group
        if aws autoscaling delete-auto-scaling-group --region "$REGION" --profile "$PROFILE" --auto-scaling-group-name "$ASG_NAME" --force-delete; then
            echo "Successfully deleted Auto Scaling group: $ASG_NAME"
        else
            echo "Failed to delete Auto Scaling group: $ASG_NAME. Please check the permissions or the state of the ASG."
        fi
    done
}

# Function to delete EC2 Instances
delete_ec2() {
    # Get the list of all EC2 instances that are not terminated
    INSTANCE_INFO=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
        --filters "Name=instance-state-name,Values=pending,running,stopping,stopped" \
        --query 'Reservations[*].Instances[*].{InstanceId:InstanceId, Name:Tags[?Key==`Name`].Value | [0]}' \
        --output text)

    if [ -z "$INSTANCE_INFO" ]; then
        echo "No EC2 instances found in region '$REGION'."
        return
    fi

    echo "The following EC2 instances were found in region '$REGION':"
    #echo "$INSTANCE_INFO"

    # Filter EC2 instances that contain the pattern in their Name
    MATCHING_INSTANCE_IDS=()
    while read -r INSTANCE_ID NAME; do
        # Trim leading/trailing spaces from NAME
        NAME=$(echo "$NAME" | xargs)
        
        # Check if the Name contains the pattern.
        if [[ -n "$NAME" && "${NAME,,}" == *"${PATTERN,,}"* ]]; then
            MATCHING_INSTANCE_IDS+=("$INSTANCE_ID")
            echo "Found matching instance: $INSTANCE_ID with Name: $NAME"
        fi
    done <<< "$INSTANCE_INFO"

    if [ ${#MATCHING_INSTANCE_IDS[@]} -eq 0 ]; then
        echo "No EC2 instances found with the name containing '$PATTERN' in region '$REGION'."
        return
    fi

    echo "The following matching EC2 instances were found:"
    printf '%s\n' "${MATCHING_INSTANCE_IDS[@]}"

    read -p "Do you want to delete these EC2 instances? (yes/no): " CONFIRMATION

    if [[ "$CONFIRMATION" != "yes" ]]; then
        echo "Aborting deletion process for EC2 instances."
        return
    fi

    # Loop through each matching EC2 instance and delete it
    for INSTANCE_ID in "${MATCHING_INSTANCE_IDS[@]}"; do
        echo "Attempting to terminate EC2 instance: $INSTANCE_ID"
        
        # Attempt to terminate the EC2 instance
        if aws ec2 terminate-instances --region "$REGION" --profile "$PROFILE" --instance-ids "$INSTANCE_ID"; then
            echo "Successfully terminated EC2 instance: $INSTANCE_ID"
        else
            echo "Failed to terminate EC2 instance: $INSTANCE_ID. Please check the permissions or the state of the instance."
        fi
    done
}

# Function to delete EFS file systems
delete_efs() {
    EFS_IDS=$(aws efs describe-file-systems --region "$REGION" --profile "$PROFILE" --query "FileSystems[*].FileSystemId" --output text)

    if [ -z "$EFS_IDS" ]; then
        echo "No EFS file systems found in region '$REGION'."
        return
    fi

    # Filter EFS file systems that contain the pattern in their Name tag
    MATCHING_EFS_IDS=()
    for EFS_ID in $EFS_IDS; do
    
        EFS_NAME=$(aws efs describe-tags --region "$REGION" --profile "$PROFILE" --file-system-id "$EFS_ID" \
                    --query "Tags[?Key=='Name'].Value" --output text)

        # Check if name matches pattern
        if [[ -n "$EFS_NAME" && "${EFS_NAME,,}" == *"${PATTERN,,}"* ]]; then
            MATCHING_EFS_IDS+=("$EFS_ID")
            echo "Found matching EFS: $EFS_ID with Name: $EFS_NAME"
        fi
    done


    if [ ${#MATCHING_EFS_IDS[@]} -eq 0 ]; then
        echo "No EFS file systems found with name containing '$PATTERN' in region '$REGION'."
        return
    fi
    echo "The following matching EFS file systems were found:"
    printf '%s\n' "${MATCHING_EFS_IDS[@]}"

    read -p "Do you want to delete these EFS file systems? (yes/no): " CONFIRMATION

    if [[ "$CONFIRMATION" != "yes" ]]; then
        echo "Aborting deletion process for EFS file systems."
        return
    fi

    # Delete matching EFS file systems
    for EFS_ID in "${MATCHING_EFS_IDS[@]}"; do
        echo "Processing EFS file system: $EFS_ID"
        
        # Delete mount targets first
        MOUNT_TARGET_IDS=$(aws efs describe-mount-targets --region "$REGION" --profile "$PROFILE" \
                          --file-system-id "$EFS_ID" \
                          --query "MountTargets[*].MountTargetId" \
                          --output text)
        
        if [ -n "$MOUNT_TARGET_IDS" ]; then
            echo "Found mount targets: $MOUNT_TARGET_IDS"
            for MT_ID in $MOUNT_TARGET_IDS; do
                echo "Deleting mount target: $MT_ID"
                aws efs delete-mount-target --region "$REGION" --profile "$PROFILE" --mount-target-id "$MT_ID"
            done

            # Wait for mount targets to be fully removed
            echo "Waiting for mount targets to be deleted..."
            RETRY_COUNT=0
            MAX_RETRIES=10
            while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
                REMAINING_TARGETS=$(aws efs describe-mount-targets --region "$REGION" --profile "$PROFILE" \
                                   --file-system-id "$EFS_ID" \
                                   --query "length(MountTargets)" \
                                   --output text)
                
                if [ "$REMAINING_TARGETS" -eq 0 ]; then
                    echo "All mount targets removed"
                    break
                fi
                
                echo "Waiting for $REMAINING_TARGETS mount targets to be deleted... ($((MAX_RETRIES - RETRY_COUNT)) retries left)"
                sleep 15
                ((RETRY_COUNT++))
            done

            if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
                echo "Timeout waiting for mount targets to be deleted. Skipping EFS deletion."
                continue
            fi
        else
            echo "No mount targets found for $EFS_ID"
        fi

        # Delete the EFS
        echo "Attempting to delete EFS file system: $EFS_ID"
        if aws efs delete-file-system --region "$REGION" --profile "$PROFILE" --file-system-id "$EFS_ID"; then
            echo "Successfully deleted EFS file system: $EFS_ID"
        else
            echo "Failed to delete EFS file system: $EFS_ID. Please check dependencies or permissions."
        fi
    done
}

# Function to delete ECS Clusters
delete_ecs() {
    # Get the list of all ECS clusters
    CLUSTER_INFO=$(aws ecs list-clusters --region "$REGION" --profile "$PROFILE" --query 'clusterArns[*]' --output text)

    if [ -z "$CLUSTER_INFO" ]; then
        echo "No ECS clusters found in region '$REGION'."
        return
    fi

    echo "The following ECS clusters were found in region '$REGION':"
    echo "$CLUSTER_INFO"

    # Filter ECS clusters that contain the pattern in their name
    MATCHING_CLUSTER_ARNS=()
    for CLUSTER_ARN in $CLUSTER_INFO; do
        # Extract the cluster name from the ARN
        CLUSTER_NAME=$(basename "$CLUSTER_ARN")

        # Check if the Name contains the pattern.
        if [[ -n "$CLUSTER_NAME" && "${CLUSTER_NAME,,}" == *"${PATTERN,,}"* ]]; then
            MATCHING_CLUSTER_ARNS+=("$CLUSTER_ARN")
            echo "Found matching cluster: $CLUSTER_NAME with ARN: $CLUSTER_ARN"
        fi
    done

    if [ ${#MATCHING_CLUSTER_ARNS[@]} -eq 0 ]; then
        echo "No ECS clusters found with the name containing '$PATTERN' in region '$REGION'."
        return
    fi

    echo "The following matching ECS clusters were found:"
    printf '%s\n' "${MATCHING_CLUSTER_ARNS[@]}"

    read -p "Do you want to delete these ECS clusters? (yes/no): " CONFIRMATION

    if [[ "$CONFIRMATION" != "yes" ]]; then
        echo "Aborting deletion process for ECS clusters."
        return
    fi

    # Loop through each matching ECS cluster and delete it
    for CLUSTER_ARN in "${MATCHING_CLUSTER_ARNS[@]}"; do
        CLUSTER_NAME=$(basename "$CLUSTER_ARN")
        echo "Attempting to delete ECS cluster: $CLUSTER_NAME"

        # Delete the ECS cluster
        if aws ecs delete-cluster --region "$REGION" --profile "$PROFILE" --cluster "$CLUSTER_NAME"; then
            echo "Successfully deleted ECS cluster: $CLUSTER_NAME"
        else
            echo "Failed to delete ECS cluster: $CLUSTER_NAME. Please check the permissions or the state of the cluster."
        fi
    done
}

delete_asg
delete_ec2
delete_efs
delete_ecs

echo "Deletion process completed."
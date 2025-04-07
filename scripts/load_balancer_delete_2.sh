#!/bin/bash

#(Listeners, Target Groups, ALB, NLB)

REGION="us-east-1"
PATTERN=$1

if [ -z "$2" ]; then
    echo "No AWS profile provided"
else
    PROFILE=$2
    echo "Using AWS profile: $PROFILE"
fi


delete_lb_resources() {
    LB_NAMES=$(aws elbv2 describe-load-balancers --region "$REGION" --profile "$PROFILE" --query "LoadBalancers[*].LoadBalancerName" --output text)


    if [ -z "$LB_NAMES" ]; then
        echo "No Load Balancers found in region '$REGION'."
        return
    fi

    echo "The following Load Balancers were found in region '$REGION':"
    #echo "$LB_NAMES"


    echo "*****************************************************************************************************************************"
    
    # Filter Load Balancers whose names contain the pattern
    MATCHING_LB_NAMES=$(echo "$LB_NAMES" | tr '\t' '\n' | grep -i "$PATTERN" | tr '\n' ' ')

    # Check if any matching load balancers were found
    if [ -z "$MATCHING_LB_NAMES" ]; then
        echo "No Load Balancers found with the name containing '$PATTERN' in region '$REGION'."
        return
    fi

    echo "The following matching Load Balancers were found:"
    echo "$MATCHING_LB_NAMES"

    # Loop through each matching load balancer (ALB or NLB)
    for LB_NAME in $MATCHING_LB_NAMES; do
        echo "Retrieving information for Load Balancer: $LB_NAME"

        # Get the Load Balancer ARN using the LB name
        LB_ARN=$(aws elbv2 describe-load-balancers --region "$REGION" --profile "$PROFILE" --names "$LB_NAME" --query "LoadBalancers[0].LoadBalancerArn" --output text)
        LB_SCHEME=$(aws elbv2 describe-load-balancers --region "$REGION" --profile "$PROFILE" --names "$LB_NAME" --query "LoadBalancers[0].Scheme" --output text)

        if [ "$LB_ARN" == "None" ]; then
            echo "Load Balancer with name '$LB_NAME' not found in region '$REGION'."
            continue
        fi

        echo "Found Load Balancer ARN: $LB_ARN"
        echo "Load Balancer Scheme: $LB_SCHEME"

        echo "*****************************************************************************************************************************"
        
        LISTENERS=$(aws elbv2 describe-listeners --region "$REGION" --profile "$PROFILE" --load-balancer-arn "$LB_ARN" --query "Listeners[*].ListenerArn" --output text)
        echo "Found Listeners: $LISTENERS"

        echo "*****************************************************************************************************************************"
        
        # Retrieve target groups associated with the Load Balancer
        TARGET_GROUPS=$(aws elbv2 describe-target-groups --region "$REGION" --profile "$PROFILE" --load-balancer-arn "$LB_ARN" --query "TargetGroups[*].TargetGroupArn" --output text)
        echo "Found Target Groups: $TARGET_GROUPS"

        echo "*****************************************************************************************************************************"
        
        # Retrieve security groups associated with the Load Balancer
        SECURITY_GROUPS=$(aws elbv2 describe-load-balancers --region "$REGION" --profile "$PROFILE" --names "$LB_NAME" --query "LoadBalancers[0].SecurityGroups" --output text)
        echo "Found Security Groups: $SECURITY_GROUPS"

        echo "*****************************************************************************************************************************"
        
        read -p "Do you want to delete the Listeners for '$LB_NAME'? (yes/no): " CONFIRMATION

        if [[ "$CONFIRMATION" == "yes" ]]; then
            # Delete listeners 
            for LISTENER in $LISTENERS; do
                echo "Deleting Listener: $LISTENER"
                if aws elbv2 delete-listener --region "$REGION" --profile "$PROFILE" --listener-arn "$LISTENER"; then
                    echo "Successfully deleted Listener: $LISTENER"
                else
                    echo "Failed to delete Listener: $LISTENER"
                fi
            done
        else
            echo "Skipping deletion of Listeners for Load Balancer: $LB_NAME"
        fi

        echo "*****************************************************************************************************************************"
        
        read -p "Do you want to delete the Target Groups for '$LB_NAME'? (yes/no): " CONFIRMATION

        if [[ "$CONFIRMATION" == "yes" ]]; then
            # Delete target groups
            for TARGET_GROUP in $TARGET_GROUPS; do
                echo "Deleting Target Group: $TARGET_GROUP"
                if aws elbv2 delete-target-group --region "$REGION" --profile "$PROFILE" --target-group-arn "$TARGET_GROUP"; then
                    echo "Successfully deleted Target Group: $TARGET_GROUP"
                else
                    echo "Failed to delete Target Group: $TARGET_GROUP"
                fi
            done
        else
            echo "Skipping deletion of Target Groups for Load Balancer: $LB_NAME"
        fi

        echo "*****************************************************************************************************************************"
        
        read -p "Do you want to delete the Load Balancer '$LB_NAME'? (yes/no): " CONFIRMATION

        if [[ "$CONFIRMATION" == "yes" ]]; then
            # Delete the Load Balancer.
            echo "Deleting Load Balancer: $LB_NAME"
            if aws elbv2 delete-load-balancer --region "$REGION" --profile "$PROFILE" --load-balancer-arn "$LB_ARN"; then
                echo "Successfully deleted Load Balancer: $LB_NAME"
            else
                echo "Failed to delete Load Balancer: $LB_NAME"
            fi
        else
            echo "Skipping deletion of Load Balancer: $LB_NAME"
        fi
        echo "*****************************************************************************************************************************"

    done
}

delete_lb_resources

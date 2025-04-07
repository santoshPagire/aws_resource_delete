#!/bin/bash

export AWS_PAGER=""

REGION="us-east-1"
PATTERN=$1

if [ -z "$2" ]; then
    echo "No AWS profile provided"
else
    PROFILE=$2
    echo "Using AWS profile: $PROFILE"
fi


# Function to delete RDS instances
delete_rds() {
    echo "Fetching RDS instances matching '$PATTERN' in region '$REGION'..."

    # Fetch RDS Instances
    ALL_RDS_INSTANCES=$(aws rds describe-db-instances --region "$REGION" --profile "$PROFILE" --query "DBInstances[*].{ID:DBInstanceIdentifier, Tags:TagList, SecurityGroups:VpcSecurityGroups, Engine:Engine}" --output json)

    # Check for RDS Instances
    if [ -z "$ALL_RDS_INSTANCES" ]; then
        echo "No RDS instances found."
        echo "***************************************************************************************************************"
    else
        MATCHING_RDS_INSTANCES=$(echo "$ALL_RDS_INSTANCES" | jq -r ".[] | select(.ID | test(\"$PATTERN\")) | {ID: .ID, SecurityGroups: .SecurityGroups, Engine: .Engine}")

        if [ -z "$MATCHING_RDS_INSTANCES" ]; then
            echo "No RDS instances match the pattern '$PATTERN'."
            echo "***************************************************************************************************************"
        else
            echo "Found RDS instances matching '$PATTERN':"
            
            echo "$MATCHING_RDS_INSTANCES" | jq -r '.ID + " - Engine: " + .Engine'
            
            for CONNECT_INSTANCE in $(echo "$MATCHING_RDS_INSTANCES" | jq -r '.ID'); do
                INSTANCE_ENGINE=$(echo "$MATCHING_RDS_INSTANCES" | jq -r "select(.ID==\"$CONNECT_INSTANCE\") | .Engine")
                # Extract the security group IDs from the 'VpcSecurityGroups' array
                SECURITY_GROUPS=$(echo "$MATCHING_RDS_INSTANCES" | jq -r "select(.ID==\"$CONNECT_INSTANCE\") | .SecurityGroups | map(.VpcSecurityGroupId) | join(\", \")")
                
                echo "Found Security Groups Associated with '$CONNECT_INSTANCE' ($INSTANCE_ENGINE): $SECURITY_GROUPS"
                
                # Prompt for deletion
                echo "Do you want to delete RDS instance '$CONNECT_INSTANCE'? (yes/no):"
                read CONFIRMATION
                if [[ "$CONFIRMATION" == "yes" ]]; then
                    echo "Deleting RDS instance: $CONNECT_INSTANCE"
                    DELETE_OUTPUT=$(aws rds delete-db-instance --region "$REGION" --profile "$PROFILE" --db-instance-identifier "$CONNECT_INSTANCE" --skip-final-snapshot 2>&1)
                    
                    # Check if the deletion command was successful
                    if [[ "$DELETE_OUTPUT" =~ "DBInstanceNotFound" ]]; then
                        echo "Error: DB instance '$CONNECT_INSTANCE' not found. Deletion failed."
                    else
                        echo "$DELETE_OUTPUT"
                        echo "Initiated deletion for $CONNECT_INSTANCE"
                    fi
                    
                    # Wait for the DB instance to be deleted or check status if it's in 'deleting'
                    echo "Waiting for the DB instance '$CONNECT_INSTANCE' to be deleted..."
                    while true; do
                        # Check if DBInstance exists, if it doesn't, exit the loop
                        STATUS=$(aws rds describe-db-instances --region "$REGION" --profile "$PROFILE" --db-instance-identifier "$CONNECT_INSTANCE" --query "DBInstances[0].DBInstanceStatus" --output text 2>&1)
                        
                        # If DBInstanceNotFound is encountered, break the loop
                        if [[ "$STATUS" == *"DBInstanceNotFound"* ]]; then
                            echo "$CONNECT_INSTANCE has been successfully deleted."
                            break
                        elif [[ "$STATUS" == "deleting" ]]; then
                            echo "$CONNECT_INSTANCE is still being deleted. Checking again in 30 seconds..."
                            sleep 30
                        else
                            echo "$CONNECT_INSTANCE deletion failed with status: $STATUS"
                            break
                        fi
                    done
                else
                    echo "Skipping RDS instance: $CONNECT_INSTANCE"
                fi
                echo "***************************************************************************************************************"    
            done
        fi
    fi
}

delete_rds


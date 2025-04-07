#!/bin/bash

# Define the log group name pattern
PATTERN=$1
PROFILE=$2
REGION="us-east-1"

delete_ssm_parameter(){
        PARAMETERS=$(aws ssm describe-parameters --region "$REGION" --profile "$PROFILE" --query "Parameters[?contains(Name, '$PATTERN')].Name" --output text)

        # Check if any SSM parameters were found
        if [ -z "$PARAMETERS" ]; then
            echo "No SSM parameters found with the pattern '$PATTERN'."
            return
        fi

        # Loop through each parameter found and prompt for deletion
        for PARAM_NAME in $PARAMETERS; do
            echo "Found SSM parameter: $PARAM_NAME"
            
            # Prompt for confirmation
            read -p "Do you want to delete this SSM parameter? (yes/no): " CONFIRMATION
            if [[ "$CONFIRMATION" == "yes" ]]; then
                # Delete the SSM parameter using the fully qualified name
                aws ssm delete-parameter --name "$PARAM_NAME" --region "$REGION" --profile "$PROFILE"
                if [ $? -eq 0 ]; then
                    echo "SSM parameter '$PARAM_NAME' has been deleted."
                else
                    echo "Failed to delete SSM parameter '$PARAM_NAME'."
                fi
            else
                echo "Skipping deletion of '$PARAM_NAME'."
            fi
        done
}

delete_log_groups() {

    echo "Deletion of Cloudwatch log groups"
    log_groups=$(aws logs describe-log-groups --region "$REGION" --profile "$PROFILE" --query "logGroups[?contains(logGroupName, '$PATTERN')].logGroupName" --output json)

    # Check if any log groups were found
    if [ "$log_groups" == "[]" ]; then
        echo "No log groups found matching the pattern '$PATTERN'."
        return  
    fi

    echo "Matching log groups:"
    echo "$log_groups" | jq -r '.[]'

    read -p "Do you want to delete these log groups? (yes/no): " confirm

    if [[ "$confirm" == "yes" ]]; then
        echo "$log_groups" | jq -r '.[]' | while read -r log_group; do
            echo "Deleting log group: $log_group"
            aws logs delete-log-group --log-group-name "$log_group" --region "$REGION" --profile "$PROFILE"
        done
        echo "Deletion completed."
    else
        echo "No log groups were deleted."
    fi
}

delete_cloudwatch_alarms() {

    echo "Deletion of Cloudwatch alarms"
    alarms=$(aws cloudwatch describe-alarms --region "$REGION" --profile "$PROFILE" --query "MetricAlarms[?contains(AlarmName, '$PATTERN')].AlarmName" --output json)

    if [ "$alarms" == "[]" ]; then
        echo "No CloudWatch alarms found matching the pattern '$PATTERN'."
        return 
    fi

    echo "Matching CloudWatch alarms:"
    echo "$alarms" | jq -r '.[]'

    read -p "Do you want to delete these CloudWatch alarms? (yes/no): " confirm

    if [[ "$confirm" == "yes" ]]; then
        echo "$alarms" | jq -r '.[]' | while read -r alarm; do
            echo "Deleting CloudWatch alarm: $alarm"
            aws cloudwatch delete-alarms --alarm-names "$alarm" --region "$REGION" --profile "$PROFILE"
        done
        echo "Deletion completed."
    else
        echo "No CloudWatch alarms were deleted."
    fi
}

delete_ssm_parameter
delete_log_groups
delete_cloudwatch_alarms
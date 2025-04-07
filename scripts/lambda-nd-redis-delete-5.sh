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
  
# Function to delete Lambda functions
delete_lambda() {
    
    # Fetch the list of Lambda functions in the specified region
    LAMBDA_FUNCTIONS=$(aws lambda list-functions --region "$REGION" --profile "$PROFILE" --query "Functions[*].FunctionName" --output text)

    if [ -z "$LAMBDA_FUNCTIONS" ]; then
        echo "No Lambda functions found in region '$REGION'."
        return
    fi

    echo "The following Lambda functions were found in region '$REGION':"
    echo "$LAMBDA_FUNCTIONS"

    MATCHING_LAMBDAS=$(echo "$LAMBDA_FUNCTIONS" | tr ' ' '\n' | grep -i "$PATTERN")

    if [ -z "$MATCHING_LAMBDAS" ]; then
        echo "No Lambda functions found with the name containing '$PATTERN' in region '$REGION'."
        return
    fi

    echo "The following matching Lambda functions were found:"
    echo "$MATCHING_LAMBDAS"

    # Prompt the user for confirmation to delete
    read -p "Do you want to delete these Lambda functions? (yes/no): " CONFIRMATION

    if [[ "$CONFIRMATION" != "yes" ]]; then
        echo "Aborting deletion process for Lambda functions."
        return
    fi

    # Loop through each matching Lambda function and delete it
    for LAMBDA_FUNCTION in $MATCHING_LAMBDAS; do
        echo "Attempting to delete Lambda function: $LAMBDA_FUNCTION"
        
        # Attempt to delete the Lambda function
        if aws lambda delete-function --region "$REGION" --profile "$PROFILE" --function-name "$LAMBDA_FUNCTION"; then
            echo "Successfully deleted Lambda function: $LAMBDA_FUNCTION"
        else
            echo "Failed to delete Lambda function: $LAMBDA_FUNCTION. Please check the permissions or the state of the Lambda function."
        fi
        echo "***************************************************************************************************************"
    done
}

delete_redis_cache(){
    # Fetch the list of ElastiCache Redis clusters
    CLUSTERS=$(aws elasticache describe-cache-clusters --region "$REGION" --profile "$PROFILE" --query "CacheClusters[?contains(CacheClusterId, '$PATTERN')].CacheClusterId" --output text)

    # Check if any Redis clusters were found
    if [ -z "$CLUSTERS" ]; then
        echo "No Redis clusters found with the pattern '$PATTERN'."
        return
    fi

    # Loop through each cluster found and prompt for deletion
    for CLUSTER_ID in $CLUSTERS; do
        echo "Found Redis cluster: $CLUSTER_ID"
        
        # Check if the cluster is part of a replication group
        REPLICATION_GROUP_ID=$(aws elasticache describe-cache-clusters --region "$REGION" --profile "$PROFILE" --cache-cluster-id "$CLUSTER_ID" --query "CacheClusters[0].ReplicationGroupId" --output text)
        
        if [ "$REPLICATION_GROUP_ID" != "None" ]; then
            echo "Cluster '$CLUSTER_ID' is part of replication group '$REPLICATION_GROUP_ID'."
            # Check if it's the only node in the replication group
            REPLICATION_GROUP_STATUS=$(aws elasticache describe-replication-groups --region "$REGION" --profile "$PROFILE" --replication-group-id "$REPLICATION_GROUP_ID" --query "ReplicationGroups[0].NodeGroups[0].NodeGroupMembers | length(@)" --output text)
            
            if [ "$REPLICATION_GROUP_STATUS" -eq 1 ]; then
                echo "This is the only node in the replication group. You need to delete the replication group."
                read -p "Do you want to delete the entire replication group '$REPLICATION_GROUP_ID'? (yes/no): " CONFIRMATION
                if [[ "$CONFIRMATION" == "yes" ]]; then
                    # Delete the replication group
                    aws elasticache delete-replication-group --replication-group-id "$REPLICATION_GROUP_ID" --region "$REGION" --profile "$PROFILE"
                    echo "Replication group '$REPLICATION_GROUP_ID' deletion started."
                    
                    # Poll for the status of the replication group deletion
                    while true; do
                        STATUS=$(aws elasticache describe-replication-groups --region "$REGION" --profile "$PROFILE" --replication-group-id "$REPLICATION_GROUP_ID" 2>&1)
                        if [[ "$STATUS" == *"ReplicationGroupNotFoundFault"* ]]; then
                            echo "Replication group '$REPLICATION_GROUP_ID' has been deleted."
                            break
                        else
                            echo "Waiting for deletion of replication group '$REPLICATION_GROUP_ID'... $STATUS"
                            sleep 30  # Wait for 30 seconds before checking the status again
                        fi
                    done
                else
                    echo "Skipping deletion of replication group '$REPLICATION_GROUP_ID'."
                fi
            else
                echo "Skipping deletion of '$CLUSTER_ID' because it's part of a multi-node replication group."
            fi
        else
            # If the cluster is not part of a replication group, proceed to delete the cluster
            read -p "Do you want to delete this Redis cluster? (yes/no): " CONFIRMATION
            if [[ "$CONFIRMATION" == "yes" ]]; then
                # Delete the Redis cluster
                aws elasticache delete-cache-cluster --cache-cluster-id "$CLUSTER_ID" --region "$REGION" --profile "$PROFILE"
                echo "Redis cluster '$CLUSTER_ID' deletion started."
                
                # Poll for the status of the cluster deletion
                while true; do
                    STATUS=$(aws elasticache describe-cache-clusters --region "$REGION" --profile "$PROFILE" --cache-cluster-id "$CLUSTER_ID" 2>&1)
                    if [[ "$STATUS" == *"CacheClusterNotFoundFault"* ]]; then
                        echo "Redis cluster '$CLUSTER_ID' has been deleted."
                        break
                    else
                        echo "Waiting for deletion of Redis cluster '$CLUSTER_ID'"
                        sleep 30  # Wait for 30 seconds before checking the status again
                    fi
                done
            else
                echo "Skipping deletion of '$CLUSTER_ID'."
            fi
        fi
    done
}



delete_lambda
delete_redis_cache

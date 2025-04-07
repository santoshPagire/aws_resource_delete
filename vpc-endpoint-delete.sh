#!/bin/bash

REGION="us-east-1"
PATTERN=$1

if [ -z "$2" ]; then
    echo "No AWS profile provided"
    exit 1
else
    PROFILE=$2
    echo "Using AWS profile: $PROFILE"
fi

# Function to delete VPC Endpoints
delete_endpoints() {
    echo "Fetching VPC (Interface & Gateway) Endpoints matching '$PATTERN' in region '$REGION'..."
    
    ALL_VPC_ENDPOINTS=$(aws ec2 describe-vpc-endpoints --region "$REGION" --profile "$PROFILE" --query "VpcEndpoints[*].{ID:VpcEndpointId, Tags:Tags, Groups:Groups}" --output json)
    

    if [ -z "$ALL_VPC_ENDPOINTS" ]; then
        echo "No VPC Endpoints found."
        echo "***************************************************************************************************************"
        return
    fi

    MATCHING_VPC_ENDPOINTS=$(echo "$ALL_VPC_ENDPOINTS" | jq -r ".[] | select(.ID == \"$PATTERN\") | {ID: .ID, Name: .ID, Groups: .Groups}")

    if [ -z "$MATCHING_VPC_ENDPOINTS" ]; then
        echo "No VPC endpoints match the pattern '$PATTERN'."
        echo "***************************************************************************************************************"
        return
    fi

    echo "Found VPC Endpoints matching '$PATTERN':"
    echo "$MATCHING_VPC_ENDPOINTS" | jq -r '.Name + " (" + .ID + ")"'

    # Loop through each matching endpoint and ask for confirmation
    for CONNECT_ENDPOINT in $(echo "$MATCHING_VPC_ENDPOINTS" | jq -r '.ID'); do
        ENDPOINT_NAME=$(echo "$MATCHING_VPC_ENDPOINTS" | jq -r "select(.ID==\"$CONNECT_ENDPOINT\") | .Name")
        SECURITY_GROUPS=$(echo "$MATCHING_VPC_ENDPOINTS" | jq -r "select(.ID==\"$CONNECT_ENDPOINT\") | .Groups | map(.GroupId) | join(\", \")")
        
        echo "Found Security Group Associated with '$ENDPOINT_NAME': $SECURITY_GROUPS"
        
        # Prompt for deletion
        read -p "Do you want to delete VPC Endpoint '$ENDPOINT_NAME' ($CONNECT_ENDPOINT)? (yes/no):" CONFIRMATION
        if [[ "$CONFIRMATION" == "yes" ]]; then
            echo "Deleting VPC Endpoint: $CONNECT_ENDPOINT"
            aws ec2 delete-vpc-endpoints --region "$REGION" --profile "$PROFILE" --vpc-endpoint-id "$CONNECT_ENDPOINT" && echo "Deleted $CONNECT_ENDPOINT"
        else
            echo "Skipping VPC Endpoint: $CONNECT_ENDPOINT"
        fi
        echo "***************************************************************************************************************"
    done
}

delete_endpoints
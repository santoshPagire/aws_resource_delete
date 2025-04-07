#!/bin/bash

REGION="us-east-1"
PATTERN=$1

if [ -z "$2" ]; then
    echo "No AWS profile provided"
else
    PROFILE=$2
    echo "Using AWS profile: $PROFILE"
fi


delete_security_groups() {
    echo "Fetching Security Groups matching '$PATTERN' in region '$REGION'..."

    # Fetch all security groups in the region
    ALL_SG=$(aws ec2 describe-security-groups --region "$REGION" --profile "$PROFILE" --query "SecurityGroups[*].{ID:GroupId, Name:GroupName}" --output json)

    if [ -z "$ALL_SG" ]; then
        echo "No Security Groups found."
    else
        # Filter security groups that match the pattern
        MATCHING_SG=$(echo "$ALL_SG" | jq -r ".[] | select(.Name | test(\"$PATTERN\")) | {ID: .ID, Name: .Name}")

        if [ -z "$MATCHING_SG" ]; then
            echo "No Security Groups match the pattern '$PATTERN'."
        else
            echo "Found Security Groups matching '$PATTERN':"

            # Display matching security groups
            echo "$MATCHING_SG" | jq -r '.Name + " (" + .ID + ")"'

            # Loop through each matching security group and ask for deletion
            for SG in $(echo "$MATCHING_SG" | jq -r '.ID'); do
                SG_NAME=$(echo "$MATCHING_SG" | jq -r "select(.ID==\"$SG\") | .Name")
                echo "*****************************************************************************************************************************"
                echo "Found Security Group '$SG_NAME' ($SG)"

                # Fetch the inbound rules (Ingress)
                INGRESS_RULES=$(aws ec2 describe-security-group-rules --region "$REGION" --profile "$PROFILE" --filters Name=group-id,Values="$SG" --query "SecurityGroupRules[?IsEgress==\`false\`].SecurityGroupRuleId" --output text)
                # Fetch the outbound rules (Egress)
                EGRESS_RULES=$(aws ec2 describe-security-group-rules --region "$REGION" --profile "$PROFILE" --filters Name=group-id,Values="$SG" --query "SecurityGroupRules[?IsEgress==\`true\`].SecurityGroupRuleId" --output text)

                # Prompt for deletion of the rules and the Security Group
                echo "Do you want to delete the rules and Security Group '$SG_NAME' ($SG)? (yes/no):"
                read CONFIRMATION

                if [[ "$CONFIRMATION" == "yes" ]]; then
                    # Delete Ingress (Inbound) rules
                    if [ -n "$INGRESS_RULES" ]; then
                        for rule in $INGRESS_RULES; do
                            echo "Deleting Ingress Rule: $rule"
                            aws ec2 revoke-security-group-ingress --region "$REGION" --profile "$PROFILE" --group-id "$SG" --security-group-rule-ids "$rule" && echo "Deleted Ingress Rule: $rule"
                        done
                    else
                        echo "No Ingress rules found for Security Group '$SG_NAME'."
                    fi

                    # Delete Egress (Outbound) rules
                    if [ -n "$EGRESS_RULES" ]; then
                        for rule in $EGRESS_RULES; do
                            echo "Deleting Egress Rule: $rule"
                            aws ec2 revoke-security-group-egress --region "$REGION" --profile "$PROFILE" --group-id "$SG" --security-group-rule-ids "$rule" && echo "Deleted Egress Rule: $rule"
                        done
                    else
                        echo "No Egress rules found for Security Group '$SG_NAME'."
                    fi

                    # Delete the security group
                    echo "Deleting Security Group: $SG"
                    aws ec2 delete-security-group --region "$REGION" --profile "$PROFILE" --group-id "$SG" && echo "Deleted $SG"
                else
                    echo "Skipping deletion of rules and Security Group: $SG_NAME ($SG)"
                fi
            done
        fi
    fi
}

delete_security_groups

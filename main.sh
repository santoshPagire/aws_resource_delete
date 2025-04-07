#!/bin/bash

PATTERN=$1
PROFILE=$2

# 1.Deleting ASG, EC2, EFS, ECS
echo "Calling ASG-EC2-EFS-ECS-delete-1.sh script..."
./ASG-EC2-EFS-ECS-delete-1.sh "$PATTERN" "$PROFILE"
echo "***************************************************************************************************************"

# 2.Deleting Listeners, Target Groups, ALB, NLB
echo "Calling load_balancer_delete_2.sh script..."
./load_balancer_delete_2.sh "$PATTERN" "$PROFILE"
echo "***************************************************************************************************************"

# 3.Deleting rds
echo "Calling rds-delete-3.sh..."
./rds-delete-3.sh "$PATTERN" "$PROFILE"
echo "***************************************************************************************************************"

# 4.Deleting security groups
echo "Calling security-group-delete-4.sh..."
./security-group-delete-4.sh "$PATTERN" "$PROFILE"
echo "***************************************************************************************************************"

# 5.Deleting lambda function and redis cache
echo "Calling lambda-nd-redis-delete-5.sh..."
./lambda-nd-redis-delete-5.sh "$PATTERN" "$PROFILE"
echo "***************************************************************************************************************"

# 6.Deleting ssm parameter and cloudwatch log groups & alarms
echo "Calling ssm-nd-cloudwatch-delete-6.sh..."
./ssm-nd-cloudwatch-delete-6.sh "$PATTERN" "$PROFILE"
echo "***************************************************************************************************************"

echo "All scripts have been executed."
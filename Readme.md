
# AWS Resource Deletion Script

This repository contains a Bash script that helps automate the process of deleting various AWS resources, including Auto Scaling Groups (ASG), EC2 instances, EFS, ECS services, Load Balancers (ALB, NLB), RDS instances, security groups, Lambda functions, Redis caches, SSM parameters, and CloudWatch logs/alarms.

The main script orchestrates the execution of several deletion tasks by calling other specific scripts.

## Overview

The `main.sh` script is a comprehensive solution for cleaning up multiple AWS resources. It executes several other shell scripts in a sequence to delete different resources.

### What does this script do?

The main tasks the script performs include:

1. Deleting **ASG, EC2 instances, EFS, ECS services**.
2. Deleting **Listeners, Target Groups, ALB, NLB** (Load Balancers).
3. Deleting **RDS instances**.
4. Deleting **Security Groups**.
5. Deleting **Lambda functions and Redis cache**.
6. Deleting **SSM Parameters and CloudWatch log groups/alarms**.

Each of these tasks is handled by a separate script, and they are executed in order to ensure resources are cleaned up appropriately.

## Prerequisites

Before running the script, ensure you meet the following prerequisites:

- **AWS CLI** installed and configured.
- Access to the required AWS resources using an **AWS profile**.
- Bash environment to execute the script.
- Necessary IAM permissions to delete the respective AWS resources.

## Usage

### Step 1: Clone the repository
```bash
git clone https://github.com/your-repository/aws-resource-deletion.git
cd aws-resource-deletion
```

### Step 2: Provide input parameters

The script requires two input parameters when executed:
- `PATTERN`: A pattern used to match AWS resource names or IDs (e.g., part of an instance name or tag or environment name).
- `PROFILE`: The AWS CLI profile that provides credentials for the AWS account.

### Step 3: Execute the script

Run the script by passing the `PATTERN` and `PROFILE` parameters:

```bash
./main.sh <PATTERN> <PROFILE>
```

Example:
```bash
./main.sh "dev" "my-aws-profile"
```

This will delete all resources matching the `dev` pattern using the `my-aws-profile` credentials.

## Scripts Overview

### 1. [`ASG-EC2-EFS-ECS-delete-1.sh`](./scripts/ASG-EC2-EFS-ECS-delete-1.sh)
This script handles the deletion of Auto Scaling Groups (ASG), EC2 instances, EFS volumes, and ECS services.

### 2. [`load_balancer_delete_2.sh`](./scripts/load_balancer_delete_2.sh)
This script deletes the AWS Load Balancers (ALB and NLB), target groups, and listeners.

### 3. [`rds-delete-3.sh`](./scripts/rds-delete-3.sh)
This script deletes RDS instances.

### 4. [`security-group-delete-4.sh`](./scripts/security-group-delete-4.sh)
This script deletes security groups.

### 5. [`lambda-nd-redis-delete-5.sh`](./scripts/lambda-nd-redis-delete-5.sh)
This script deletes Lambda functions and Redis caches.

### 6. [`ssm-nd-cloudwatch-delete-6.sh`](./scripts/ssm-nd-cloudwatch-delete-6.sh)
This script deletes SSM parameters and CloudWatch log groups/alarms.


# AWS S3 Bucket Object Deletion Script

This repository contains a Bash script to delete objects from two specified AWS S3 buckets that match a given pattern. The script checks if the buckets exist, lists objects matching the pattern, and prompts for user confirmation before deleting them. It supports two buckets with optional folder paths.


To run the script, execute the following command:

(In this script user need to pass two bucket_names and aws_profile as a argument as below.) 

```bash
./s3_object-delete.sh <first-bucket-name> <second-bucket-name> <aws-profile>
```

For example:

```bash
./s3_object-delete.sh "my-first-bucket" "my-second-bucket" "my-aws-profile"
```

# AWS VPC Endpoint Deletion Script

This script automates the process of deleting AWS VPC (Interface & Gateway) endpoints that match a given pattern. The pattern is matched against the VPC Endpoint IDs, and the script will ask for confirmation before deleting any matching endpoints.

To run the script, use the following command:
(In this script user need to pass vpc_endpoint_id and aws_profile as a argument as below.) 

```bash
./delete_vpc_endpoints.sh <vpc-endpoint-id-pattern> <aws-profile>
```
For example:

```bash
./delete_vpc_endpoints.sh "vpce-12345678" "my-aws-profile"
```
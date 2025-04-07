#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <bucket-name>"
    exit 1
fi

REGION="us-east-1" 
FIRST_BUCKET_NAME=$1
SECOND_BUCKET_NAME=$2
PROFILE=$3
PATTERN="test"
FOLDER_PATH="env:/"


delete_object_first_bucket(){

    check_bucket_exists() {
        aws s3api head-bucket --bucket "$FIRST_BUCKET_NAME" --region "$REGION" --profile "$PROFILE" 2>/dev/null
    }
 
    delete_objects() {
    
        echo "Deleting all objects in the bucket: $FIRST_BUCKET_NAME that match the pattern '$PATTERN'"
        aws s3 rm "s3://$FIRST_BUCKET_NAME" --recursive --exclude "*" --include "*$PATTERN*" --region "$REGION" --profile "$PROFILE"
    }

    # Main script execution
    if check_bucket_exists; then
        echo "Bucket found with name: $FIRST_BUCKET_NAME"
        matching_objects=$(aws s3api list-objects-v2 --bucket "$FIRST_BUCKET_NAME" --query "Contents[?contains(Key, '$PATTERN')].Key" --output text --region "$REGION" --profile "$PROFILE")

        if [ -z "$matching_objects" ]; then
            echo "No objects found in '$FIRST_BUCKET_NAME' matching the pattern '$PATTERN'."
            return
        fi
        
        echo "Following objects found in $FIRST_BUCKET_NAME which match the given pattern:"
        echo "$matching_objects"

        read -p "Do you want to delete all objects in this bucket that match the pattern '$PATTERN'? (yes/no): " confirm

        if [[ "$confirm" == "yes" ]]; then
            delete_objects

            # Check if the objects were deleted successfully
            if [ $? -eq 0 ]; then
                echo "Objects in the bucket '$FIRST_BUCKET_NAME' that match the pattern '$PATTERN' have been deleted successfully."
            else
                echo "Failed to delete objects in the bucket '$FIRST_BUCKET_NAME' that match the pattern '$PATTERN'."
            fi
        else
            echo "No objects were deleted from the bucket '$FIRST_BUCKET_NAME'."
        fi
    else
        echo "Bucket '$FIRST_BUCKET_NAME' does not exist."
        return
    fi
}


delete_object_second_bucket(){

    check_bucket_exists() {
        aws s3api head-bucket --bucket "$SECOND_BUCKET_NAME" --region "$REGION" --profile "$PROFILE" 2>/dev/null
    }


    delete_objects() {
        echo "Deleting all objects in the bucket: $SECOND_BUCKET_NAME/$FOLDER_PATH that match the pattern '$PATTERN'"
        aws s3 rm "s3://$SECOND_BUCKET_NAME/$FOLDER_PATH" --recursive --exclude "*" --include "*$PATTERN*" --region "$REGION" --profile "$PROFILE"
    }

    # Main script execution
    if check_bucket_exists; then
        echo "Bucket found with name: $SECOND_BUCKET_NAME"
        
        matching_objects=$(aws s3api list-objects-v2 --bucket "$SECOND_BUCKET_NAME" --prefix "$FOLDER_PATH" --query "Contents[?contains(Key, '$PATTERN')].Key" --output text --region "$REGION" --profile "$PROFILE")
        
        if [ -z "$matching_objects" ]; then
            echo "No objects found in '$SECOND_BUCKET_NAME/$FOLDER_PATH' matching the pattern '$PATTERN'."
            return
        fi
        
        echo "Following objects found in $SECOND_BUCKET_NAME/$FOLDER_PATH which match the given pattern:"
        echo "$matching_objects"
        
        read -p "Do you want to delete all objects in this folder that match the pattern '$PATTERN'? (yes/no): " confirm

        if [[ "$confirm" == "yes" ]]; then
            delete_objects

            if [ $? -eq 0 ]; then
                echo "Objects in the bucket '$SECOND_BUCKET_NAME/$FOLDER_PATH' that match the pattern '$PATTERN' have been deleted successfully."
            else
                echo "Failed to delete objects in the bucket '$SECOND_BUCKET_NAME/$FOLDER_PATH' that match the pattern '$PATTERN'."
            fi
        else
            echo "No objects were deleted from the bucket '$SECOND_BUCKET_NAME/$FOLDER_PATH'."
        fi
    else
        echo "Bucket '$SECOND_BUCKET_NAME' does not exist."
        return
    fi
}

delete_object_first_bucket
delete_object_second_bucket
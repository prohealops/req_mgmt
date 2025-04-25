#!/bin/bash

# Check if required parameters are provided
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Usage: $0 <request_number> [password]"
    echo "  If password is not provided, it will use the REQUEST_NUMBER"
    exit 1
fi

REQ_NUMBER="$1"
PASSWORD="${2:-$REQ_NUMBER}"  # Use second parameter if provided, otherwise use request number

# ----------------------------
# Config Section
# ----------------------------
BUCKET_NAME="ank-courier-healops"
MOUNT_POINT="/home/ubuntu/s3bucket1"
S3_URL="https://s3.amazonaws.com"
LOG_FILE="/var/log/s3_mount.log"
# ServiceNow Configuration - updated to match sanity_mount_s3.sh
SERVICENOW_INSTANCE="dev303944.service-now.com"
SERVICENOW_API_URL="https://$SERVICENOW_INSTANCE/api/now/table/sc_request"
SERVICENOW_USER="admin"
SERVICENOW_PASS="$PASSWORD"
# ----------------------------

# Timestamp function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "==== Starting S3 bucket mount script for request $REQ_NUMBER ===="

# Update ServiceNow ticket to work in progress
log "Updating ServiceNow ticket $REQ_NUMBER to work in progress"

# First, get the sys_id for the request
SYS_ID=$(curl -s -X GET \
    -u "$SERVICENOW_USER:$SERVICENOW_PASS" \
    -H "Accept: application/json" \
    "$SERVICENOW_API_URL?sysparm_query=number=$REQ_NUMBER&sysparm_fields=sys_id" \
    | grep -o '"sys_id":"[^"]*' | cut -d'"' -f4)

if [ -z "$SYS_ID" ]; then
    log "ERROR: Failed to get sys_id for request $REQ_NUMBER"
    # Continue with the script even if the update fails
else
    log "Found sys_id: $SYS_ID"
    
    # Update the ticket to in progress
    update_response=$(curl -s -X PUT \
        -u "$SERVICENOW_USER:$SERVICENOW_PASS" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d '{"state":2,"comments":"S3 bucket mount process started","request_state":"in_progress"}' \
        "$SERVICENOW_API_URL/$SYS_ID")
    
    if echo "$update_response" | grep -q "sys_id"; then
        log "ServiceNow ticket updated successfully"
    else
        log "Warning: Failed to update ServiceNow ticket"
        log "Response: $update_response"
        # Continue with the script even if the update fails
    fi
fi

# Check if s3fs is installed
if ! command -v s3fs >/dev/null 2>&1; then
    log "s3fs not installed. Exiting."
    exit 1
fi

# Check if mount point exists, create if not
if [ ! -d "$MOUNT_POINT" ]; then
    log "Mount point $MOUNT_POINT does not exist. Creating..."
    mkdir -p "$MOUNT_POINT"
fi

# Check if already mounted
if mount | grep "on $MOUNT_POINT type fuse.s3fs" > /dev/null; then
    log "Bucket already mounted on $MOUNT_POINT"
else
    log "Mounting bucket $BUCKET_NAME to $MOUNT_POINT"
    s3fs "$BUCKET_NAME" "$MOUNT_POINT" 

    if [ $? -eq 0 ]; then
        log "Successfully mounted $BUCKET_NAME"
    else
        log "Mount failed. Check credentials or network."
    fi
fi

log "==== Script finished ===="
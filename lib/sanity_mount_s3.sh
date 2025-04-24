#!/bin/bash
# Parse command line arguments
if [ $# -ne 2 ]; then
  echo "Usage: $0 REQUEST_NUMBER PASSWORD"
  echo "  REQUEST_NUMBER: ServiceNow request number"
  echo "  PASSWORD: ServiceNow password"
  echo ""
  echo "Error: Both parameters are required"
  exit 1
fi

REQUEST_NUMBER="$1"
PASSWORD="$2"
echo "Using ServiceNow request: $REQUEST_NUMBER"

# File: /Users/anksoni/Documents/Repositories/req_mgmt/lib/sanity_mount_s3.sh
# Script to check if S3 bucket is mounted and update ServiceNow ticket accordingly

# ----------------------------
# Config Section
# ----------------------------
# ServiceNow Configuration
INSTANCE="dev303944.service-now.com"
USERNAME="admin"


# S3 Configuration
BUCKET_NAME="ank-courier-healops"
MOUNT_POINT="/home/ubuntu/s3bucket1"
LOG_FILE="/var/log/s3_mount_sanity.log"
# ----------------------------

# Timestamp function for logging
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to check if the S3 bucket is properly mounted
check_mount() {
  log "Checking if $BUCKET_NAME is mounted at $MOUNT_POINT..."
  
  # Check if mount point exists
  if [ ! -d "$MOUNT_POINT" ]; then
    log "ERROR: Mount point $MOUNT_POINT does not exist"
    return 1
  fi
  
  # Check if it's mounted using s3fs
  if ! mount | grep "on $MOUNT_POINT type fuse.s3fs" > /dev/null; then
    log "ERROR: $BUCKET_NAME is not mounted on $MOUNT_POINT"
    return 1
  fi
  
  # Try to write a test file to verify write access
  TEST_FILE="$MOUNT_POINT/.mount_test_$(date +%s)"
  if ! touch "$TEST_FILE" 2>/dev/null; then
    log "ERROR: Cannot write to mount point $MOUNT_POINT"
    return 1
  fi
  
  # Clean up test file
  rm -f "$TEST_FILE" 2>/dev/null
  
  log "SUCCESS: $BUCKET_NAME is properly mounted at $MOUNT_POINT"
  return 0
}

# Function to update ServiceNow ticket
update_ticket() {
  local status=$1
  local update_data=""
  
  log "Getting sys_id for request $REQUEST_NUMBER..."
  
  # Get the sys_id of the request
  SYS_ID=$(curl -s -X GET \
     -u "$USERNAME":"$PASSWORD" \
     -H "Accept: application/json" \
     "https://$INSTANCE/api/now/table/sc_request?sysparm_query=number=$REQUEST_NUMBER&sysparm_fields=sys_id" \
     | grep -o '"sys_id":"[^"]*' | cut -d'"' -f4)
  
  if [ -z "$SYS_ID" ]; then
    log "ERROR: Failed to get sys_id for request $REQUEST_NUMBER"
    return 1
  fi
  
  log "Found sys_id: $SYS_ID"
  
  # Prepare update data based on mount status
  if [ "$status" -eq 0 ]; then
    log "Updating ticket to closed_complete"
    update_data='{"state":3,"close_code":"Completed Successfully","close_notes":"Automated closure: S3 bucket successfully mounted","request_state":"closed_complete"}'
  else
    log "Updating ticket to in progress"
    update_data='{"state":4,"comments":"S3 bucket mount check failed. Please check logs for details.","request_state":"in_progress"}'
  fi
  
  # Update the request
  response=$(curl -s -X PUT \
     -u "$USERNAME":"$PASSWORD" \
     -H "Content-Type: application/json" \
     -H "Accept: application/json" \
     -d "$update_data" \
     "https://$INSTANCE/api/now/table/sc_request/$SYS_ID")
  
  if echo "$response" | grep -q "sys_id"; then
    log "ServiceNow ticket updated successfully"
    return 0
  else
    log "ERROR: Failed to update ServiceNow ticket. Response: $response"
    return 1
  fi
}

# Main script execution
log "==== Starting S3 mount sanity check script ===="

# Check if the S3 bucket is mounted
check_mount
mount_status=$?

# Update ServiceNow ticket based on mount status
update_ticket $mount_status
ticket_status=$?

# Final status message
if [ $mount_status -eq 0 ] && [ $ticket_status -eq 0 ]; then
  log "==== S3 mount verified and ticket updated successfully ===="
  exit 0
else
  log "==== Script completed with errors. Check logs for details. ===="
  exit 1
fi
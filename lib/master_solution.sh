#!/bin/bash

# Enable error handling
set -e  # Exit immediately if a command exits with a non-zero status
set -u  # Treat unset variables as an error
set -o pipefail  # Catch errors in pipelines

# Global variables
DEBUG=true
LOG_FILE="/tmp/default.log"
ACCESS_KEY="YTZIPMUCE0HGVLQD1KWS"
SECRET_KEY="nnvOrq9Rg91TTpsztcYmcCX9CYTlZDxDLa5tIkQY"
STATE="random-string"

# Initialize log file based on the request number
initialize_logging() {
  local req_num="$1"
  LOG_FILE="/tmp/${req_num}.log"
  echo "Initializing log file at ${LOG_FILE}" > "${LOG_FILE}"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Script execution started" >> "${LOG_FILE}"
}

# Log function to write to both console and log file
log() {
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  local message="[${timestamp}] $1"
  
  if [[ "$DEBUG" == "true" ]]; then
    echo "[DEBUG] $1"
  fi
  
  # Always write to log file regardless of DEBUG setting
  echo "${message}" >> "${LOG_FILE}"
}

# Function to get access token
get_access_token() {
  local LOGIN_URL="http://ankchef360.success.chef.co:31000/platform/user-accounts/v1/user/api-token/login"
  log "Login URL: $LOGIN_URL"

  local LOGIN_PAYLOAD=$(jq -n \
    --arg accessKey "$ACCESS_KEY" \
    --arg secretKey "$SECRET_KEY" \
    --arg state "$STATE" \
    '{accessKey: $accessKey, secretKey: $secretKey, state: $state}')
  log "Login payload: $LOGIN_PAYLOAD"

  local LOGIN_RESPONSE=$(curl -s -X POST "$LOGIN_URL" \
    -H "Content-Type: application/json" \
    -d "$LOGIN_PAYLOAD")
  log "Login response: $LOGIN_RESPONSE"

  local OAUTH_CODE=$(echo "$LOGIN_RESPONSE" | jq -r '.item.oauthCode')
  log "OAuth code: $OAUTH_CODE"

  if [[ -z "$OAUTH_CODE" || "$OAUTH_CODE" == "null" ]]; then
    echo "Error: Failed to fetch oauthCode."
    return 1
  fi

  local JWT_URL="http://ankchef360.success.chef.co:31000/platform/user-accounts/v1/user/api-token/jwt"
  log "JWT URL: $JWT_URL"

  local JWT_PAYLOAD=$(jq -n \
    --arg oauthCode "$OAUTH_CODE" \
    --arg state "$STATE" \
    '{oauthCode: $oauthCode, state: $state}')
  log "JWT payload: $JWT_PAYLOAD"

  local JWT_RESPONSE=$(curl -s -X POST "$JWT_URL" \
    -H "Content-Type: application/json" \
    -d "$JWT_PAYLOAD")
  log "JWT response: $JWT_RESPONSE"

  local ACCESS_TOKEN=$(echo "$JWT_RESPONSE" | jq -r '.item.accessToken')
  log "Access token: $ACCESS_TOKEN"

  if [[ -z "$ACCESS_TOKEN" || "$ACCESS_TOKEN" == "null" ]]; then
    echo "Error: Failed to fetch accessToken."
    return 1
  fi
  
  echo "$ACCESS_TOKEN"
}

# Function to resolve node ID from IP address
get_node_id() {
  local server_ip="$1"
  
  log "Server IP: $server_ip"
  if [[ -z "$server_ip" || "$server_ip" == "null" ]]; then
    echo "Error: Invalid server IP."
    return 1
  fi

  local NODE_ID_SCRIPT="/tmp/nodeID_resolve.sh"
  wget -q -O "$NODE_ID_SCRIPT" "https://raw.githubusercontent.com/prohealops/req_mgmt/refs/heads/main/lib/nodeID_resolve.sh"
  chmod +x "$NODE_ID_SCRIPT"
  log "Fetched and prepared nodeID_resolve.sh script."

  local node_id=$("$NODE_ID_SCRIPT" "$server_ip")
  log "Resolved node ID: $node_id"

  if [[ -z "$node_id" || "$node_id" == "null" ]]; then
    echo "Error: Failed to resolve node ID for IP $server_ip."
    return 1
  fi
  
  echo "$node_id"
}

# Function to download scheduler template
get_scheduler_template() {
  local template_path="/tmp/scheduler_payload_template.json"
  wget -q -O "$template_path" "https://raw.githubusercontent.com/prohealops/req_mgmt/refs/heads/main/courier_jobs/scheduler_payload_template.json"
  
  if [[ ! -f "$template_path" ]]; then
    echo "Error: Scheduler payload template not found at $template_path."
    return 1
  fi
  
  echo "$template_path"
}

# Function to execute courier job
execute_courier_job() {
  local job_name="$1"
  local node_id="$2"
  local access_token="$3"
  local cmd_array="$4"
  local template_path="$5"
  
  log "Creating job: $job_name"
  
  local SCHEDULER_URL="http://ankchef360.success.chef.co:31000/courier/scheduler-api/v1/jobs"
  log "Scheduler URL: $SCHEDULER_URL"
  
  local payload=$(jq \
    --arg jobName "$job_name" \
    --arg nodeID "$node_id" \
    --argjson cmdArray "$cmd_array" \
    '.name = $jobName |
     .target.groups[0].nodeIdentifiers[0] = $nodeID |
     .actions.steps[0].command.linux = $cmdArray' \
    "$template_path")
  
  log "Job payload: $payload"
  
  local response=$(curl -s -X POST "$SCHEDULER_URL" \
    -H "Authorization: Bearer $access_token" \
    -H "Content-Type: application/json" \
    -d "$payload")
  log "Job response: $response"
  
  echo "$response"
}

# Main function
main() {
  # Check if the ServiceNow request number is passed as an argument
  if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <ServiceNow Request Number>"
    exit 1
  fi

  local REQ_NUMBER="$1"
  initialize_logging "$REQ_NUMBER"
  log "Request number: $REQ_NUMBER"

  local SEARCH_DIR="/tmp"
  local JSON_FILE="$SEARCH_DIR/${REQ_NUMBER}.json"
  log "Looking for JSON file at: $JSON_FILE"

  if [[ ! -f "$JSON_FILE" ]]; then
    echo "Error: File $JSON_FILE does not exist."
    exit 1
  fi

  local catalogName=$(jq -r '.catalogName' "$JSON_FILE" 2>/dev/null)
  log "Extracted catalogName: $catalogName"

  if [[ "$catalogName" == "S3 Bucket Mapping in Windows Machine" ]]; then
    log "Catalog name matches the required value."

    # Get the access token
    local ACCESS_TOKEN=$(get_access_token)
    if [[ $? -ne 0 ]]; then
      echo "Error: Failed to get access token."
      exit 1
    fi

    # Get server IP and node ID
    local SERVER_IP=$(jq -r '.variables.ip_address' "$JSON_FILE")
    local NODE_ID=$(get_node_id "$SERVER_IP")
    if [[ $? -ne 0 ]]; then
      exit 1
    fi

    # Get scheduler template
    local SCHEDULER_TEMPLATE=$(get_scheduler_template)
    if [[ $? -ne 0 ]]; then
      exit 1
    fi

    # Create and execute initial job
    local INITIAL_JOB_NAME="${REQ_NUMBER}_RECEIVED"
    local INITIAL_CMD_ARRAY='[
      "echo '\''{\\\"requestNumber\\\": \\\"'$REQ_NUMBER'\\\"}'\'' > /tmp/'$REQ_NUMBER'.json",
      "[ ! -f /home/ubuntu/create_mount_s3.sh ] || sudo rm -f /home/ubuntu/create_mount_s3.sh",
      "sudo wget -P /home/ubuntu/ https://raw.githubusercontent.com/prohealops/req_mgmt/refs/heads/main/lib/create_mount_s3.sh",
      "sudo chmod +x /home/ubuntu/create_mount_s3.sh",
      "sudo /home/ubuntu/create_mount_s3.sh"
    ]'
    
    local INITIAL_JOB_RESPONSE=$(execute_courier_job "$INITIAL_JOB_NAME" "$NODE_ID" "$ACCESS_TOKEN" "$INITIAL_CMD_ARRAY" "$SCHEDULER_TEMPLATE")
    echo "Courier job response: $INITIAL_JOB_RESPONSE"
    
    # Sleep for 2 minutes before running the sanity check
    log "Sleeping for 2 minutes before running sanity check..."
    sleep 120
    
    # Create and execute sanity check job
    local SANITY_JOB_NAME="${REQ_NUMBER}_Sanity"
    local SANITY_PASSWORD="Password123"
    local SANITY_CMD_ARRAY='[
      "[ ! -f /home/ubuntu/sanity_mount_s3.sh ] || sudo rm -f /home/ubuntu/sanity_mount_s3.sh",
      "sudo wget -P /home/ubuntu/ https://raw.githubusercontent.com/prohealops/req_mgmt/refs/heads/main/lib/sanity_mount_s3.sh",
      "sudo chmod +x /home/ubuntu/sanity_mount_s3.sh",
      "sudo /home/ubuntu/sanity_mount_s3.sh '$REQ_NUMBER' '\''$SANITY_PASSWORD'\''"
    ]'
    
    local SANITY_JOB_RESPONSE=$(execute_courier_job "$SANITY_JOB_NAME" "$NODE_ID" "$ACCESS_TOKEN" "$SANITY_CMD_ARRAY" "$SCHEDULER_TEMPLATE")
    echo "Sanity check job response: $SANITY_JOB_RESPONSE"
  else
    echo "catalogName does not match the required value."
  fi
}

# Execute main function
main "$@"
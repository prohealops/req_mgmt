#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status
set -u  # Treat unset variables as an error
set -o pipefail  # Catch errors in pipelines

# Enable verbose logging
DEBUG=true

log() {
  if [[ "$DEBUG" == "true" ]]; then
    echo "[DEBUG] $1"
  fi
}

# Check if the ServerNow request number is passed as an argument
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <ServerNow Request Number>"
  exit 1
fi

REQ_NUMBER="$1"
log "Request number: $REQ_NUMBER"

SEARCH_DIR="/tmp"
JSON_FILE="$SEARCH_DIR/${REQ_NUMBER}.json"
log "Looking for JSON file at: $JSON_FILE"

if [[ ! -f "$JSON_FILE" ]]; then
  echo "Error: File $JSON_FILE does not exist."
  exit 1
fi

catalogName=$(jq -r '.catalogName' "$JSON_FILE" 2>/dev/null)
log "Extracted catalogName: $catalogName"

if [[ "$catalogName" == "S3 Bucket Mapping in Windows Machine" ]]; then
  log "Catalog name matches the required value."

  ACCESS_KEY="YTZIPMUCE0HGVLQD1KWS"
  SECRET_KEY="nnvOrq9Rg91TTpsztcYmcCX9CYTlZDxDLa5tIkQY"
  STATE="random-string"

  LOGIN_URL="http://ankchef360.success.chef.co:31000/platform/user-accounts/v1/user/api-token/login"
  log "Login URL: $LOGIN_URL"

  LOGIN_PAYLOAD=$(jq -n \
    --arg accessKey "$ACCESS_KEY" \
    --arg secretKey "$SECRET_KEY" \
    --arg state "$STATE" \
    '{accessKey: $accessKey, secretKey: $secretKey, state: $state}')
  log "Login payload: $LOGIN_PAYLOAD"

  LOGIN_RESPONSE=$(curl -s -X POST "$LOGIN_URL" \
    -H "Content-Type: application/json" \
    -d "$LOGIN_PAYLOAD")
  log "Login response: $LOGIN_RESPONSE"

  OAUTH_CODE=$(echo "$LOGIN_RESPONSE" | jq -r '.item.oauthCode')
  log "OAuth code: $OAUTH_CODE"

  if [[ -z "$OAUTH_CODE" || "$OAUTH_CODE" == "null" ]]; then
    echo "Error: Failed to fetch oauthCode."
    exit 1
  fi

  JWT_URL="http://ankchef360.success.chef.co:31000/platform/user-accounts/v1/user/api-token/jwt"
  log "JWT URL: $JWT_URL"

  JWT_PAYLOAD=$(jq -n \
    --arg oauthCode "$OAUTH_CODE" \
    --arg state "$STATE" \
    '{oauthCode: $oauthCode, state: $state}')
  log "JWT payload: $JWT_PAYLOAD"

  JWT_RESPONSE=$(curl -s -X POST "$JWT_URL" \
    -H "Content-Type: application/json" \
    -d "$JWT_PAYLOAD")
  log "JWT response: $JWT_RESPONSE"

  ACCESS_TOKEN=$(echo "$JWT_RESPONSE" | jq -r '.item.accessToken')
  log "Access token: $ACCESS_TOKEN"

  if [[ -z "$ACCESS_TOKEN" || "$ACCESS_TOKEN" == "null" ]]; then
    echo "Error: Failed to fetch accessToken."
    exit 1
  fi

  SERVER_IP=$(jq -r '.variables.ip_address' "$JSON_FILE")
  log "Server IP: $SERVER_IP"

  if [[ -z "$SERVER_IP" || "$SERVER_IP" == "null" ]]; then
    echo "Error: Failed to fetch server IP from JSON file."
    exit 1
  fi

  NODE_ID_SCRIPT="/tmp/nodeID_resolve.sh"
  wget -q -O "$NODE_ID_SCRIPT" "https://raw.githubusercontent.com/prohealops/req_mgmt/refs/heads/main/lib/nodeID_resolve.sh"
  chmod +x "$NODE_ID_SCRIPT"
  log "Fetched and prepared nodeID_resolve.sh script."

  NODE_ID=$("$NODE_ID_SCRIPT" "$SERVER_IP")
  log "Resolved node ID: $NODE_ID"

  if [[ -z "$NODE_ID" || "$NODE_ID" == "null" ]]; then
    echo "Error: Failed to resolve node ID for IP $SERVER_IP."
    exit 1
  fi

  SCHEDULER_URL="http://ankchef360.success.chef.co:31000/courier/scheduler-api/v1/jobs"
  log "Scheduler URL: $SCHEDULER_URL"

  SCHEDULER_TEMPLATE="/tmp/scheduler_payload_template.json"
  wget -q -O "$SCHEDULER_TEMPLATE" "https://raw.githubusercontent.com/prohealops/req_mgmt/refs/heads/main/courier_jobs/scheduler_payload_template.json"
  if [[ ! -f "$SCHEDULER_TEMPLATE" ]]; then
    echo "Error: Scheduler payload template not found at $SCHEDULER_TEMPLATE."
    exit 1
  fi

  # Replace placeholders in the JSON template
  SCHEDULER_PAYLOAD=$(jq \
    --arg reqNumber "$REQ_NUMBER" \
    --arg nodeID "$NODE_ID" \
    --arg cmd "echo '{\\\"requestNumber\\\": \\\"$REQ_NUMBER\\\"}' > /tmp/$REQ_NUMBER.json" \
    '.name = $reqNumber |
     .target.groups[0].nodeIdentifiers[0] = $nodeID |
     .actions.steps[0].command.linux[0] = $cmd' \
    "$SCHEDULER_TEMPLATE")

  log "Scheduler payload: $SCHEDULER_PAYLOAD"

  SCHEDULER_RESPONSE=$(curl -s -X POST "$SCHEDULER_URL" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$SCHEDULER_PAYLOAD")
  log "Scheduler response: $SCHEDULER_RESPONSE"

  echo "Courier job response: $SCHEDULER_RESPONSE"
else
  echo "catalogName does not match the required value."
fi
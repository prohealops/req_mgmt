#!/bin/bash

ACCESS_KEY="YTZIPMUCE0HGVLQD1KWS"
SECRET_KEY="nnvOrq9Rg91TTpsztcYmcCX9CYTlZDxDLa5tIkQY"
STATE="random-string"

BASE_URL="http://ankchef360.success.chef.co:31000"

# Check if the IP/FQDN is passed as an argument
if [[ -z "$1" ]]; then
  echo "❌ Usage: $0 <TARGET_FQDN>"
  exit 1
fi

TARGET_FQDN="$1" # The IP/FQDN to search for

# Function to make HTTP requests
make_request() {
  local method=$1
  local url=$2
  local data=$3
  shift 3
  local headers=("$@")
  curl -s -X "$method" "$url" -H "Content-Type: application/json" "${headers[@]}" -d "$data"
}

# Step 1: Get oauthCode
login_response=$(make_request "POST" "$BASE_URL/platform/user-accounts/v1/user/api-token/login" \
  "{\"accessKey\":\"$ACCESS_KEY\",\"secretKey\":\"$SECRET_KEY\",\"state\":\"$STATE\"}" "")
oauth_code=$(echo "$login_response" | jq -r '.item.oauthCode')
if [[ -z "$oauth_code" || "$oauth_code" == "null" ]]; then
  echo "❌ OAuth code not found"
  exit 1
fi

# Step 2: Get accessToken
token_response=$(make_request "POST" "$BASE_URL/platform/user-accounts/v1/user/api-token/jwt" \
  "{\"oauthCode\":\"$oauth_code\",\"state\":\"$STATE\"}" "")
access_token=$(echo "$token_response" | jq -r '.item.accessToken')
if [[ -z "$access_token" || "$access_token" == "null" ]]; then
  echo "❌ Access token not found"
  exit 1
fi

# Step 3: Paginated node fetch to find node by FQDN attribute
current_page=1
page_size=10
matched_node_id=""

while true; do
  nodes_response=$(make_request "GET" "$BASE_URL/node/management/v1/nodes?pagination.page=$current_page&pagination.size=$page_size" \
    "" "-H" "Authorization: Bearer $access_token")

  if [[ -z "$nodes_response" || "$nodes_response" == "null" ]]; then
    echo "❌ Failed to fetch nodes. Response: $nodes_response"
    exit 1
  fi

  echo "$nodes_response" | jq -c '.items[]' > /tmp/nodes.json

  # Check if there are no items in the current page
  items_count=$(echo "$nodes_response" | jq '.items | length')
  if [[ "$items_count" -eq 0 ]]; then
    break
  fi

  while read -r node; do
    fqdn_attr=$(echo "$node" | jq -r '.attributes[]? | select(.name == "fqdn") | .value // empty')
    if [[ "$fqdn_attr" == "$TARGET_FQDN" ]]; then
      matched_node_id=$(echo "$node" | jq -r '.id // empty')
      break 2
    fi
  done < <(cat /tmp/nodes.json)

  # Increment the page number
  ((current_page++))
done

if [[ -z "$matched_node_id" ]]; then
  echo "NA"
else
  echo "$matched_node_id"
fi
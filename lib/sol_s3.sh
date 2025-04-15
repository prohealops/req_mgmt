#!/bin/bash

# Check if REQ number is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <REQ_NUMBER>"
  exit 1
fi

REQ_NUMBER=$1
JSON_FILE="/tmp/${REQ_NUMBER}.json"

# Check if JSON file exists
if [ ! -f "$JSON_FILE" ]; then
  echo "JSON file $JSON_FILE not found!"
  exit 1
fi

# Read JSON file and extract required fields
IP_ADDRESS=$(jq -r '.variables.ip_address' "$JSON_FILE")
S3_BUCKET_NAME=$(jq -r '.variables.s3_bucket_name' "$JSON_FILE")

if [ -z "$IP_ADDRESS" ] || [ "$IP_ADDRESS" == "null" ]; then
  echo "IP address not found in JSON file!"
  exit 1
fi

if [ -z "$S3_BUCKET_NAME" ] || [ "$S3_BUCKET_NAME" == "null" ]; then
  echo "S3 bucket name not found in JSON file!"
  exit 1
fi

# Resolve NodeID
NODE_ID=$(./nodeID_resolve.sh "$IP_ADDRESS")

if [ "$NODE_ID" == "NA" ]; then
  echo "NA"
  exit 0
fi

# Create new JSON file with NodeID and S3 bucket name
NEW_JSON_FILE="request_${REQ_NUMBER}.json"
cat > "$NEW_JSON_FILE" <<EOF
{
  "name": "Request for Vulnerability Scan v1",
  "description": "Identifies the vulnerabilities on the servers",
  "scheduleRule": "immediate",
  "exceptionRules": [],
  "target": {
    "executionType": "parallel",
    "groups": [
      {
        "timeoutSeconds": 600,
        "batchSize": {
          "type": "number",
          "value": 5
        },
        "distributionMethod": "batching",
        "successCriteria": [
          {
            "numRuns": { "type": "percent", "value": 100 },
            "status": "success"
          }
        ],
        "nodeListType": "nodes",
        "nodeIdentifiers": [
          "$NODE_ID"
        ]
      }
    ]
  },
  "actions": {
    "accessMode": "agent",
    "steps": [
      {
        "name": "Analyze Request requirements and resolve NodeID",
        "interpreter": {
          "skill": {
            "minVersion": "1.0.0"
          },
          "name": "chef-platform/shell-interpreter"
        },
        "command": {
          "linux": [
            "sudo bash -c 'mkdir -p /home/ubuntu/reports; sudo inspec exec https://github.com/AkashKhurana3092/ubuntu_compliance --reporter json > /home/ubuntu/reports/log.json'"
          ]
        },
        "inputs": {},
        "expectedInputs": {},
        "outputFieldRules": {},
        "retryCount": 1,
        "failureBehavior": {
          "action": "retryThenIgnore",
          "retryBackoffStrategy": {
            "type": "linear",
            "delaySeconds": 1,
            "arguments": [1, 3, 5]
          }
        },
        "limits": {},
        "conditions": []
      },
      {
        "name": "Execution of Request",
        "interpreter": {
          "skill": {
            "minVersion": "1.0.0"
          },
          "name": "chef-platform/shell-interpreter"
        },
        "command": {
          "linux": [
            "sudo wget -P /home/ubuntu/ https://raw.githubusercontent.com/ankit100ni/auto_heal/refs/heads/main/job_scripts/create_mount_s3.sh; sudo chmod +x /home/ubuntu/create_mount_s3.sh; sudo /home/ubuntu/create_mount_s3.sh $S3_BUCKET_NAME"
          ]
        },
        "inputs": {},
        "expectedInputs": {},
        "outputFieldRules": {},
        "retryCount": 2,
        "failureBehavior": {
          "action": "retryThenFail",
          "retryBackoffStrategy": {
            "type": "linear",
            "delaySeconds": 1,
            "arguments": [1, 3, 5]
          }
        },
        "limits": {},
        "conditions": []
      }
    ]
  }
}
EOF

echo "New JSON file created: $NEW_JSON_FILE"
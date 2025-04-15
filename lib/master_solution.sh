#!/bin/bash

# Directory to search for JSON files
SEARCH_DIR="/tmp"

# URL of the sol_s3.sh script
SOL_S3_URL="https://raw.githubusercontent.com/prohealops/req_mgmt/refs/heads/main/lib/sol_s3.sh"

# Loop through all JSON files starting with "REQ" in the specified directory
for file in "$SEARCH_DIR"/REQ*.json; do
  # Check if the file exists (in case no files match the pattern)
  if [[ -f "$file" ]]; then
    # Extract the value of "catalogName" from the JSON file
    catalogName=$(jq -r '.catalogName' "$file" 2>/dev/null)

    # Check if the catalogName matches the desired value
    if [[ "$catalogName" == "S3 Bucket Mapping in Windows Machine" ]]; then
      # Download the sol_s3.sh script
      curl -s -o /tmp/sol_s3.sh "$SOL_S3_URL"

      # Make the script executable
      chmod +x /tmp/sol_s3.sh

      # Execute the script
      /tmp/sol_s3.sh REQXXXX

      # Delete the script after execution
      rm -f /tmp/sol_s3.sh
    fi
  fi
done
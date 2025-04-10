#!/bin/bash

# Directory to search for JSON files
SEARCH_DIR="/tmp"

# Loop through all JSON files starting with "REQ" in the specified directory
for file in "$SEARCH_DIR"/REQ*.json; do
  # Check if the file exists (in case no files match the pattern)
  if [[ -f "$file" ]]; then
    # Extract the value of "catalogName" from the JSON file
    catalogName=$(jq -r '.catalogName' "$file" 2>/dev/null)

    # Check if the catalogName matches the desired value
    if [[ "$catalogName" == "S3 Bucket Mapping in Windows Machine" ]]; then
      # Execute the sol_s3.sh script
      ./sol_s3.sh
    fi
  fi
done
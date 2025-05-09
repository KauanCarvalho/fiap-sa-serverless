#!/bin/bash

# Function to check if required dependencies are installed
check_dependencies() {
    # Check if jq is installed
    if ! command -v jq &> /dev/null
    then
        echo -e "\033[31mError: jq is not installed. Please install jq to proceed.\033[0m"
        exit 1
    fi
    # Check if curl is installed
    if ! command -v curl &> /dev/null
    then
        echo -e "\033[31mError: curl is not installed. Please install curl to proceed.\033[0m"
        exit 1
    fi
}

# Function to print status and body with color-coded output
print_response() {
    local status_code=$1
    local body=$2

    if [[ "$status_code" -ge 200 && "$status_code" -lt 300 ]]; then
        echo -e "\033[32mStatus: $status_code\033[0m"  # Green for 200-299
    elif [[ "$status_code" -ge 400 && "$status_code" -lt 500 ]]; then
        echo -e "\033[34mStatus: $status_code\033[0m"  # Blue for 400-499
    else
        echo -e "\033[31mStatus: $status_code\033[0m"  # Red for all others
    fi

    if [[ -z "$body" ]]; then
        echo -e "\033[33mNo Body\033[0m"
    else
        # Check if the body is a valid JSON before attempting to parse it
        echo "$body" | jq empty &>/dev/null
        if [ $? -eq 0 ]; then
            # Pretty print the JSON body
            echo -e "$body" | jq .
        else
            # If it's not a valid JSON, just print it as it is
            echo -e "$body"
        fi
    fi
}

# Main script starts here

# Validate inputs
BASE_URL="$1"
EXTERNAL_REF="$2"
STATUS="${3:-completed}"  # Default status is 'completed'

# Validate required inputs
if [ -z "$BASE_URL" ] || [ -z "$EXTERNAL_REF" ]; then
  echo -e "\033[31mError: base_url and external_ref are required.\033[0m"
  echo "Usage: $0 <base_url> <external_ref> [status]"
  exit 1
fi

# Check if the required dependencies are installed
check_dependencies

# Compose full URL
URL="${BASE_URL}/prod/webhook_events"

# Construct JSON payload
DATA=$(jq -n \
  --arg ref "$EXTERNAL_REF" \
  --arg status "$STATUS" \
  '{external_reference: $ref, status: $status}')

# Send POST request and capture response and status code
response=$(curl -s -w "\n%{http_code}" -X POST "$URL" \
  -H "Content-Type: application/json" \
  -d "$DATA")

# Split body and status code
body=$(echo "$response" | sed '$d')
code=$(echo "$response" | tail -n1)

# Print result with color-coded output
print_response "$code" "$body"

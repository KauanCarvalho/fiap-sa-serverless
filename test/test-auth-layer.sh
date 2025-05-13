#!/bin/bash

# Check for required tools
command -v uuidgen >/dev/null 2>&1 || { echo >&2 "uuidgen is required but not installed. Aborting."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo >&2 "jq is required but not installed. Aborting."; exit 1; }

base_url=$1
shift
skus=("$@")

if [ -z "$base_url" ]; then
  echo "Usage: $0 <base_url>"
  exit 1
fi

if [ ${#skus[@]} -eq 0 ]; then
  echo "Error: You must provide at least one SKU."
  echo "Usage: $0 <base_url> <sku1> <sku2> ..."
  exit 1
fi

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to generate a random CPF (11 digits)
generate_random_cpf() {
  echo "$((RANDOM % 10000000000 + 10000000000))"
}

# Function to format JSON or handle empty/invalid responses
print_pretty_body() {
  body="$1"
  if [ -z "$body" ]; then
    echo "no body"
  elif echo "$body" | jq . >/dev/null 2>&1; then
    echo "$body" | jq .
  else
    echo "$body"
  fi
}

# Function to color status code
print_status_code() {
  code="$1"
  if [ "$code" -ge 200 ] && [ "$code" -lt 300 ]; then
    echo -e "${GREEN}$code${NC}"
  elif [ "$code" -ge 400 ] && [ "$code" -lt 500 ]; then
    echo -e "${BLUE}$code${NC}"
  else
    echo -e "${RED}$code${NC}"
  fi
}

# Create two users
echo "Creating user 1..."
user1_cpf=$(generate_random_cpf)
response=$(curl -s -w "\n%{http_code}" -X POST "$base_url/signup" \
  -H "Content-Type: application/json" \
  -d "{\"cpf\": \"$user1_cpf\", \"password\": \"senhaSegura123!\"}")
body=$(echo "$response" | sed '$d')
status_code=$(echo "$response" | tail -n1)

echo -n "Status: "
print_status_code "$status_code"
echo "Response body:"
print_pretty_body "$body"
echo "---------------------------------------------"

echo "Creating user 2..."
user2_cpf=$(generate_random_cpf)
response=$(curl -s -w "\n%{http_code}" -X POST "$base_url/signup" \
  -H "Content-Type: application/json" \
  -d "{\"cpf\": \"$user2_cpf\", \"password\": \"senhaSegura123!\"}")
body=$(echo "$response" | sed '$d')
status_code=$(echo "$response" | tail -n1)

echo -n "Status: "
print_status_code "$status_code"
echo "Response body:"
print_pretty_body "$body"
echo "---------------------------------------------"

# Log in and get tokens
echo "Logging in user 1..."
response=$(curl -s -w "\n%{http_code}" -X POST "$base_url/login" \
  -H "Content-Type: application/json" \
  -d "{\"cpf\": \"$user1_cpf\", \"password\": \"senhaSegura123!\"}")
body=$(echo "$response" | sed '$d')
status_code=$(echo "$response" | tail -n1)

user1_access_token=$(echo "$body" | jq -r '.access_token')

echo -n "Status: "
print_status_code "$status_code"
echo "Response body:"
print_pretty_body "$body"
echo "---------------------------------------------"

echo "Logging in user 2..."
response=$(curl -s -w "\n%{http_code}" -X POST "$base_url/login" \
  -H "Content-Type: application/json" \
  -d "{\"cpf\": \"$user2_cpf\", \"password\": \"senhaSegura123!\"}")
body=$(echo "$response" | sed '$d')
status_code=$(echo "$response" | tail -n1)

user2_access_token=$(echo "$body" | jq -r '.access_token')

echo -n "Status: "
print_status_code "$status_code"
echo "Response body:"
print_pretty_body "$body"
echo "---------------------------------------------"

# Randomly select an SKU from the list
random_sku="${skus[RANDOM % ${#skus[@]}]}"

# Create orders for both users
echo "Creating order for user 1..."
response=$(curl -s -w "\n%{http_code}" -X POST "$base_url/checkout" \
  -H "Content-Type: application/json" \
  -H "Authorization: $user1_access_token" \
  -d '{
    "items": [
      {
        "sku": "'"$random_sku"'",
        "quantity": 1
      }
    ]
  }')
body=$(echo "$response" | sed '$d')
status_code=$(echo "$response" | tail -n1)

echo -n "Status: "
print_status_code "$status_code"
echo "Response body:"
print_pretty_body "$body"
echo "---------------------------------------------"

# Create another order for user 2 with a new random SKU
random_sku="${skus[RANDOM % ${#skus[@]}]}"

echo "Creating order for user 2..."
response=$(curl -s -w "\n%{http_code}" -X POST "$base_url/checkout" \
  -H "Content-Type: application/json" \
  -H "Authorization: $user2_access_token" \
  -d '{
    "items": [
      {
        "sku": "'"$random_sku"'",
        "quantity": 1
      }
    ]
  }')
body=$(echo "$response" | sed '$d')
status_code=$(echo "$response" | tail -n1)

echo -n "Status: "
print_status_code "$status_code"
echo "Response body:"
print_pretty_body "$body"
echo "---------------------------------------------"

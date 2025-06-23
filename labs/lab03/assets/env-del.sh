#!/bin/bash
pac auth login --tenant wpaine.onmicrosoft.com

# Delete environments Dev1 to Dev99
echo "Starting deletion of Dev1-Dev99 environments..."

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for JSON parsing. Please install jq first."
    exit 1
fi

# Get list of environments as JSON and filter for Dev1-Dev99 pattern
pac admin list --json | jq -r '.[] | select(.DisplayName | test("^Dev([1-9]|[1-9][0-9])$")) | "\(.EnvironmentId) \(.DisplayName)"' | while read -r env_id env_name; do
  if [[ -n "$env_id" && -n "$env_name" ]]; then
    echo "Deleting environment: $env_name (ID: $env_id)"
    pac admin delete --environment "$env_id" --async
  fi
done

echo "Environment deletion process completed."
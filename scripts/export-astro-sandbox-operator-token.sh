#!/usr/bin/env sh

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is not installed. Please install jq to use this script." >&2
  return 1 2>/dev/null || exit 1
fi

export ASTRO_API_TOKEN=$(aws secretsmanager get-secret-value --secret-id "etl/astro/sandbox/operator-token" --profile dataeng-dev --query 'SecretString' --output text | jq -r '.ASTRO_API_TOKEN')

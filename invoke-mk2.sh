#!/bin/bash

# Usage:
# For a single request:
#   ./invoke.sh --endpoint_url <url> --api_key <key> [--content <message>] [--input_cost <cost>] [--output_cost <cost>]
#
# For batch processing (each line in the file is a request):
#   ./invoke.sh --endpoint_url <url> --api_key <key> --input_file <path> [--input_cost <cost>] [--output_cost <cost>]

usage() {
  echo "Usage: $0 --endpoint_url <url> --api_key <key> [--content <message>] [--input_file <file>] [--input_cost <cost>] [--output_cost <cost>]"
  exit 1
}

# Default values for arguments
endpoint_url=""
api_key=""
content="Tell me a story"  # Default content if not provided
input_file=""
input_cost=0.00013  # Default cost per 1,000 input tokens
output_cost=0.00052 # Default cost per 1,000 output tokens

# Parse named parameters
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --endpoint_url) endpoint_url="$2"; shift ;;
    --api_key) api_key="$2"; shift ;;
    --content) content="$2"; shift ;;
    --input_file) input_file="$2"; shift ;;
    --input_cost) input_cost="$2"; shift ;;
    --output_cost) output_cost="$2"; shift ;;
    --help) usage ;;
    *) echo "Unknown parameter: $1"; usage ;;
  esac
  shift
done

# Validate required parameters
if [[ -z "$endpoint_url" ]]; then
  echo "Error: --endpoint_url is required"
  usage
fi

if [[ -z "$api_key" ]]; then
  echo "Error: --api_key is required"
  usage
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  echo "Error: jq is not installed. Please install it to parse JSON responses."
  exit 1
fi

# Function to process a single request given a content string
process_request() {
  local req_content="$1"

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📝 REQUEST: $req_content"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Escape special characters in content for JSON
  req_content=$(echo "$req_content" | sed 's/"/\\"/g' | sed 's/\\/\\\\/g' | sed ':a;N;$!ba;s/\n/\\n/g')

  # Construct JSON payload
  input_data=$(cat <<EOF
{
  "messages": [
    {
      "role": "user",
      "content": "$req_content"
    }
  ],
  "max_tokens": 1000,
  "temperature": 0.7
}
EOF
)

  # Start timing the API request
  start_time=$(date +%s.%N)
  response=$(curl -s -w "\n%{http_code}" -X POST "$endpoint_url" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $api_key" \
    -H "api-key: $api_key" \
    -d "$input_data")
  end_time=$(date +%s.%N)
  elapsed_time=$(bc <<< "scale=3; $end_time - $start_time")

  # Split the response and HTTP code
  http_body=$(echo "$response" | sed '$d')
  http_code=$(echo "$response" | tail -n1)

  if [[ "$http_code" -ne 200 ]]; then
    echo "❌ ERROR: HTTP request failed with status code $http_code"
    echo "Response: $http_body"
    return
  fi

  # Extract content from the response
  content_response=$(echo "$http_body" | jq -r '.choices[0].message.content // .choices[0].text // "No content found"')

  # Extract token usage using jq with null handling
  prompt_tokens=$(echo "$http_body" | jq '.usage.prompt_tokens // 0')
  completion_tokens=$(echo "$http_body" | jq '.usage.completion_tokens // 0')

  # Calculate cost (using bc with scale=6 for precision)
  input_cost_per_token=$(bc <<< "scale=10; $input_cost / 1000")
  output_cost_per_token=$(bc <<< "scale=10; $output_cost / 1000")
  input_cost_exact=$(bc <<< "scale=6; $prompt_tokens * $input_cost_per_token")
  output_cost_exact=$(bc <<< "scale=6; $completion_tokens * $output_cost_per_token")
  total_cost=$(bc <<< "scale=6; $input_cost_exact + $output_cost_exact")

  # Calculate completion tokens per second
  tokens_per_second=0
  if (( $(echo "$elapsed_time > 0" | bc -l) )); then
    tokens_per_second=$(bc <<< "scale=1; $completion_tokens / $elapsed_time")
  fi

  # Output the results for this request
  echo "✅ RESPONSE SUCCESS"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "$content_response"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📊 STATS:"
  echo "  • Token Usage: ${prompt_tokens} in / ${completion_tokens} out (${tokens_per_second} tokens/sec)"
  echo "  • Cost: $total_cost USD (in: $input_cost_exact, out: $output_cost_exact)"
  echo "  • Response Time: ${elapsed_time}s"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Main execution
echo "🤖 Azure AI API Client"
echo ""

# Process batch if an input file is provided; otherwise, process a single request.
if [[ -n "$input_file" ]]; then
  if [[ ! -f "$input_file" ]]; then
    echo "Error: Input file '$input_file' not found."
    exit 1
  fi

  echo "📂 Processing requests from: $input_file"
  echo ""

  request_count=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines
    [[ -z "$line" ]] && continue
    ((request_count++))
    echo "⚡ Request #$request_count"
    process_request "$line"
    echo ""
  done < "$input_file"

  echo "✅ Finished processing $request_count requests"
else
  process_request "$content"
fi

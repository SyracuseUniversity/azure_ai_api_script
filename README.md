# Azure AI API Script

A simple bash script for making requests to Azure AI APIs with token usage and cost tracking.

## Features

- Make single or batch requests to Azure AI endpoints
- Process multiple requests from an input file
- Track token usage and calculate costs
- Display performance metrics (tokens per second, response time)
- Formatted output for easy reading

## Requirements

- Bash shell environment
- `curl` for making HTTP requests
- `jq` for parsing JSON responses
- `bc` for mathematical calculations

## Usage

### Single Request

```bash
./invoke.sh --endpoint_url <url> --api_key <key> [--content <message>] [--input_cost <cost>] [--output_cost <cost>]
```

### Batch Processing

```bash
./invoke.sh --endpoint_url <url> --api_key <key> --input_file <path> [--input_cost <cost>] [--output_cost <cost>]
```

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `--endpoint_url` | Azure AI API endpoint URL | (Required) |
| `--api_key` | Your API key | (Required) |
| `--content` | Message content for single request | "Tell me a story" |
| `--input_file` | Path to file with one request per line | None |
| `--input_cost` | Cost per 1,000 input tokens | 0.00013 |
| `--output_cost` | Cost per 1,000 output tokens | 0.00052 |

## Example

```bash
# Single request
./invoke.sh --endpoint_url "https://your-endpoint.models.ai.azure.com/chat/completions" --api_key "$API_KEY" --content "Write a haiku about programming" --input_cost 0.00015 --output_cost 0.0006

# Batch processing
./invoke.sh --endpoint_url "https://your-endpoint.models.ai.azure.com/chat/completions" --api_key "$API_KEY" --input_file "requests.txt" --input_cost 0.00015 --output_cost 0.0006
```

## Output

The script provides formatted output including:
- Request content
- Full API response
- Token usage statistics
- Cost calculation
- Response time and tokens per second

## Notes

- Modify the input/output costs to match your specific model pricing
- For batch processing, each line in the input file is treated as a separate request

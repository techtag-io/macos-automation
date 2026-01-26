#!/bin/bash

################################################################################
# Gemini API Status Checker
# Description: Monitors the availability of the Gemini API service
# Author: Travis Green
################################################################################

set -euo pipefail

# Configuration
readonly GEMINI_ENDPOINT="https://api.gemini.com/v1/status"
readonly GEMINI_API_KEY="key goes here"
readonly SUCCESS_CODE=200

# Color codes for output
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

################################################################################
# Function: check_api_status
# Description: Performs HTTP request to check Gemini API availability
# Returns: HTTP status code
################################################################################
check_api_status() {
    local http_code
    
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer ${GEMINI_API_KEY}" \
        "${GEMINI_ENDPOINT}")
    
    echo "${http_code}"
}

################################################################################
# Function: display_status
# Description: Formats and displays the API status result
# Arguments:
#   $1 - HTTP status code
################################################################################
display_status() {
    local status_code=$1
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "═══════════════════════════════════════════════════════════"
    echo "Gemini API Status Check"
    echo "Timestamp: ${timestamp}"
    echo "═══════════════════════════════════════════════════════════"
    
    if [ "${status_code}" -eq "${SUCCESS_CODE}" ]; then
        echo -e "${GREEN}✓ Status: Operational${NC}"
        echo -e "${GREEN}✓ HTTP Code: ${status_code}${NC}"
        echo -e "${GREEN}✓ Service is up and running${NC}"
    else
        echo -e "${RED}✗ Status: Degraded${NC}"
        echo -e "${RED}✗ HTTP Code: ${status_code}${NC}"
        echo -e "${YELLOW}⚠ Service is down or unreachable${NC}"
    fi
    
    echo "═══════════════════════════════════════════════════════════"
}

################################################################################
# Main execution
################################################################################
main() {
    local response_code
    
    # Check if API key is configured
    if [ "${GEMINI_API_KEY}" = "key goes here" ]; then
        echo -e "${YELLOW}Warning: API key not configured${NC}"
        echo "Please update the GEMINI_API_KEY variable with your actual API key"
        exit 1
    fi
    
    # Perform status check
    response_code=$(check_api_status)
    
    # Display results
    display_status "${response_code}"
    
    # Exit with appropriate code
    [ "${response_code}" -eq "${SUCCESS_CODE}" ] && exit 0 || exit 1
}

# Execute main function
main "$@"


-----OG
#!/bin/bash

# Define the Gemini API endpoint and your API key
gemini_endpoint="https://api.gemini.com/v1/status"  # Replace with the correct status endpoint if available
gemini_key="key goes here"

# Perform a test request
response=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $gemini_key" $gemini_endpoint)

# Check the HTTP response code
if [ "$response" -eq 200 ]; then
    echo "Gemini service is up"
else
    echo "Gemini service is down or unreachable (HTTP status: $response)"
fi

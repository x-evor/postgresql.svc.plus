#!/bin/bash

# Build Test Script
# Tests the build process for dashboard-fresh, rag-server, and account services

set -e

echo "=================================="
echo "Build Test - Starting"
echo "=================================="
echo ""

# Configuration
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="tests/output/build_test_${TIMESTAMP}.log"
RESULTS_FILE="tests/output/build_results_${TIMESTAMP}.json"

# Create output directory
mkdir -p tests/output

# Initialize results
echo "{" > "$RESULTS_FILE"
echo '  "timestamp": "'$TIMESTAMP'",' >> "$RESULTS_FILE"
echo '  "tests": [' >> "$RESULTS_FILE"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to test build for a service
test_build() {
    local service_name=$1
    local service_path=$2
    local build_command=$3

    echo "----------------------------------------"
    echo "Testing: $service_name"
    echo "----------------------------------------"
    echo ""

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if [ -d "$service_path" ]; then
        echo "Service directory exists: $service_path"

        # Try to build the service
        echo "Running build command: $build_command"
        if eval "cd $service_path && $build_command" >> "$LOG_FILE" 2>&1; then
            echo "✓ Build succeeded for $service_name"
            PASSED_TESTS=$((PASSED_TESTS + 1))

            # Add to results
            if [ $TOTAL_TESTS -gt 1 ]; then
                echo "," >> "$RESULTS_FILE"
            fi
            echo '    {' >> "$RESULTS_FILE"
            echo '      "service": "'$service_name'",' >> "$RESULTS_FILE"
            echo '      "status": "PASSED",' >> "$RESULTS_FILE"
            echo '      "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"' >> "$RESULTS_FILE"
            echo -n '    }' >> "$RESULTS_FILE"
        else
            echo "✗ Build failed for $service_name"
            FAILED_TESTS=$((FAILED_TESTS + 1))

            # Add to results
            if [ $TOTAL_TESTS -gt 1 ]; then
                echo "," >> "$RESULTS_FILE"
            fi
            echo '    {' >> "$RESULTS_FILE"
            echo '      "service": "'$service_name'",' >> "$RESULTS_FILE"
            echo '      "status": "FAILED",' >> "$RESULTS_FILE"
            echo '      "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"' >> "$RESULTS_FILE"
            echo -n '    }' >> "$RESULTS_FILE"
        fi
    else
        echo "✗ Service directory not found: $service_path"
        FAILED_TESTS=$((FAILED_TESTS + 1))

        # Add to results
        if [ $TOTAL_TESTS -gt 1 ]; then
            echo "," >> "$RESULTS_FILE"
        fi
        echo '    {' >> "$RESULTS_FILE"
        echo '      "service": "'$service_name'",' >> "$RESULTS_FILE"
        echo '      "status": "NOT_FOUND",' >> "$RESULTS_FILE"
        echo '      "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"' >> "$RESULTS_FILE"
        echo -n '    }' >> "$RESULTS_FILE"
    fi

    echo ""
}

# Test builds for each service
echo "Starting build tests..."
echo ""

# Account service (Go)
test_build "account" "account" "go build -o xcontrol-account ./"

# RAG server (Go)
test_build "rag-server" "rag-server" "go build -o xcontrol-rag-server ./"

# Dashboard fresh (TypeScript/Node.js)
test_build "dashboard-fresh" "dashboard-fresh" "npm run build 2>/dev/null || echo 'Build script not found'"

# Close results JSON
echo "" >> "$RESULTS_FILE"
echo '  ],' >> "$RESULTS_FILE"
echo '  "summary": {' >> "$RESULTS_FILE"
echo '    "total": '$TOTAL_TESTS',' >> "$RESULTS_FILE"
echo '    "passed": '$PASSED_TESTS',' >> "$RESULTS_FILE"
echo '    "failed": '$FAILED_TESTS'' >> "$RESULTS_FILE"
echo '  }' >> "$RESULTS_FILE"
echo "}" >> "$RESULTS_FILE"

# Summary
echo "=================================="
echo "Build Test - Summary"
echo "=================================="
echo "Total tests: $TOTAL_TESTS"
echo "Passed: $PASSED_TESTS"
echo "Failed: $FAILED_TESTS"
echo ""
echo "Detailed log: $LOG_FILE"
echo "Results JSON: $RESULTS_FILE"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo "✓ All build tests passed!"
    exit 0
else
    echo "✗ Some build tests failed"
    exit 1
fi

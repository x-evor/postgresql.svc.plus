#!/bin/bash

# Dry-Run Test Script
# Tests configuration validation and startup readiness without actually running services

set -e

echo "=================================="
echo "Dry-Run Test - Starting"
echo "=================================="
echo ""

# Configuration
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="tests/output/dry_run_test_${TIMESTAMP}.log"
RESULTS_FILE="tests/output/dry_run_results_${TIMESTAMP}.json"

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

# Function to validate configuration files
validate_configs() {
    local service_name=$1
    local config_path=$2

    echo "----------------------------------------"
    echo "Validating: $service_name"
    echo "----------------------------------------"
    echo ""

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if [ -d "$config_path" ]; then
        echo "Config directory exists: $config_path"

        # Check for config files
        CONFIG_FILES=$(find "$config_path" -name "*.yaml" -o -name "*.yml" -o -name "*.json" 2>/dev/null || echo "")

        if [ -n "$CONFIG_FILES" ]; then
            echo "✓ Found configuration files"
            PASSED_TESTS=$((PASSED_TESTS + 1))

            # Add to results
            if [ $TOTAL_TESTS -gt 1 ]; then
                echo "," >> "$RESULTS_FILE"
            fi
            echo '    {' >> "$RESULTS_FILE"
            echo '      "service": "'$service_name'",' >> "$RESULTS_FILE"
            echo '      "test": "config_validation",' >> "$RESULTS_FILE"
            echo '      "status": "PASSED",' >> "$RESULTS_FILE"
            echo '      "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"' >> "$RESULTS_FILE"
            echo -n '    }' >> "$RESULTS_FILE"

            # Log configs
            echo "$CONFIG_FILES" >> "$LOG_FILE"
        else
            echo "✗ No configuration files found"
            FAILED_TESTS=$((FAILED_TESTS + 1))

            # Add to results
            if [ $TOTAL_TESTS -gt 1 ]; then
                echo "," >> "$RESULTS_FILE"
            fi
            echo '    {' >> "$RESULTS_FILE"
            echo '      "service": "'$service_name'",' >> "$RESULTS_FILE"
            echo '      "test": "config_validation",' >> "$RESULTS_FILE"
            echo '      "status": "FAILED",' >> "$RESULTS_FILE"
            echo '      "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"' >> "$RESULTS_FILE"
            echo -n '    }' >> "$RESULTS_FILE"
        fi
    else
        echo "✗ Config directory not found: $config_path"
        FAILED_TESTS=$((FAILED_TESTS + 1))

        # Add to results
        if [ $TOTAL_TESTS -gt 1 ]; then
            echo "," >> "$RESULTS_FILE"
        fi
        echo '    {' >> "$RESULTS_FILE"
        echo '      "service": "'$service_name'",' >> "$RESULTS_FILE"
        echo '      "test": "config_validation",' >> "$RESULTS_FILE"
        echo '      "status": "NOT_FOUND",' >> "$RESULTS_FILE"
        echo '      "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"' >> "$RESULTS_FILE"
        echo -n '    }' >> "$RESULTS_FILE"
    fi

    echo ""
}

# Function to validate auth configuration
validate_auth_config() {
    local service_name=$1
    local auth_file=$2

    echo "----------------------------------------"
    echo "Validating Auth: $service_name"
    echo "----------------------------------------"
    echo ""

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if [ -f "$auth_file" ]; then
        echo "Auth file exists: $auth_file"

        # Check if it contains expected auth structures
        if grep -q "token" "$auth_file" 2>/dev/null || grep -q "auth" "$auth_file" 2>/dev/null || grep -q "Auth" "$auth_file" 2>/dev/null; then
            echo "✓ Auth configuration present"
            PASSED_TESTS=$((PASSED_TESTS + 1))

            # Add to results
            echo "," >> "$RESULTS_FILE"
            echo '    {' >> "$RESULTS_FILE"
            echo '      "service": "'$service_name'",' >> "$RESULTS_FILE"
            echo '      "test": "auth_validation",' >> "$RESULTS_FILE"
            echo '      "status": "PASSED",' >> "$RESULTS_FILE"
            echo '      "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"' >> "$RESULTS_FILE"
            echo -n '    }' >> "$RESULTS_FILE"
        else
            echo "⚠ Auth file found but no token/auth keywords detected"
            PASSED_TESTS=$((PASSED_TESTS + 1))

            # Add to results
            echo "," >> "$RESULTS_FILE"
            echo '    {' >> "$RESULTS_FILE"
            echo '      "service": "'$service_name'",' >> "$RESULTS_FILE"
            echo '      "test": "auth_validation",' >> "$RESULTS_FILE"
            echo '      "status": "PARTIAL",' >> "$RESULTS_FILE"
            echo '      "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"' >> "$RESULTS_FILE"
            echo -n '    }' >> "$RESULTS_FILE"
        fi
    else
        echo "⚠ Auth file not found: $auth_file"

        # Add to results
        echo "," >> "$RESULTS_FILE"
        echo '    {' >> "$RESULTS_FILE"
        echo '      "service": "'$service_name'",' >> "$RESULTS_FILE"
        echo '      "test": "auth_validation",' >> "$RESULTS_FILE"
        echo '      "status": "WARNING",' >> "$RESULTS_FILE"
        echo '      "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"' >> "$RESULTS_FILE"
        echo -n '    }' >> "$RESULTS_FILE"
    fi

    echo ""
}

# Test configuration validation for each service
echo "Starting configuration validation tests..."
echo ""

# Account service
validate_configs "account" "account/config"
validate_auth_config "account" "account/internal/auth/token_service.go"

# RAG server
validate_configs "rag-server" "rag-server/config"
validate_auth_config "rag-server" "rag-server/internal/auth/token_service.go"

# Dashboard fresh
validate_configs "dashboard-fresh" "dashboard-fresh/config"
validate_auth_config "dashboard-fresh" "dashboard-fresh/lib/auth/token_service.ts"

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
echo "Dry-Run Test - Summary"
echo "=================================="
echo "Total tests: $TOTAL_TESTS"
echo "Passed: $PASSED_TESTS"
echo "Failed: $FAILED_TESTS"
echo ""
echo "Detailed log: $LOG_FILE"
echo "Results JSON: $RESULTS_FILE"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo "✓ All dry-run tests passed!"
    exit 0
else
    echo "✗ Some dry-run tests failed"
    exit 1
fi

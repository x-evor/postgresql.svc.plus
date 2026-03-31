# Test Suite

This directory contains test scripts for validating the XControl services:
- **account** (Go service)
- **rag-server** (Go service)
- **dashboard-fresh** (TypeScript/Deno service)

## Test Scripts

### 1. Build Test (`build_test.sh`)
Tests the build process for all three services.

**What it does:**
- Compiles Go services (account, rag-server)
- Builds TypeScript/Node.js service (dashboard-fresh)
- Validates that binaries and build artifacts are generated
- Generates JSON test results

**Usage:**
```bash
./tests/build_test.sh
```

**Outputs:**
- Log file: `tests/output/build_test_<timestamp>.log`
- Results: `tests/output/build_results_<timestamp>.json`

---

### 2. Dry-Run Test (`dry_run_test.sh`)
Tests configuration validation and startup readiness without running services.

**What it does:**
- Validates configuration files exist (.yaml, .yml, .json)
- Checks for authentication configuration
- Verifies token service implementations
- Validates middleware setup

**Usage:**
```bash
./tests/dry_run_test.sh
```

**Outputs:**
- Log file: `tests/output/dry_run_test_<timestamp>.log`
- Results: `tests/output/dry_run_results_<timestamp>.json`

---

### 3. Local Test (`local_test.sh`)
Runs integration tests with services running locally.

**What it does:**
- Starts services locally (if not already running)
- Tests HTTP endpoints
- Validates service health checks
- Tests authentication flows

**Prerequisites:**
- Services must be built first (run `build_test.sh`)
- Services should be configured and ready to start
- curl must be installed for endpoint testing

**Usage:**
```bash
./tests/local_test.sh
```

**Outputs:**
- Log file: `tests/output/local_test_<timestamp>.log`
- Results: `tests/output/local_test_results_<timestamp>.json`
- PID file: `tests/temp/services.pid` (for cleanup)

---

## Directory Structure

```
tests/
├── README.md              # This file
├── build_test.sh          # Build validation test
├── dry_run_test.sh        # Configuration validation test
├── local_test.sh          # Integration test
├── local/                 # Local test data (gitignored)
├── output/                # Test results and logs (gitignored)
│   ├── build_test_*.log
│   ├── build_test_*.json
│   ├── dry_run_test_*.log
│   ├── dry_run_test_*.json
│   ├── local_test_*.log
│   └── local_test_*.json
└── temp/                  # Temporary files (gitignored)
    └── services.pid
```

## Running All Tests

To run all tests in sequence:

```bash
# 1. Build validation
./tests/build_test.sh

# 2. Configuration validation
./tests/dry_run_test.sh

# 3. Integration tests
./tests/local_test.sh
```

## Test Results

All test scripts generate JSON results with the following structure:

```json
{
  "timestamp": "20241105_143022",
  "tests": [
    {
      "service": "account",
      "status": "PASSED",
      "timestamp": "2024-11-05T14:30:22Z"
    }
  ],
  "summary": {
    "total": 3,
    "passed": 3,
    "failed": 0
  }
}
```

## Configuration

No configuration files are required. The scripts automatically detect:
- Service directories (`account/`, `rag-server/`, `dashboard-fresh/`)
- Configuration files in each service
- Authentication implementations

## Cleanup

Test scripts automatically clean up:
- Background service processes
- Temporary files
- PID files

The `local_test.sh` script includes a trap to ensure cleanup even on interruption.

## Notes

- All test artifacts are gitignored (see `.gitignore`)
- Services are tested independently
- Auth token service implementations are validated in dry-run tests
- No sensitive information is logged or stored in test results

## Requirements

- **bash** (for running test scripts)
- **Go** (for building Go services)
- **Node.js & npm** (for building dashboard-fresh)
- **curl** (for integration tests, only in local_test.sh)
- **Git** (for repository operations)

## Troubleshooting

### Build Test Fails
- Ensure Go is installed and in PATH
- Check that service directories exist
- Verify dependencies are installed

### Dry-Run Test Fails
- Check that configuration files exist in each service
- Verify file permissions
- Look at detailed log output

### Local Test Fails
- Ensure services are built (run build_test.sh first)
- Check if ports are already in use
- Verify curl is installed
- Check that services can bind to configured ports

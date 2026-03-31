#!/usr/bin/env bash
set -euo pipefail

# Install pgbench on macOS or Linux (Debian/Ubuntu/Rocky)

OS="$(uname -s)"
PG_VERSION="${PG_VERSION:-}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

fail() {
  echo "❌ $*" >&2
  exit 1
}

if [[ "$OS" == "Darwin" ]]; then
  if ! need_cmd brew; then
    fail "Homebrew not found. Install Homebrew first: https://brew.sh"
  fi
  if [[ -n "$PG_VERSION" ]]; then
    echo "🔧 Installing PostgreSQL $PG_VERSION (includes pgbench) via Homebrew..."
    brew install "postgresql@${PG_VERSION}"
    PG_BENCH_BIN="$(brew --prefix "postgresql@${PG_VERSION}")/bin/pgbench"
    echo "✅ pgbench version:"
    "$PG_BENCH_BIN" --version
    echo "ℹ️  Tip: export PATH=\"$(brew --prefix "postgresql@${PG_VERSION}")/bin:\$PATH\""
  else
    echo "🔧 Installing PostgreSQL (includes pgbench) via Homebrew..."
    brew install postgresql
    echo "✅ pgbench version:"
    pgbench --version
  fi
  exit 0
fi

if [[ "$OS" == "Linux" ]]; then
  if [[ -f /etc/debian_version ]]; then
    if [[ -n "$PG_VERSION" ]]; then
      echo "🔧 Installing pgbench (PostgreSQL $PG_VERSION) on Debian/Ubuntu..."
      sudo apt-get update
      sudo apt-get install -y "postgresql-client-${PG_VERSION}" "postgresql-contrib-${PG_VERSION}"
    else
      echo "🔧 Installing pgbench on Debian/Ubuntu..."
      sudo apt-get update
      sudo apt-get install -y postgresql-contrib
    fi
    echo "✅ pgbench version:"
    pgbench --version
    exit 0
  fi

  if [[ -f /etc/redhat-release ]]; then
    if [[ -n "$PG_VERSION" ]]; then
      echo "🔧 Installing pgbench (PostgreSQL $PG_VERSION) on Rocky/RHEL..."
      if ! sudo dnf install -y "postgresql${PG_VERSION}-contrib"; then
        echo "⚠️  Versioned package not found. Falling back to default postgresql-contrib."
        sudo dnf install -y postgresql-contrib
      fi
    else
      echo "🔧 Installing pgbench on Rocky/RHEL..."
      sudo dnf install -y postgresql-contrib
    fi
    echo "✅ pgbench version:"
    pgbench --version
    exit 0
  fi

  fail "Unsupported Linux distribution. Supported: Debian/Ubuntu/Rocky."
fi

fail "Unsupported OS: $OS"

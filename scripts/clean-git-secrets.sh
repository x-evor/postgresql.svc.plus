#!/bin/bash
# =============================================================================
# Git Secrets Cleanup Script
# =============================================================================
# This script removes sensitive files from Git history using git-filter-repo.
# 
# Usage:
#   ./scripts/clean-git-secrets.sh [--dry-run]
#
# Requirements:
#   - git-filter-repo (brew install git-filter-repo)
#   - gitleaks (for verification)
#
# WARNING: This rewrites Git history! All commit hashes will change.
#          Force push required after cleanup.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    log_info "Dry run mode - no changes will be made"
fi

cd "$PROJECT_ROOT"

# Check dependencies
if ! command -v git-filter-repo &>/dev/null; then
    log_error "git-filter-repo not found. Install with: brew install git-filter-repo"
    exit 1
fi

if ! command -v gitleaks &>/dev/null; then
    log_warn "gitleaks not found. Install with: brew install gitleaks"
fi

# Run gitleaks to detect secrets
log_info "Scanning for secrets with gitleaks..."
LEAKS_OUTPUT=$(gitleaks detect -v 2>&1 || true)
LEAK_COUNT=$(echo "$LEAKS_OUTPUT" | grep -c "^Finding:" || echo "0")

if [[ "$LEAK_COUNT" == "0" ]]; then
    log_info "No leaks found! Repository is clean."
    exit 0
fi

log_warn "Found $LEAK_COUNT potential leaks"

# Extract unique files with leaks
FILES_WITH_LEAKS=$(echo "$LEAKS_OUTPUT" | grep "^File:" | sed 's/File: *//' | sort -u)

echo ""
log_info "Files with potential secrets:"
echo "$FILES_WITH_LEAKS" | while read -r file; do
    echo "  - $file"
done

if $DRY_RUN; then
    echo ""
    log_info "Dry run complete. Run without --dry-run to remove these files from history."
    exit 0
fi

echo ""
read -p "Remove these files from Git history? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    log_info "Aborted."
    exit 0
fi

# Backup
log_info "Creating backup..."
BACKUP_DIR="../$(basename "$PROJECT_ROOT").backup.$(date +%Y%m%d%H%M%S)"
cp -r "$PROJECT_ROOT" "$BACKUP_DIR"
log_info "Backup created at: $BACKUP_DIR"

# Get remote URL before removing
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")

# Remove remote (required by git-filter-repo)
if [[ -n "$REMOTE_URL" ]]; then
    log_info "Removing remote origin temporarily..."
    git remote remove origin
fi

# Build filter-repo command
FILTER_CMD="git filter-repo --invert-paths --force"
while IFS= read -r file; do
    FILTER_CMD="$FILTER_CMD --path \"$file\""
done <<< "$FILES_WITH_LEAKS"

# Execute
log_info "Rewriting Git history..."
eval "$FILTER_CMD"

# Re-add remote
if [[ -n "$REMOTE_URL" ]]; then
    log_info "Re-adding remote origin..."
    git remote add origin "$REMOTE_URL"
fi

# Verify
log_info "Verifying cleanup..."
if command -v gitleaks &>/dev/null; then
    VERIFY_OUTPUT=$(gitleaks detect -v 2>&1 || true)
    REMAINING_LEAKS=$(echo "$VERIFY_OUTPUT" | grep -c "^Finding:" || echo "0")
    
    if [[ "$REMAINING_LEAKS" == "0" ]]; then
        log_info "✅ All secrets removed successfully!"
    else
        log_warn "⚠️  $REMAINING_LEAKS leaks still remain. Manual review required."
    fi
fi

echo ""
log_info "Next steps:"
echo "  1. Review changes: git log --oneline -20"
echo "  2. Force push: git push --force origin main"
echo "  3. Notify collaborators to re-clone the repository"
echo ""

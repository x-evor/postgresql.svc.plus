#!/usr/bin/env bash
#
# clean_git_history.sh
# Purge history of specific files/directories while retaining current content.
# 
# Usage:
#   ./scripts/clean_git_history.sh <path1> [path2 ...]
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "${CYAN}==> $1${NC}"; }

# 1. Check Dependencies
if ! command -v git-filter-repo &>/dev/null; then
    log_error "git-filter-repo not found. Install with: brew install git-filter-repo"
    exit 1
fi

if [ "$#" -lt 1 ]; then
    log_error "Usage: $0 <path1> [path2 ...]"
    exit 1
fi

# 2. Preparation
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [[ -z "$REMOTE_URL" ]]; then
    log_warn "No remote 'origin' found. History rewriting will continue locally."
fi

log_step "Backing up current content for restoration..."
TMP_BACKUP=$(mktemp -d)
for PATH_ITEM in "$@"; do
    if [ -e "$PATH_ITEM" ]; then
        PARENT_DIR=$(dirname "$PATH_ITEM")
        mkdir -p "$TMP_BACKUP/$PARENT_DIR"
        cp -r "$PATH_ITEM" "$TMP_BACKUP/$PATH_ITEM"
        log_info "Backed up: $PATH_ITEM"
    else
        log_warn "Path does not exist (skipping backup): $PATH_ITEM"
    fi
done

# 3. Purge History
log_step "Rewriting Git history (this may take a while)..."
# Save remote for later if exists
if [[ -n "$REMOTE_URL" ]]; then
    git remote remove origin
fi

# Build path arguments
PATHS=()
for p in "$@"; do
    PATHS+=("--path" "$p")
done

# Execute filter-repo
# --invert-paths removes the history of the specified paths
git filter-repo --invert-paths "${PATHS[@]}" --force

# 4. Restoration
if [[ -n "$REMOTE_URL" ]]; then
    log_step "Restoring remote configuration..."
    git remote add origin "$REMOTE_URL"
fi

log_step "Restoring current content of cleaned paths..."
for PATH_ITEM in "$@"; do
    if [ -e "$TMP_BACKUP/$PATH_ITEM" ]; then
        # Ensure target directory exists for files
        mkdir -p "$(dirname "$PATH_ITEM")"
        cp -r "$TMP_BACKUP/$PATH_ITEM" "$PATH_ITEM"
        log_info "Restored: $PATH_ITEM"
    fi
done

# 5. Commit and Verify
log_step "Committing cleaned state..."
git add .
if git diff-index --quiet HEAD --; then
    log_info "No changes to commit (history was already purged or nothing to restore)."
else
    git commit -m "chore: re-add cleaned files after history purge"
    log_info "Changes committed."
fi

if command -v gitleaks &>/dev/null; then
    log_step "Running verification scan with gitleaks..."
    if gitleaks detect -v; then
        log_info "✅ No leaks detected in current history."
    else
        log_warn "⚠️ Gitleaks found potential issues. Please review manually."
    fi
fi

# 6. Cleanup
rm -rf "$TMP_BACKUP"

log_step "Done! History has been purged."
echo
log_warn "CRITICAL NEXT STEPS:"
echo "  1. Review history: git log --all --oneline -20"
echo "  2. Force push:    git push origin --force --all"
echo "  3. Force tags:    git push origin --force --tags"
echo "  4. ALERT TEAM:    Collaborators MUST re-clone the repository."
echo

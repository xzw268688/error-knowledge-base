#!/usr/bin/env bash
# Error Knowledge Base Skill - Install Script
# Usage: bash install.sh

set -e

FORCE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force|-f) FORCE=true; shift ;;
        *) shift ;;
    esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SRC="$REPO_ROOT/error-knowledge-base"
SKILL_DEST="$HOME/.claude/skills/error-knowledge-base"

if [ ! -d "$SKILL_SRC" ]; then
    echo "Error: error-knowledge-base/ directory not found"
    echo "Run from repository root: bash install.sh"
    exit 1
fi

if [ -d "$SKILL_DEST" ]; then
    if [ "$FORCE" != "true" ]; then
        echo "Already installed. Use --force to reinstall."
        exit 0
    fi
    rm -rf "$SKILL_DEST"
fi

mkdir -p "$HOME/.claude/skills"
cp -r "$SKILL_SRC" "$SKILL_DEST"

echo "Installed to: $SKILL_DEST"

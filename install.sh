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

# Append the standing convention to the user-level CLAUDE.md (idempotent).
# This is what makes the skill ask to record automatically in every session,
# instead of requiring the user to type /error-knowledge-base by hand.
GLOBAL_MD="$HOME/.claude/CLAUDE.md"
CONVENTION_SRC="$REPO_ROOT/convention.md"
MARKER="<!-- error-knowledge-base:convention -->"

if [ ! -f "$GLOBAL_MD" ] || ! grep -qF "$MARKER" "$GLOBAL_MD"; then
    if [ ! -f "$CONVENTION_SRC" ]; then
        echo "Warning: convention.md not found; skipping global convention."
    else
        mkdir -p "$HOME/.claude"
        if [ -s "$GLOBAL_MD" ]; then echo "" >> "$GLOBAL_MD"; fi
        cat "$CONVENTION_SRC" >> "$GLOBAL_MD"
        echo "" >> "$GLOBAL_MD"
        echo "Convention added to: $GLOBAL_MD"
    fi
else
    echo "Convention already present in: $GLOBAL_MD"
fi

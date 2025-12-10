#!/bin/bash
# Disable all CI/CD workflows by renaming them
# Usage: ./scripts/disable-cicd.sh

WORKFLOWS_DIR="$(dirname "$0")/../.github/workflows"

echo "🔴 Disabling CI/CD workflows..."

cd "$WORKFLOWS_DIR"

count=0
shopt -s nullglob
for f in *.yml; do
    mv "$f" "$f.disabled"
    echo "   ✓ Disabled: $f"
    count=$((count + 1))
done
shopt -u nullglob

if [ $count -eq 0 ]; then
    echo "   No active workflows found (already disabled?)"
else
    echo ""
    echo "✅ Disabled $count workflow(s)"
    echo ""
    echo "To re-enable, run: ./scripts/enable-cicd.sh"
fi

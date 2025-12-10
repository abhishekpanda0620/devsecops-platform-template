#!/bin/bash
# Enable all CI/CD workflows by removing .disabled extension
# Usage: ./scripts/enable-cicd.sh

WORKFLOWS_DIR="$(dirname "$0")/../.github/workflows"

echo "🟢 Enabling CI/CD workflows..."

cd "$WORKFLOWS_DIR"

count=0
shopt -s nullglob
for f in *.disabled; do
    new_name="${f%.disabled}"
    mv "$f" "$new_name"
    echo "   ✓ Enabled: $new_name"
    count=$((count + 1))
done
shopt -u nullglob

if [ $count -eq 0 ]; then
    echo "   No disabled workflows found (already enabled?)"
else
    echo ""
    echo "✅ Enabled $count workflow(s)"
    echo ""
    echo "CI/CD pipelines will now run on push/pull_request events."
fi

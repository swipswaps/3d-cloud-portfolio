#!/bin/bash
if git diff --staged index.html | grep -E '^-.*function animate|^-.*minimap' | wc -l | grep -q '^[5-9]'; then
    echo "FAIL: Large removal detected – possible regex over‑deletion"
    exit 1
fi
echo "PASS: No suspicious large deletions"
exit 0

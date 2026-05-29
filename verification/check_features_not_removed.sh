#!/bin/bash
missing=0
for id in minimap-container control-panel similarBtn fuzzySearchInput; do
    if ! grep -q "id=\"$id\"" index.html; then
        echo "FAIL: Feature $id was removed without justification"
        missing=1
    fi
done
[ $missing -eq 0 ] && echo "PASS: All requested features present"
exit $missing

#!/bin/bash
LOCAL=$(sha256sum index.html | cut -d' ' -f1)
LIVE=$(curl -s https://swipswaps.github.io/3d-cloud-portfolio/index.html | sha256sum | cut -d' ' -f1)
if [ "$LOCAL" = "$LIVE" ]; then
    echo "PASS: Deployment SHA256 matches"
    exit 0
else
    echo "FAIL: SHA256 mismatch (local: $LOCAL, live: $LIVE)"
    exit 1
fi

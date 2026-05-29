#!/bin/bash
# Poll GitHub Pages until SHA256 matches local, with progress every 10 seconds

LOCAL_SHA=$(sha256sum index.html | cut -d' ' -f1)
echo "Local SHA256: $LOCAL_SHA"
echo "Polling https://swipswaps.github.io/3d-cloud-portfolio/index.html ..."

for i in {1..18}; do
    sleep 10
    LIVE_SHA=$(curl -s https://swipswaps.github.io/3d-cloud-portfolio/index.html | sha256sum | cut -d' ' -f1)
    echo "   Attempt $i/18: Live SHA = $LIVE_SHA"
    if [ "$LIVE_SHA" = "$LOCAL_SHA" ]; then
        echo "✅ Deployment successful – files match."
        exit 0
    fi
done
echo "❌ Timeout – SHA256 still mismatched after 3 minutes."
echo "   Check GitHub Actions or Pages source branch setting."
exit 1

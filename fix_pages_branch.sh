#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$PWD"
cd "$REPO_DIR"

# Get repo owner/name from git remote
REPO_URL=$(git config --get remote.origin.url)
if [[ "$REPO_URL" =~ github.com[:/](.+)/(.+)\.git ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
else
    echo "❌ Could not parse GitHub repo"
    exit 1
fi
echo "📦 $OWNER/$REPO"

# Use GitHub CLI if available, else require GITHUB_TOKEN
if command -v gh &>/dev/null && gh auth status &>/dev/null; then
    USE_GH=true
else
    USE_GH=false
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        echo "❌ Set GITHUB_TOKEN or install gh CLI"
        exit 1
    fi
fi

get_branch() {
    if $USE_GH; then
        gh api "repos/$OWNER/$REPO/pages" --jq '.source.branch' 2>/dev/null || echo "none"
    else
        curl -s -H "Authorization: token $GITHUB_TOKEN" \
            "https://api.github.com/repos/$OWNER/$REPO/pages" | jq -r '.source.branch // "none"'
    fi
}

CURRENT=$(get_branch)
echo "🌿 Current Pages branch: $CURRENT"

if [[ "$CURRENT" != "main" ]]; then
    echo "🔄 Switching to main..."
    if $USE_GH; then
        gh api -X POST "repos/$OWNER/$REPO/pages" -f source='{"branch":"main","path":"/"}' >/dev/null
    else
        curl -s -X POST -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/$OWNER/$REPO/pages" \
            -d '{"source":{"branch":"main","path":"/"}}' >/dev/null
    fi
else
    echo "✅ Already on main – forcing rebuild with empty commit"
    git commit --allow-empty -m "Force rebuild" || true
    git push origin main
fi

echo "⏳ Waiting up to 3 minutes for deployment..."
for i in {1..18}; do
    sleep 10
    LIVE_SHA=$(curl -s "https://$OWNER.github.io/$REPO/index.html" | sha256sum | cut -d' ' -f1)
    LOCAL_SHA=$(sha256sum index.html | cut -d' ' -f1)
    echo "   Attempt $i: Live $LIVE_SHA vs Local $LOCAL_SHA"
    if [[ "$LIVE_SHA" == "$LOCAL_SHA" ]]; then
        echo "✅ SUCCESS!"
        exit 0
    fi
done
echo "❌ Timeout – check https://github.com/$OWNER/$REPO/actions"
exit 1

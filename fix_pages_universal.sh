#!/usr/bin/env bash
set -euo pipefail

cd ~/Documents/be971609-17d6-4ba5-8840-e41e6b2d5191/cloud-portfolio-pages

# Get repo owner/name
REPO_URL=$(git config --get remote.origin.url)
if [[ "$REPO_URL" =~ github.com[:/](.+)/(.+)\.git ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
else
    echo "❌ Could not parse GitHub repo"
    exit 1
fi

# Get current Pages source branch via API (curl with token or gh)
if command -v gh &>/dev/null && gh auth status &>/dev/null; then
    PAGES_BRANCH=$(gh api "repos/$OWNER/$REPO/pages" --jq '.source.branch' 2>/dev/null || echo "unknown")
else
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        echo "❌ Set GITHUB_TOKEN or use gh CLI"
        exit 1
    fi
    PAGES_BRANCH=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$OWNER/$REPO/pages" | jq -r '.source.branch // "unknown"')
fi

echo "📦 Pages source branch: $PAGES_BRANCH"

# If Pages expects master, push main to master
if [[ "$PAGES_BRANCH" == "master" ]]; then
    echo "🔄 Pushing current main branch to master (as Pages expects) ..."
    git push origin main:master
    DEPLOY_BRANCH="master"
elif [[ "$PAGES_BRANCH" == "main" ]]; then
    echo "✅ Pages already on main – forcing rebuild"
    git commit --allow-empty -m "Force rebuild" || true
    git push origin main
    DEPLOY_BRANCH="main"
else
    echo "⚠️ Unknown Pages branch: $PAGES_BRANCH. Defaulting to push to master"
    git push origin main:master
    DEPLOY_BRANCH="master"
fi

echo "⏳ Waiting up to 3 minutes for deployment from branch $DEPLOY_BRANCH..."
for i in {1..18}; do
    sleep 10
    LIVE_SHA=$(curl -s "https://$OWNER.github.io/$REPO/index.html" | sha256sum | cut -d' ' -f1)
    LOCAL_SHA=$(sha256sum index.html | cut -d' ' -f1)
    echo "   Attempt $i: Live $LIVE_SHA vs Local $LOCAL_SHA"
    if [[ "$LIVE_SHA" == "$LOCAL_SHA" ]]; then
        echo "✅ SUCCESS! Live site matches local."
        exit 0
    fi
done
echo "❌ Timeout – check https://github.com/$OWNER/$REPO/actions"
exit 1

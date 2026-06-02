#!/usr/bin/env bash
# PATH: diagnose_pages.sh
#
# WHAT: gathers every fact needed to distinguish the four candidate causes of
#       the "deployed sha256 != local sha256" symptom, then prints exactly one
#       diagnosis based on what the facts show. No fix is applied automatically.
#
# WHY:  the previous deploy loop cycled through three different fix proposals
#       (push to master, force-rebuild commit, switch to gh-pages branch)
#       without ever confirming which cause was real. Per Rule 24, after a
#       repeated failure the next move is one diagnostic, not another guess.
#
# CANDIDATE CAUSES this script distinguishes:
#   A. Pages is configured for a different branch than you pushed to
#   B. Pages build errored (you can read the error message via the API)
#   C. Pages build is still in progress (just wait)
#   D. Configured branch is correct but CDN edge cache is stale
#   E. Deployment already succeeded -- the sha256 comparison method was wrong
#      (curl-of-URL vs file-on-disk can differ on trailing whitespace alone)
#
# REQUIRES: gh (authenticated), jq, curl, git
#
# USAGE: cd into the repo directory, then: bash diagnose_pages.sh

set -euo pipefail

REPO="swipswaps/3d-cloud-portfolio"
LOCAL_FILE="index.html"

# A string that exists in the new local file but NOT in the old served file.
# Grepping for this is more reliable than sha256 because it survives whitespace
# normalization, server-added headers, and other byte-level differences that
# don't actually mean the deploy failed.
UNIQUE_MARKER='use what github allows without a key'

echo "==================================================================="
echo "[1/6] Pages configuration"
echo "==================================================================="
# Fields we extract:
#   .source.branch  -- which branch Pages serves from (main, master, gh-pages)
#   .source.path    -- which directory inside that branch (/ or /docs)
#   .build_type     -- 'legacy' means branch-based, 'workflow' means Actions
#   .html_url       -- the canonical URL Pages serves (we use this for curl)
#   .status         -- 'built', 'building', 'errored', 'null'
PAGES_CFG=$(gh api "repos/$REPO/pages" 2>&1) || {
    echo "FAIL: gh api returned an error:"
    echo "$PAGES_CFG"
    echo
    echo "Possible causes:"
    echo "  - Pages is not enabled for this repo"
    echo "  - gh is not authenticated (run: gh auth status)"
    echo "  - Repo name is wrong (current: $REPO)"
    exit 1
}

PAGES_BRANCH=$(echo "$PAGES_CFG" | jq -r '.source.branch')
PAGES_PATH=$(echo "$PAGES_CFG" | jq -r '.source.path')
PAGES_BUILD_TYPE=$(echo "$PAGES_CFG" | jq -r '.build_type')
PAGES_URL=$(echo "$PAGES_CFG" | jq -r '.html_url')
PAGES_STATUS=$(echo "$PAGES_CFG" | jq -r '.status')

echo "  branch:     $PAGES_BRANCH"
echo "  path:       $PAGES_PATH"
echo "  build_type: $PAGES_BUILD_TYPE   (legacy = branch-based, workflow = Actions)"
echo "  html_url:   $PAGES_URL"
echo "  status:     $PAGES_STATUS"

echo
echo "==================================================================="
echo "[2/6] Latest Pages build"
echo "==================================================================="
BUILD_JSON=$(gh api "repos/$REPO/pages/builds/latest" 2>&1) || BUILD_JSON='{}'
BUILD_STATUS=$(echo "$BUILD_JSON"  | jq -r '.status      // "unknown"')
BUILD_ERROR=$(echo  "$BUILD_JSON"  | jq -r '.error.message // "none"')
BUILD_COMMIT=$(echo "$BUILD_JSON"  | jq -r '.commit      // "unknown"')
BUILD_TIME=$(echo   "$BUILD_JSON"  | jq -r '.updated_at  // "unknown"')

echo "  status:  $BUILD_STATUS"
echo "  error:   $BUILD_ERROR"
echo "  commit:  $BUILD_COMMIT"
echo "  updated: $BUILD_TIME"

echo
echo "==================================================================="
echo "[3/6] Local HEAD vs remote configured branch"
echo "==================================================================="
LOCAL_HEAD=$(git rev-parse HEAD)
echo "  local HEAD:               $LOCAL_HEAD"

REMOTE_CONFIGURED=$(git ls-remote origin "$PAGES_BRANCH" 2>/dev/null | cut -f1 || echo "")
if [ -z "$REMOTE_CONFIGURED" ]; then
    echo "  remote $PAGES_BRANCH:  (branch does not exist on remote)"
else
    echo "  remote $PAGES_BRANCH:  $REMOTE_CONFIGURED"
fi

# Show all candidate branches so we can see where the code actually is
for b in main master gh-pages; do
    if [ "$b" != "$PAGES_BRANCH" ]; then
        OTHER=$(git ls-remote origin "$b" 2>/dev/null | cut -f1 || echo "")
        [ -n "$OTHER" ] && echo "  remote $b:    $OTHER"
    fi
done

echo
echo "==================================================================="
echo "[4/6] Served response headers (cache age tells us CDN freshness)"
echo "==================================================================="
curl -sI "$PAGES_URL" | grep -iE 'last-modified|^age:|x-served|etag|cache-control' \
    | sed 's/^/  /' || echo "  (no cache headers returned)"

echo
echo "==================================================================="
echo "[5/6] Content marker check (more reliable than sha256)"
echo "==================================================================="
curl -s "$PAGES_URL" -o /tmp/deployed_index.html

if [ ! -f "$LOCAL_FILE" ]; then
    echo "  FAIL: $LOCAL_FILE does not exist in current directory"
    echo "  Are you in the repo root? pwd: $(pwd)"
    exit 1
fi

LOCAL_HAS=$(grep -cF "$UNIQUE_MARKER" "$LOCAL_FILE" || true)
DEPLOYED_HAS=$(grep -cF "$UNIQUE_MARKER" /tmp/deployed_index.html || true)
echo "  marker text: \"$UNIQUE_MARKER\""
echo "  occurrences in local:    $LOCAL_HAS"
echo "  occurrences in deployed: $DEPLOYED_HAS"

if [ "$LOCAL_HAS" -eq 0 ]; then
    echo
    echo "  WARNING: marker not found in local file. Either you are not in"
    echo "  the right repo, or the UNIQUE_MARKER constant at the top of this"
    echo "  script is out of date. Update it to a string that exists ONLY in"
    echo "  the new version of index.html, then re-run."
    exit 1
fi

echo
echo "==================================================================="
echo "[6/6] DIAGNOSIS AND RECOMMENDED ACTION"
echo "==================================================================="

# Decision order matters: most-specific conditions first.

# Case E: deployment already succeeded, sha comparison was a false alarm
if [ "$DEPLOYED_HAS" -gt 0 ]; then
    echo "  Cause E: deployment ALREADY SUCCEEDED."
    echo
    echo "  The new code IS being served. The earlier sha256 mismatch was"
    echo "  a false negative -- curl-of-URL and file-on-disk can differ on"
    echo "  trailing whitespace alone. The grep above confirms the new code"
    echo "  is live."
    echo
    echo "  ACTION: open the URL in an incognito window (or hard-refresh):"
    echo "    $PAGES_URL"
    exit 0
fi

# Case B: build errored
if [ "$BUILD_STATUS" = "errored" ] || [ "$BUILD_STATUS" = "failed" ]; then
    echo "  Cause B: Pages build FAILED."
    echo
    echo "  Error message from GitHub:"
    echo "    $BUILD_ERROR"
    echo
    echo "  ACTION: read the error above. Common fixes:"
    echo "    - if it mentions Jekyll: create a .nojekyll file in the repo root"
    echo "    - if it mentions a workflow: check Actions tab for the failing step"
    echo "    - if it mentions invalid HTML/YAML: fix the file it points to"
    exit 1
fi

# Case C: build still running
if [ "$BUILD_STATUS" = "building" ] || [ "$BUILD_STATUS" = "queued" ]; then
    echo "  Cause C: Pages build IS IN PROGRESS."
    echo
    echo "  Build commit:  $BUILD_COMMIT"
    echo "  Build updated: $BUILD_TIME"
    echo
    echo "  ACTION: wait 60-120 seconds, then re-run this script."
    exit 0
fi

# Case A: wrong branch
if [ -z "$REMOTE_CONFIGURED" ]; then
    echo "  Cause A: Pages is configured for branch '$PAGES_BRANCH' but"
    echo "  that branch does not exist on the remote."
    echo
    echo "  ACTION: push your current HEAD to that branch:"
    echo "    git push origin HEAD:$PAGES_BRANCH"
    exit 1
fi

if [ "$LOCAL_HEAD" != "$REMOTE_CONFIGURED" ]; then
    echo "  Cause A: configured Pages branch '$PAGES_BRANCH' is at commit"
    echo "    $REMOTE_CONFIGURED"
    echo "  but your local HEAD is at"
    echo "    $LOCAL_HEAD"
    echo
    echo "  You pushed to a different branch than Pages serves from."
    echo
    echo "  ACTION: push your current HEAD to the configured Pages branch:"
    echo "    git push origin HEAD:$PAGES_BRANCH"
    echo
    echo "  Alternative: change the Pages source to the branch you pushed to,"
    echo "  in GitHub repo Settings -> Pages."
    exit 1
fi

# Case D: configured branch correct, build status fine, but content not served
echo "  Cause D: configured branch '$PAGES_BRANCH' is at the right commit"
echo "  ($LOCAL_HEAD) and build status is '$BUILD_STATUS', but the served"
echo "  content lacks the new marker. Most likely cause: CDN edge cache."
echo
echo "  ACTION (in order):"
echo "    1. Wait 5-10 minutes and re-run this script."
echo "    2. If still stale, force a fresh Pages build:"
echo "         git commit --allow-empty -m 'force pages rebuild'"
echo "         git push origin HEAD:$PAGES_BRANCH"
echo "    3. If still stale after that, check the Actions tab on github.com"
echo "       for build_type=$PAGES_BUILD_TYPE -- there may be a workflow"
echo "       that has to run and is being skipped."
exit 0

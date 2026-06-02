#!/bin/bash
# Mechanical compliance gate – runs all checks against a single server instance.
# Citations: skills_0030 T011 (Mechanical Compliance Gate), T018 (Idempotent Process Kill),
#            T019 (Trap-based cleanup), R041 (no unconditional xdg-open), R044 (tee output)

echo "========================================="
echo " LLM Evasion Detection Gate"
echo "========================================="

FAILED=0
LOG_FILE="/tmp/gate_run_$(date +%s).log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Helper: kill server on port 8765
kill_server() {
    lsof -ti:8765 | xargs kill -9 2>/dev/null || true
}

# Cleanup on exit
cleanup() {
    echo ""
    echo "🛑 Stopping server and cleaning up..."
    kill_server
    exit $FAILED
}
trap cleanup EXIT INT TERM

# 1. Static checks
bash test_static.sh || { echo "❌ static checks failed"; FAILED=1; }

# 2. Detectors (no server needed)
bash verification/check_fake_citations.sh      || { echo "❌ check_fake_citations failed"; FAILED=1; }
bash verification/check_terminal_logging.sh    || { echo "❌ check_terminal_logging failed"; FAILED=1; }
bash verification/check_features_not_removed.sh || { echo "❌ check_features_not_removed failed"; FAILED=1; }
bash verification/check_no_regex_breakage.sh   || { echo "❌ check_no_regex_breakage failed"; FAILED=1; }

# 3. Start server (once for all runtime tests)
kill_server
echo ""
echo "Starting server_with_logs.py (unbuffered)..."
python3 -u server_with_logs.py > /tmp/server_logs.txt 2>&1 &
SERVER_PID=$!
sleep 2

if ! curl -s http://localhost:8765 >/dev/null 2>&1; then
    echo "❌ Server failed to start. Last 20 lines of log:"
    tail -20 /tmp/server_logs.txt
    exit 1
fi

# Optional browser open (only with --open flag, R041)
if [ "$1" = "--open" ]; then
    command -v xdg-open >/dev/null 2>&1 && xdg-open http://localhost:8765 2>/dev/null &
fi

# 4. Runtime search tests
bash verification/check_search_works.sh        || { echo "❌ check_search_works failed"; FAILED=1; }

# Property‑based test (requires fast-check)
if command -v node >/dev/null 2>&1 && npm list fast-check >/dev/null 2>&1; then
    echo ""
    echo "Running property‑based search tests..."
    node verification/property_test_search.js || { echo "❌ property test failed"; FAILED=1; }
else
    echo "⚠️  Property test skipped – fast-check not installed. Run: npm install fast-check --save-dev"
fi

# Visual isolation test
if [ -f verification/verify_visual_search.js ]; then
    echo ""
    echo "Running visual isolation test (87 hidden, 13 visible confirms spheres hide)..."
    node verification/verify_visual_search.js || { echo "❌ visual isolation test failed"; FAILED=1; }
else
    echo "⚠️  verify_visual_search.js missing – skipping visual isolation test."
fi

# 5. Self‑test (already logged in server logs)
echo ""
echo "Waiting for self‑test to complete (max 60 seconds)..."
SELF_TEST_PASSED=0
for i in {1..60}; do
    if grep -q "self_test_complete" /tmp/server_logs.txt 2>/dev/null; then
        if grep -q "test_fail" /tmp/server_logs.txt; then
            echo "❌ Self‑test failures detected:"
            grep "test_fail" /tmp/server_logs.txt
            FAILED=1
        else
            echo "✅ Self‑test completed successfully."
            SELF_TEST_PASSED=1
        fi
        break
    fi
    sleep 1
done

if [ $SELF_TEST_PASSED -eq 0 ]; then
    echo "❌ Self‑test timed out (60 seconds). Last 20 lines:"
    tail -20 /tmp/server_logs.txt
    FAILED=1
fi

# 6. Warning only
if grep -q similarBtn index.html && [ ! -f similarity.json ]; then
    echo "⚠️  Warning: similarBtn exists but similarity.json is missing."
fi

# 7. Deployment check (only with --deploy)
if [ "$1" = "--deploy" ] && git rev-parse --verify HEAD >/dev/null 2>&1; then
    bash verification/check_deployment_sha256_match.sh || { echo "❌ deployment SHA256 mismatch"; FAILED=1; }
fi

# Final verdict
if [ $FAILED -eq 0 ]; then
    echo "========================================="
    echo " All checks passed. Ready to commit/push."
    echo "========================================="
else
    echo "========================================="
    echo " Some checks failed. Fix above issues."
    echo "========================================="
fi

exit $FAILED

#!/bin/bash
# T011 & best practice: dynamic search verification using Playwright auto‑waiting and console events.
# Tests "fedora", waits for console log, then verifies DOM reflects the count.
# Citations: skills_0030 T015 (Component Decomposition Notation), best_practice_libraries (Playwright)

echo "Checking search functionality (Playwright dynamic test)..."

if ! curl -s http://localhost:8765 >/dev/null 2>&1; then
    echo "❌ Server not running. Please start server_with_logs.py first."
    exit 1
fi

if ! command -v node >/dev/null 2>&1; then
    echo "❌ Node.js not found."
    exit 1
fi

# Install Playwright once if missing
if ! node -e "require('playwright')" 2>/dev/null; then
    echo "📦 Installing Playwright (first time only)..."
    npm init -y >/dev/null 2>&1
    npm install playwright >/dev/null 2>&1
    [ $? -ne 0 ] && { echo "❌ Playwright installation failed."; exit 1; }
    npx playwright install chromium >/dev/null 2>&1
fi

node << 'NODEEOF'
const { chromium } = require('playwright');

(async () => {
    let browser;
    try {
        browser = await chromium.launch({ headless: true });
        const page = await browser.newPage();

        // [C1] Console listener for fuzzy_search_result
        let visibleCount = null;
        page.on('console', msg => {
            const text = msg.text();
            console.log(`[BROWSER] ${msg.type()}: ${text}`);
            if (text.includes('"fuzzy_search_result"')) {
                try {
                    const json = JSON.parse(text);
                    if (json.event === 'fuzzy_search_result' && json.data && json.data.visible !== undefined) {
                        visibleCount = json.data.visible;
                    }
                } catch(e) {}
            }
        });

        // [C2] Navigate and wait for network idle
        await page.goto('http://localhost:8765/index.html', { waitUntil: 'networkidle' });
        const searchInput = page.locator('#fuzzySearchInput');
        await searchInput.waitFor({ state: 'visible' });

        const totalBefore = await page.locator('.repo-label').count();
        console.log(`📋 Total repos visible before search: ${totalBefore}`);

        const TEST_TERM = 'fedora';
        console.log(`🔍 Testing fuzzy search with term: "${TEST_TERM}"`);
        await searchInput.fill(TEST_TERM);

        // Wait for console event (max 5s)
        let waited = 0;
        while (visibleCount === null && waited < 50) {
            await page.waitForTimeout(100);
            waited++;
        }
        if (visibleCount === null) throw new Error('Timeout waiting for fuzzy_search_result log');
        console.log(`📊 Expected visible repos from log: ${visibleCount}`);

        // [C3] Allow CSS2DRenderer to apply visibility changes (skills_0030 R046)
        await page.waitForTimeout(200);

        // [C4] Directly evaluate visible count (same as verify_visual_search.js)
        const getVisibleCount = async () => {
            return await page.$$eval('.repo-label', els =>
                els.filter(el => {
                    const display = el.style.display || getComputedStyle(el).display;
                    return display !== 'none';
                }).length
            );
        };

        let actualCount = await getVisibleCount();
        let retries = 0;
        while (actualCount !== visibleCount && retries < 10) {
            await page.waitForTimeout(100);
            actualCount = await getVisibleCount();
            retries++;
        }

        if (actualCount !== visibleCount) {
            throw new Error(`Visible count mismatch: expected ${visibleCount}, got ${actualCount}`);
        }

        console.log(`📊 DOM visible repos after search: ${actualCount}`);

        // Also print matching names for debugging
        const visibleNames = await page.$$eval('.repo-label', els =>
            els.filter(el => {
                const display = el.style.display || getComputedStyle(el).display;
                return display !== 'none';
            }).map(el => el.textContent)
        );
        console.log(`✅ Found ${visibleNames.length} repositories matching "${TEST_TERM}":`);
        visibleNames.slice(0, 10).forEach(name => console.log(`   - ${name}`));
        if (visibleNames.length > 10) console.log(`   ... and ${visibleNames.length - 10} more`);

        if (actualCount === 0) {
            console.error(`❌ No results for "${TEST_TERM}" – search is broken.`);
            process.exit(1);
        } else if (actualCount === totalBefore) {
            console.error(`❌ Search did not filter any results – still showing all ${totalBefore} repos.`);
            process.exit(1);
        } else {
            console.log(`✅ Search filtering works (visible count decreased from ${totalBefore} to ${actualCount})`);
            process.exit(0);
        }
    } catch (err) {
        console.error(`ERROR: ${err.message}`);
        process.exit(1);
    } finally {
        if (browser) await browser.close();
    }
})();
NODEEOF

if [ $? -eq 0 ]; then
    echo "✅ Dynamic search test passed (filtering reduced visible count)"
    exit 0
else
    echo "❌ Dynamic search test failed – see output above."
    exit 1
fi

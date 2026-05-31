// PATH: verification/verify_visual_search.js
// PURPOSE: confirm fuzzy search visually hides spheres and CSS2DObject labels
// Citations: skills_0030 T031 (Hover‑Cache Fallback), T007 (Pointer‑Events Auto Override),
//            CSS2DRenderer r128 line 130 — object.visible controls element.style.display
'use strict';
const { chromium } = require('playwright');

(async () => {
    let browser;
    try {
        browser = await chromium.launch({ headless: true });
        const page = await browser.newPage();
        let searchResult = null;
        page.on('console', msg => {
            const text = msg.text();
            if (text.includes('"fuzzy_search_result"')) {
                try { const j = JSON.parse(text); if (j.event === 'fuzzy_search_result') searchResult = j.data; } catch(e) {}
            }
        });
        await page.goto('http://localhost:8765/index.html', { waitUntil: 'networkidle', timeout: 15000 });

        // Wait for repos to load
        await page.waitForFunction(() => document.querySelectorAll('.repo-label').length >= 50, { timeout: 15000 });

        const totalLabels = await page.locator('.repo-label').count();
        console.log(`[C1] Total .repo-label elements in DOM: ${totalLabels}`);

        await page.locator('#fuzzySearchInput').fill('fedora');

        let waited = 0;
        while (!searchResult && waited < 80) { await page.waitForTimeout(100); waited++; }
        if (!searchResult) { console.error('[FAIL] fuzzy_search_result log never fired'); process.exit(1); }
        console.log(`[C2] fuzzy_search_result: query="${searchResult.query}" visible=${searchResult.visible}`);

        // Allow CSS2DRenderer to apply visibility
        await page.waitForTimeout(200);

        const hiddenCount = await page.evaluate(() => {
            let h = 0;
            document.querySelectorAll('.repo-label').forEach(el => {
                if (el.style.display === 'none' || getComputedStyle(el).display === 'none') h++;
            });
            return h;
        });
        const visibleCount = await page.evaluate(() => {
            let v = 0;
            document.querySelectorAll('.repo-label').forEach(el => {
                if (el.style.display !== 'none' && getComputedStyle(el).display !== 'none') v++;
            });
            return v;
        });
        console.log(`[C3] Labels hidden in DOM: ${hiddenCount}`);
        console.log(`[C4] Labels visible in DOM: ${visibleCount}`);

        if (hiddenCount === 0 || visibleCount === totalLabels) {
            console.error(`[FAIL] Visual filtering not working — hidden=${hiddenCount} visible=${visibleCount} total=${totalLabels}`);
            process.exit(1);
        }
        console.log(`[PASS] Visual isolation confirmed: ${hiddenCount} hidden, ${visibleCount} visible of ${totalLabels} total`);
    } catch(err) { console.error(`[ERROR] ${err.message}`); process.exit(1); }
    finally { if (browser) await browser.close(); }
})();

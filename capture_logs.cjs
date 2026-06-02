const puppeteer = require('puppeteer');

(async () => {
  console.log('[CAPTURE] Starting – will output all browser console logs to terminal');
  const browser = await puppeteer.launch({ headless: false, dumpio: true });
  const page = await browser.newPage();
  page.on('console', msg => console.log(`[BROWSER] ${msg.text()}`));
  page.on('pageerror', err => console.log(`[PAGE ERROR] ${err.message}`));
  console.log('[CAPTURE] Navigating to http://localhost:8080');
  await page.goto('http://localhost:8080');
  // Keep browser open for 30 seconds to allow interaction
  await new Promise(r => setTimeout(r, 30000));
  await browser.close();
})();

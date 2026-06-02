const puppeteer = require('puppeteer');
(async () => {
  const browser = await puppeteer.launch({ headless: false });
  const page = await browser.newPage();
  page.on('console', msg => console.log(msg.text()));
  await page.goto('http://localhost:8080');
  await page.click('#debug-toggle');
  console.log('\n=== Interact now. Press Ctrl+C to stop and save logs ===\n');
  // Keep alive until Ctrl+C
  await new Promise(() => {});
})();

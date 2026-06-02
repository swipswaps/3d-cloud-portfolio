const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({ headless: false, dumpio: true });
  const page = await browser.newPage();

  // Capture console with file/line/col
  page.on('console', msg => {
    const loc = msg.location();
    console.log(`[BROWSER ${msg.type().toUpperCase()}] ${msg.text()} (${loc.url || 'inline'}:${loc.lineNumber}:${loc.columnNumber})`);
  });

  // Capture errors with stack traces
  page.on('pageerror', err => {
    console.log(`[PAGE ERROR] ${err.message}`);
    if (err.stack) console.log(`[STACK] ${err.stack}`);
  });

  // Capture unhandled rejections
  page.on('requestfailed', req => {
    console.log(`[REQUEST FAILED] ${req.url()} - ${req.failure().errorText}`);
  });

  // Capture network responses (full body for API)
  page.on('response', async res => {
    const url = res.url();
    if (url.includes('api.github.com') || url.includes('localhost')) {
      console.log(`[NETWORK RESP] ${res.status()} ${url}`);
      try {
        const body = await res.text();
        console.log(`[RESPONSE BODY] ${body.substring(0, 500)}`);
      } catch(e) {}
    }
  });

  await page.goto('http://localhost:8080', { waitUntil: 'networkidle2' });

  // Expand debug panel
  await page.click('#debug-toggle');

  // Wait for repos to load
  await page.waitForSelector('.css2d-object', { timeout: 10000 });

  // Simulate clicks on first 3 spheres
  const labels = await page.$$('.css2d-object');
  for (let i = 0; i < Math.min(3, labels.length); i++) {
    await labels[i].click();
    await new Promise(r => setTimeout(r, 500));
  }

  // Simulate drag
  const canvas = await page.$('canvas');
  if (canvas) {
    const bounds = await canvas.boundingBox();
    await page.mouse.move(bounds.x + bounds.width/2, bounds.y + bounds.height/2);
    await page.mouse.down();
    await page.mouse.move(bounds.x + bounds.width/2 + 100, bounds.y + bounds.height/2 + 50, { steps: 10 });
    await page.mouse.up();
  }

  // Wait a moment for logs to flush
  await new Promise(r => setTimeout(r, 2000));

  // Get debug panel content
  const debugContent = await page.evaluate(() => document.getElementById('debug-panel')?.innerText);
  console.log('\n=== DEBUG PANEL CONTENT ===\n', debugContent);

  await browser.close();
})();

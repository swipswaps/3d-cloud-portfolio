const puppeteer = require('puppeteer');
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

(async () => {
  const browser = await puppeteer.launch({ headless: false, dumpio: true });
  const page = await browser.newPage();

  const logs = [];

  // Capture everything
  page.on('console', msg => {
    const loc = msg.location();
    const logLine = `[BROWSER ${msg.type().toUpperCase()}] ${msg.text()} (${loc.url || 'inline'}:${loc.lineNumber}:${loc.columnNumber})`;
    logs.push(logLine);
    console.log(logLine);
  });
  page.on('pageerror', err => {
    logs.push(`[PAGE ERROR] ${err.message}`);
    if (err.stack) logs.push(`[STACK] ${err.stack}`);
    console.log(`[PAGE ERROR] ${err.message}`);
  });
  page.on('requestfailed', req => {
    const line = `[REQUEST FAILED] ${req.url()} - ${req.failure().errorText}`;
    logs.push(line);
    console.log(line);
  });
  page.on('response', async res => {
    const url = res.url();
    if (url.includes('api.github.com')) {
      const line = `[NETWORK RESP] ${res.status()} ${url}`;
      logs.push(line);
      console.log(line);
      try {
        const body = await res.text();
        const bodyLine = `[RESPONSE BODY] ${body.substring(0, 500)}`;
        logs.push(bodyLine);
        console.log(bodyLine);
      } catch(e) {}
    }
  });

  await page.goto('http://localhost:8080', { waitUntil: 'networkidle2' });
  await page.click('#debug-toggle'); // expand debug panel

  console.log('\n=== 🖱️ NOW INTERACT WITH THE BROWSER ===');
  console.log('Click spheres, drag the cloud, double-click, hover...');
  console.log('When you are done, close the browser window OR press Ctrl+C in this terminal.\n');

  // Wait until the browser is closed manually
  await new Promise(resolve => {
    const checkInterval = setInterval(async () => {
      const pages = await browser.pages();
      if (pages.length === 0 || !pages[0].isClosed()) {
        // still open
        return;
      }
      clearInterval(checkInterval);
      resolve();
    }, 1000);
  });

  console.log('\n=== ALL CAPTURED LOGS ===');
  logs.forEach(l => console.log(l));

  await browser.close();
  rl.close();
  process.exit(0);
})();

const puppeteer = require('puppeteer');
const { spawn } = require('child_process');
const fs = require('fs');
const logFile = fs.createWriteStream('/tmp/full_browser_log.txt', { flags: 'w' });
function tee(msg) {
    console.log(msg);
    logFile.write(msg + '\n');
}

// Start local server on port 8765
const server = spawn('python3', ['-m', 'http.server', '8765', '--bind', '127.0.0.1']);
server.stdout.on('data', d => tee(`[SERVER] ${d}`));
server.stderr.on('data', d => tee(`[SERVER ERR] ${d}`));

setTimeout(async () => {
    tee('🚀 Launching browser (headless=false, dumpio=true)...');
    const browser = await puppeteer.launch({ headless: false, dumpio: true });
    const page = await browser.newPage();
    page.on('console', msg => tee(`[BROWSER] ${msg.type()}: ${msg.text()}`));
    page.on('pageerror', err => tee(`[PAGE ERROR] ${err.message}`));
    page.on('requestfailed', req => tee(`[FAILED] ${req.url()} - ${req.failure().errorText}`));
    
    await page.goto('http://localhost:8765/index.html');
    tee('✅ Page loaded. Perform actions now (clicks, drags, double‑clicks).');
    tee('⏱️ Logs will be captured for 30 seconds, then saved to /tmp/full_browser_log.txt');
    
    setTimeout(async () => {
        tee('⏹️ Stopping capture...');
        await browser.close();
        server.kill();
        tee(`✅ Logs saved to /tmp/full_browser_log.txt`);
        process.exit(0);
    }, 30000);
}, 2000);

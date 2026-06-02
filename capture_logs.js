const puppeteer = require('puppeteer');
const { spawn } = require('child_process');
const fs = require('fs');
const logStream = fs.createWriteStream('/tmp/captured_logs.txt', { flags: 'a' });

function tee(msg) {
    console.log(msg);
    logStream.write(msg + '\n');
}

// Start local server (assumes Python HTTP server on port 8765)
const server = spawn('python3', ['-m', 'http.server', '8765', '--bind', '127.0.0.1']);
server.stdout.on('data', d => tee(`[SERVER] ${d}`));
server.stderr.on('data', d => tee(`[SERVER ERR] ${d}`));

setTimeout(async () => {
    const browser = await puppeteer.launch({ headless: false, dumpio: true });
    const page = await browser.newPage();
    page.on('console', msg => tee(`[BROWSER] ${msg.type()}: ${msg.text()}`));
    page.on('pageerror', err => tee(`[PAGE ERROR] ${err.message}`));
    page.on('requestfailed', req => tee(`[FAILED] ${req.url()} - ${req.failure().errorText}`));
    
    await page.goto('http://localhost:8765/index.html');
    tee('✅ Page loaded. Perform clicks/drags now. Press Ctrl+C to stop capture.');
    
    // Wait 30 seconds for manual testing, then close
    setTimeout(async () => {
        tee('⏱️ Capture ending in 5 seconds...');
        await browser.close();
        server.kill();
        tee('✅ Capture complete. Logs saved to /tmp/captured_logs.txt');
        process.exit(0);
    }, 35000);
}, 2000);

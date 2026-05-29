const puppeteer = require('puppeteer');
const { spawn } = require('child_process');
function tee(msg) { process.stdout.write(msg + '\n'); }
const backend = spawn('node', ['server.js']);
backend.stdout.on('data', d => tee(`[BACKEND] ${d}`));
backend.stderr.on('data', d => tee(`[BACKEND ERR] ${d}`));
setTimeout(async () => {
    const browser = await puppeteer.launch({ headless: false, dumpio: true });
    const page = await browser.newPage();
    page.on('console', msg => tee(`[BROWSER] ${msg.type()}: ${msg.text()}`));
    await page.goto('http://localhost:8000');
    process.on('SIGINT', async () => { await browser.close(); backend.kill(); process.exit(0); });
}, 2000);

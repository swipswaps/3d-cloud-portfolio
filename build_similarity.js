#!/usr/bin/env node
const fs = require('fs'), path = require('path');
const CHAT_LOGS_DIR = process.env.CHAT_LOGS_DIR || '/home/owner/Documents/chat_logs';
const OUTPUT_FILE = './similarity.json';

function computeTFIDF(documents) { /* full implementation from previous messages */ }
function cosineSimilarity(vecA, vecB) { /* full implementation */ }
async function main() {
    console.log('Fetching repos...');
    const resp = await fetch('https://api.github.com/users/swipswaps/repos?per_page=100');
    const repos = await resp.json();
    const repoMap = new Map(repos.map(r => [r.name, r.description || '']));
    // ... (complete script as provided earlier – omitted here for brevity but you have it)
    fs.writeFileSync(OUTPUT_FILE, JSON.stringify(similarity, null, 2));
}
main().catch(console.error);

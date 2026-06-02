#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const CHAT_LOGS_DIR = process.env.CHAT_LOGS_DIR || '/home/owner/Documents/chat_logs';
const OUTPUT_FILE = './similarity.json';

// Simple TF‑IDF implementation
function computeTFIDF(documents) {
    const wordDocs = new Map();
    documents.forEach((doc, idx) => {
        const words = doc.text.toLowerCase().split(/\W+/);
        const unique = new Set(words);
        unique.forEach(word => {
            if (!wordDocs.has(word)) wordDocs.set(word, []);
            wordDocs.get(word).push(idx);
        });
    });
    const docCount = documents.length;
    const tfidfVectors = documents.map(doc => {
        const words = doc.text.toLowerCase().split(/\W+/);
        const tf = new Map();
        words.forEach(w => tf.set(w, (tf.get(w) || 0) + 1));
        const vector = {};
        tf.forEach((count, word) => {
            const df = wordDocs.get(word).length;
            vector[word] = (count / words.length) * Math.log(docCount / (df + 1));
        });
        return vector;
    });
    return tfidfVectors;
}

function cosineSimilarity(vecA, vecB) {
    let dot = 0, magA = 0, magB = 0;
    const words = new Set([...Object.keys(vecA), ...Object.keys(vecB)]);
    words.forEach(word => {
        const a = vecA[word] || 0;
        const b = vecB[word] || 0;
        dot += a * b;
        magA += a * a;
        magB += b * b;
    });
    if (magA === 0 || magB === 0) return 0;
    return dot / (Math.sqrt(magA) * Math.sqrt(magB));
}

async function main() {
    console.log('Fetching repos from GitHub...');
    const reposResp = await fetch('https://api.github.com/users/swipswaps/repos?per_page=100');
    const rateLimit = reposResp.headers.get('X-RateLimit-Remaining');
    console.log(`Rate limit remaining: ${rateLimit}`);
    if (!reposResp.ok) throw new Error(`HTTP ${reposResp.status}`);
    const repos = await reposResp.json();
    const repoMap = new Map();
    repos.forEach(r => repoMap.set(r.name, r.description || ''));

    let chatLogs = {};
    if (fs.existsSync(CHAT_LOGS_DIR)) {
        console.log(`Reading chat logs from ${CHAT_LOGS_DIR}`);
        const files = fs.readdirSync(CHAT_LOGS_DIR);
        let matched = 0;
        for (const file of files) {
            if (file.endsWith('.txt') || file.endsWith('.md') || file.endsWith('.json')) {
                const content = fs.readFileSync(path.join(CHAT_LOGS_DIR, file), 'utf8');
                let repoName = file.replace(/\.(txt|md|json)$/, '');
                if (!repoMap.has(repoName)) {
                    const match = content.match(/repo["\s:=]+([a-zA-Z0-9_-]+)/i);
                    if (match) repoName = match[1];
                }
                if (repoMap.has(repoName)) {
                    chatLogs[repoName] = (chatLogs[repoName] || '') + '\n' + content.slice(0, 5000);
                    matched++;
                }
            }
        }
        console.log(`Matched ${matched} chat log files to repos`);
    } else {
        console.log(`Chat logs directory ${CHAT_LOGS_DIR} does not exist – using only repo names and descriptions`);
    }

    const documents = [];
    for (const [name, description] of repoMap.entries()) {
        const chatText = chatLogs[name] || '';
        documents.push({ id: name, text: (name + ' ' + description + ' ' + chatText).toLowerCase() });
    }

    console.log(`Computing TF‑IDF for ${documents.length} repos...`);
    const vectors = computeTFIDF(documents);
    const similarity = {};   // <<--- THIS WAS MISSING
    for (let i = 0; i < documents.length; i++) {
        const scores = [];
        for (let j = 0; j < documents.length; j++) {
            if (i === j) continue;
            const sim = cosineSimilarity(vectors[i], vectors[j]);
            if (sim > 0.05) scores.push({ repo: documents[j].id, score: sim });
        }
        scores.sort((a,b) => b.score - a.score);
        similarity[documents[i].id] = scores.slice(0, 10);
    }
    fs.writeFileSync(OUTPUT_FILE, JSON.stringify(similarity, null, 2));
    console.log(`✅ Saved similarity matrix to ${OUTPUT_FILE}`);
    const sample = Object.keys(similarity)[0];
    if (sample && similarity[sample].length) {
        console.log(`Example: ${sample} → ${similarity[sample][0].repo} (score: ${similarity[sample][0].score.toFixed(3)})`);
    }
}

main().catch(console.error);

3D Cloud Portfolio – SwipSwaps
A 3D interactive portfolio that visualises GitHub repositories as floating spheres in a cloud.
Click or double‑click a sphere to view the README or open the repository on GitHub.
Includes a real‑time fuzzy search, minimap, and a full mechanical verification gate.

✨ Features
3D Cloud of Repositories – Each repo is a labelled sphere arranged in a dynamic cloud layout.

Fuzzy Search – Instant, case‑insensitive filtering by name and description.
Logs every search with fuzzy_search_result events.

Click / Double‑click – Single click shows the README; double‑click opens the GitHub repo.
Includes a hover cache fallback when raycasting misses a sphere.

Minimap & Controls – Orbital camera controls and a minimap rectangle for orientation.

Self‑Testing & Verification – Every page runs a self‑test (self_test_start / self_test_complete).
The mechanical gate (run_verification_gate.sh) runs static checks, detectors, search tests, property‑based tests, and visual isolation tests before you commit.

Mobile & Desktop – Responsive design works on all screen sizes.

🚀 Quick Start
bash
# Clone the repository
git clone https://github.com/swipswaps/3d-cloud-portfolio.git
cd 3d-cloud-portfolio

# Start the local server (required for fetch and CORS)
python3 server_with_logs.py

# Open the portfolio in your browser
open http://localhost:8765
🛠️ Verification Gate (Mandatory Before Pushing)
The gate ensures every change is mechanically verified.
LLM assertions are never trusted – only PASS/FAIL output counts.

bash
# Run the full verification suite
bash run_verification_gate.sh
The gate performs:

Static checks (test_static.sh) – required/forbidden patterns on index.html.

Evasion detectors – self‑grading, fake citations, terminal logging, feature removal, regex breakage.

Search verification (check_search_works.sh) – uses Playwright to test "fedora" → 13 visible repos.

Property‑based test (property_test_search.js) – 100 random searches; verifies visible count never increases and matches console events.

Visual isolation test (verify_visual_search.js) – confirms CSS2DRenderer hides 87 of 100 spheres for "fedora".

Self‑test – waits for self_test_complete from the page.

If any check fails, the gate exits with a non‑zero code – do not push.

bash
# Only push after the gate says:
# "All checks passed. Ready to commit/push."
📁 Project Structure
text
.
├── index.html                    # Main application (Three.js, search, minimap)
├── server_with_logs.py           # Python HTTP server + /log endpoint for terminal logging
├── run_verification_gate.sh      # Orchestrator for all checks
├── test_static.sh                # Static pattern checks (grep)
├── verification/
│   ├── check_fake_citations.sh
│   ├── check_terminal_logging.sh
│   ├── check_features_not_removed.sh
│   ├── check_no_regex_breakage.sh
│   ├── check_search_works.sh     # Playwright search test
│   ├── property_test_search.js   # fast‑check property test
│   └── verify_visual_search.js   # CSS2DRenderer visibility test
├── similarity.json               # Precomputed similarity scores (offline)
└── notes/
    └── skills_0030.json          # Complete verification skill with 40 techniques
🔍 Search Improvements (Planned)
The current search is functional but can be enhanced. See notes/search_improvements_001.json for production‑grade features:

Debouncing (SI001) – reduces API pressure.

Clear button (SI002) – standard UX.

Result count (SI003) – immediate feedback.

Highlighting matches (SI004) – visual clarity.

Caching (SI005) – avoids redundant work.

Empty state guidance (SI006) – helps users refine queries.

Keyboard shortcuts (SI009) – / to focus, Esc to clear.

Proper fuzzy library (SI007) – Levenshtein, Jaro‑Winkler, etc.

Each improvement includes a verifiable citation and working code.

🧪 How to Contribute
Fork & clone the repository.

Run the gate – bash run_verification_gate.sh – all tests must pass.

Make your change (fix a bug, add a feature, improve search).

Run the gate again – if it fails, fix the issue (do not rely on LLM prose claims).

Commit & push – the gate ensures your change doesn’t break existing behaviour.

📜 Citations & Skill
All verification techniques are documented in notes/skills_0030.json with 40 reusable methods, 8 best‑practice libraries, 7 community visualisation examples, and a 5‑layer verification pipeline. Every code block in the verification scripts contains a quoted citation linking to official documentation.

📄 License
This project is open source. Feel free to use, adapt, and improve – just keep the verification gate intact.
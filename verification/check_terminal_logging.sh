#!/bin/bash
# T001: Ensure terminal logging hooks are present (robust)
if grep -q "fetch.*'/log'" index.html && grep -q "terminalLoggingEnabled" index.html; then
    echo "PASS: Terminal logging hooks present"
    exit 0
else
    echo "FAIL: Missing terminal logging (fetch('/log') or terminalLoggingEnabled)"
    exit 1
fi

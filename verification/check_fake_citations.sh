#!/bin/bash
mis=0
for ref in $(grep -oP 'skills_\d+\.json' index.html | sort -u); do
    if [ ! -f "../notes/$ref" ]; then
        echo "FAIL: Fake citation $ref does not exist"
        mis=1
    fi
done
[ $mis -eq 0 ] && echo "PASS: All citations exist"
exit $mis

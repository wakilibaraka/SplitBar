#!/bin/bash
repo="wakilibaraka/SplitBar"
run_id="36409541581"
job_id="108886228414"

while true; do
    status=$(gh run view $run_id --repo $repo)
    if echo "$status" | grep -q "completed"; then
        echo "Job completed!"
        break
    elif echo "$status" | grep -q "X main"; then
        echo "Job failed!"
        break
    elif echo "$status" | grep -q "✓ main"; then
        echo "Job succeeded!"
        break
    fi
    echo "Still running... sleeping 10s"
    sleep 10
done

echo "Fetching logs..."
gh run view --job=$job_id --repo $repo --log > ci_log.txt
grep -E "error:" ci_log.txt | head -n 20

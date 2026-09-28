#!/bin/bash
repo="wakilibaraka/SplitBar"

echo "Waiting for a new run to appear..."
sleep 5

while true; do
    run_id=$(gh run list --repo $repo --limit 1 --json databaseId -q ".[0].databaseId")
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

echo "Status:"
echo "$status"

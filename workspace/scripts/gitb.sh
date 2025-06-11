#!/bin/bash

usage="Usage: git-open [-pr|--pr]"
description="Opens the current Git branch or its latest PR/MR in the web interface (GitHub, GitLab, Bitbucket, etc.)."

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  echo "$usage"
  echo "$description"
  exit 0
fi

open_pr=false
if [[ "$1" == "--pr" || "$1" == "-pr" ]]; then
  open_pr=true
fi

# Ensure we're inside a Git repo
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "Not a Git repository. Navigate to one and try again."
  exit 1
fi

remote=$(git config --get remote.origin.url)
if [ -z "$remote" ]; then
  echo "No remote origin found. Set a remote repository first."
  exit 1
fi

# Normalize URL
url=$(echo "$remote" | sed -E 's#git@([^:]+):#https://\1/#; s#(https://[^/]+)/([^ ]+)#\1/\2#; s#\.git$##')
branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD)

# Extract host and repo path
host=$(echo "$url" | awk -F/ '{print $3}')
repo_path=$(echo "$url" | cut -d'/' -f4-)

# Determine URL
if $open_pr; then
  if echo "$host" | grep -q "github.com"; then
    pr_url="https://$host/$repo_path/pulls?q=is%3Apr+is%3Aopen+head%3A$branch"
  elif echo "$host" | grep -q "gitlab.com"; then
    pr_url="https://$host/$repo_path/-/merge_requests?scope=all&state=opened&search=$branch"
  elif echo "$host" | grep -q "bitbucket.org"; then
    pr_url="https://$host/$repo_path/pull-requests/?q=source.branch.name=\"$branch\""
  else
    echo "PR search not supported for host: $host"
    exit 1
  fi

  echo "Opening PR search URL: $pr_url"
  if command -v xdg-open > /dev/null; then
    xdg-open "$pr_url" &> /dev/null
  elif command -v open > /dev/null; then
    open "$pr_url" &> /dev/null
  elif command -v start > /dev/null; then
    start "$pr_url" &> /dev/null
  else
    echo "No supported browser open command found."
    echo "Visit manually: $pr_url"
  fi
  exit 0
fi

# Fallback: open branch in repo
if echo "$host" | grep -q "github.com"; then
  final_url="$url/tree/$branch"
elif echo "$host" | grep -q "gitlab.com"; then
  final_url="$url/-/tree/$branch"
elif echo "$host" | grep -q "bitbucket.org"; then
  final_url="$url/src/$branch"
else
  final_url="$url/tree/$branch"
fi

echo "Opening: $final_url"
if command -v xdg-open > /dev/null; then
  xdg-open "$final_url" &> /dev/null
elif command -v open > /dev/null; then
  open "$final_url" &> /dev/null
elif command -v start > /dev/null; then
  start "$final_url" &> /dev/null
else
  echo "No supported browser open command found."
  echo "Visit manually: $final_url"
fi


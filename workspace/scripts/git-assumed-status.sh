git status -sb
echo
echo "=== Assumed-Unchanged Files ==="
git ls-files -v | grep '^[a-z]' | awk '{print $2}' | while read f; do
    git update-index --no-assume-unchanged "$f"
    git status -sb -- "$f"
    git update-index --assume-unchanged "$f"
done


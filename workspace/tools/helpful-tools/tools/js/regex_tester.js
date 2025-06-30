let currentMatches = [];
let matchPanelVisible = false;

function getRegexFlags() {
    let flags = '';
    if (document.getElementById('flagGlobal').checked) flags += 'g';
    if (document.getElementById('flagIgnoreCase').checked) flags += 'i';
    if (document.getElementById('flagMultiline').checked) flags += 'm';
    if (document.getElementById('flagDotAll').checked) flags += 's';
    if (document.getElementById('flagUnicode').checked) flags += 'u';
    return flags;
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function testRegex() {
    const regexInput = document.getElementById('regexInput');
    const testText = document.getElementById('testText').value;
    const regexError = document.getElementById('regexError');
    const highlightedText = document.getElementById('highlightedText');
    const matchCount = document.getElementById('matchCount');
    const statusText = document.getElementById('statusText');
    const matchesList = document.getElementById('matchesList');

    const pattern = regexInput.value.trim();

    // Clear previous error
    regexError.textContent = '';
    regexInput.className = 'regex-input';

    if (!pattern) {
        highlightedText.innerHTML = '<div class="regex-no-match">Enter a regex pattern to test</div>';
        matchCount.textContent = 'NO PATTERN';
        matchCount.className = 'match-indicator';
        statusText.textContent = 'Enter a regex pattern';
        statusText.style.color = '#ff8800';
        return;
    }

    if (!testText) {
        highlightedText.innerHTML = '<div class="regex-no-match">Enter test string to match against</div>';
        matchCount.textContent = 'NO TEXT';
        matchCount.className = 'match-indicator';
        statusText.textContent = 'Enter test string';
        statusText.style.color = '#ff8800';
        return;
    }

    try {
        const flags = getRegexFlags();
        const regex = new RegExp(pattern, flags);
        regexInput.className = 'regex-input valid';

        // Find all matches
        const matches = [];
        let match;

        if (flags.includes('g')) {
            while ((match = regex.exec(testText)) !== null) {
                matches.push({
                    match: match[0],
                    index: match.index,
                    groups: match.slice(1),
                    fullMatch: match
                });

                // Prevent infinite loop on zero-length matches
                if (match.index === regex.lastIndex) {
                    regex.lastIndex++;
                }
            }
        } else {
            match = regex.exec(testText);
            if (match) {
                matches.push({
                    match: match[0],
                    index: match.index,
                    groups: match.slice(1),
                    fullMatch: match
                });
            }
        }

        currentMatches = matches;

        // Update match count
        if (matches.length > 0) {
            matchCount.textContent = `${matches.length} MATCH${matches.length > 1 ? 'ES' : ''}`;
            matchCount.className = 'match-indicator matches';
            statusText.textContent = `Found ${matches.length} match${matches.length > 1 ? 'es' : ''}`;
            statusText.style.color = '#008000';
        } else {
            matchCount.textContent = 'NO MATCHES';
            matchCount.className = 'match-indicator no-matches';
            statusText.textContent = 'No matches found';
            statusText.style.color = '#ff8800';
        }

        // Highlight matches in text
        highlightMatches(testText, matches);

        // Update matches list
        updateMatchesList(matches);

        // Show match panel by default when there are matches
        if (matches.length > 0 && !matchPanelVisible) {
            toggleMatchPanel();
        }

    } catch (error) {
        regexInput.className = 'regex-input error';
        regexError.textContent = 'Error: ' + error.message;
        highlightedText.innerHTML = '<div class="regex-no-match">Invalid regex pattern</div>';
        matchCount.textContent = 'ERROR';
        matchCount.className = 'match-indicator no-matches';
        statusText.textContent = 'Regex error: ' + error.message;
        statusText.style.color = '#cc0000';
        currentMatches = [];
        matchesList.innerHTML = '';
    }
}

function highlightMatches(text, matches) {
    const highlightedText = document.getElementById('highlightedText');

    if (matches.length === 0) {
        highlightedText.innerHTML = '<div class="regex-no-match">No matches found</div>';
        return;
    }

    // Sort matches by index (descending) to avoid index shifting during replacement
    const sortedMatches = [...matches].sort((a, b) => b.index - a.index);

    let highlightedContent = escapeHtml(text);

    // Replace matches with highlighted versions (backwards to preserve indices)
    sortedMatches.forEach((matchData, sortIndex) => {
        const start = matchData.index;
        const end = start + matchData.match.length;
        const matchText = escapeHtml(matchData.match);

        const before = highlightedContent.substring(0, start);
        const after = highlightedContent.substring(end);

        highlightedContent = before + `<span class="regex-match">${matchText}</span>` + after;
    });

    // Convert newlines to <br> for proper display
    highlightedContent = highlightedContent.replace(/\n/g, '<br>');

    highlightedText.innerHTML = highlightedContent;
}

function updateMatchesList(matches) {
    const matchesList = document.getElementById('matchesList');

    if (matches.length === 0) {
        matchesList.innerHTML = '<div style="padding: 12px; color: #999; font-style: italic;">No matches to display</div>';
        return;
    }

    let listHTML = '';
    matches.forEach((matchData, index) => {
        const endIndex = matchData.index + matchData.match.length - 1;

        listHTML += `
                <div class="match-item">
                    <span class="match-index">#${index + 1}</span>
                    <span class="match-text">${escapeHtml(matchData.match)}</span>
                    <span class="match-position">[${matchData.index}-${endIndex}]</span>
            `;

        if (matchData.groups.length > 0) {
            listHTML += '<div class="group-matches">';
            matchData.groups.forEach((group, groupIndex) => {
                if (group !== undefined) {
                    listHTML += `<span class="group-match">Group ${groupIndex + 1}: "${escapeHtml(group)}"</span>`;
                }
            });
            listHTML += '</div>';
        }

        listHTML += '</div>';
    });

    matchesList.innerHTML = listHTML;
}

function toggleMatchPanel() {
    const matchesPanel = document.getElementById('matchesPanel');
    const button = event.target;

    matchPanelVisible = !matchPanelVisible;

    if (matchPanelVisible) {
        matchesPanel.style.display = 'block';
        button.textContent = 'Hide Matches';
    } else {
        matchesPanel.style.display = 'none';
        button.textContent = 'Show Matches';
    }
}

function loadExample(pattern, text) {
    document.getElementById('regexInput').value = pattern;
    document.getElementById('testText').value = text;
    updateRegexInfo();
    testRegex();
}

function loadSampleData() {
    loadExample(
        '\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b',
        'Please contact us at:\n' +
        'john.doe@example.com\n' +
        'support@company.org\n' +
        'invalid-email\n' +
        'test@domain.co.uk\n' +
        'user123@test-site.com'
    );
}

function clearAll() {
    document.getElementById('regexInput').value = '';
    document.getElementById('testText').value = '';
    document.getElementById('highlightedText').innerHTML = '<div class="regex-no-match">Enter a regex pattern and test string to see matches highlighted</div>';
    document.getElementById('regexError').textContent = '';
    document.getElementById('matchCount').textContent = 'NO MATCHES';
    document.getElementById('matchCount').className = 'match-indicator';
    document.getElementById('statusText').textContent = 'Ready - Enter a regex pattern and test string';
    document.getElementById('statusText').style.color = '#666';
    document.getElementById('matchesList').innerHTML = '';
    document.getElementById('regexInput').className = 'regex-input';
    currentMatches = [];
    updateRegexInfo();
}

function copyMatches() {
    if (currentMatches.length === 0) {
        document.getElementById('statusText').textContent = 'No matches to copy';
        document.getElementById('statusText').style.color = '#ff8800';
        return;
    }

    const matchText = currentMatches.map((match, index) => {
        let result = `Match ${index + 1}: "${match.match}" [${match.index}-${match.index + match.match.length - 1}]`;
        if (match.groups.length > 0) {
            const groups = match.groups.map((group, i) => group !== undefined ? `Group ${i + 1}: "${group}"` : '').filter(g => g);
            if (groups.length > 0) {
                result += '\n  ' + groups.join('\n  ');
            }
        }
        return result;
    }).join('\n\n');

    navigator.clipboard.writeText(matchText).then(() => {
        const statusText = document.getElementById('statusText');
        const originalText = statusText.textContent;
        const originalColor = statusText.style.color;
        statusText.textContent = 'Matches copied to clipboard';
        statusText.style.color = '#008000';
        setTimeout(() => {
            statusText.textContent = originalText;
            statusText.style.color = originalColor;
        }, 2000);
    }).catch(() => {
        const textArea = document.createElement('textarea');
        textArea.value = matchText;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
    });
}

function updateRegexInfo() {
    const pattern = document.getElementById('regexInput').value;
    const testText = document.getElementById('testText').value;
    const flags = getRegexFlags();

    document.getElementById('regexInfo').textContent =
        `Pattern: ${pattern || 'None'} /${flags}/ | Test length: ${testText.length}`;
}

// Auto-test on input change
document.getElementById('regexInput').addEventListener('input', function() {
    updateRegexInfo();
    clearTimeout(this.testTimer);
    this.testTimer = setTimeout(testRegex, 300);
});

document.getElementById('testText').addEventListener('input', function() {
    updateRegexInfo();
    clearTimeout(this.testTimer);
    this.testTimer = setTimeout(testRegex, 300);
});

// Auto-test on flag change
document.querySelectorAll('input[type="checkbox"]').forEach(checkbox => {
    checkbox.addEventListener('change', function() {
        updateRegexInfo();
        testRegex();
    });
});

// Initialize
updateRegexInfo();
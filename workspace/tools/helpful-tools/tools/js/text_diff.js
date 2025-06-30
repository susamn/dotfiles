async function compareTexts() {
    const text1 = document.getElementById('text1').value;
    const text2 = document.getElementById('text2').value;

    document.getElementById('left-diff').innerHTML = '<div class="loading">Comparing...</div>';
    document.getElementById('right-diff').innerHTML = '<div class="loading">Comparing...</div>';
    document.getElementById('stats').textContent = 'Comparing texts...';

    try {
        const response = await fetch('/api/text-diff/compare', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ text1, text2 })
        });

        const result = await response.json();

        if (result.success) {
            displayDiff(result.diff);
        } else {
            document.getElementById('stats').textContent = 'Error: ' + result.error;
            document.getElementById('left-diff').innerHTML = '<div class="loading">Error occurred</div>';
            document.getElementById('right-diff').innerHTML = '<div class="loading">Error occurred</div>';
        }
    } catch (error) {
        console.error('Error:', error);
        document.getElementById('stats').textContent = 'Network error occurred';
        document.getElementById('left-diff').innerHTML = '<div class="loading">Network error</div>';
        document.getElementById('right-diff').innerHTML = '<div class="loading">Network error</div>';
    }
}

function displayDiff(diffData) {
    const leftDiff = document.getElementById('left-diff');
    const rightDiff = document.getElementById('right-diff');

    leftDiff.innerHTML = '';
    rightDiff.innerHTML = '';

    let leftLineNum = 1;
    let rightLineNum = 1;
    let deletions = 0;
    let insertions = 0;
    let equals = 0;

    diffData.forEach(item => {
        const leftLine = createLine(item, 'left', leftLineNum, rightLineNum);
        const rightLine = createLine(item, 'right', leftLineNum, rightLineNum);

        leftDiff.appendChild(leftLine);
        rightDiff.appendChild(rightLine);

        if (item.type === 'equal') {
            equals++;
            leftLineNum++;
            rightLineNum++;
        } else if (item.type === 'delete') {
            deletions++;
            leftLineNum++;
        } else if (item.type === 'insert') {
            insertions++;
            rightLineNum++;
        } else if (item.type === 'replace') {
            // Replace counts as both deletion and insertion
            deletions++;
            insertions++;
            leftLineNum++;
            rightLineNum++;
        }
    });

    document.getElementById('stats').textContent =
        `Changes: ${equals} equal, ${deletions} deleted, ${insertions} inserted`;
    document.getElementById('lineCount').textContent =
        `Lines: ${leftLineNum - 1} / ${rightLineNum - 1}`;
}

function renderCharacterDiff(charDiffs, side) {
    const fragment = document.createDocumentFragment();
    
    charDiffs.forEach(charDiff => {
        if (charDiff.type === 'equal') {
            const span = document.createElement('span');
            span.className = 'char-equal';
            span.textContent = charDiff.content;
            fragment.appendChild(span);
        } else if (charDiff.type === 'delete' && side === 'left') {
            const span = document.createElement('span');
            span.className = 'char-delete';
            span.textContent = charDiff.content;
            fragment.appendChild(span);
        } else if (charDiff.type === 'insert' && side === 'right') {
            const span = document.createElement('span');
            span.className = 'char-insert';
            span.textContent = charDiff.content;
            fragment.appendChild(span);
        }
    });
    
    return fragment;
}

function createLine(item, side, leftLineNum, rightLineNum) {
    const line = document.createElement('div');
    line.className = `line ${item.type}`;

    const lineNumber = document.createElement('div');
    lineNumber.className = 'line-number';

    const lineContent = document.createElement('div');
    lineContent.className = 'line-content';

    if (item.type === 'equal') {
        lineNumber.textContent = side === 'left' ? leftLineNum : rightLineNum;
        lineContent.textContent = item.content;
    } else if (item.type === 'delete' && side === 'left') {
        lineNumber.textContent = leftLineNum;
        lineContent.textContent = item.content;
    } else if (item.type === 'insert' && side === 'right') {
        lineNumber.textContent = rightLineNum;
        lineContent.textContent = item.content;
    } else if (item.type === 'replace') {
        // Handle replace type with character-level diffs
        if (side === 'left') {
            lineNumber.textContent = leftLineNum;
            if (item.char_diff) {
                lineContent.appendChild(renderCharacterDiff(item.char_diff, 'left'));
            } else {
                lineContent.textContent = item.original_content || item.content;
            }
        } else {
            lineNumber.textContent = rightLineNum;
            if (item.char_diff) {
                lineContent.appendChild(renderCharacterDiff(item.char_diff, 'right'));
            } else {
                lineContent.textContent = item.content;
            }
        }
    } else {
        lineNumber.textContent = '';
        lineContent.textContent = '';
        line.classList.add('empty');
    }

    line.appendChild(lineNumber);
    line.appendChild(lineContent);

    return line;
}

function clearAll() {
    document.getElementById('text1').value = '';
    document.getElementById('text2').value = '';
    document.getElementById('left-diff').innerHTML = '<div class="loading">Enter text above and click Compare</div>';
    document.getElementById('right-diff').innerHTML = '<div class="loading">Enter text above and click Compare</div>';
    document.getElementById('stats').textContent = 'Ready to compare';
    document.getElementById('lineCount').textContent = 'Lines: 0 / 0';
}

function swapTexts() {
    const text1 = document.getElementById('text1').value;
    const text2 = document.getElementById('text2').value;

    document.getElementById('text1').value = text2;
    document.getElementById('text2').value = text1;

    if (text1 || text2) {
        compareTexts();
    }
}

// Keyboard shortcuts
document.addEventListener('keydown', function(e) {
    if (e.ctrlKey && e.key === 'Enter') {
        compareTexts();
    }
});

// Auto-resize textareas
document.querySelectorAll('textarea').forEach(textarea => {
    textarea.addEventListener('input', function() {
        this.style.height = 'auto';
        this.style.height = Math.max(120, this.scrollHeight) + 'px';
    });
});
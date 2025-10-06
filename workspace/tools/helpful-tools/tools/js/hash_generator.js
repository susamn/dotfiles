let currentHashes = {
    md5: '',
    sha1: '',
    sha256: '',
    sha512: ''
};

async function generateHashes() {
    const input = document.getElementById('inputText').value;
    const statusText = document.getElementById('statusText');

    if (!input.trim()) {
        statusText.textContent = 'Please enter text to generate hashes';
        statusText.style.color = '#ff8800';
        return;
    }

    // Show loading state
    ['md5Hash', 'sha1Hash', 'sha256Hash', 'sha512Hash'].forEach(id => {
        document.getElementById(id).innerHTML = '<span class="loading">Generating...</span>';
    });

    statusText.textContent = 'Generating hashes...';
    statusText.style.color = '#666';

    try {
        const response = await fetch('/api/hash/generate', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ text: input })
        });

        const result = await response.json();

        if (result.success) {
            currentHashes = {
                md5: result.md5,
                sha1: result.sha1,
                sha256: result.sha256,
                sha512: result.sha512
            };

            displayHashes();
            statusText.textContent = 'Hashes generated successfully';
            statusText.style.color = '#008000';
        } else {
            clearHashDisplays();
            statusText.textContent = 'Error: ' + result.error;
            statusText.style.color = '#cc0000';
        }
    } catch (error) {
        clearHashDisplays();
        statusText.textContent = 'Network error: ' + error.message;
        statusText.style.color = '#cc0000';
    }
}

function displayHashes() {
    const uppercase = document.getElementById('uppercaseHex').checked;

    Object.keys(currentHashes).forEach(hashType => {
        const element = document.getElementById(hashType + 'Hash');
        let hash = currentHashes[hashType];

        if (uppercase) {
            hash = hash.toUpperCase();
        }

        element.textContent = hash;
        element.className = 'hash-content';
    });
}

function clearHashDisplays() {
    ['md5Hash', 'sha1Hash', 'sha256Hash', 'sha512Hash'].forEach(id => {
        const element = document.getElementById(id);
        element.innerHTML = '<span class="hash-placeholder">Enter text above to generate ' +
            id.replace('Hash', '').toUpperCase() + ' hash</span>';
    });

    currentHashes = { md5: '', sha1: '', sha256: '', sha512: '' };
}

function toggleCase() {
    if (Object.values(currentHashes).some(hash => hash !== '')) {
        displayHashes();
    }
}

function copyHash(hashType) {
    const hash = currentHashes[hashType];
    if (!hash) {
        return;
    }

    const uppercase = document.getElementById('uppercaseHex').checked;
    const finalHash = uppercase ? hash.toUpperCase() : hash;

    navigator.clipboard.writeText(finalHash).then(() => {
        showCopyFeedback(`${hashType.toUpperCase()} hash copied to clipboard`);
    }).catch(() => {
        // Fallback for older browsers
        const textArea = document.createElement('textarea');
        textArea.value = finalHash;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
        showCopyFeedback(`${hashType.toUpperCase()} hash copied to clipboard`);
    });
}

function copyAllHashes() {
    const hashes = Object.values(currentHashes);
    if (hashes.every(hash => hash === '')) {
        return;
    }

    const uppercase = document.getElementById('uppercaseHex').checked;
    const hashText = Object.entries(currentHashes)
        .map(([type, hash]) => `${type.toUpperCase()}: ${uppercase ? hash.toUpperCase() : hash}`)
        .join('\n');

    navigator.clipboard.writeText(hashText).then(() => {
        showCopyFeedback('All hashes copied to clipboard');
    }).catch(() => {
        const textArea = document.createElement('textarea');
        textArea.value = hashText;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
        showCopyFeedback('All hashes copied to clipboard');
    });
}

function showCopyFeedback(message) {
    const statusText = document.getElementById('statusText');
    const originalText = statusText.textContent;
    const originalColor = statusText.style.color;

    statusText.textContent = message;
    statusText.style.color = '#008000';

    setTimeout(() => {
        statusText.textContent = originalText;
        statusText.style.color = originalColor;
    }, 2000);
}

function clearAll() {
    document.getElementById('inputText').value = '';
    clearHashDisplays();
    document.getElementById('statusText').textContent = 'Ready - Enter text to generate hashes';
    document.getElementById('statusText').style.color = '#666';
    updateCharCount();
}

function updateCharCount() {
    const input = document.getElementById('inputText').value;
    document.getElementById('charCount').textContent = `Characters: ${input.length}`;
}

// Auto-generate on input change
document.getElementById('inputText').addEventListener('input', function() {
    updateCharCount();

    if (document.getElementById('autoGenerate').checked) {
        clearTimeout(this.generateTimer);
        this.generateTimer = setTimeout(generateHashes, 500);
    }
});

// Initialize
updateCharCount();
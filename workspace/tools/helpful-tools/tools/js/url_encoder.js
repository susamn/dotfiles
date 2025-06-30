let currentMode = 'unknown';

function detectUrlEncoding(text) {
    if (!text.trim()) return 'unknown';

    // Check if text contains URL-encoded characters
    if (text.includes('%') && /(%[0-9A-Fa-f]{2})+/.test(text)) {
        return 'encoded';
    }

    // Check for characters that would need encoding
    if (/[^A-Za-z0-9\-_.~]/.test(text)) {
        return 'plain';
    }

    return 'plain';
}

async function encodeUrl() {
    const input = document.getElementById('inputText').value;
    const output = document.getElementById('outputText');
    const statusText = document.getElementById('statusText');

    if (!input.trim()) {
        statusText.textContent = 'Please enter text to encode';
        statusText.style.color = '#ff8800';
        return;
    }

    try {
        const response = await fetch('/api/url-encoder/encode', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ text: input })
        });

        const result = await response.json();

        if (result.success) {
            output.value = result.result;
            statusText.textContent = 'Text encoded successfully';
            statusText.style.color = '#008000';
            currentMode = 'encode';
            updateIndicators();
            updateCharCount();
        } else {
            output.value = '';
            statusText.textContent = 'Error: ' + result.error;
            statusText.style.color = '#cc0000';
        }
    } catch (error) {
        output.value = '';
        statusText.textContent = 'Network error: ' + error.message;
        statusText.style.color = '#cc0000';
    }
}

async function decodeUrl() {
    const input = document.getElementById('inputText').value;
    const output = document.getElementById('outputText');
    const statusText = document.getElementById('statusText');

    if (!input.trim()) {
        statusText.textContent = 'Please enter encoded text to decode';
        statusText.style.color = '#ff8800';
        return;
    }

    try {
        const response = await fetch('/api/url-encoder/decode', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ text: input })
        });

        const result = await response.json();

        if (result.success) {
            output.value = result.result;
            statusText.textContent = 'Text decoded successfully';
            statusText.style.color = '#008000';
            currentMode = 'decode';
            updateIndicators();
            updateCharCount();
        } else {
            output.value = '';
            statusText.textContent = 'Error: ' + result.error;
            statusText.style.color = '#cc0000';
        }
    } catch (error) {
        output.value = '';
        statusText.textContent = 'Network error: ' + error.message;
        statusText.style.color = '#cc0000';
    }
}

function autoProcessText() {
    const input = document.getElementById('inputText').value.trim();
    if (!input) return;

    const encoding = detectUrlEncoding(input);

    if (encoding === 'encoded') {
        decodeUrl();
    } else if (encoding === 'plain') {
        encodeUrl();
    }
}

function swapContent() {
    const inputEl = document.getElementById('inputText');
    const outputEl = document.getElementById('outputText');

    const outputValue = outputEl.value;
    if (!outputValue.trim()) return;

    inputEl.value = outputValue;
    outputEl.value = '';

    updateIndicators();
    updateCharCount();

    document.getElementById('statusText').textContent = 'Content swapped between panels';
    document.getElementById('statusText').style.color = '#008000';
}

function clearAll() {
    document.getElementById('inputText').value = '';
    document.getElementById('outputText').value = '';
    document.getElementById('statusText').textContent = 'Ready - Enter text to encode or decode URLs';
    document.getElementById('statusText').style.color = '#666';
    currentMode = 'unknown';
    updateIndicators();
    updateCharCount();
}

function copyOutput() {
    const output = document.getElementById('outputText').value;
    if (!output.trim()) {
        const statusText = document.getElementById('statusText');
        statusText.textContent = 'No output to copy';
        statusText.style.color = '#ff8800';
        return;
    }

    navigator.clipboard.writeText(output).then(() => {
        const statusText = document.getElementById('statusText');
        const originalText = statusText.textContent;
        const originalColor = statusText.style.color;
        statusText.textContent = 'Copied to clipboard';
        statusText.style.color = '#008000';
        setTimeout(() => {
            statusText.textContent = originalText;
            statusText.style.color = originalColor;
        }, 2000);
    }).catch(() => {
        const textArea = document.createElement('textarea');
        textArea.value = output;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
    });
}

function loadExample(text) {
    document.getElementById('inputText').value = text;
    updateCharCount();

    if (document.getElementById('autoProcess').checked) {
        autoProcessText();
    }
}

function updateIndicators() {
    const inputIndicator = document.getElementById('inputIndicator');
    const outputIndicator = document.getElementById('outputIndicator');
    const input = document.getElementById('inputText').value;
    const output = document.getElementById('outputText').value;

    // Update input indicator based on content
    if (input.trim()) {
        const encoding = detectUrlEncoding(input);
        if (encoding === 'encoded') {
            inputIndicator.textContent = 'ENCODED';
            inputIndicator.style.backgroundColor = '#ff6b35';
        } else {
            inputIndicator.textContent = 'PLAIN';
            inputIndicator.style.backgroundColor = '#4a90e2';
        }
    } else {
        inputIndicator.textContent = 'EMPTY';
        inputIndicator.style.backgroundColor = '#888';
    }

    // Update output indicator
    if (output.trim()) {
        if (currentMode === 'encode') {
            outputIndicator.textContent = 'ENCODED';
            outputIndicator.style.backgroundColor = '#ff6b35';
        } else if (currentMode === 'decode') {
            outputIndicator.textContent = 'DECODED';
            outputIndicator.style.backgroundColor = '#4a90e2';
        } else {
            outputIndicator.textContent = 'RESULT';
            outputIndicator.style.backgroundColor = '#4a90e2';
        }
    } else {
        outputIndicator.textContent = 'EMPTY';
        outputIndicator.style.backgroundColor = '#888';
    }
}

function updateCharCount() {
    const input = document.getElementById('inputText').value;
    const output = document.getElementById('outputText').value;
    document.getElementById('charCount').textContent =
        `Input: ${input.length} chars | Output: ${output.length} chars`;
}

function updateEncoding() {
    // This would be used for different encoding types in the future
    const encodingType = document.getElementById('encodingType').value;
    console.log('Encoding type changed to:', encodingType);
}

// Auto-process on input change
document.getElementById('inputText').addEventListener('input', function() {
    updateCharCount();
    updateIndicators();

    if (document.getElementById('autoProcess').checked) {
        clearTimeout(this.processTimer);
        this.processTimer = setTimeout(autoProcessText, 800);
    }
});

// Initialize
updateCharCount();
updateIndicators();
function escapeText() {
    const input = document.getElementById('inputText').value;
    const output = escapeString(input);
    document.getElementById('outputText').value = output;
    updateStatus('Text escaped');
    updateCharCounts();
}

function unescapeText() {
    const input = document.getElementById('outputText').value;
    try {
        const output = unescapeString(input);
        document.getElementById('inputText').value = output;
        updateStatus('Text unescaped');
    } catch (error) {
        updateStatus('Error unescaping: ' + error.message, true);
    }
    updateCharCounts();
}

function escapeString(str) {
    return str
        .replace(/\\/g, '\\\\')  // Escape backslashes first
        .replace(/\n/g, '\\n')   // Newlines
        .replace(/\t/g, '\\t')   // Tabs
        .replace(/\r/g, '\\r')   // Carriage returns
        .replace(/"/g, '\\"')    // Double quotes
        .replace(/'/g, "\\'")    // Single quotes
        .replace(/\0/g, '\\0')   // Null characters
        .replace(/\b/g, '\\b')   // Backspace
        .replace(/\f/g, '\\f')   // Form feed
        .replace(/\v/g, '\\v');  // Vertical tab
}

function unescapeString(str) {
    return str
        .replace(/\\n/g, '\n')   // Newlines
        .replace(/\\t/g, '\t')   // Tabs
        .replace(/\\r/g, '\r')   // Carriage returns
        .replace(/\\"/g, '"')    // Double quotes
        .replace(/\\'/g, "'")    // Single quotes
        .replace(/\\0/g, '\0')   // Null characters
        .replace(/\\b/g, '\b')   // Backspace
        .replace(/\\f/g, '\f')   // Form feed
        .replace(/\\v/g, '\v')   // Vertical tab
        .replace(/\\\\/g, '\\'); // Backslashes last
}

function clearAll() {
    document.getElementById('inputText').value = '';
    document.getElementById('outputText').value = '';
    updateStatus('Cleared all text');
    updateCharCounts();
}

function swapPanels() {
    const inputText = document.getElementById('inputText').value;
    const outputText = document.getElementById('outputText').value;
    
    document.getElementById('inputText').value = outputText;
    document.getElementById('outputText').value = inputText;
    updateStatus('Panels swapped');
    updateCharCounts();
}

function copyLeft() {
    const text = document.getElementById('inputText').value;
    copyToClipboard(text, 'Input text copied to clipboard');
}

function copyRight() {
    const text = document.getElementById('outputText').value;
    copyToClipboard(text, 'Output text copied to clipboard');
}

function copyToClipboard(text, message) {
    if (!text) {
        updateStatus('Nothing to copy', true);
        return;
    }

    navigator.clipboard.writeText(text).then(() => {
        updateStatus(message);
    }).catch(() => {
        // Fallback for older browsers
        const textArea = document.createElement('textarea');
        textArea.value = text;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
        updateStatus(message);
    });
}

function loadExample(exampleText) {
    document.getElementById('inputText').value = exampleText;
    escapeText();
    updateStatus('Example loaded');
}

function updateStatus(message, isError = false) {
    const statusText = document.getElementById('statusText');
    statusText.textContent = message;
    statusText.style.color = isError ? '#cc0000' : '#008000';
    
    // Reset to default after 3 seconds
    setTimeout(() => {
        statusText.textContent = 'Ready - Enter text to escape or unescape';
        statusText.style.color = '#666';
    }, 3000);
}

function updateCharCounts() {
    const inputCount = document.getElementById('inputText').value.length;
    const outputCount = document.getElementById('outputText').value.length;
    
    document.getElementById('inputCount').textContent = inputCount;
    document.getElementById('outputCount').textContent = outputCount;
}

// Auto-escape on input
document.getElementById('inputText').addEventListener('input', function() {
    if (this.value) {
        const output = escapeString(this.value);
        document.getElementById('outputText').value = output;
    } else {
        document.getElementById('outputText').value = '';
    }
    updateCharCounts();
});

// Auto-unescape on output input
document.getElementById('outputText').addEventListener('input', function() {
    updateCharCounts();
});

// Initialize character counts
updateCharCounts();
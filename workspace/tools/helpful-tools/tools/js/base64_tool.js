async function encodeBase64() {
    const input = document.getElementById('inputText').value;
    const output = document.getElementById('outputText');
    const statusText = document.getElementById('statusText');

    if (!input.trim()) {
        statusText.textContent = 'Please enter text to encode';
        statusText.style.color = '#ff8800';
        return;
    }

    try {
        const response = await fetch('/api/base64/encode', {
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

async function decodeBase64() {
    const input = document.getElementById('inputText').value;
    const output = document.getElementById('outputText');
    const statusText = document.getElementById('statusText');

    if (!input.trim()) {
        statusText.textContent = 'Please enter Base64 text to decode';
        statusText.style.color = '#ff8800';
        return;
    }

    try {
        const response = await fetch('/api/base64/decode', {
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

function clearAll() {
    document.getElementById('inputText').value = '';
    document.getElementById('outputText').value = '';
    document.getElementById('statusText').textContent = 'Ready';
    document.getElementById('statusText').style.color = '#666';
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

function updateCharCount() {
    const input = document.getElementById('inputText').value;
    document.getElementById('charCount').textContent = `Characters: ${input.length}`;
}

document.getElementById('inputText').addEventListener('input', updateCharCount);
updateCharCount();
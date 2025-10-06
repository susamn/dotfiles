let currentJWT = null;

function isValidJWT(token) {
    if (!token || typeof token !== 'string') return false;
    const parts = token.split('.');
    return parts.length === 3;
}

function base64UrlDecode(str) {
    // Convert base64url to base64
    str = str.replace(/-/g, '+').replace(/_/g, '/');

    // Add proper padding
    const pad = str.length % 4;
    if (pad) {
        if (pad === 1) {
            throw new Error('Invalid base64url string');
        }
        str += new Array(5 - pad).join('=');
    }

    try {
        return atob(str);
    } catch (e) {
        throw new Error('Invalid base64 encoding');
    }
}

function parseJWT(token) {
    const parts = token.split('.');
    if (parts.length !== 3) {
        throw new Error('Invalid JWT format. Token must have 3 parts separated by dots.');
    }

    try {
        const header = JSON.parse(base64UrlDecode(parts[0]));
        const payload = JSON.parse(base64UrlDecode(parts[1]));
        const signature = parts[2];

        return {
            header,
            payload,
            signature,
            parts: {
                header: parts[0],
                payload: parts[1],
                signature: parts[2]
            }
        };
    } catch (e) {
        throw new Error('Failed to decode JWT: ' + e.message);
    }
}

function syntaxHighlightJSON(json) {
    json = json.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    return json.replace(/("(\\u[a-zA-Z0-9]{4}|\\[^u]|[^\\"])*"(\s*:)?|\b(true|false|null)\b|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?)/g, function (match) {
        let cls = 'json-number';
        if (/^"/.test(match)) {
            if (/:$/.test(match)) {
                cls = 'json-key';
            } else {
                cls = 'json-string';
            }
        } else if (/true|false/.test(match)) {
            cls = 'json-boolean';
        } else if (/null/.test(match)) {
            cls = 'json-null';
        }
        return '<span class="' + cls + '">' + match + '</span>';
    });
}

function formatTimestamp(timestamp) {
    if (!timestamp) return 'Not set';
    const date = new Date(timestamp * 1000);
    const now = new Date();
    const isExpired = date < now;

    const formatted = date.toLocaleString() + ' (' + date.toISOString() + ')';
    return {
        formatted,
        isExpired
    };
}

function decodeJWT() {
    const input = document.getElementById('jwtInput').value.trim();
    const decodedContent = document.getElementById('decodedContent');
    const statusText = document.getElementById('statusText');
    const jwtStatus = document.getElementById('jwtStatus');
    const jwtAlgorithm = document.getElementById('jwtAlgorithm');

    if (!input) {
        statusText.textContent = 'Please enter a JWT token';
        statusText.style.color = '#ff8800';
        return;
    }

    try {
        const decoded = parseJWT(input);
        currentJWT = decoded;

        // Update status indicators
        jwtStatus.textContent = 'VALID';
        jwtStatus.className = 'jwt-indicator valid';

        const algorithm = decoded.header.alg || 'Unknown';
        jwtAlgorithm.textContent = algorithm;
        jwtAlgorithm.style.background = '#388e3c';
        jwtAlgorithm.style.color = 'white';
        jwtAlgorithm.style.padding = '2px 6px';
        jwtAlgorithm.style.borderRadius = '3px';
        jwtAlgorithm.style.fontSize = '10px';

        // Create JWT info section
        let infoSection = '<div class="jwt-info">';

        // Add timestamp info if available
        if (decoded.payload.iat) {
            const iat = formatTimestamp(decoded.payload.iat);
            infoSection += `<div class="info-row"><span class="info-label">Issued At:</span><span class="info-value">${iat.formatted}</span></div>`;
        }

        if (decoded.payload.exp) {
            const exp = formatTimestamp(decoded.payload.exp);
            const expClass = exp.isExpired ? 'expired' : 'valid-time';
            infoSection += `<div class="info-row"><span class="info-label">Expires At:</span><span class="info-value ${expClass}">${exp.formatted}</span></div>`;
        }

        if (decoded.payload.nbf) {
            const nbf = formatTimestamp(decoded.payload.nbf);
            infoSection += `<div class="info-row"><span class="info-label">Not Before:</span><span class="info-value">${nbf.formatted}</span></div>`;
        }

        if (decoded.payload.iss) {
            infoSection += `<div class="info-row"><span class="info-label">Issuer:</span><span class="info-value">${decoded.payload.iss}</span></div>`;
        }

        if (decoded.payload.aud) {
            const audience = Array.isArray(decoded.payload.aud) ? decoded.payload.aud.join(', ') : decoded.payload.aud;
            infoSection += `<div class="info-row"><span class="info-label">Audience:</span><span class="info-value">${audience}</span></div>`;
        }

        infoSection += '</div>';

        // Create JWT parts visualization
        const partsSection = `
                <div class="jwt-parts">
                    <div class="jwt-part jwt-header-part">Header: ${decoded.parts.header}</div>
                    <div class="jwt-part jwt-payload-part">Payload: ${decoded.parts.payload}</div>
                    <div class="jwt-part jwt-signature-part">Signature: ${decoded.parts.signature}</div>
                </div>
            `;

        // Create decoded sections
        const headerJSON = JSON.stringify(decoded.header, null, 2);
        const payloadJSON = JSON.stringify(decoded.payload, null, 2);

        decodedContent.innerHTML = `
                ${infoSection}
                ${partsSection}
                <div class="jwt-section">
                    <div class="section-header">
                        Header
                        <button class="copy-section-btn" onclick="copySection('header')">Copy</button>
                    </div>
                    <div class="section-content">${syntaxHighlightJSON(headerJSON)}</div>
                </div>
                <div class="jwt-section">
                    <div class="section-header">
                        Payload
                        <button class="copy-section-btn" onclick="copySection('payload')">Copy</button>
                    </div>
                    <div class="section-content">${syntaxHighlightJSON(payloadJSON)}</div>
                </div>
                <div class="jwt-section">
                    <div class="section-header">
                        Signature (Base64URL)
                        <button class="copy-section-btn" onclick="copySection('signature')">Copy</button>
                    </div>
                    <div class="section-content">${decoded.signature}</div>
                </div>
            `;

        statusText.textContent = 'JWT decoded successfully';
        statusText.style.color = '#008000';

    } catch (error) {
        currentJWT = null;
        jwtStatus.textContent = 'INVALID';
        jwtStatus.className = 'jwt-indicator invalid';
        jwtAlgorithm.textContent = '';
        jwtAlgorithm.style.background = '';
        jwtAlgorithm.style.color = '';
        jwtAlgorithm.style.padding = '';

        decodedContent.innerHTML = `<div class="error-display">Error: ${error.message}</div>`;
        statusText.textContent = 'JWT decoding error';
        statusText.style.color = '#cc0000';
    }
}

function copySection(section) {
    if (!currentJWT) return;

    let content = '';
    if (section === 'header') {
        content = JSON.stringify(currentJWT.header, null, 2);
    } else if (section === 'payload') {
        content = JSON.stringify(currentJWT.payload, null, 2);
    } else if (section === 'signature') {
        content = currentJWT.signature;
    }

    navigator.clipboard.writeText(content).then(() => {
        showCopyFeedback(`${section.charAt(0).toUpperCase() + section.slice(1)} copied to clipboard`);
    }).catch(() => {
        const textArea = document.createElement('textarea');
        textArea.value = content;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
        showCopyFeedback(`${section.charAt(0).toUpperCase() + section.slice(1)} copied to clipboard`);
    });
}

function copyDecoded() {
    if (!currentJWT) return;

    const content = `Header:\n${JSON.stringify(currentJWT.header, null, 2)}\n\nPayload:\n${JSON.stringify(currentJWT.payload, null, 2)}\n\nSignature:\n${currentJWT.signature}`;

    navigator.clipboard.writeText(content).then(() => {
        showCopyFeedback('Full decoded JWT copied to clipboard');
    }).catch(() => {
        const textArea = document.createElement('textarea');
        textArea.value = content;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
        showCopyFeedback('Full decoded JWT copied to clipboard');
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
    document.getElementById('jwtInput').value = '';
    document.getElementById('decodedContent').innerHTML = `
            <div style="padding: 20px; text-align: center; color: #999; font-style: italic;">
                Enter a JWT token on the left to see its decoded content
            </div>
        `;
    document.getElementById('jwtStatus').textContent = 'WAITING';
    document.getElementById('jwtStatus').className = 'jwt-indicator';
    document.getElementById('jwtAlgorithm').textContent = '';
    document.getElementById('jwtAlgorithm').style.background = '';
    document.getElementById('statusText').textContent = 'Ready - Paste a JWT token to decode';
    document.getElementById('statusText').style.color = '#666';
    currentJWT = null;
    updateTokenInfo();
}

function loadSampleJWT() {
    const sampleJWT = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjE1MTYyNDI2MjIsImF1ZCI6InNhbXBsZS1hdWRpZW5jZSIsImlzcyI6InNhbXBsZS1pc3N1ZXIifQ.4Adcj3UFYzPUVaVF43FmMab6RlaQD8A9V8wFzzht-KQ';
    document.getElementById('jwtInput').value = sampleJWT;
    updateTokenInfo();
    decodeJWT();
}

function updateTokenInfo() {
    const input = document.getElementById('jwtInput').value;
    const parts = input.split('.');
    document.getElementById('tokenInfo').textContent =
        `Token length: ${input.length} | Parts: ${parts.length}`;
}

// Auto-decode on input change
document.getElementById('jwtInput').addEventListener('input', function() {
    updateTokenInfo();

    clearTimeout(this.decodeTimer);
    this.decodeTimer = setTimeout(() => {
        if (this.value.trim() && isValidJWT(this.value.trim())) {
            decodeJWT();
        } else if (this.value.trim()) {
            document.getElementById('jwtStatus').textContent = 'INVALID';
            document.getElementById('jwtStatus').className = 'jwt-indicator invalid';
        } else {
            document.getElementById('jwtStatus').textContent = 'WAITING';
            document.getElementById('jwtStatus').className = 'jwt-indicator';
        }
    }, 500);
});

// Initialize
updateTokenInfo();
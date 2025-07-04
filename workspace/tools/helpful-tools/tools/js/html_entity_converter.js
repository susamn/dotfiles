// Common HTML entities for reference
const commonEntities = [
    { char: '<', entity: '&lt;', name: 'less than' },
    { char: '>', entity: '&gt;', name: 'greater than' },
    { char: '&', entity: '&amp;', name: 'ampersand' },
    { char: '"', entity: '&quot;', name: 'quotation mark' },
    { char: "'", entity: '&apos;', name: 'apostrophe' },
    { char: ' ', entity: '&nbsp;', name: 'non-breaking space' },
    { char: '©', entity: '&copy;', name: 'copyright' },
    { char: '®', entity: '&reg;', name: 'registered' },
    { char: '™', entity: '&trade;', name: 'trademark' },
    { char: '€', entity: '&euro;', name: 'euro' },
    { char: '£', entity: '&pound;', name: 'pound' },
    { char: '¥', entity: '&yen;', name: 'yen' },
    { char: '¢', entity: '&cent;', name: 'cent' },
    { char: '§', entity: '&sect;', name: 'section' },
    { char: '¶', entity: '&para;', name: 'paragraph' },
    { char: '†', entity: '&dagger;', name: 'dagger' },
    { char: '‡', entity: '&Dagger;', name: 'double dagger' },
    { char: '•', entity: '&bull;', name: 'bullet' },
    { char: '…', entity: '&hellip;', name: 'ellipsis' },
    { char: '′', entity: '&prime;', name: 'prime' },
    { char: '″', entity: '&Prime;', name: 'double prime' },
    { char: '‹', entity: '&lsaquo;', name: 'left single angle' },
    { char: '›', entity: '&rsaquo;', name: 'right single angle' },
    { char: '«', entity: '&laquo;', name: 'left double angle' },
    { char: '»', entity: '&raquo;', name: 'right double angle' },
    { char: '\u2018', entity: '&lsquo;', name: 'left single quote' },
    { char: '\u2019', entity: '&rsquo;', name: 'right single quote' },
    { char: '\u201c', entity: '&ldquo;', name: 'left double quote' },
    { char: '\u201d', entity: '&rdquo;', name: 'right double quote' },
    { char: '–', entity: '&ndash;', name: 'en dash' },
    { char: '—', entity: '&mdash;', name: 'em dash' },
    { char: '←', entity: '&larr;', name: 'left arrow' },
    { char: '→', entity: '&rarr;', name: 'right arrow' },
    { char: '↑', entity: '&uarr;', name: 'up arrow' },
    { char: '↓', entity: '&darr;', name: 'down arrow' },
    { char: '↔', entity: '&harr;', name: 'left right arrow' },
    { char: '∞', entity: '&infin;', name: 'infinity' },
    { char: '±', entity: '&plusmn;', name: 'plus minus' },
    { char: '×', entity: '&times;', name: 'multiplication' },
    { char: '÷', entity: '&divide;', name: 'division' },
    { char: '≠', entity: '&ne;', name: 'not equal' },
    { char: '≤', entity: '&le;', name: 'less than or equal' },
    { char: '≥', entity: '&ge;', name: 'greater than or equal' },
    { char: '¼', entity: '&frac14;', name: 'one quarter' },
    { char: '½', entity: '&frac12;', name: 'one half' },
    { char: '¾', entity: '&frac34;', name: 'three quarters' },
    { char: '°', entity: '&deg;', name: 'degree' },
    { char: 'α', entity: '&alpha;', name: 'alpha' },
    { char: 'β', entity: '&beta;', name: 'beta' },
    { char: 'γ', entity: '&gamma;', name: 'gamma' },
    { char: 'δ', entity: '&delta;', name: 'delta' },
    { char: 'π', entity: '&pi;', name: 'pi' },
    { char: 'Σ', entity: '&Sigma;', name: 'sigma' },
    { char: 'Ω', entity: '&Omega;', name: 'omega' }
];

    let currentMode = 'unknown';

    function detectEntityEncoding(text) {
        if (!text.trim()) return 'unknown';

        // Check if text contains HTML entities
        if (/&[a-zA-Z][a-zA-Z0-9]*;|&#[0-9]+;|&#x[0-9a-fA-F]+;/.test(text)) {
            return 'encoded';
        }

        // Check for characters that would need encoding
        if (/[<>&"']/.test(text)) {
            return 'plain';
        }

        return 'plain';
    }

    function encodeEntities() {
        const input = document.getElementById('inputText').value;
        const output = document.getElementById('outputText');
        const statusText = document.getElementById('statusText');
        const encodeAllChars = document.getElementById('encodeAllChars').checked;

        if (!input.trim()) {
            statusText.textContent = 'Please enter text to encode';
            statusText.style.color = '#ff8800';
            return;
        }

        try {
            let encoded = input;

            if (encodeAllChars) {
                // Encode all non-ASCII characters
                encoded = input.replace(/[\u0080-\uFFFF]/g, function(match) {
                    return '&#' + match.charCodeAt(0) + ';';
                });

                // Also encode basic HTML characters
                encoded = encoded
                    .replace(/&/g, '&amp;')
                    .replace(/</g, '&lt;')
                    .replace(/>/g, '&gt;')
                    .replace(/"/g, '&quot;')
                    .replace(/'/g, '&apos;');
            } else {
                // Encode only basic HTML characters
                encoded = input
                    .replace(/&/g, '&amp;')
                    .replace(/</g, '&lt;')
                    .replace(/>/g, '&gt;')
                    .replace(/"/g, '&quot;')
                    .replace(/'/g, '&apos;');
            }

            output.value = encoded;
            statusText.textContent = 'Text encoded successfully';
            statusText.style.color = '#008000';
            currentMode = 'encode';
            updateIndicators();
            updateStats();

        } catch (error) {
            output.value = '';
            statusText.textContent = 'Error encoding text: ' + error.message;
            statusText.style.color = '#cc0000';
        }
    }

    function decodeEntities() {
        const input = document.getElementById('inputText').value;
        const output = document.getElementById('outputText');
        const statusText = document.getElementById('statusText');

        if (!input.trim()) {
            statusText.textContent = 'Please enter encoded text to decode';
            statusText.style.color = '#ff8800';
            return;
        }

        try {
            // Create a temporary element to decode entities
            const tempDiv = document.createElement('div');
            tempDiv.innerHTML = input;
            const decoded = tempDiv.textContent || tempDiv.innerText || '';

            output.value = decoded;
            statusText.textContent = 'Text decoded successfully';
            statusText.style.color = '#008000';
            currentMode = 'decode';
            updateIndicators();
            updateStats();

        } catch (error) {
            output.value = '';
            statusText.textContent = 'Error decoding text: ' + error.message;
            statusText.style.color = '#cc0000';
        }
    }

    function autoConvert() {
        const input = document.getElementById('inputText').value.trim();
        if (!input) return;

        const encoding = detectEntityEncoding(input);

        if (encoding === 'encoded') {
            decodeEntities();
        } else if (encoding === 'plain') {
            encodeEntities();
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
        updateStats();

        document.getElementById('statusText').textContent = 'Content swapped between panels';
        document.getElementById('statusText').style.color = '#008000';
    }

    function clearAll() {
        document.getElementById('inputText').value = '';
        document.getElementById('outputText').value = '';
        document.getElementById('statusText').textContent = 'Ready - Enter text to encode or decode HTML entities';
        document.getElementById('statusText').style.color = '#666';
        currentMode = 'unknown';
        updateIndicators();
        updateStats();
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

    function insertText(text) {
        const inputEl = document.getElementById('inputText');
        const start = inputEl.selectionStart;
        const end = inputEl.selectionEnd;
        const value = inputEl.value;

        inputEl.value = value.substring(0, start) + text + value.substring(end);
        inputEl.focus();
        inputEl.setSelectionRange(start + text.length, start + text.length);

        updateStats();

        if (document.getElementById('autoConvert').checked) {
            autoConvert();
        }
    }

    function loadExample(type) {
        let exampleText = '';

        switch (type) {
            case 'HTML & XML':
                exampleText = '<div class="example">Hello & Welcome to HTML/XML</div>';
                break;
            case 'Quotes':
                exampleText = 'He said "Hello" and she replied \'Hi there!\'';
                break;
            case 'Math':
                exampleText = '2 × 3 = 6, 10 ÷ 2 = 5, π ≈ 3.14, 1 ≠ 2, 5 ≥ 3';
                break;
            case 'Arrows':
                exampleText = 'Left ← Right →, Up ↑ Down ↓, Both ↔';
                break;
        }

        document.getElementById('inputText').value = exampleText;
        updateStats();

        if (document.getElementById('autoConvert').checked) {
            autoConvert();
        }
    }

    function updateIndicators() {
        const inputIndicator = document.getElementById('inputIndicator');
        const outputIndicator = document.getElementById('outputIndicator');
        const input = document.getElementById('inputText').value;
        const output = document.getElementById('outputText').value;

        // Update input indicator
        if (input.trim()) {
            const encoding = detectEntityEncoding(input);
            if (encoding === 'encoded') {
                inputIndicator.textContent = 'ENCODED';
                inputIndicator.className = 'encoding-indicator encoded';
            } else {
                inputIndicator.textContent = 'PLAIN';
                inputIndicator.className = 'encoding-indicator';
            }
        } else {
            inputIndicator.textContent = 'EMPTY';
            inputIndicator.className = 'encoding-indicator';
        }

        // Update output indicator
        if (output.trim()) {
            if (currentMode === 'encode') {
                outputIndicator.textContent = 'ENCODED';
                outputIndicator.className = 'encoding-indicator encoded';
            } else if (currentMode === 'decode') {
                outputIndicator.textContent = 'DECODED';
                outputIndicator.className = 'encoding-indicator decoded';
            } else {
                outputIndicator.textContent = 'RESULT';
                outputIndicator.className = 'encoding-indicator';
            }
        } else {
            outputIndicator.textContent = 'EMPTY';
            outputIndicator.className = 'encoding-indicator';
        }
    }

    function updateStats() {
        const input = document.getElementById('inputText').value;
        const output = document.getElementById('outputText').value;

        // Count HTML entities in input
        const entityMatches = input.match(/&[a-zA-Z][a-zA-Z0-9]*;|&#[0-9]+;|&#x[0-9a-fA-F]+;/g) || [];

        document.getElementById('inputLength').textContent = `${input.length} chars`;
        document.getElementById('outputLength').textContent = `${output.length} chars`;
        document.getElementById('entityCount').textContent = entityMatches.length;
    }

    function initializeEntityGrid() {
        const grid = document.getElementById('entityGrid');

        grid.innerHTML = commonEntities.map(entity => `
            <div class="entity-item" onclick="insertText('${entity.entity}')" title="${entity.name}">
                <div class="entity-char">${entity.char}</div>
                <div class="entity-code">${entity.entity}</div>
            </div>
        `).join('');
    }

    // Auto-convert on input change
    document.getElementById('inputText').addEventListener('input', function() {
        updateStats();
        updateIndicators();

        if (document.getElementById('autoConvert').checked) {
            clearTimeout(this.convertTimer);
            this.convertTimer = setTimeout(autoConvert, 800);
        }
    });

    // Initialize
    initializeEntityGrid();
    updateStats();
    updateIndicators();
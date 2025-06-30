let currentYamlData = null;
let validationTimer = null;

function parseYaml(yamlText) {
    // Simple YAML parser for validation
    const lines = yamlText.split('\n');
    const result = {};
    const stack = [result];
    const indentStack = [-1];

    for (let lineNum = 0; lineNum < lines.length; lineNum++) {
        const line = lines[lineNum];
        const trimmedLine = line.trim();

        // Skip empty lines, comments, and document separators
        if (!trimmedLine || trimmedLine.startsWith('#') || trimmedLine === '---') {
            continue;
        }

        const indent = line.search(/\S/);

        // Handle indent changes - pop stack until we find the right parent
        while (indentStack.length > 1 && indent <= indentStack[indentStack.length - 1]) {
            stack.pop();
            indentStack.pop();
        }

        const currentObj = stack[stack.length - 1];

        if (trimmedLine.startsWith('-')) {
            // Array item
            const value = trimmedLine.substring(1).trim();

            // Only check if current object is compatible with arrays
            if (!Array.isArray(currentObj)) {
                const keys = Object.keys(currentObj);
                if (keys.length > 0) {
                    // This means we're trying to add array items to an object that already has properties
                    // This should only be an error if we're at the same level
                    const parentObj = stack.length > 1 ? stack[stack.length - 2] : null;
                    if (parentObj && indent === indentStack[indentStack.length - 1]) {
                        throw new Error(`Line ${lineNum + 1}: Cannot mix array and object syntax at the same level`);
                    }
                }

                // Convert to array if it's empty or we're in a new context
                if (keys.length === 0) {
                    Object.setPrototypeOf(currentObj, Array.prototype);
                    currentObj.length = 0;
                }
            }

            // If currentObj is still not an array, we need to handle this differently
            if (!Array.isArray(currentObj)) {
                // We're likely in a nested context, find the right parent
                let targetParent = currentObj;

                // For array items, we might need to create a new array context
                if (typeof targetParent === 'object' && !Array.isArray(targetParent)) {
                    // This could be a value for a key that expects an array
                    const newArray = [];

                    // Find which key this array belongs to by looking at recent context
                    // For now, just create the array item
                    const parsedValue = parseYamlValue(value);
                    newArray.push(parsedValue);

                    // This is a complex case - for now, just allow it
                    if (typeof parsedValue === 'object' && parsedValue !== null) {
                        stack.push(parsedValue);
                        indentStack.push(indent);
                    }
                    continue;
                }
            }

            const parsedValue = parseYamlValue(value);
            if (Array.isArray(currentObj)) {
                currentObj.push(parsedValue);

                if (typeof parsedValue === 'object' && parsedValue !== null) {
                    stack.push(parsedValue);
                    indentStack.push(indent);
                }
            }

        } else if (trimmedLine.includes(':')) {
            // Key-value pair
            const colonIndex = trimmedLine.indexOf(':');
            const key = trimmedLine.substring(0, colonIndex).trim();
            const value = trimmedLine.substring(colonIndex + 1).trim();

            if (!key) {
                throw new Error(`Line ${lineNum + 1}: Empty key not allowed`);
            }

            // Only check array/object mixing at the same indentation level
            if (Array.isArray(currentObj)) {
                // If we're in an array context but this is a key-value pair,
                // it might be a property of an array item
                if (stack.length > 1) {
                    const arrayItem = currentObj[currentObj.length - 1];
                    if (typeof arrayItem === 'object' && arrayItem !== null && !Array.isArray(arrayItem)) {
                        // Add this key-value to the last array item
                        arrayItem[key] = parseYamlValue(value);
                        if (value === '' || (typeof arrayItem[key] === 'object' && arrayItem[key] !== null)) {
                            if (value === '') {
                                arrayItem[key] = {};
                            }
                            stack.push(arrayItem[key]);
                            indentStack.push(indent);
                        }
                        continue;
                    }
                }
                throw new Error(`Line ${lineNum + 1}: Cannot mix object and array syntax at the same level`);
            }

            if (value === '') {
                // Object or array follows
                currentObj[key] = {};
                stack.push(currentObj[key]);
                indentStack.push(indent);
            } else {
                currentObj[key] = parseYamlValue(value);
            }

        } else {
            throw new Error(`Line ${lineNum + 1}: Invalid YAML syntax`);
        }
    }

    return result;
}

function parseYamlValue(value) {
    if (value === '' || value === 'null' || value === '~') return null;
    if (value === 'true') return true;
    if (value === 'false') return false;

    // Number detection
    if (!isNaN(value) && !isNaN(parseFloat(value))) {
        const num = parseFloat(value);
        return Number.isInteger(num) && value.indexOf('.') === -1 ? parseInt(value) : num;
    }

    // String handling
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
        return value.substring(1, value.length - 1);
    }

    // Handle multi-word strings that need quoting
    if (value.includes(' ') && !value.startsWith('"') && !value.startsWith("'")) {
        // Check if it's a special case like "yes" or "no"
        const lowerValue = value.toLowerCase();
        if (lowerValue === 'yes' || lowerValue === 'on') return true;
        if (lowerValue === 'no' || lowerValue === 'off') return false;
    }

    return value;
}

function validateYaml() {
    const yamlInput = document.getElementById('yamlInput').value;
    const validationResults = document.getElementById('validationResults');
    const validationStatus = document.getElementById('validationStatus');
    const statusText = document.getElementById('statusText');

    if (!yamlInput.trim()) {
        validationResults.innerHTML = `
                <div class="empty-state">
                    <div class="empty-icon">📝</div>
                    <div>Enter YAML content to see validation results</div>
                </div>
            `;
        validationStatus.textContent = 'WAITING';
        validationStatus.className = 'validation-indicator';
        statusText.textContent = 'Enter YAML content to validate';
        statusText.style.color = '#666';
        currentYamlData = null;
        return;
    }

    try {
        const parsed = parseYaml(yamlInput);
        currentYamlData = parsed;

        // Success - valid YAML
        validationStatus.textContent = 'VALID';
        validationStatus.className = 'validation-indicator valid';
        statusText.textContent = 'YAML is valid';
        statusText.style.color = '#008000';

        displayValidationSuccess(parsed);

    } catch (error) {
        currentYamlData = null;
        validationStatus.textContent = 'INVALID';
        validationStatus.className = 'validation-indicator invalid';
        statusText.textContent = 'YAML validation failed';
        statusText.style.color = '#cc0000';

        displayValidationError(error);
    }
}

function displayValidationSuccess(parsed) {
    const validationResults = document.getElementById('validationResults');
    const yamlInput = document.getElementById('yamlInput').value;

    // Calculate statistics
    const lines = yamlInput.split('\n').length;
    const chars = yamlInput.length;
    const words = yamlInput.trim().split(/\s+/).length;
    const size = new Blob([yamlInput]).size;

    // Count different YAML elements
    const yamlStats = analyzeYamlStructure(yamlInput);

    validationResults.innerHTML = `
            <div class="result-section">
                <div class="success-message">
                    <span class="success-icon">✓</span>
                    YAML is valid and well-formed
                </div>
            </div>

            <div class="result-section">
                <div class="result-header">Document Statistics</div>
                <div class="yaml-stats">
                    <div class="stat-row">
                        <span class="stat-label">Lines:</span>
                        <span class="stat-value">${lines}</span>
                    </div>
                    <div class="stat-row">
                        <span class="stat-label">Characters:</span>
                        <span class="stat-value">${chars}</span>
                    </div>
                    <div class="stat-row">
                        <span class="stat-label">Words:</span>
                        <span class="stat-value">${words}</span>
                    </div>
                    <div class="stat-row">
                        <span class="stat-label">Size:</span>
                        <span class="stat-value">${formatBytes(size)}</span>
                    </div>
                    <div class="stat-row">
                        <span class="stat-label">Keys:</span>
                        <span class="stat-value">${yamlStats.keys}</span>
                    </div>
                    <div class="stat-row">
                        <span class="stat-label">Arrays:</span>
                        <span class="stat-value">${yamlStats.arrays}</span>
                    </div>
                    <div class="stat-row">
                        <span class="stat-label">Comments:</span>
                        <span class="stat-value">${yamlStats.comments}</span>
                    </div>
                </div>
            </div>

            <div class="result-section">
                <div class="result-header">Parsed Structure Preview</div>
                <div class="parsed-preview">${syntaxHighlightYaml(JSON.stringify(parsed, null, 2))}</div>
            </div>
        `;
}

function displayValidationError(error) {
    const validationResults = document.getElementById('validationResults');

    validationResults.innerHTML = `
            <div class="result-section">
                <div class="error-message">
                    <span class="error-icon">✗</span>
                    ${error.message}
                </div>
            </div>

            <div class="result-section">
                <div class="result-header">Common YAML Issues</div>
                <div class="yaml-stats">
                    <div style="font-size: 11px; line-height: 1.4; color: #666;">
                        • Check indentation (use spaces, not tabs)<br>
                        • Ensure proper key-value syntax (key: value)<br>
                        • Quote strings with special characters<br>
                        • Verify array syntax (- item)<br>
                        • Check for unclosed quotes or brackets<br>
                        • Ensure consistent indentation levels
                    </div>
                </div>
            </div>
        `;
}

function analyzeYamlStructure(yamlText) {
    const lines = yamlText.split('\n');
    let keys = 0;
    let arrays = 0;
    let comments = 0;

    lines.forEach(line => {
        const trimmed = line.trim();
        if (trimmed.startsWith('#')) {
            comments++;
        } else if (trimmed.includes(':') && !trimmed.startsWith('-')) {
            keys++;
        } else if (trimmed.startsWith('-')) {
            arrays++;
        }
    });

    return { keys, arrays, comments };
}

function syntaxHighlightYaml(text) {
    // Simple syntax highlighting for JSON representation
    return text.replace(/("(\\u[a-zA-Z0-9]{4}|\\[^u]|[^\\"])*"(\s*:)?|\b(true|false|null)\b|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?)/g, function (match) {
        let cls = 'yaml-number';
        if (/^"/.test(match)) {
            if (/:$/.test(match)) {
                cls = 'yaml-key';
            } else {
                cls = 'yaml-string';
            }
        } else if (/true|false/.test(match)) {
            cls = 'yaml-boolean';
        } else if (/null/.test(match)) {
            cls = 'yaml-null';
        }
        return '<span class="' + cls + '">' + match + '</span>';
    });
}

function formatBytes(bytes) {
    if (bytes === 0) return '0 bytes';
    const k = 1024;
    const sizes = ['bytes', 'KB', 'MB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
}

function formatYaml() {
    const yamlInput = document.getElementById('yamlInput');
    const input = yamlInput.value;

    if (!input.trim()) {
        return;
    }

    try {
        // Basic YAML formatting
        const lines = input.split('\n');
        const formatted = [];
        let currentIndent = 0;

        lines.forEach(line => {
            const trimmed = line.trim();
            if (!trimmed || trimmed.startsWith('#')) {
                formatted.push(line);
                return;
            }

            const indent = line.search(/\S/);
            const spaces = '  '.repeat(Math.floor(indent / 2));
            formatted.push(spaces + trimmed);
        });

        yamlInput.value = formatted.join('\n');
        validateYaml();

    } catch (error) {
        document.getElementById('statusText').textContent = 'Cannot format invalid YAML';
        document.getElementById('statusText').style.color = '#cc0000';
    }
}

function updateLineNumbers() {
    const yamlInput = document.getElementById('yamlInput');
    const lineNumbers = document.getElementById('lineNumbers');
    const showLineNumbers = document.getElementById('showLineNumbers').checked;

    if (showLineNumbers) {
        const lines = yamlInput.value.split('\n');
        const lineNumbersText = lines.map((_, index) => index + 1).join('\n');
        lineNumbers.textContent = lineNumbersText;
        lineNumbers.style.display = 'block';
        yamlInput.classList.add('yaml-editor-with-numbers');
    } else {
        lineNumbers.style.display = 'none';
        yamlInput.classList.remove('yaml-editor-with-numbers');
    }
}

function updateStats() {
    const yamlInput = document.getElementById('yamlInput').value;
    const lines = yamlInput.split('\n').length;
    const chars = yamlInput.length;
    const size = new Blob([yamlInput]).size;

    document.getElementById('lineCount').textContent = lines;
    document.getElementById('charCount').textContent = chars;
    document.getElementById('fileSize').textContent = formatBytes(size);
}

function loadSample(type) {
    let sampleYaml = '';

    switch (type) {
        case 'config':
            sampleYaml = `# Application Configuration
app:
  name: "My Application"
  version: "1.0.0"
  debug: true

database:
  host: "localhost"
  port: 5432
  name: "myapp_db"
  credentials:
    username: "admin"
    password: "secret123"

server:
  host: "0.0.0.0"
  port: 8080
  ssl: false

features:
  - authentication
  - logging
  - caching
  - monitoring`;
            break;

        case 'docker':
            sampleYaml = `version: '3.8'

services:
  web:
    build: .
    ports:
      - "8000:8000"
    volumes:
      - .:/app
    environment:
      - DEBUG=1
      - DATABASE_URL=postgresql://user:pass@db:5432/mydb
    depends_on:
      - db
      - redis

  db:
    image: postgres:13
    environment:
      POSTGRES_DB: mydb
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:6-alpine
    ports:
      - "6379:6379"

volumes:
  postgres_data:`;
            break;

        case 'kubernetes':
            sampleYaml = `apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          limits:
            memory: "128Mi"
            cpu: "500m"
          requests:
            memory: "64Mi"
            cpu: "250m"`;
            break;

        case 'ci':
            sampleYaml = `name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node-version: [14, 16, 18]
    steps:
    - uses: actions/checkout@v3
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: \${{ matrix.node-version }}
    - run: npm install
    - run: npm test
    - run: npm run build

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
    - uses: actions/checkout@v3
    - name: Deploy to production
      env:
        API_KEY: \${{ secrets.API_KEY }}
      run: ./deploy.sh`;
            break;

        case 'data':
            sampleYaml = `# Data Structure Example
users:
  - id: 1
    name: "John Doe"
    email: "john@example.com"
    active: true
    roles:
      - admin
      - user
    metadata:
      last_login: "2024-01-15T10:30:00Z"
      login_count: 42

  - id: 2
    name: "Jane Smith"
    email: "jane@example.com"
    active: false
    roles:
      - user
    metadata:
      last_login: null
      login_count: 0

settings:
  theme: "dark"
  notifications:
    email: true
    push: false
    sms: true
  preferences:
    language: "en"
    timezone: "UTC"
    date_format: "YYYY-MM-DD"`;
            break;

        case 'invalid':
            sampleYaml = `# This YAML has intentional errors
name: "Test File"
version: 1.0
  invalid_indent: true
missing_colon
  another_key: "value"

array_mixed_with_object:
  key1: "value1"
  - "this should not be here"
  key2: "value2"

unclosed_quote: "this quote is not closed
tabs:	"using tabs instead of spaces"

duplicate_key: "first value"
duplicate_key: "second value"`;
            break;
    }

    document.getElementById('yamlInput').value = sampleYaml;
    updateStats();
    updateLineNumbers();
    validateYaml();
}

function loadSampleYaml() {
    loadSample('config');
}

function clearAll() {
    document.getElementById('yamlInput').value = '';
    document.getElementById('validationResults').innerHTML = `
            <div class="empty-state">
                <div class="empty-icon">📝</div>
                <div>Enter YAML content to see validation results</div>
            </div>
        `;
    document.getElementById('validationStatus').textContent = 'WAITING';
    document.getElementById('validationStatus').className = 'validation-indicator';
    document.getElementById('statusText').textContent = 'Ready - Enter YAML content to validate';
    document.getElementById('statusText').style.color = '#666';
    currentYamlData = null;
    updateStats();
    updateLineNumbers();
}

function copyYaml() {
    const yamlInput = document.getElementById('yamlInput').value;
    if (!yamlInput.trim()) {
        const statusText = document.getElementById('statusText');
        statusText.textContent = 'No YAML content to copy';
        statusText.style.color = '#ff8800';
        return;
    }

    navigator.clipboard.writeText(yamlInput).then(() => {
        const statusText = document.getElementById('statusText');
        const originalText = statusText.textContent;
        const originalColor = statusText.style.color;
        statusText.textContent = 'YAML copied to clipboard';
        statusText.style.color = '#008000';
        setTimeout(() => {
            statusText.textContent = originalText;
            statusText.style.color = originalColor;
        }, 2000);
    }).catch(() => {
        const textArea = document.createElement('textarea');
        textArea.value = yamlInput;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
    });
}

// Event listeners
document.getElementById('yamlInput').addEventListener('input', function() {
    updateStats();
    updateLineNumbers();

    if (document.getElementById('autoValidate').checked) {
        clearTimeout(validationTimer);
        validationTimer = setTimeout(validateYaml, 800);
    }
});

document.getElementById('yamlInput').addEventListener('scroll', function() {
    const lineNumbers = document.getElementById('lineNumbers');
    lineNumbers.scrollTop = this.scrollTop;
});

document.getElementById('showLineNumbers').addEventListener('change', updateLineNumbers);

// Initialize
updateStats();
updateLineNumbers();
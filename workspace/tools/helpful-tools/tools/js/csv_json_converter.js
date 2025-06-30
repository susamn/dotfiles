let parsedCsvData = null;
let currentJsonOutput = '';

function parseCsv(csvText, options = {}) {
    const {
        delimiter = ',',
        hasHeaders = true,
        skipEmptyLines = true,
        trimWhitespace = true,
        inferTypes = false
    } = options;

    if (!csvText.trim()) {
        throw new Error('CSV data is empty');
    }

    let lines = csvText.split(/\r?\n/);

    if (skipEmptyLines) {
        lines = lines.filter(line => line.trim() !== '');
    }

    if (lines.length === 0) {
        throw new Error('No valid CSV lines found');
    }

    const rows = [];
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const row = parseCsvLine(line, delimiter, trimWhitespace);
        if (row.length > 0 || !skipEmptyLines) {
            rows.push(row);
        }
    }

    if (rows.length === 0) {
        throw new Error('No valid CSV rows found');
    }

    let headers = null;
    let dataRows = rows;

    if (hasHeaders && rows.length > 0) {
        headers = rows[0];
        dataRows = rows.slice(1);
    } else {
        const columnCount = Math.max(...rows.map(row => row.length));
        headers = Array.from({ length: columnCount }, (_, i) => `Column${i + 1}`);
    }

    if (inferTypes) {
        dataRows = dataRows.map(row =>
            row.map(cell => inferType(cell))
        );
    }

    return {
        headers,
        rows: dataRows,
        allRows: rows
    };
}

function parseCsvLine(line, delimiter, trimWhitespace) {
    const result = [];
    let current = '';
    let inQuotes = false;
    let i = 0;

    while (i < line.length) {
        const char = line[i];
        const nextChar = line[i + 1];

        if (char === '"') {
            if (inQuotes && nextChar === '"') {
                current += '"';
                i += 2;
            } else {
                inQuotes = !inQuotes;
                i++;
            }
        } else if (char === delimiter && !inQuotes) {
            result.push(trimWhitespace ? current.trim() : current);
            current = '';
            i++;
        } else {
            current += char;
            i++;
        }
    }

    result.push(trimWhitespace ? current.trim() : current);

    return result;
}

function inferType(value) {
    if (value === '' || value === null || value === undefined) {
        return null;
    }

    if (value.toLowerCase() === 'true') return true;
    if (value.toLowerCase() === 'false') return false;

    if (!isNaN(value) && !isNaN(parseFloat(value))) {
        const num = parseFloat(value);
        return Number.isInteger(num) ? parseInt(value) : num;
    }

    return value;
}

function convertToJson() {
    const csvInput = document.getElementById('csvInput').value;
    const jsonOutput = document.getElementById('jsonOutput');
    const statusText = document.getElementById('statusText');

    if (!csvInput.trim()) {
        statusText.textContent = 'Please enter CSV data';
        statusText.style.color = '#ff8800';
        return;
    }

    try {
        const options = {
            delimiter: document.getElementById('delimiter').value === '\\t' ? '\t' : document.getElementById('delimiter').value,
            hasHeaders: document.getElementById('hasHeaders').checked,
            skipEmptyLines: document.getElementById('skipEmptyLines').checked,
            trimWhitespace: document.getElementById('trimWhitespace').checked,
            inferTypes: document.getElementById('inferTypes').checked
        };

        const parsed = parseCsv(csvInput, options);
        parsedCsvData = parsed;

        const outputFormat = document.getElementById('outputFormat').value;
        let jsonData;

        switch (outputFormat) {
            case 'array':
                jsonData = parsed.rows.map(row => {
                    const obj = {};
                    parsed.headers.forEach((header, index) => {
                        obj[header] = row[index] || null;
                    });
                    return obj;
                });
                break;

            case 'rows':
                jsonData = {
                    headers: parsed.headers,
                    rows: parsed.rows
                };
                break;

            case 'columns':
                jsonData = {};
                parsed.headers.forEach((header, index) => {
                    jsonData[header] = parsed.rows.map(row => row[index] || null);
                });
                break;
        }

        const jsonString = JSON.stringify(jsonData, null, 2);
        currentJsonOutput = jsonString;

        const highlighted = syntaxHighlightJson(jsonString);
        jsonOutput.innerHTML = highlighted;

        updateCsvPreview(parsed);

        updateStats(parsed, jsonString);

        statusText.textContent = 'CSV converted to JSON successfully';
        statusText.style.color = '#008000';

    } catch (error) {
        jsonOutput.innerHTML = `<div class="error-display">Error: ${error.message}</div>`;
        statusText.textContent = 'CSV parsing error';
        statusText.style.color = '#cc0000';
        currentJsonOutput = '';
        parsedCsvData = null;
        document.getElementById('csvPreview').style.display = 'none';
        updateStats(null, '');
    }
}

function syntaxHighlightJson(json) {
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

function updateCsvPreview(parsed) {
    const previewSection = document.getElementById('csvPreview');
    const previewContent = document.getElementById('csvPreviewContent');

    if (!parsed || parsed.allRows.length === 0) {
        previewSection.style.display = 'none';
        return;
    }

    const rowsToShow = parsed.allRows.slice(0, 5);
    const maxColumns = Math.max(...rowsToShow.map(row => row.length));

    let tableHtml = '<table class="preview-table">';

    if (document.getElementById('hasHeaders').checked && parsed.headers) {
        tableHtml += '<thead><tr>';
        parsed.headers.forEach(header => {
            tableHtml += `<th>${escapeHtml(header)}</th>`;
        });
        tableHtml += '</tr></thead>';
    }

    tableHtml += '<tbody>';
    const dataRows = document.getElementById('hasHeaders').checked ? rowsToShow.slice(1) : rowsToShow;
    dataRows.forEach(row => {
        tableHtml += '<tr>';
        for (let i = 0; i < maxColumns; i++) {
            const cell = row[i] || '';
            tableHtml += `<td>${escapeHtml(cell)}</td>`;
        }
        tableHtml += '</tr>';
    });
    tableHtml += '</tbody></table>';

    previewContent.innerHTML = tableHtml;
    previewSection.style.display = 'block';
}

function updateStats(parsed, jsonString) {
    const rowCount = parsed ? parsed.rows.length : 0;
    const columnCount = parsed ? parsed.headers.length : 0;
    const dataSize = new Blob([jsonString]).size;

    document.getElementById('rowCount').textContent = rowCount;
    document.getElementById('columnCount').textContent = columnCount;
    document.getElementById('dataSize').textContent = formatBytes(dataSize);
}

function formatBytes(bytes) {
    if (bytes === 0) return '0 bytes';
    const k = 1024;
    const sizes = ['bytes', 'KB', 'MB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function updateConversion() {
    const csvInput = document.getElementById('csvInput').value.trim();
    if (csvInput) {
        convertToJson();
    }
}

function loadSample(type) {
    let sampleCsv = '';

    switch (type) {
        case 'users':
            sampleCsv = `name,email,age,city
John Doe,john@example.com,30,New York
Jane Smith,jane@example.com,25,Los Angeles
Bob Johnson,bob@example.com,35,Chicago
Alice Brown,alice@example.com,28,Miami`;
            break;

        case 'products':
            sampleCsv = `id,name,price,category,in_stock
1,Laptop,999.99,Electronics,true
2,Coffee Mug,12.50,Kitchen,true
3,Desk Chair,199.00,Furniture,false
4,Notebook,5.99,Office,true`;
            break;

        case 'sales':
            sampleCsv = `date,product,quantity,revenue,region
2024-01-15,Widget A,100,1500.00,North
2024-01-16,Widget B,75,2250.50,South
2024-01-17,Widget C,50,999.99,East
2024-01-18,Widget A,125,1875.00,West`;
            break;

        case 'simple':
            sampleCsv = `fruit,color
apple,red
banana,yellow
grape,purple
orange,orange`;
            break;

        case 'mixed':
            sampleCsv = `name,active,score,notes
Alice,true,95.5,"Excellent work"
Bob,false,78,"Needs improvement"
Charlie,true,88.2,""
Diana,true,92,"Very good"`;
            break;
    }

    document.getElementById('csvInput').value = sampleCsv;
    convertToJson();
}

function loadSampleCsv() {
    loadSample('users');
}

function clearAll() {
    document.getElementById('csvInput').value = '';
    document.getElementById('jsonOutput').innerHTML = 'Enter CSV data to see JSON output';
    document.getElementById('csvPreview').style.display = 'none';
    document.getElementById('statusText').textContent = 'Ready - Paste CSV data to convert to JSON';
    document.getElementById('statusText').style.color = '#666';
    currentJsonOutput = '';
    parsedCsvData = null;
    updateStats(null, '');
}

function copyOutput() {
    if (!currentJsonOutput) {
        const statusText = document.getElementById('statusText');
        statusText.textContent = 'No JSON output to copy';
        statusText.style.color = '#ff8800';
        return;
    }

    navigator.clipboard.writeText(currentJsonOutput).then(() => {
        const statusText = document.getElementById('statusText');
        const originalText = statusText.textContent;
        const originalColor = statusText.style.color;
        statusText.textContent = 'JSON copied to clipboard';
        statusText.style.color = '#008000';
        setTimeout(() => {
            statusText.textContent = originalText;
            statusText.style.color = originalColor;
        }, 2000);
    }).catch(() => {
        const textArea = document.createElement('textarea');
        textArea.value = currentJsonOutput;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
    });
}

function downloadJson() {
    if (!currentJsonOutput) {
        const statusText = document.getElementById('statusText');
        statusText.textContent = 'No JSON output to download';
        statusText.style.color = '#ff8800';
        return;
    }

    const blob = new Blob([currentJsonOutput], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'converted_data.json';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);

    const statusText = document.getElementById('statusText');
    const originalText = statusText.textContent;
    const originalColor = statusText.style.color;
    statusText.textContent = 'JSON file downloaded';
    statusText.style.color = '#008000';
    setTimeout(() => {
        statusText.textContent = originalText;
        statusText.style.color = originalColor;
    }, 2000);
}

document.getElementById('csvInput').addEventListener('input', function() {
    clearTimeout(this.convertTimer);
    this.convertTimer = setTimeout(() => {
        if (this.value.trim()) {
            convertToJson();
        } else {
            clearAll();
        }
    }, 500);
});

updateStats(null, '');
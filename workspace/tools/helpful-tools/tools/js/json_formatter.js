let indentType = 'spaces';
let indentSize = 2;
let isCollapsible = false;
let originalParsedData = null;
let searchTimer = null;
let isJsonlMode = false;
let jsonlData = [];
let lastFormattedJson = '';
let showMarkup = true;

function parseJsonlDocuments(text) {
    const documents = [];
    let currentJson = '';
    let braceCount = 0;
    let inString = false;
    let escaped = false;
    
    for (let i = 0; i < text.length; i++) {
        const char = text[i];
        
        if (escaped) {
            escaped = false;
            currentJson += char;
            continue;
        }
        
        if (char === '\\' && inString) {
            escaped = true;
            currentJson += char;
            continue;
        }
        
        if (char === '"') {
            inString = !inString;
            currentJson += char;
            continue;
        }
        
        if (!inString) {
            if (char === '{') {
                braceCount++;
                currentJson += char;
            } else if (char === '}') {
                braceCount--;
                currentJson += char;
                
                if (braceCount === 0) {
                    const trimmed = currentJson.trim();
                    if (trimmed) {
                        documents.push(trimmed);
                    }
                    currentJson = '';
                }
            } else if (braceCount > 0) {
                currentJson += char;
            } else if (char.trim() === '') {
                continue;
            } else {
                currentJson += char;
            }
        } else {
            currentJson += char;
        }
    }
    
    const trimmed = currentJson.trim();
    if (trimmed && braceCount === 0) {
        documents.push(trimmed);
    }
    
    return documents;
}

function isJsonlContent(text) {
    const documents = parseJsonlDocuments(text);
    if (documents.length <= 1) return false;

    return documents.every(doc => {
        try {
            JSON.parse(doc);
            return true;
        } catch {
            return false;
        }
    });
}

function formatJsonl() {
    const input = document.getElementById('inputJson').value.trim();
    const output = document.getElementById('outputJson');
    const statusText = document.getElementById('statusText');

    if (!input) {
        output.innerHTML = '';
        statusText.textContent = 'Ready';
        originalParsedData = null;
        lastFormattedJson = '';
        isJsonlMode = false;
        return;
    }

    try {
        const documents = parseJsonlDocuments(input);
        const parsedLines = [];

        for (let i = 0; i < documents.length; i++) {
            try {
                const parsed = JSON.parse(documents[i]);
                parsedLines.push(parsed);
            } catch (error) {
                throw new Error(`Document ${i + 1}: ${error.message}`);
            }
        }

        isJsonlMode = true;
        jsonlData = parsedLines;
        originalParsedData = parsedLines;

        const indentStr = indentType === 'tabs' ? '\t' : ' '.repeat(indentSize);
        lastFormattedJson = parsedLines.map(obj => JSON.stringify(obj, null, indentStr)).join('\n');

        if (showMarkup) {
            let htmlOutput = '';
            parsedLines.forEach((obj, index) => {
                htmlOutput += `<div style="margin-bottom: 15px; border-left: 3px solid #0066cc; padding-left: 8px;">`;
                htmlOutput += `<div style="font-size: 11px; color: #666; margin-bottom: 5px;">Line ${index + 1}:</div>`;
                htmlOutput += createCollapsibleJson(obj, 0);
                htmlOutput += `</div>`;
            });
            output.innerHTML = htmlOutput;
        } else {
            output.innerHTML = `<pre style="margin: 0; white-space: pre-wrap; font-family: inherit;">${lastFormattedJson.replace(/</g, '&lt;').replace(/>/g, '&gt;')}</pre>`;
        }

        statusText.textContent = `JSONL formatted successfully (${parsedLines.length} lines)`;
        statusText.style.color = '#008000';

        const searchQuery = document.getElementById('searchInput').value.trim();
        if (searchQuery) {
            performJsonlSearch();
        }
    } catch (error) {
        output.innerHTML = `<div class="error-display">JSONL Error: ${error.message}</div>`;
        statusText.textContent = 'JSONL parsing error';
        statusText.style.color = '#cc0000';
        originalParsedData = null;
        lastFormattedJson = '';
        isJsonlMode = false;
    }
}

function performJsonlSearch() {
    const searchQuery = document.getElementById('searchInput').value.trim();
    const searchInput = document.getElementById('searchInput');
    const statusText = document.getElementById('statusText');

    if (!isJsonlMode || !jsonlData) {
        return;
    }

    if (!searchQuery) {
        formatJsonl();
        searchInput.style.borderColor = '#a0a0a0';
        return;
    }

    try {
        let totalMatches = 0;
        let htmlOutput = '';

        jsonlData.forEach((obj, index) => {
            const searchResult = searchJsonPath(obj, searchQuery);
            if (searchResult.matches.length > 0) {
                totalMatches += searchResult.matches.length;
                htmlOutput += `<div style="margin-bottom: 15px; border-left: 3px solid #ff8800; padding-left: 8px; background: #fff9e6;">`;
                htmlOutput += `<div style="font-size: 11px; color: #666; margin-bottom: 5px;">Line ${index + 1} (${searchResult.matches.length} matches):</div>`;
                htmlOutput += createCollapsibleJson(searchResult.filteredData, 0, searchResult.matches);
                htmlOutput += `</div>`;
            }
        });

        if (totalMatches > 0) {
            document.getElementById('outputJson').innerHTML = htmlOutput;
            statusText.textContent = `Found ${totalMatches} matches across ${htmlOutput.split('Line ').length - 1} lines`;
            statusText.style.color = '#008000';
            searchInput.style.borderColor = '#388e3c';
        } else {
            document.getElementById('outputJson').innerHTML = '<div style="padding: 12px; color: #888; font-style: italic;">No matches found in JSONL</div>';
            statusText.textContent = 'No matches found';
            statusText.style.color = '#ff8800';
            searchInput.style.borderColor = '#d32f2f';
        }
    } catch (error) {
        statusText.textContent = 'Search error: ' + error.message;
        statusText.style.color = '#cc0000';
        searchInput.style.borderColor = '#d32f2f';
    }
}

function getIndentString() {
    if (indentType === 'tabs') {
        return '\t';
    }
    return ' '.repeat(indentSize);
}

function searchJsonPath(obj, path) {
    if (!path || path.trim() === '') {
        return { matches: [], filteredData: obj };
    }
    
    try {
        const results = evaluateJsonPath(obj, path);
        
        if (results.length > 0) {
            if (results.length === 1 && path.includes('[?(@.')) {
                return { matches: results, filteredData: results[0].value };
            }
            
            const filteredData = buildFilteredStructure(results);
            return { matches: results, filteredData: filteredData };
        }
        return { matches: [], filteredData: null };
    } catch (error) {
        console.error('JSONPath evaluation error:', error);
        return { matches: [], filteredData: null };
    }
}

function buildFilteredStructure(results) {
    if (results.length === 1) {
        return results[0].value;
    }
    
    const filteredData = {};
    
    const groupedResults = new Map();
    
    results.forEach(result => {
        const parentPath = result.path.slice(0, -1);
        const parentKey = parentPath.join('.');
        const lastKey = result.path[result.path.length - 1];
        
        if (!groupedResults.has(parentKey)) {
            groupedResults.set(parentKey, []);
        }
        
        groupedResults.get(parentKey).push({
            key: lastKey,
            value: result.value,
            fullPath: result.path
        });
    });
    
    groupedResults.forEach((items, parentKey) => {
        if (parentKey === '') {
            if (items.length === 1) {
                Object.assign(filteredData, { [items[0].key]: items[0].value });
            } else {
                items.forEach(item => {
                    filteredData[item.key] = item.value;
                });
            }
        } else {
            const isArrayContext = items.some(item => typeof item.key === 'number');
            
            if (isArrayContext && items.length > 1) {
                const array = items.map(item => item.value);
                setNestedValue(filteredData, parentKey.split('.').concat(['matches']), array);
            } else {
                items.forEach(item => {
                    setNestedValue(filteredData, item.fullPath, item.value);
                });
            }
        }
    });
    
    return filteredData;
}

function evaluateJsonPath(obj, path) {
    if (!path.startsWith('$')) {
        const results = [];
        findByKey(obj, path, [], results);
        return results;
    }

    const tokens = parseJsonPath(path);
    return traverseJsonPath(obj, tokens, []);
}

function parseJsonPath(path) {
    const tokens = [];
    let i = 0;
    
    if (path[0] === '$') {
        tokens.push({ type: 'root' });
        i = 1;
    }
    
    while (i < path.length) {
        if (path[i] === '.') {
            i++;
            if (i >= path.length) break;
            
            if (path[i] === '.') {
                tokens.push({ type: 'recursive' });
                i++;
            } else {
                let prop = '';
                while (i < path.length && path[i] !== '.' && path[i] !== '[') {
                    prop += path[i];
                    i++;
                }
                if (prop) {
                    tokens.push({ type: 'property', name: prop });
                }
            }
        } else if (path[i] === '[') {
            i++;
            let bracketContent = '';
            let depth = 1;
            
            while (i < path.length && depth > 0) {
                if (path[i] === '[') depth++;
                else if (path[i] === ']') depth--;
                
                if (depth > 0) {
                    bracketContent += path[i];
                }
                i++;
            }
            
            if (bracketContent === '*') {
                tokens.push({ type: 'wildcard' });
            } else if (bracketContent.startsWith('?')) {
                tokens.push({ type: 'filter', expression: bracketContent });
            } else if (!isNaN(bracketContent)) {
                tokens.push({ type: 'index', value: parseInt(bracketContent) });
            } else {
                const unquoted = bracketContent.replace(/^['"]|['"]$/g, '');
                tokens.push({ type: 'property', name: unquoted });
            }
        } else {
            let prop = '';
            while (i < path.length && path[i] !== '.' && path[i] !== '[') {
                prop += path[i];
                i++;
            }
            if (prop) {
                tokens.push({ type: 'property', name: prop });
            }
        }
    }
    
    return tokens;
}

function traverseJsonPath(obj, tokens, currentPath) {
    if (tokens.length === 0) {
        return [{
            path: currentPath.slice(),
            value: obj,
            fullPath: '$.' + currentPath.join('.')
        }];
    }
    
    const [currentToken, ...remainingTokens] = tokens;
    const results = [];
    
    switch (currentToken.type) {
        case 'root':
            return traverseJsonPath(obj, remainingTokens, currentPath);
            
        case 'property':
            if (typeof obj === 'object' && obj !== null && obj.hasOwnProperty(currentToken.name)) {
                const newPath = [...currentPath, currentToken.name];
                return traverseJsonPath(obj[currentToken.name], remainingTokens, newPath);
            }
            break;
            
        case 'wildcard':
            if (Array.isArray(obj)) {
                obj.forEach((item, index) => {
                    const newPath = [...currentPath, index];
                    results.push(...traverseJsonPath(item, remainingTokens, newPath));
                });
            } else if (typeof obj === 'object' && obj !== null) {
                Object.keys(obj).forEach(key => {
                    const newPath = [...currentPath, key];
                    results.push(...traverseJsonPath(obj[key], remainingTokens, newPath));
                });
            }
            break;
            
        case 'index':
            if (Array.isArray(obj) && currentToken.value >= 0 && currentToken.value < obj.length) {
                const newPath = [...currentPath, currentToken.value];
                return traverseJsonPath(obj[currentToken.value], remainingTokens, newPath);
            }
            break;
            
        case 'filter':
            if (Array.isArray(obj)) {
                obj.forEach((item, index) => {
                    if (evaluateFilterExpression(item, currentToken.expression)) {
                        const newPath = [...currentPath, index];
                        results.push(...traverseJsonPath(item, remainingTokens, newPath));
                    }
                });
            }
            break;
            
        case 'recursive':
            results.push(...findRecursive(obj, remainingTokens, currentPath));
            break;
    }
    
    return results;
}

function findByPath(obj, pathParts, currentPath, results) {
    if (pathParts.length === 0) {
        results.push({
            path: currentPath.slice(),
            value: obj,
            fullPath: '$.' + currentPath.join('.')
        });
        return;
    }
    
    const [currentPart, ...remainingParts] = pathParts;
    
    if (currentPart.startsWith('?(@.')) {
        if (Array.isArray(obj)) {
            obj.forEach((item, index) => {
                if (evaluateFilter(item, currentPart)) {
                    currentPath.push(index);
                    findByPath(item, remainingParts, currentPath, results);
                    currentPath.pop();
                }
            });
        }
        return;
    }
    
    if (currentPart === '*') {
        if (Array.isArray(obj)) {
            obj.forEach((item, index) => {
                currentPath.push(index);
                findByPath(item, remainingParts, currentPath, results);
                currentPath.pop();
            });
        } else if (typeof obj === 'object' && obj !== null) {
            Object.keys(obj).forEach(key => {
                currentPath.push(key);
                findByPath(obj[key], remainingParts, currentPath, results);
                currentPath.pop();
            });
        }
        return;
    }
    
    if (Array.isArray(obj)) {
        const index = parseInt(currentPart);
        if (!isNaN(index) && index >= 0 && index < obj.length) {
            currentPath.push(index);
            findByPath(obj[index], remainingParts, currentPath, results);
            currentPath.pop();
        }
    } else if (typeof obj === 'object' && obj !== null) {
        if (obj.hasOwnProperty(currentPart)) {
            currentPath.push(currentPart);
            findByPath(obj[currentPart], remainingParts, currentPath, results);
            currentPath.pop();
        }
    }
}

function evaluateFilterExpression(item, filterExpression) {
    try {
        const expr = filterExpression.substring(1);
        
        const comparisonMatch = expr.match(/\(@\.?([^=!<>\s]*)\s*(==|!=|<=|>=|<|>)\s*(.+)\)/);
        if (comparisonMatch) {
            const [, property, operator, valueStr] = comparisonMatch;
            const actualValue = property ? getNestedProperty(item, property) : item;
            let expectedValue = valueStr.trim();
            
            if ((expectedValue.startsWith('"') && expectedValue.endsWith('"')) ||
                (expectedValue.startsWith("'") && expectedValue.endsWith("'"))) {
                expectedValue = expectedValue.slice(1, -1);
            }
            
            if (!isNaN(expectedValue) && expectedValue !== '' && !isNaN(parseFloat(expectedValue))) {
                expectedValue = parseFloat(expectedValue);
            } else if (expectedValue === 'true') {
                expectedValue = true;
            } else if (expectedValue === 'false') {
                expectedValue = false;
            } else if (expectedValue === 'null') {
                expectedValue = null;
            }
            
            switch (operator) {
                case '==': return actualValue == expectedValue;
                case '!=': return actualValue != expectedValue;
                case '<': return actualValue < expectedValue;
                case '<=': return actualValue <= expectedValue;
                case '>': return actualValue > expectedValue;
                case '>=': return actualValue >= expectedValue;
                default: return false;
            }
        }
        
        const existenceMatch = expr.match(/\(@\.([^)]+)\)/);
        if (existenceMatch) {
            const [, property] = existenceMatch;
            const value = getNestedProperty(item, property);
            return value !== undefined && value !== null;
        }
        
        return false;
    } catch (error) {
        console.error('Filter evaluation error:', error);
        return false;
    }
}

function findRecursive(obj, tokens, currentPath) {
    const results = [];
    
    const matches = traverseJsonPath(obj, tokens, currentPath);
    results.push(...matches);
    
    if (typeof obj === 'object' && obj !== null) {
        if (Array.isArray(obj)) {
            obj.forEach((item, index) => {
                const newPath = [...currentPath, index];
                results.push(...findRecursive(item, tokens, newPath));
            });
        } else {
            Object.keys(obj).forEach(key => {
                const newPath = [...currentPath, key];
                results.push(...findRecursive(obj[key], tokens, newPath));
            });
        }
    }
    
    return results;
}

function getNestedProperty(obj, path) {
    return path.split('.').reduce((current, key) => {
        return current && current[key] !== undefined ? current[key] : undefined;
    }, obj);
}

function findByKey(obj, searchKey, currentPath, results) {
    if (typeof obj === 'object' && obj !== null) {
        if (Array.isArray(obj)) {
            obj.forEach((item, index) => {
                currentPath.push(index);
                findByKey(item, searchKey, currentPath, results);
                currentPath.pop();
            });
        } else {
            Object.keys(obj).forEach(key => {
                currentPath.push(key);
                if (key.toLowerCase().includes(searchKey.toLowerCase())) {
                    results.push({
                        path: currentPath.slice(),
                        value: obj[key],
                        fullPath: '$.' + currentPath.join('.'),
                        matchedKey: key
                    });
                }
                findByKey(obj[key], searchKey, currentPath, results);
                currentPath.pop();
            });
        }
    }
}

function setNestedValue(obj, path, value) {
    let current = obj;
    for (let i = 0; i < path.length - 1; i++) {
        const key = path[i];
        if (!(key in current)) {
            current[key] = typeof path[i + 1] === 'number' ? [] : {};
        }
        current = current[key];
    }
    current[path[path.length - 1]] = value;
}

function performSearch() {
    if (isJsonlMode) {
        performJsonlSearch();
        return;
    }

    const searchQuery = document.getElementById('searchInput').value.trim();
    const searchInput = document.getElementById('searchInput');
    const statusText = document.getElementById('statusText');
    if (!originalParsedData) {
        return;
    }
    if (!searchQuery) {
        const collapsibleHtml = createCollapsibleJson(originalParsedData, 0);
        document.getElementById('outputJson').innerHTML = collapsibleHtml;
        statusText.textContent = 'JSON formatted successfully';
        statusText.style.color = '#008000';
        searchInput.style.borderColor = '#a0a0a0';
        return;
    }
    try {
        const searchResult = searchJsonPath(originalParsedData, searchQuery);
        if (searchResult.matches.length > 0) {
            const collapsibleHtml = createCollapsibleJson(searchResult.filteredData, 0, searchResult.matches);
            document.getElementById('outputJson').innerHTML = collapsibleHtml;
            statusText.textContent = `Found ${searchResult.matches.length} matches`;
            statusText.style.color = '#008000';
            searchInput.style.borderColor = '#388e3c';
        } else {
            document.getElementById('outputJson').innerHTML = '<div style="padding: 12px; color: #888; font-style: italic;">No matches found</div>';
            statusText.textContent = 'No matches found';
            statusText.style.color = '#ff8800';
            searchInput.style.borderColor = '#d32f2f';
        }
    } catch (error) {
        statusText.textContent = 'Search error: ' + error.message;
        statusText.style.color = '#cc0000';
        searchInput.style.borderColor = '#d32f2f';
    }
}

function clearSearch() {
    document.getElementById('searchInput').value = '';
    performSearch();
}

function createCollapsibleJson(obj, indent = 0, searchMatches = []) {
    const indentStr = ' '.repeat(indent);
    const nextIndentStr = ' '.repeat(indent + (indentType === 'tabs' ? 1 : indentSize));
    if (obj === null) {
        return '<span class="json-null">null</span>';
    }
    if (typeof obj === 'boolean') {
        return `<span class="json-boolean">${obj}</span>`;
    }
    if (typeof obj === 'number') {
        return `<span class="json-number">${obj}</span>`;
    }
    if (typeof obj === 'string') {
        const escaped = obj.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
        return `<span class="json-string">"${escaped}"</span>`;
    }
    if (Array.isArray(obj)) {
        if (obj.length === 0) {
            return '<span class="json-punctuation">[]</span>';
        }
        const id = 'array_' + Math.random().toString(36).substr(2, 9);
        let result = `<span class="expand-collapse-btn" onclick="toggleCollapse('${id}')">-</span><span class="json-punctuation">[</span>\n`;
        result += `<div id="${id}" class="collapsible-content">`;
        for (let i = 0; i < obj.length; i++) {
            result += nextIndentStr + createCollapsibleJson(obj[i], indent + (indentType === 'tabs' ? 1 : indentSize), searchMatches);
            if (i < obj.length - 1) {
                result += '<span class="json-punctuation">,</span>';
            }
            result += '\n';
        }
        result += `</div>`;
        result += `<div id="${id}_collapsed" class="collapsed-content collapsed-indicator">${nextIndentStr}... ${obj.length} items\n</div>`;
        result += indentStr + '<span class="json-punctuation">]</span>';
        return result;
    }
    if (typeof obj === 'object') {
        const keys = Object.keys(obj);
        if (keys.length === 0) {
            return '<span class="json-punctuation">{}</span>';
        }
        const id = 'object_' + Math.random().toString(36).substr(2, 9);
        let result = `<span class="expand-collapse-btn" onclick="toggleCollapse('${id}')">-</span><span class="json-punctuation">{</span>\n`;
        result += `<div id="${id}" class="collapsible-content">`;
        for (let i = 0; i < keys.length; i++) {
            const key = keys[i];
            const escapedKey = key.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
            const isMatchedKey = searchMatches.some(match => match.matchedKey === key);
            const keyClass = isMatchedKey ? 'json-key search-match' : 'json-key';
            result += nextIndentStr + `<span class="${keyClass}">"${escapedKey}"</span><span class="json-punctuation">: </span>`;
            result += createCollapsibleJson(obj[key], indent + (indentType === 'tabs' ? 1 : indentSize), searchMatches);
            if (i < keys.length - 1) {
                result += '<span class="json-punctuation">,</span>';
            }
            result += '\n';
        }
        result += `</div>`;
        result += `<div id="${id}_collapsed" class="collapsed-content collapsed-indicator">${nextIndentStr}... ${keys.length} properties\n</div>`;
        result += indentStr + '<span class="json-punctuation">}</span>';
        return result;
    }
    return String(obj);
}

function toggleCollapse(id) {
    const content = document.getElementById(id);
    const collapsed = document.getElementById(id + '_collapsed');
    const btn = content.previousElementSibling;
    if (content.style.display === 'none' || content.classList.contains('collapsed-content')) {
        content.style.display = 'block';
        content.classList.remove('collapsed-content');
        collapsed.style.display = 'none';
        collapsed.classList.add('collapsed-content');
        btn.textContent = '-';
    } else {
        content.style.display = 'none';
        content.classList.add('collapsed-content');
        collapsed.style.display = 'block';
        collapsed.classList.remove('collapsed-content');
        btn.textContent = '+';
    }
}

function expandAll() {
    const allContents = document.querySelectorAll('.collapsible-content');
    const allCollapsed = document.querySelectorAll('.collapsed-content');
    const allBtns = document.querySelectorAll('.expand-collapse-btn');
    allContents.forEach(content => {
        content.style.display = 'block';
        content.classList.remove('collapsed-content');
    });
    allCollapsed.forEach(collapsed => {
        if (collapsed.classList.contains('collapsed-indicator')) {
            collapsed.style.display = 'none';
            collapsed.classList.add('collapsed-content');
        }
    });
    allBtns.forEach(btn => {
        btn.textContent = '-';
    });
}

function collapseAll() {
    const allContents = document.querySelectorAll('.collapsible-content');
    const allCollapsed = document.querySelectorAll('.collapsed-content');
    const allBtns = document.querySelectorAll('.expand-collapse-btn');
    allContents.forEach(content => {
        content.style.display = 'none';
        content.classList.add('collapsed-content');
    });
    allCollapsed.forEach(collapsed => {
        if (collapsed.classList.contains('collapsed-indicator')) {
            collapsed.style.display = 'block';
            collapsed.classList.remove('collapsed-content');
        }
    });
    allBtns.forEach(btn => {
        btn.textContent = '+';
    });
}

function updateIndentPreference() {
    indentType = document.getElementById('indentType').value;
    indentSize = parseInt(document.getElementById('indentSize').value);
    const input = document.getElementById('inputJson').value.trim();
    if (input) {
        formatJson();
    }
}

function syntaxHighlight(json) {
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

function toggleMarkup() {
    showMarkup = !showMarkup;
    const btn = document.getElementById('toggleMarkupBtn');
    const output = document.getElementById('outputJson');
    if (showMarkup) {
        btn.textContent = 'Remove Markup';
        if (originalParsedData !== null) {
            const searchQuery = document.getElementById('searchInput').value.trim();
            if (searchQuery) {
                performSearch();
            } else {
                const collapsibleHtml = createCollapsibleJson(originalParsedData, 0);
                output.innerHTML = collapsibleHtml;
            }
        }
    } else {
        btn.textContent = 'Show Markup';
        if (lastFormattedJson) {
            output.innerHTML = `<pre style="margin: 0; white-space: pre-wrap; font-family: inherit;">${lastFormattedJson.replace(/</g, '&lt;').replace(/>/g, '&gt;')}</pre>`;
        }
    }
}

function formatJson() {
    const input = document.getElementById('inputJson').value.trim();
    const output = document.getElementById('outputJson');
    const statusText = document.getElementById('statusText');

    if (!input) {
        output.innerHTML = '';
        statusText.textContent = 'Ready';
        originalParsedData = null;
        lastFormattedJson = '';
        isJsonlMode = false;
        return;
    }

    if (isJsonlContent(input)) {
        formatJsonl();
        return;
    }

    try {
        const parsed = JSON.parse(input);
        isJsonlMode = false;
        originalParsedData = parsed;
        const indentStr = indentType === 'tabs' ? '\t' : ' '.repeat(indentSize);
        lastFormattedJson = JSON.stringify(parsed, null, indentStr);
        if (showMarkup) {
            const collapsibleHtml = createCollapsibleJson(parsed, 0);
            output.innerHTML = collapsibleHtml;
        } else {
            output.innerHTML = `<pre style="margin: 0; white-space: pre-wrap; font-family: inherit;">${lastFormattedJson.replace(/</g, '&lt;').replace(/>/g, '&gt;')}</pre>`;
        }
        statusText.textContent = 'JSON formatted successfully';
        statusText.style.color = '#008000';
        const searchQuery = document.getElementById('searchInput').value.trim();
        if (searchQuery) {
            performSearch();
        }
    } catch (error) {
        output.innerHTML = `<div class="error-display">Error: ${error.message}</div>`;
        statusText.textContent = 'JSON parsing error';
        statusText.style.color = '#cc0000';
        originalParsedData = null;
        lastFormattedJson = '';
        isJsonlMode = false;
    }
}

function minifyJson() {
    const input = document.getElementById('inputJson').value.trim();
    const output = document.getElementById('outputJson');
    const statusText = document.getElementById('statusText');
    if (!input) {
        return;
    }
    try {
        const parsed = JSON.parse(input);
        const minified = JSON.stringify(parsed);
        lastFormattedJson = minified;
        if (showMarkup) {
            const highlighted = syntaxHighlight(minified);
            output.innerHTML = highlighted;
        } else {
            output.innerHTML = `<pre style="margin: 0; white-space: pre-wrap; font-family: inherit;">${minified.replace(/</g, '&lt;').replace(/>/g, '&gt;')}</pre>`;
        }
        statusText.textContent = 'JSON minified successfully';
        statusText.style.color = '#008000';
    } catch (error) {
        output.innerHTML = `<div class="error-display">Error: ${error.message}</div>`;
        statusText.textContent = 'JSON parsing error';
        statusText.style.color = '#cc0000';
        lastFormattedJson = '';
    }
}

function stringifyJson() {
    const input = document.getElementById('inputJson').value.trim();
    const output = document.getElementById('outputJson');
    const statusText = document.getElementById('statusText');
    if (!input) {
        return;
    }
    try {
        const parsed = JSON.parse(input);
        const stringified = JSON.stringify(JSON.stringify(parsed));
        lastFormattedJson = stringified;
        if (showMarkup) {
            const highlighted = syntaxHighlight(stringified);
            output.innerHTML = highlighted;
        } else {
            output.innerHTML = `<pre style="margin: 0; white-space: pre-wrap; font-family: inherit;">${stringified.replace(/</g, '&lt;').replace(/>/g, '&gt;')}</pre>`;
        }
        statusText.textContent = 'JSON stringified successfully';
        statusText.style.color = '#008000';
    } catch (error) {
        output.innerHTML = `<div class="error-display">Error: ${error.message}</div>`;
        statusText.textContent = 'JSON parsing error';
        statusText.style.color = '#cc0000';
        lastFormattedJson = '';
    }
}

function clearAll() {
    document.getElementById('inputJson').value = '';
    document.getElementById('outputJson').innerHTML = '';
    document.getElementById('statusText').textContent = 'Ready';
    document.getElementById('statusText').style.color = '#666';
    lastFormattedJson = '';
    originalParsedData = null;
    isJsonlMode = false;
    jsonlData = [];
    updateCharCount();
}

function copyFormatted() {
    if (!lastFormattedJson.trim()) {
        const statusText = document.getElementById('statusText');
        statusText.textContent = 'No formatted JSON to copy';
        statusText.style.color = '#ff8800';
        return;
    }
    navigator.clipboard.writeText(lastFormattedJson).then(() => {
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
        textArea.value = lastFormattedJson;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
        const statusText = document.getElementById('statusText');
        const originalText = statusText.textContent;
        const originalColor = statusText.style.color;
        statusText.textContent = 'Copied to clipboard';
        statusText.style.color = '#008000';
        setTimeout(() => {
            statusText.textContent = originalText;
            statusText.style.color = originalColor;
        }, 2000);
    });
}

function updateCharCount() {
    const input = document.getElementById('inputJson').value;
    document.getElementById('charCount').textContent = `Characters: ${input.length}`;
}

document.getElementById('inputJson').addEventListener('input', function() {
    updateCharCount();
    clearTimeout(this.formatTimer);
    this.formatTimer = setTimeout(formatJson, 300);
});

updateCharCount();

document.getElementById('searchInput').addEventListener('input', function() {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(performSearch, 2000);
});

document.getElementById('searchInput').addEventListener('keydown', function(e) {
    if (e.key === 'Enter') {
        clearTimeout(searchTimer);
        performSearch();
    }
});
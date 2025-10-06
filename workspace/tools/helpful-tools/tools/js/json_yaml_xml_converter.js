    let yamlIndentSize = 2;
    let currentInputFormat = 'unknown';
    let currentOutputFormat = 'unknown';

    const examples = {
        json: `{
  "users": [
    {
      "id": 1,
      "name": "John Doe",
      "email": "john@example.com",
      "active": true,
      "roles": ["admin", "user"],
      "settings": {
        "theme": "dark",
        "notifications": true
      }
    },
    {
      "id": 2,
      "name": "Jane Smith",
      "email": "jane@example.com",
      "active": false,
      "roles": ["user"],
      "settings": null
    }
  ],
  "metadata": {
    "total": 2,
    "version": "1.0"
  }
}`,
        yaml: `users:
  - id: 1
    name: John Doe
    email: john@example.com
    active: true
    roles:
      - admin
      - user
    settings:
      theme: dark
      notifications: true
  - id: 2
    name: Jane Smith
    email: jane@example.com
    active: false
    roles:
      - user
    settings: null
metadata:
  total: 2
  version: "1.0"`,
        xml: `<?xml version="1.0" encoding="UTF-8"?>
<root>
  <users>
    <user>
      <id>1</id>
      <name>John Doe</name>
      <email>john@example.com</email>
      <active>true</active>
      <roles>
        <role>admin</role>
        <role>user</role>
      </roles>
      <settings>
        <theme>dark</theme>
        <notifications>true</notifications>
      </settings>
    </user>
    <user>
      <id>2</id>
      <name>Jane Smith</name>
      <email>jane@example.com</email>
      <active>false</active>
      <roles>
        <role>user</role>
      </roles>
      <settings></settings>
    </user>
  </users>
  <metadata>
    <total>2</total>
    <version>1.0</version>
  </metadata>
</root>`
    };

    function loadJsonExample() {
        document.getElementById('inputContent').value = examples.json;
        currentInputFormat = 'json';
        updateFormatIndicators();
        updateCharCount();
        document.getElementById('statusText').textContent = 'JSON example loaded - try converting to other formats';
        document.getElementById('statusText').style.color = '#008000';
    }

    function loadYamlExample() {
        document.getElementById('inputContent').value = examples.yaml;
        currentInputFormat = 'yaml';
        updateFormatIndicators();
        updateCharCount();
        document.getElementById('statusText').textContent = 'YAML example loaded - try converting to other formats';
        document.getElementById('statusText').style.color = '#008000';
    }

    function convertTo(targetFormat) {
        const input = document.getElementById('inputContent').value.trim();
        const output = document.getElementById('outputContent');
        const statusText = document.getElementById('statusText');
        
        if (!input) {
            statusText.textContent = 'Please enter some content to convert';
            statusText.style.color = '#ff8800';
            return;
        }

        try {
            const inputFormat = detectFormat(input);
            
            if (inputFormat === 'unknown') {
                statusText.textContent = 'Could not detect input format';
                statusText.style.color = '#cc0000';
                return;
            }

            let result = '';
            let highlightedResult = '';

            // If same format, just format it nicely
            if (inputFormat === targetFormat) {
                if (targetFormat === 'json') {
                    const parsed = JSON.parse(input);
                    result = JSON.stringify(parsed, null, 2);
                    highlightedResult = syntaxHighlightJson(result);
                } else if (targetFormat === 'yaml') {
                    // For YAML, convert to JSON and back to ensure proper formatting
                    const jsonResult = yamlToJson(input);
                    const parsed = JSON.parse(jsonResult);
                    result = objectToYaml(parsed, 0);
                    highlightedResult = syntaxHighlightYaml(result);
                } else if (targetFormat === 'xml') {
                    const parser = new DOMParser();
                    const doc = parser.parseFromString(input, 'text/xml');
                    const serializer = new XMLSerializer();
                    result = formatXml(serializer.serializeToString(doc));
                    highlightedResult = syntaxHighlightXml(result);
                }
                statusText.textContent = `${targetFormat.toUpperCase()} formatted`;
            } else {
                // Convert between formats
                if (inputFormat === 'json' && targetFormat === 'yaml') {
                    result = jsonToYaml(input);
                    highlightedResult = syntaxHighlightYaml(result);
                } else if (inputFormat === 'yaml' && targetFormat === 'json') {
                    result = yamlToJson(input);
                    highlightedResult = syntaxHighlightJson(result);
                } else if (inputFormat === 'json' && targetFormat === 'xml') {
                    result = jsonToXml(input);
                    highlightedResult = syntaxHighlightXml(result);
                } else if (inputFormat === 'xml' && targetFormat === 'json') {
                    result = xmlToJson(input);
                    highlightedResult = syntaxHighlightJson(result);
                } else if (inputFormat === 'yaml' && targetFormat === 'xml') {
                    result = yamlToXml(input);
                    highlightedResult = syntaxHighlightXml(result);
                } else if (inputFormat === 'xml' && targetFormat === 'yaml') {
                    result = xmlToYaml(input);
                    highlightedResult = syntaxHighlightYaml(result);
                }
                statusText.textContent = `Converted ${inputFormat.toUpperCase()} to ${targetFormat.toUpperCase()}`;
            }

            output.innerHTML = highlightedResult;
            statusText.style.color = '#008000';
            currentInputFormat = inputFormat;
            currentOutputFormat = targetFormat;
            updateFormatIndicators();

        } catch (error) {
            output.innerHTML = `<div class="error-display">Error: ${error.message}</div>`;
            statusText.textContent = `Conversion error`;
            statusText.style.color = '#cc0000';
        }
    }

    function updateYamlPreference() {
        yamlIndentSize = parseInt(document.getElementById('yamlIndent').value);
        const input = document.getElementById('inputContent').value.trim();
        if (input && currentInputFormat === 'json') {
            convertToYaml();
        }
    }

    function detectFormat(content) {
        if (!content.trim()) return 'unknown';

        content = content.trim();

        // Check for XML
        if (content.startsWith('<?xml') || content.startsWith('<') && content.endsWith('>')) {
            try {
                const parser = new DOMParser();
                const doc = parser.parseFromString(content, 'text/xml');
                if (!doc.getElementsByTagName('parsererror').length) {
                    return 'xml';
                }
            } catch (e) {
                // Continue to other checks
            }
        }

        // Check for JSON
        try {
            JSON.parse(content);
            return 'json';
        } catch (e) {
            // Continue to YAML check
        }

        // Check for YAML
        if (content.includes(':') && !content.startsWith('{') && !content.startsWith('[')) {
            return 'yaml';
        }

        return 'unknown';
    }

    function jsonToYaml(jsonStr) {
        const obj = JSON.parse(jsonStr);
        return objectToYaml(obj, 0);
    }

    function objectToYaml(obj, indent = 0) {
        const spaces = ' '.repeat(indent);
        if (obj === null) return 'null';
        if (typeof obj === 'boolean') return obj.toString();
        if (typeof obj === 'number') return obj.toString();
        if (typeof obj === 'string') {
            if (obj.includes('\n') || obj.includes(':') || obj.includes('#') ||
                obj.match(/^\s/) || obj.match(/\s$/) || obj === '' ||
                obj.toLowerCase() === 'true' || obj.toLowerCase() === 'false' ||
                obj.toLowerCase() === 'null' || !isNaN(obj)) {
                return `"${obj.replace(/"/g, '\\"')}"`;
            }
            return obj;
        }
        if (Array.isArray(obj)) {
            if (obj.length === 0) return '[]';
            return obj.map(item => {
                const yamlItem = objectToYaml(item, indent + yamlIndentSize);
                if (typeof item === 'object' && item !== null && !Array.isArray(item)) {
                    return `${spaces}- ${yamlItem.substring(yamlIndentSize)}`;
                }
                return `${spaces}- ${yamlItem}`;
            }).join('\n');
        }
        if (typeof obj === 'object') {
            if (Object.keys(obj).length === 0) return '{}';
            return Object.entries(obj).map(([key, value]) => {
                const yamlValue = objectToYaml(value, indent + yamlIndentSize);
                if (typeof value === 'object' && value !== null) {
                    if (Array.isArray(value) && value.length > 0) {
                        return `${spaces}${key}:\n${yamlValue}`;
                    } else if (!Array.isArray(value) && Object.keys(value).length > 0) {
                        return `${spaces}${key}:\n${yamlValue}`;
                    }
                }
                return `${spaces}${key}: ${yamlValue}`;
            }).join('\n');
        }
        return String(obj);
    }

    function yamlToJson(yamlStr) {
        const lines = yamlStr.split('\n');
        const result = parseYamlLines(lines);
        return JSON.stringify(result, null, 2);
    }

    function parseYamlLines(lines) {
        const root = {};
        const stack = [{obj: root, indent: -1, isArray: false}];
        let currentArrayKey = null;
        
        for (let i = 0; i < lines.length; i++) {
            let line = lines[i].replace(/\r$/, '');
            if (!line.trim() || line.trim().startsWith('#')) continue;
            
            const indent = line.search(/\S/);
            const content = line.trim();
            
            // Pop stack for decreasing indentation
            while (stack.length > 1 && indent <= stack[stack.length - 1].indent) {
                stack.pop();
            }
            
            const current = stack[stack.length - 1];
            
            if (content.startsWith('- ')) {
                const value = content.substring(2).trim();
                
                // Create array if it doesn't exist
                if (currentArrayKey && !Array.isArray(current.obj[currentArrayKey])) {
                    current.obj[currentArrayKey] = [];
                }
                
                let targetArray = current.isArray ? current.obj : current.obj[currentArrayKey];
                
                if (value === '') {
                    // Array item that will have nested properties
                    const newObj = {};
                    targetArray.push(newObj);
                    stack.push({obj: newObj, indent: indent, isArray: false});
                } else if (value.includes(':')) {
                    // Array item with inline key-value
                    const colonIndex = value.indexOf(':');
                    const key = value.substring(0, colonIndex).trim();
                    const val = value.substring(colonIndex + 1).trim();
                    const newObj = {};
                    newObj[key] = parseYamlValue(val);
                    targetArray.push(newObj);
                    stack.push({obj: newObj, indent: indent, isArray: false});
                } else {
                    // Simple array item
                    targetArray.push(parseYamlValue(value));
                }
            } else if (content.includes(':')) {
                const colonIndex = content.indexOf(':');
                let key = content.substring(0, colonIndex).trim();
                const value = content.substring(colonIndex + 1).trim();
                
                if (value === '') {
                    // Check if next lines are array items
                    let isNextArray = false;
                    for (let j = i + 1; j < lines.length; j++) {
                        const nextLine = lines[j].trim();
                        if (!nextLine || nextLine.startsWith('#')) continue;
                        const nextIndent = lines[j].search(/\S/);
                        if (nextIndent <= indent) break;
                        if (nextLine.startsWith('- ')) {
                            isNextArray = true;
                            break;
                        }
                        if (nextLine.includes(':')) break;
                    }
                    
                    if (isNextArray) {
                        current.obj[key] = [];
                        currentArrayKey = key;
                        stack.push({obj: current.obj[key], indent: indent, isArray: true});
                    } else {
                        current.obj[key] = {};
                        currentArrayKey = null;
                        stack.push({obj: current.obj[key], indent: indent, isArray: false});
                    }
                } else {
                    // Key with immediate value
                    current.obj[key] = parseYamlValue(value);
                }
            }
        }
        
        return root;
    }

    function parseYamlValue(value) {
        if (value === 'null' || value === '~') return null;
        if (value === 'true') return true;
        if (value === 'false') return false;
        if (!isNaN(value) && !isNaN(parseFloat(value))) return parseFloat(value);
        if (value.startsWith('"') && value.endsWith('"')) {
            return value.substring(1, value.length - 1).replace(/\\"/g, '"');
        }
        if (value.startsWith("'") && value.endsWith("'")) {
            return value.substring(1, value.length - 1);
        }
        return value;
    }

    function jsonToXml(jsonStr) {
        const obj = JSON.parse(jsonStr);
        let xml = '<?xml version="1.0" encoding="UTF-8"?>\n';
        xml += objectToXml(obj, 'root', 0);
        return xml;
    }

    function objectToXml(obj, tagName, indent = 0) {
        const spaces = '  '.repeat(indent);

        if (obj === null || obj === undefined) {
            return `${spaces}<${tagName}></${tagName}>`;
        }

        if (typeof obj === 'string' || typeof obj === 'number' || typeof obj === 'boolean') {
            return `${spaces}<${tagName}>${escapeXml(String(obj))}</${tagName}>`;
        }

        if (Array.isArray(obj)) {
            if (obj.length === 0) {
                return `${spaces}<${tagName}></${tagName}>`;
            }

            let xml = '';
            obj.forEach(item => {
                xml += objectToXml(item, getArrayItemTagName(tagName), indent) + '\n';
            });
            return xml.trimEnd();
        }

        if (typeof obj === 'object') {
            if (Object.keys(obj).length === 0) {
                return `${spaces}<${tagName}></${tagName}>`;
            }

            let xml = `${spaces}<${tagName}>\n`;
            Object.entries(obj).forEach(([key, value]) => {
                xml += objectToXml(value, key, indent + 1) + '\n';
            });
            xml += `${spaces}</${tagName}>`;
            return xml;
        }

        return `${spaces}<${tagName}>${escapeXml(String(obj))}</${tagName}>`;
    }

    function getArrayItemTagName(parentTag) {
        // Convert plural to singular for array items
        if (parentTag.endsWith('s')) {
            return parentTag.slice(0, -1);
        }
        return parentTag + '_item';
    }

    function escapeXml(text) {
        return text
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#x27;');
    }

    function xmlToJson(xmlStr) {
        const parser = new DOMParser();
        const doc = parser.parseFromString(xmlStr, 'text/xml');

        // Check for parsing errors
        const errorNode = doc.querySelector('parsererror');
        if (errorNode) {
            throw new Error('Invalid XML format');
        }

        const result = xmlNodeToObject(doc.documentElement);
        return JSON.stringify(result, null, 2);
    }

    function xmlNodeToObject(node) {
        const obj = {};

        // Handle attributes
        if (node.attributes && node.attributes.length > 0) {
            obj['@attributes'] = {};
            for (let i = 0; i < node.attributes.length; i++) {
                const attr = node.attributes[i];
                obj['@attributes'][attr.name] = attr.value;
            }
        }

        // Handle child nodes
        const children = Array.from(node.childNodes);
        const textContent = children
            .filter(child => child.nodeType === Node.TEXT_NODE)
            .map(child => child.textContent.trim())
            .join('')
            .trim();

        const elementChildren = children.filter(child => child.nodeType === Node.ELEMENT_NODE);

        if (elementChildren.length === 0) {
            // Leaf node
            if (textContent) {
                return parseValue(textContent);
            }
            return obj['@attributes'] ? obj : null;
        }

        // Group children by tag name
        const childGroups = {};
        elementChildren.forEach(child => {
            const tagName = child.tagName;
            if (!childGroups[tagName]) {
                childGroups[tagName] = [];
            }
            childGroups[tagName].push(xmlNodeToObject(child));
        });

        // Convert grouped children to object properties
        Object.entries(childGroups).forEach(([tagName, items]) => {
            if (items.length === 1) {
                obj[tagName] = items[0];
            } else {
                obj[tagName] = items;
            }
        });

        // If only text content and no attributes, return the text value
        if (Object.keys(obj).length === 0 && textContent) {
            return parseValue(textContent);
        }

        return obj;
    }

    function parseValue(value) {
        if (value === 'true') return true;
        if (value === 'false') return false;
        if (value === 'null') return null;
        if (!isNaN(value) && !isNaN(parseFloat(value))) return parseFloat(value);
        return value;
    }

    function yamlToXml(yamlStr) {
        const jsonStr = yamlToJson(yamlStr);
        return jsonToXml(jsonStr);
    }

    function xmlToYaml(xmlStr) {
        const jsonStr = xmlToJson(xmlStr);
        const obj = JSON.parse(jsonStr);
        return objectToYaml(obj, 0);
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

    function syntaxHighlightYaml(yaml) {
        yaml = yaml.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
        return yaml.split('\n').map(line => {
            line = line.replace(/(#.*)$/, '<span class="yaml-comment">$1</span>');
            line = line.replace(/^(\s*)([^:\s][^:]*?)(\s*:)(\s*)(.*)$/, function(match, indent, key, colon, space, value) {
                let highlightedValue = value;
                if (value.match(/^\s*(true|false)\s*$/)) {
                    highlightedValue = value.replace(/(true|false)/, '<span class="yaml-boolean">$1</span>');
                } else if (value.match(/^\s*null\s*$/)) {
                    highlightedValue = value.replace(/null/, '<span class="yaml-null">null</span>');
                } else if (value.match(/^\s*-?\d+(\.\d+)?\s*$/)) {
                    highlightedValue = value.replace(/(-?\d+(?:\.\d+)?)/, '<span class="yaml-number">$1</span>');
                } else if (value.match(/^\s*".*"\s*$/) || value.match(/^\s*'.*'\s*$/)) {
                    highlightedValue = value.replace(/(["'].*["'])/, '<span class="yaml-string">$1</span>');
                } else if (value.trim() && !value.includes('<span')) {
                    highlightedValue = value.replace(/(.+)/, '<span class="yaml-string">$1</span>');
                }
                return indent + '<span class="yaml-key">' + key + '</span>' + colon + space + highlightedValue;
            });
            line = line.replace(/^(\s*-\s+)(.*)$/, function(match, dash, value) {
                let highlightedValue = value;
                if (value.match(/^(true|false)$/)) {
                    highlightedValue = '<span class="yaml-boolean">' + value + '</span>';
                } else if (value.match(/^null$/)) {
                    highlightedValue = '<span class="yaml-null">null</span>';
                } else if (value.match(/^-?\d+(\.\d+)?$/)) {
                    highlightedValue = '<span class="yaml-number">' + value + '</span>';
                } else if (value.match(/^".*"$/) || value.match(/^'.*'$/)) {
                    highlightedValue = '<span class="yaml-string">' + value + '</span>';
                } else if (value.trim() && !value.includes('<span')) {
                    highlightedValue = '<span class="yaml-string">' + value + '</span>';
                }
                return '<span class="yaml-punctuation">' + dash + '</span>' + highlightedValue;
            });
            return line;
        }).join('\n');
    }

    function syntaxHighlightXml(xml) {
        xml = xml.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

        // Highlight XML declaration
        xml = xml.replace(/(&lt;\?xml[^&gt;]*\?&gt;)/g, '<span class="xml-declaration">$1</span>');

        // Highlight comments
        xml = xml.replace(/(&lt;!--[\s\S]*?--&gt;)/g, '<span class="xml-comment">$1</span>');

        // Highlight tags with attributes
        xml = xml.replace(/(&lt;\/?)([a-zA-Z_][\w\-]*)((?:\s+[a-zA-Z_][\w\-]*\s*=\s*"[^"]*")*)\s*(\/?&gt;)/g, function(match, openBracket, tagName, attributes, closeBracket) {
            let result = '<span class="xml-tag">' + openBracket + tagName;

            if (attributes) {
                result += attributes.replace(/([a-zA-Z_][\w\-]*)\s*=\s*("[^"]*")/g, function(attrMatch, attrName, attrValue) {
                    return ' <span class="xml-attribute">' + attrName + '</span>=<span class="xml-value">' + attrValue + '</span>';
                });
            }

            result += closeBracket + '</span>';
            return result;
        });

        return xml;
    }

    function convertToYaml() {
        const input = document.getElementById('inputContent').value.trim();
        const output = document.getElementById('outputContent');
        const statusText = document.getElementById('statusText');
        if (!input) {
            statusText.textContent = 'Please enter JSON content';
            statusText.style.color = '#ff8800';
            return;
        }
        try {
            const yamlResult = jsonToYaml(input);
            const highlighted = syntaxHighlightYaml(yamlResult);
            output.innerHTML = highlighted;
            statusText.textContent = 'Successfully converted JSON to YAML';
            statusText.style.color = '#008000';
            currentInputFormat = 'json';
            currentOutputFormat = 'yaml';
            updateFormatIndicators();
        } catch (error) {
            output.innerHTML = `<div class="error-display">Error: ${error.message}</div>`;
            statusText.textContent = 'JSON conversion error';
            statusText.style.color = '#cc0000';
        }
    }

    function convertToJson() {
        const input = document.getElementById('inputContent').value.trim();
        const output = document.getElementById('outputContent');
        const statusText = document.getElementById('statusText');
        if (!input) {
            statusText.textContent = 'Please enter YAML content';
            statusText.style.color = '#ff8800';
            return;
        }
        try {
            const jsonResult = yamlToJson(input);
            const highlighted = syntaxHighlightJson(jsonResult);
            output.innerHTML = highlighted;
            statusText.textContent = 'Successfully converted YAML to JSON';
            statusText.style.color = '#008000';
            currentInputFormat = 'yaml';
            currentOutputFormat = 'json';
            updateFormatIndicators();
        } catch (error) {
            output.innerHTML = `<div class="error-display">Error: ${error.message}</div>`;
            statusText.textContent = 'YAML conversion error';
            statusText.style.color = '#cc0000';
        }
    }

    function convertJsonToXml() {
        const input = document.getElementById('inputContent').value.trim();
        const output = document.getElementById('outputContent');
        const statusText = document.getElementById('statusText');
        if (!input) {
            statusText.textContent = 'Please enter JSON content';
            statusText.style.color = '#ff8800';
            return;
        }
        try {
            const xmlResult = jsonToXml(input);
            const highlighted = syntaxHighlightXml(xmlResult);
            output.innerHTML = highlighted;
            statusText.textContent = 'Successfully converted JSON to XML';
            statusText.style.color = '#008000';
            currentInputFormat = 'json';
            currentOutputFormat = 'xml';
            updateFormatIndicators();
        } catch (error) {
            output.innerHTML = `<div class="error-display">Error: ${error.message}</div>`;
            statusText.textContent = 'JSON to XML conversion error';
            statusText.style.color = '#cc0000';
        }
    }

    function convertXmlToJson() {
        const input = document.getElementById('inputContent').value.trim();
        const output = document.getElementById('outputContent');
        const statusText = document.getElementById('statusText');
        if (!input) {
            statusText.textContent = 'Please enter XML content';
            statusText.style.color = '#ff8800';
            return;
        }
        try {
            const jsonResult = xmlToJson(input);
            const highlighted = syntaxHighlightJson(jsonResult);
            output.innerHTML = highlighted;
            statusText.textContent = 'Successfully converted XML to JSON';
            statusText.style.color = '#008000';
            currentInputFormat = 'xml';
            currentOutputFormat = 'json';
            updateFormatIndicators();
        } catch (error) {
            output.innerHTML = `<div class="error-display">Error: ${error.message}</div>`;
            statusText.textContent = 'XML to JSON conversion error';
            statusText.style.color = '#cc0000';
        }
    }

    function convertYamlToXml() {
        const input = document.getElementById('inputContent').value.trim();
        const output = document.getElementById('outputContent');
        const statusText = document.getElementById('statusText');
        if (!input) {
            statusText.textContent = 'Please enter YAML content';
            statusText.style.color = '#ff8800';
            return;
        }
        try {
            const xmlResult = yamlToXml(input);
            const highlighted = syntaxHighlightXml(xmlResult);
            output.innerHTML = highlighted;
            statusText.textContent = 'Successfully converted YAML to XML';
            statusText.style.color = '#008000';
            currentInputFormat = 'yaml';
            currentOutputFormat = 'xml';
            updateFormatIndicators();
        } catch (error) {
            output.innerHTML = `<div class="error-display">Error: ${error.message}</div>`;
            statusText.textContent = 'YAML to XML conversion error';
            statusText.style.color = '#cc0000';
        }
    }

    function convertXmlToYaml() {
        const input = document.getElementById('inputContent').value.trim();
        const output = document.getElementById('outputContent');
        const statusText = document.getElementById('statusText');
        if (!input) {
            statusText.textContent = 'Please enter XML content';
            statusText.style.color = '#ff8800';
            return;
        }
        try {
            const yamlResult = xmlToYaml(input);
            const highlighted = syntaxHighlightYaml(yamlResult);
            output.innerHTML = highlighted;
            statusText.textContent = 'Successfully converted XML to YAML';
            statusText.style.color = '#008000';
            currentInputFormat = 'xml';
            currentOutputFormat = 'yaml';
            updateFormatIndicators();
        } catch (error) {
            output.innerHTML = `<div class="error-display">Error: ${error.message}</div>`;
            statusText.textContent = 'XML to YAML conversion error';
            statusText.style.color = '#cc0000';
        }
    }

    function formatCurrent() {
        const input = document.getElementById('inputContent').value.trim();
        if (!input) return;
        const format = detectFormat(input);
        if (format === 'json') {
            try {
                const parsed = JSON.parse(input);
                const formatted = JSON.stringify(parsed, null, 2);
                document.getElementById('inputContent').value = formatted;
                updateCharCount();
            } catch (e) {
                document.getElementById('statusText').textContent = 'Invalid JSON format';
                document.getElementById('statusText').style.color = '#cc0000';
            }
        } else if (format === 'xml') {
            try {
                const parser = new DOMParser();
                const doc = parser.parseFromString(input, 'text/xml');
                const serializer = new XMLSerializer();
                const formatted = formatXml(serializer.serializeToString(doc));
                document.getElementById('inputContent').value = formatted;
                updateCharCount();
            } catch (e) {
                document.getElementById('statusText').textContent = 'Invalid XML format';
                document.getElementById('statusText').style.color = '#cc0000';
            }
        }
    }

    function formatXml(xml) {
        let formatted = '';
        let indent = 0;
        const tab = '  ';
        xml.split(/>\s*</).forEach(function(node) {
            if (node.match(/^\/\w/)) indent--;
            formatted += tab.repeat(indent) + '<' + node + '>\n';
            if (node.match(/^<?\w[^>]*[^\/]$/)) indent++;
        });
        return formatted.substring(1, formatted.length - 3);
    }

    function swapContent() {
        const inputEl = document.getElementById('inputContent');
        const outputEl = document.getElementById('outputContent');
        const outputText = outputEl.textContent;
        if (!outputText.trim()) return;
        inputEl.value = outputText;
        outputEl.innerHTML = '';
        const temp = currentInputFormat;
        currentInputFormat = currentOutputFormat;
        currentOutputFormat = 'unknown';
        updateFormatIndicators();
        updateCharCount();
        document.getElementById('statusText').textContent = 'Content swapped between panels';
        document.getElementById('statusText').style.color = '#008000';
    }

    function clearAll() {
        document.getElementById('inputContent').value = '';
        document.getElementById('outputContent').innerHTML = '';
        document.getElementById('statusText').textContent = 'Ready - Paste JSON, YAML, or XML to auto-detect format';
        document.getElementById('statusText').style.color = '#666';
        currentInputFormat = 'unknown';
        currentOutputFormat = 'unknown';
        updateFormatIndicators();
        updateCharCount();
    }

    function copyOutput() {
        const output = document.getElementById('outputContent');
        const text = output.textContent;
        if (!text.trim()) {
            return;
        }
        navigator.clipboard.writeText(text).then(() => {
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
            textArea.value = text;
            document.body.appendChild(textArea);
            textArea.select();
            document.execCommand('copy');
            document.body.removeChild(textArea);
        });
    }

    function updateCharCount() {
        const input = document.getElementById('inputContent').value;
        document.getElementById('charCount').textContent = `Characters: ${input.length}`;
    }

    function updateFormatIndicators() {
        const inputIndicator = document.getElementById('inputFormat');
        const outputIndicator = document.getElementById('outputFormat');
        inputIndicator.textContent = currentInputFormat.toUpperCase();
        outputIndicator.textContent = currentOutputFormat.toUpperCase();

        // Set colors for input format
        if (currentInputFormat === 'json') {
            inputIndicator.style.backgroundColor = '#4a90e2';
        } else if (currentInputFormat === 'yaml') {
            inputIndicator.style.backgroundColor = '#ff6b35';
        } else if (currentInputFormat === 'xml') {
            inputIndicator.style.backgroundColor = '#28a745';
        } else {
            inputIndicator.style.backgroundColor = '#888';
        }

        // Set colors for output format
        if (currentOutputFormat === 'json') {
            outputIndicator.style.backgroundColor = '#4a90e2';
        } else if (currentOutputFormat === 'yaml') {
            outputIndicator.style.backgroundColor = '#ff6b35';
        } else if (currentOutputFormat === 'xml') {
            outputIndicator.style.backgroundColor = '#28a745';
        } else {
            outputIndicator.style.backgroundColor = '#888';
        }
    }

    function autoDetectAndConvert() {
        const input = document.getElementById('inputContent').value.trim();
        if (!input) return;
        const detectedFormat = detectFormat(input);
        if (detectedFormat !== 'unknown' && detectedFormat !== currentInputFormat) {
            currentInputFormat = detectedFormat;
            updateFormatIndicators();
            // Auto-convert to JSON as default when format is detected
            if (detectedFormat !== 'json') {
                convertTo('json');
            }
        }
    }

    document.getElementById('inputContent').addEventListener('input', function() {
        updateCharCount();
        clearTimeout(this.detectTimer);
        this.detectTimer = setTimeout(autoDetectAndConvert, 1000);
    });

    updateCharCount();
    updateFormatIndicators();
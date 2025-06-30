    let currentMode = 'cssToSvg';
    
    function setMode(mode) {
        currentMode = mode;
        
        // Update mode buttons
        document.getElementById('cssToSvgBtn').classList.toggle('active', mode === 'cssToSvg');
        document.getElementById('svgToCssBtn').classList.toggle('active', mode === 'svgToCss');
        
        // Update headers
        if (mode === 'cssToSvg') {
            document.getElementById('inputHeader').textContent = 'CSS Input';
            document.getElementById('outputHeader').textContent = 'SVG Output';
            document.getElementById('inputCode').placeholder = 'Enter your CSS code here...';
        } else {
            document.getElementById('inputHeader').textContent = 'SVG Input';
            document.getElementById('outputHeader').textContent = 'CSS Output';
            document.getElementById('inputCode').placeholder = 'Enter your SVG code here...';
        }
        
        // Clear content
        document.getElementById('inputCode').value = '';
        document.getElementById('outputCode').value = '';
        hidePreview();
        
        updateStatus('Mode changed to ' + (mode === 'cssToSvg' ? 'CSS → SVG' : 'SVG → CSS'));
        updateCodeInfo();
    }

    function convertCode() {
        const input = document.getElementById('inputCode').value.trim();
        
        if (!input) {
            updateStatus('Please enter code to convert', true);
            return;
        }

        try {
            if (currentMode === 'cssToSvg') {
                convertCssToSvg(input);
            } else {
                convertSvgToCss(input);
            }
        } catch (error) {
            showError('Conversion failed: ' + error.message);
        }
    }

    function convertCssToSvg(cssCode) {
        try {
            // Parse CSS and convert to SVG
            const svgCode = cssToSvgConverter(cssCode);
            document.getElementById('outputCode').value = svgCode;
            showPreview(svgCode, 'svg');
            updateStatus('CSS converted to SVG successfully');
        } catch (error) {
            showError('CSS to SVG conversion failed: ' + error.message);
        }
    }

    function convertSvgToCss(svgCode) {
        try {
            // Parse SVG and convert to CSS
            const cssCode = svgToCssConverter(svgCode);
            document.getElementById('outputCode').value = cssCode;
            showPreview(cssCode, 'css');
            updateStatus('SVG converted to CSS successfully');
        } catch (error) {
            showError('SVG to CSS conversion failed: ' + error.message);
        }
    }

    function cssToSvgConverter(cssCode) {
        // Basic CSS to SVG conversion
        const rules = parseCssRules(cssCode);
        let svgElements = [];
        
        rules.forEach((rule, index) => {
            const element = cssRuleToSvgElement(rule, index);
            if (element) {
                svgElements.push(element);
            }
        });

        const svgContent = svgElements.join('\n  ');
        
        return `<svg xmlns="http://www.w3.org/2000/svg" width="300" height="200" viewBox="0 0 300 200">
  ${svgContent}
</svg>`;
    }

    function svgToCssConverter(svgCode) {
        // Basic SVG to CSS conversion
        const parser = new DOMParser();
        const svgDoc = parser.parseFromString(svgCode, 'image/svg+xml');
        
        if (svgDoc.querySelector('parsererror')) {
            throw new Error('Invalid SVG format');
        }
        
        const svgElement = svgDoc.querySelector('svg');
        if (!svgElement) {
            throw new Error('No SVG element found');
        }
        
        let cssRules = [];
        const elements = svgElement.querySelectorAll('*');
        
        elements.forEach((element, index) => {
            const cssRule = svgElementToCssRule(element, index);
            if (cssRule) {
                cssRules.push(cssRule);
            }
        });

        return cssRules.join('\n\n');
    }

    function parseCssRules(cssCode) {
        const rules = [];
        const ruleRegex = /([^{]+)\s*\{([^}]+)\}/g;
        let match;
        
        while ((match = ruleRegex.exec(cssCode)) !== null) {
            const selector = match[1].trim();
            const declarations = match[2].trim();
            
            const properties = {};
            const propRegex = /([^:;]+):\s*([^;]+)/g;
            let propMatch;
            
            while ((propMatch = propRegex.exec(declarations)) !== null) {
                const property = propMatch[1].trim();
                const value = propMatch[2].trim();
                properties[property] = value;
            }
            
            rules.push({ selector, properties });
        }
        
        return rules;
    }

    function cssRuleToSvgElement(rule, index) {
        const props = rule.properties;
        let element = '';
        
        // Determine element type based on properties
        if (props['border-radius'] || props['background']) {
            // Rectangle with styling
            const width = parseFloat(props['width']) || 100;
            const height = parseFloat(props['height']) || 50;
            const x = index * 120 + 10;
            const y = 50;
            const rx = parseFloat(props['border-radius']) || 0;
            
            let fill = 'none';
            if (props['background']) {
                if (props['background'].includes('linear-gradient')) {
                    const gradientId = `gradient${index}`;
                    const gradient = createLinearGradient(props['background'], gradientId);
                    fill = `url(#${gradientId})`;
                    element = gradient + '\n  ';
                } else {
                    fill = props['background'];
                }
            }
            
            const stroke = props['border-color'] || 'none';
            const strokeWidth = parseFloat(props['border-width']) || 0;
            
            element += `<rect x="${x}" y="${y}" width="${width}" height="${height}" rx="${rx}" fill="${fill}" stroke="${stroke}" stroke-width="${strokeWidth}"/>`;
        }
        
        return element;
    }

    function createLinearGradient(gradientCss, id) {
        // Parse linear-gradient syntax
        const match = gradientCss.match(/linear-gradient\(([^)]+)\)/);
        if (!match) return '';
        
        const parts = match[1].split(',').map(s => s.trim());
        const angle = parts[0].includes('deg') ? parts[0] : '0deg';
        const colors = parts.slice(angle.includes('deg') ? 1 : 0);
        
        let stops = '';
        colors.forEach((color, index) => {
            const offset = index / (colors.length - 1);
            stops += `    <stop offset="${offset * 100}%" stop-color="${color.trim()}"/>\n`;
        });
        
        return `<defs>
    <linearGradient id="${id}" x1="0%" y1="0%" x2="100%" y2="0%">
${stops}    </linearGradient>
  </defs>`;
    }

    function svgElementToCssRule(element, index) {
        const tagName = element.tagName.toLowerCase();
        const className = `.svg-element-${index}`;
        
        let cssProperties = [];
        
        // Convert common SVG attributes to CSS
        if (element.getAttribute('fill')) {
            cssProperties.push(`background-color: ${element.getAttribute('fill')}`);
        }
        
        if (element.getAttribute('stroke')) {
            cssProperties.push(`border-color: ${element.getAttribute('stroke')}`);
        }
        
        if (element.getAttribute('stroke-width')) {
            cssProperties.push(`border-width: ${element.getAttribute('stroke-width')}px`);
            cssProperties.push(`border-style: solid`);
        }
        
        if (tagName === 'rect') {
            const width = element.getAttribute('width');
            const height = element.getAttribute('height');
            const rx = element.getAttribute('rx');
            
            if (width) cssProperties.push(`width: ${width}px`);
            if (height) cssProperties.push(`height: ${height}px`);
            if (rx) cssProperties.push(`border-radius: ${rx}px`);
        }
        
        if (tagName === 'circle') {
            const r = element.getAttribute('r');
            if (r) {
                cssProperties.push(`width: ${r * 2}px`);
                cssProperties.push(`height: ${r * 2}px`);
                cssProperties.push(`border-radius: 50%`);
            }
        }
        
        if (cssProperties.length === 0) {
            return null;
        }
        
        return `${className} {
  ${cssProperties.join(';\n  ')};
}`;
    }

    function showPreview(code, type) {
        const previewContainer = document.getElementById('previewContainer');
        
        if (type === 'svg') {
            previewContainer.innerHTML = code;
        } else if (type === 'css') {
            previewContainer.innerHTML = `
                <div style="width: 100%; max-width: 400px;">
                    <style>${code}</style>
                    <div class="svg-element-0">Preview Element</div>
                </div>
            `;
        }
        
        document.getElementById('previewPanel').style.display = 'flex';
    }

    function hidePreview() {
        document.getElementById('previewPanel').style.display = 'none';
    }

    function showError(message) {
        const outputCode = document.getElementById('outputCode');
        outputCode.value = '';
        document.getElementById('previewContainer').innerHTML = `<div class="error-display">${message}</div>`;
        document.getElementById('previewPanel').style.display = 'flex';
        updateStatus('Conversion error', true);
    }

    function clearAll() {
        document.getElementById('inputCode').value = '';
        document.getElementById('outputCode').value = '';
        hidePreview();
        updateStatus('Cleared all content');
        updateCodeInfo();
    }

    function swapPanels() {
        const input = document.getElementById('inputCode').value;
        const output = document.getElementById('outputCode').value;
        
        document.getElementById('inputCode').value = output;
        document.getElementById('outputCode').value = input;
        
        hidePreview();
        updateStatus('Panels swapped');
        updateCodeInfo();
    }

    function copyInput() {
        const text = document.getElementById('inputCode').value;
        copyToClipboard(text, 'Input copied to clipboard');
    }

    function copyOutput() {
        const text = document.getElementById('outputCode').value;
        copyToClipboard(text, 'Output copied to clipboard');
    }

    function copyToClipboard(text, message) {
        if (!text) {
            updateStatus('Nothing to copy', true);
            return;
        }

        navigator.clipboard.writeText(text).then(() => {
            updateStatus(message);
        }).catch(() => {
            const textArea = document.createElement('textarea');
            textArea.value = text;
            document.body.appendChild(textArea);
            textArea.select();
            document.execCommand('copy');
            document.body.removeChild(textArea);
            updateStatus(message);
        });
    }

    function loadExample(type) {
        const examples = {
            'button': {
                mode: 'cssToSvg',
                code: `.button {
  background: linear-gradient(45deg, #ff6b6b, #4ecdc4);
  border-radius: 8px;
  width: 120px;
  height: 40px;
  border: 2px solid #333;
}`
            },
            'gradient': {
                mode: 'cssToSvg',
                code: `.gradient-box {
  background: linear-gradient(135deg, #667eea, #764ba2);
  width: 200px;
  height: 100px;
  border-radius: 12px;
}`
            },
            'animation': {
                mode: 'cssToSvg',
                code: `.animated-circle {
  background: radial-gradient(circle, #ff9a9e, #fecfef);
  width: 80px;
  height: 80px;
  border-radius: 50%;
  border: 3px solid #ff6b9d;
}`
            },
            'shapes': {
                mode: 'svgToCss',
                code: `<svg xmlns="http://www.w3.org/2000/svg" width="200" height="150">
  <rect x="10" y="10" width="80" height="50" rx="8" fill="#4CAF50" stroke="#2E7D32" stroke-width="2"/>
  <circle cx="130" cy="35" r="25" fill="#2196F3" stroke="#1976D2" stroke-width="2"/>
</svg>`
            },
            'icons': {
                mode: 'svgToCss',
                code: `<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
  <rect x="20" y="20" width="60" height="60" rx="10" fill="#FF5722" stroke="#D84315" stroke-width="3"/>
  <circle cx="50" cy="50" r="15" fill="#FFF"/>
</svg>`
            }
        };

        const example = examples[type];
        if (example) {
            setMode(example.mode);
            document.getElementById('inputCode').value = example.code;
            updateCodeInfo();
            updateStatus(`Loaded ${type} example`);
        }
    }

    function updateStatus(message, isError = false) {
        const statusText = document.getElementById('statusText');
        statusText.textContent = message;
        statusText.style.color = isError ? '#cc0000' : '#008000';
        
        setTimeout(() => {
            statusText.textContent = 'Ready - Select mode and enter code to convert';
            statusText.style.color = '#666';
        }, 3000);
    }

    function updateCodeInfo() {
        const input = document.getElementById('inputCode').value;
        const lines = input.split('\n').length;
        const chars = input.length;
        
        document.getElementById('codeInfo').textContent = `Lines: ${lines} | Characters: ${chars}`;
    }

    // Auto-convert on input
    document.getElementById('inputCode').addEventListener('input', function() {
        updateCodeInfo();
        clearTimeout(this.convertTimer);
        this.convertTimer = setTimeout(() => {
            if (this.value.trim()) {
                convertCode();
            } else {
                hidePreview();
            }
        }, 1000);
    });

    // Initialize
    updateCodeInfo();
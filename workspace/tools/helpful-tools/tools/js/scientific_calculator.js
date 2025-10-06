let currentExpression = '';
let angleMode = 'deg';
let history = [];
let graphFunctions = [];
let graphState = {
    xMin: -10,
    xMax: 10,
    yMin: -10,
    yMax: 10,
    width: 0,
    height: 0
};

const functionExamples = {
    quadratic: 'x^2',
    sine: 'sin(x)',
    exponential: 'e^x',
    logarithmic: 'log(x)',
    polynomial: 'x^3 - 2*x^2 + x - 1',
    trigonometric: 'sin(x) + cos(2*x)',
    rational: '1/x',
    absolute: 'abs(x)',
    piecewise: 'x > 0 ? x^2 : -x^2'
};

let isDragSelect = false;
let dragStart = { x: 0, y: 0 };
let dragEnd = { x: 0, y: 0 };

// Calculator Functions
function updateDisplay() {
    document.getElementById('expression').textContent = currentExpression;
}

function appendNumber(num) {
    currentExpression += num;
    updateDisplay();
}

function appendOperator(op) {
    if (op === '.') {
        // Prevent multiple decimals in same number
        const parts = currentExpression.split(/[\+\-\*\/\(\)]/);
        const lastPart = parts[parts.length - 1];
        if (lastPart.includes('.')) return;
    }
    currentExpression += op;
    updateDisplay();
}

function appendFunction(func) {
    currentExpression += func;
    updateDisplay();
}

function appendConstant(constant) {
    currentExpression += constant;
    updateDisplay();
}

function backspace() {
    currentExpression = currentExpression.slice(0, -1);
    updateDisplay();
}

function clearEntry() {
    currentExpression = '';
    updateDisplay();
    document.getElementById('result').textContent = '0';
}

function clearAll() {
    currentExpression = '';
    history = [];
    updateDisplay();
    updateHistory();
    document.getElementById('result').textContent = '0';
}

function updateAngleMode() {
    const selected = document.querySelector('input[name="angleMode"]:checked').value;
    angleMode = selected;
    math.config({
        angles: angleMode
    });
}

function calculate() {
    if (!currentExpression.trim()) return;

    try {
        // Replace constants and functions for math.js
        let expr = currentExpression
            .replace(/pi/g, 'pi')
            .replace(/e/g, 'e')
            .replace(/\^/g, '^')
            .replace(/×/g, '*')
            .replace(/÷/g, '/')
            .replace(/√/g, 'sqrt')
            .replace(/!/g, '!');

        // Handle implicit multiplication (e.g., 2π becomes 2*π)
        expr = expr.replace(/(\d)(pi|e|sin|cos|tan|log|ln|sqrt)/g, '$1*$2');
        expr = expr.replace(/(pi|e|\))(\d)/g, '$1*$2');
        expr = expr.replace(/(\d)\(/g, '$1*(');
        expr = expr.replace(/\)(\d)/g, ')*$1');

        const result = math.evaluate(expr);
        const resultText = typeof result === 'number' ?
            (Math.abs(result) < 0.0001 && result !== 0 ? result.toExponential(6) : result.toString()) :
            result.toString();

        document.getElementById('result').textContent = resultText;

        // Add to history
        history.unshift({
            expression: currentExpression,
            result: resultText
        });
        if (history.length > 10) history.pop();
        updateHistory();

        document.getElementById('statusText').textContent = 'Calculated successfully';

    } catch (error) {
        document.getElementById('result').textContent = 'Error';
        document.getElementById('statusText').textContent = 'Error: ' + error.message;
    }
}

function updateHistory() {
    const panel = document.getElementById('historyPanel');
    panel.innerHTML = history.map(item =>
        `<div class="history-item" onclick="loadFromHistory('${item.expression.replace(/'/g, '\\\'')}')">${item.expression} = ${item.result}</div>`
    ).join('');
}

function loadFromHistory(expr) {
    currentExpression = expr;
    updateDisplay();
}

function plotCurrentExpression() {
    if (!currentExpression.trim()) return;
    document.getElementById('functionInput').value = currentExpression;
    plotFunction();
}

// Graph Functions
function initGraph() {
    const canvas = document.getElementById('graphCanvas');
    const rect = canvas.parentElement.getBoundingClientRect();
    canvas.width = rect.width;
    canvas.height = rect.height;
    graphState.width = canvas.width;
    graphState.height = canvas.height;

    drawGrid();
    plotAllFunctions();
}

function drawGrid() {
    const canvas = document.getElementById('graphCanvas');
    const ctx = canvas.getContext('2d');

    ctx.clearRect(0, 0, canvas.width, canvas.height);
    
    // Calculate appropriate step sizes
    const xRange = graphState.xMax - graphState.xMin;
    const yRange = graphState.yMax - graphState.yMin;
    const xStep = calculateNiceStep(xRange / 10);
    const yStep = calculateNiceStep(yRange / 10);
    
    // Draw minor grid lines
    ctx.strokeStyle = '#f0f0f0';
    ctx.lineWidth = 0.5;
    
    const xMinorStep = xStep / 5;
    const yMinorStep = yStep / 5;
    
    // Minor vertical lines
    for (let x = Math.ceil(graphState.xMin / xMinorStep) * xMinorStep; x <= graphState.xMax; x += xMinorStep) {
        const canvasX = ((x - graphState.xMin) / (graphState.xMax - graphState.xMin)) * canvas.width;
        ctx.beginPath();
        ctx.moveTo(canvasX, 0);
        ctx.lineTo(canvasX, canvas.height);
        ctx.stroke();
    }
    
    // Minor horizontal lines
    for (let y = Math.ceil(graphState.yMin / yMinorStep) * yMinorStep; y <= graphState.yMax; y += yMinorStep) {
        const canvasY = canvas.height - ((y - graphState.yMin) / (graphState.yMax - graphState.yMin)) * canvas.height;
        ctx.beginPath();
        ctx.moveTo(0, canvasY);
        ctx.lineTo(canvas.width, canvasY);
        ctx.stroke();
    }

    // Draw major grid lines
    ctx.strokeStyle = '#e0e0e0';
    ctx.lineWidth = 1;

    // Major vertical lines with labels
    ctx.fillStyle = '#666';
    ctx.font = '11px Segoe UI';
    ctx.textAlign = 'center';
    
    for (let x = Math.ceil(graphState.xMin / xStep) * xStep; x <= graphState.xMax; x += xStep) {
        const canvasX = ((x - graphState.xMin) / (graphState.xMax - graphState.xMin)) * canvas.width;
        ctx.beginPath();
        ctx.moveTo(canvasX, 0);
        ctx.lineTo(canvasX, canvas.height);
        ctx.stroke();
        
        // X-axis labels
        if (Math.abs(x) > 0.0001 || x === 0) {
            const label = formatNumber(x);
            const zeroY = canvas.height - ((-graphState.yMin) / (graphState.yMax - graphState.yMin)) * canvas.height;
            const labelY = Math.min(Math.max(zeroY + 15, 15), canvas.height - 5);
            ctx.fillText(label, canvasX, labelY);
        }
    }

    // Major horizontal lines with labels
    ctx.textAlign = 'left';
    for (let y = Math.ceil(graphState.yMin / yStep) * yStep; y <= graphState.yMax; y += yStep) {
        const canvasY = canvas.height - ((y - graphState.yMin) / (graphState.yMax - graphState.yMin)) * canvas.height;
        ctx.beginPath();
        ctx.moveTo(0, canvasY);
        ctx.lineTo(canvas.width, canvasY);
        ctx.stroke();
        
        // Y-axis labels
        if (Math.abs(y) > 0.0001 || y === 0) {
            const label = formatNumber(y);
            const zeroX = ((-graphState.xMin) / (graphState.xMax - graphState.xMin)) * canvas.width;
            const labelX = Math.max(zeroX + 5, 5);
            if (labelX < canvas.width - 30) {
                ctx.fillText(label, labelX, canvasY - 3);
            }
        }
    }

    // Draw axes
    ctx.strokeStyle = '#666';
    ctx.lineWidth = 2;

    // X-axis
    const zeroY = canvas.height - ((-graphState.yMin) / (graphState.yMax - graphState.yMin)) * canvas.height;
    if (zeroY >= 0 && zeroY <= canvas.height) {
        ctx.beginPath();
        ctx.moveTo(0, zeroY);
        ctx.lineTo(canvas.width, zeroY);
        ctx.stroke();
    }

    // Y-axis
    const zeroX = ((-graphState.xMin) / (graphState.xMax - graphState.xMin)) * canvas.width;
    if (zeroX >= 0 && zeroX <= canvas.width) {
        ctx.beginPath();
        ctx.moveTo(zeroX, 0);
        ctx.lineTo(zeroX, canvas.height);
        ctx.stroke();
    }
}

function plotFunction() {
    const input = document.getElementById('functionInput').value.trim();
    if (!input) return;
    
    const validation = validateFunction(input);
    if (!validation.valid) {
        document.getElementById('statusText').textContent = 'Cannot plot: ' + validation.error;
        return;
    }

    graphFunctions = [{ expr: input, color: '#4a90e2', id: Date.now() }];
    plotAllFunctions();
    updateLegend();
}

function addToGraph() {
    const input = document.getElementById('functionInput').value.trim();
    if (!input) return;
    
    const validation = validateFunction(input);
    if (!validation.valid) {
        document.getElementById('statusText').textContent = 'Cannot add: ' + validation.error;
        return;
    }

    const colors = ['#4a90e2', '#ff6b35', '#388e3c', '#9c27b0', '#ff9800', '#e91e63', '#00bcd4', '#8bc34a'];
    const color = colors[graphFunctions.length % colors.length];

    graphFunctions.push({ expr: input, color: color, id: Date.now() });
    plotAllFunctions();
    updateLegend();
}

function plotAllFunctions() {
    drawGrid();

    graphFunctions.forEach(func => {
        plotSingleFunction(func, func.color);
    });

    document.getElementById('statusText').textContent = `Plotted ${graphFunctions.length} function(s)`;
}

function plotSingleFunction(functionObj, color) {
    const canvas = document.getElementById('graphCanvas');
    const ctx = canvas.getContext('2d');
    const expression = typeof functionObj === 'string' ? functionObj : functionObj.expr;
    const isDerivative = functionObj.isDerivative || false;

    try {
        // Prepare expression for math.js
        let expr = expression
            .replace(/derivative\(/g, '')
            .replace(/pi/g, 'pi')
            .replace(/e/g, 'e')
            .replace(/\^/g, '^')
            .replace(/×/g, '*')
            .replace(/÷/g, '/')
            .replace(/√/g, 'sqrt');
        
        // Remove trailing parenthesis for derivative expressions
        if (isDerivative && expr.endsWith(')')) {
            expr = expr.slice(0, -1);
        }

        ctx.strokeStyle = color;
        ctx.lineWidth = isDerivative ? 1.5 : 2;
        if (isDerivative) {
            ctx.setLineDash([5, 5]);
        } else {
            ctx.setLineDash([]);
        }
        ctx.beginPath();

        let firstPoint = true;
        const step = (graphState.xMax - graphState.xMin) / (canvas.width * 2);

        for (let x = graphState.xMin; x <= graphState.xMax; x += step) {
            try {
                let y;
                
                if (isDerivative) {
                    y = numericalDerivative(expr, x);
                } else {
                    y = math.evaluate(expr, { x: x });
                }

                if (typeof y === 'number' && isFinite(y)) {
                    const canvasX = ((x - graphState.xMin) / (graphState.xMax - graphState.xMin)) * canvas.width;
                    const canvasY = canvas.height - ((y - graphState.yMin) / (graphState.yMax - graphState.yMin)) * canvas.height;

                    if (canvasY >= -100 && canvasY <= canvas.height + 100) {
                        if (firstPoint) {
                            ctx.moveTo(canvasX, canvasY);
                            firstPoint = false;
                        } else {
                            ctx.lineTo(canvasX, canvasY);
                        }
                    } else {
                        firstPoint = true;
                    }
                } else {
                    firstPoint = true;
                }
            } catch (e) {
                firstPoint = true;
            }
        }

        ctx.stroke();
        ctx.setLineDash([]);

    } catch (error) {
        document.getElementById('statusText').textContent = 'Error plotting function: ' + error.message;
    }
}

function clearGraph() {
    graphFunctions = [];
    drawGrid();
    updateLegend();
    document.getElementById('statusText').textContent = 'Graph cleared';
}

function resetZoom() {
    graphState.xMin = -10;
    graphState.xMax = 10;
    graphState.yMin = -10;
    graphState.yMax = 10;
    updateZoomInputs();
    plotAllFunctions();
    document.getElementById('graphInfo').textContent = 'View reset to (-10,10) x (-10,10)';
}

function calculateNiceStep(roughStep) {
    const magnitude = Math.pow(10, Math.floor(Math.log10(roughStep)));
    const normalizedStep = roughStep / magnitude;
    
    if (normalizedStep <= 1) return magnitude;
    if (normalizedStep <= 2) return 2 * magnitude;
    if (normalizedStep <= 5) return 5 * magnitude;
    return 10 * magnitude;
}

function formatNumber(num) {
    if (Math.abs(num) < 0.0001 && num !== 0) return num.toExponential(1);
    if (Math.abs(num) >= 1000) return num.toExponential(1);
    if (num === Math.floor(num)) return num.toString();
    return num.toFixed(2).replace(/\.?0+$/, '');
}

function updateLegend() {
    const legend = document.getElementById('functionLegend');
    
    if (graphFunctions.length === 0) {
        legend.style.display = 'none';
        return;
    }
    
    legend.style.display = 'block';
    legend.innerHTML = graphFunctions.map((func, index) => {
        const displayExpr = func.isDerivative ? 
            `d/dx(${func.originalExpr})` : 
            func.expr;
        const lineStyle = func.isDerivative ? 
            'border-bottom: 2px dashed;' : 
            '';
        
        return `<div class="legend-item">
            <div class="legend-color" style="background-color: ${func.color}; ${lineStyle}"></div>
            <div class="legend-text">${displayExpr}</div>
            <div class="legend-remove" onclick="removeFunction(${func.id})" title="Remove function">×</div>
        </div>`;
    }).join('');
}

function removeFunction(id) {
    graphFunctions = graphFunctions.filter(func => func.id !== id);
    plotAllFunctions();
    updateLegend();
}

function loadExample(type) {
    const example = functionExamples[type];
    if (example) {
        document.getElementById('functionInput').value = example;
    }
}

function updateZoom() {
    const xMin = parseFloat(document.getElementById('xMinInput').value);
    const xMax = parseFloat(document.getElementById('xMaxInput').value);
    const yMin = parseFloat(document.getElementById('yMinInput').value);
    const yMax = parseFloat(document.getElementById('yMaxInput').value);
    
    if (isNaN(xMin) || isNaN(xMax) || isNaN(yMin) || isNaN(yMax)) return;
    if (xMin >= xMax || yMin >= yMax) return;
    
    graphState.xMin = xMin;
    graphState.xMax = xMax;
    graphState.yMin = yMin;
    graphState.yMax = yMax;
    
    plotAllFunctions();
}

function updateZoomInputs() {
    document.getElementById('xMinInput').value = graphState.xMin;
    document.getElementById('xMaxInput').value = graphState.xMax;
    document.getElementById('yMinInput').value = graphState.yMin;
    document.getElementById('yMaxInput').value = graphState.yMax;
}

function fitToData() {
    if (graphFunctions.length === 0) return;
    
    let xValues = [];
    let yValues = [];
    
    const step = (graphState.xMax - graphState.xMin) / 1000;
    
    graphFunctions.forEach(func => {
        try {
            let expr = func.expr
                .replace(/pi/g, 'pi')
                .replace(/e/g, 'e')
                .replace(/\^/g, '^')
                .replace(/×/g, '*')
                .replace(/÷/g, '/')
                .replace(/√/g, 'sqrt');
            
            for (let x = graphState.xMin; x <= graphState.xMax; x += step) {
                try {
                    const y = math.evaluate(expr, { x: x });
                    if (typeof y === 'number' && isFinite(y)) {
                        xValues.push(x);
                        yValues.push(y);
                    }
                } catch (e) {}
            }
        } catch (e) {}
    });
    
    if (yValues.length === 0) return;
    
    const yMin = Math.min(...yValues);
    const yMax = Math.max(...yValues);
    const yPadding = (yMax - yMin) * 0.1;
    
    graphState.yMin = yMin - yPadding;
    graphState.yMax = yMax + yPadding;
    
    updateZoomInputs();
    plotAllFunctions();
    
    document.getElementById('statusText').textContent = 'Fitted to data range';
}

function plotDerivative() {
    const input = document.getElementById('functionInput').value.trim();
    if (!input) return;
    
    try {
        // Use numerical differentiation
        const colors = ['#4a90e2', '#ff6b35', '#388e3c', '#9c27b0', '#ff9800', '#e91e63', '#00bcd4', '#8bc34a'];
        const color = colors[graphFunctions.length % colors.length];
        
        const derivativeExpr = `derivative(${input})`;
        graphFunctions.push({ 
            expr: derivativeExpr, 
            color: color, 
            id: Date.now(),
            isDerivative: true,
            originalExpr: input
        });
        
        plotAllFunctions();
        updateLegend();
        document.getElementById('statusText').textContent = `Added derivative of ${input}`;
        
    } catch (error) {
        document.getElementById('statusText').textContent = 'Error calculating derivative: ' + error.message;
    }
}

function numericalDerivative(expr, x, h = 0.0001) {
    try {
        const y1 = math.evaluate(expr, { x: x + h });
        const y2 = math.evaluate(expr, { x: x - h });
        return (y1 - y2) / (2 * h);
    } catch (e) {
        return NaN;
    }
}

// Mouse events for panning and zooming
let isDragging = false;
let lastMouseX = 0;
let lastMouseY = 0;

document.getElementById('graphCanvas').addEventListener('mousedown', (e) => {
    isDragging = true;
    lastMouseX = e.offsetX;
    lastMouseY = e.offsetY;
});

document.getElementById('graphCanvas').addEventListener('mousemove', (e) => {
    // Update coordinate display
    const rect = e.target.getBoundingClientRect();
    const x = graphState.xMin + (e.offsetX / graphState.width) * (graphState.xMax - graphState.xMin);
    const y = graphState.yMax - (e.offsetY / graphState.height) * (graphState.yMax - graphState.yMin);
    
    const coordDisplay = document.getElementById('coordinateDisplay');
    coordDisplay.textContent = `x: ${formatNumber(x)}, y: ${formatNumber(y)}`;
    coordDisplay.style.display = 'block';
    
    if (isDragging) {
        const deltaX = e.offsetX - lastMouseX;
        const deltaY = e.offsetY - lastMouseY;

        const xRange = graphState.xMax - graphState.xMin;
        const yRange = graphState.yMax - graphState.yMin;

        const dx = -(deltaX / graphState.width) * xRange;
        const dy = (deltaY / graphState.height) * yRange;

        graphState.xMin += dx;
        graphState.xMax += dx;
        graphState.yMin += dy;
        graphState.yMax += dy;

        updateZoomInputs();
        plotAllFunctions();

        lastMouseX = e.offsetX;
        lastMouseY = e.offsetY;
    }
});

document.getElementById('graphCanvas').addEventListener('mouseup', () => {
    isDragging = false;
});

document.getElementById('graphCanvas').addEventListener('wheel', (e) => {
    e.preventDefault();

    const zoomFactor = e.deltaY > 0 ? 1.1 : 0.9;
    
    // Zoom towards mouse position
    const mouseX = graphState.xMin + (e.offsetX / graphState.width) * (graphState.xMax - graphState.xMin);
    const mouseY = graphState.yMax - (e.offsetY / graphState.height) * (graphState.yMax - graphState.yMin);

    const xRange = (graphState.xMax - graphState.xMin) * zoomFactor;
    const yRange = (graphState.yMax - graphState.yMin) * zoomFactor;

    graphState.xMin = mouseX - (mouseX - graphState.xMin) * zoomFactor;
    graphState.xMax = mouseX + (graphState.xMax - mouseX) * zoomFactor;
    graphState.yMin = mouseY - (mouseY - graphState.yMin) * zoomFactor;
    graphState.yMax = mouseY + (graphState.yMax - mouseY) * zoomFactor;

    updateZoomInputs();
    plotAllFunctions();
});

document.getElementById('graphCanvas').addEventListener('mouseleave', () => {
    document.getElementById('coordinateDisplay').style.display = 'none';
});

// Keyboard support
document.addEventListener('keydown', (e) => {
    if (document.activeElement.tagName === 'INPUT') return;

    if (e.key >= '0' && e.key <= '9') {
        appendNumber(e.key);
    } else if (e.key === '+') {
        appendOperator('+');
    } else if (e.key === '-') {
        appendOperator('-');
    } else if (e.key === '*') {
        appendOperator('*');
    } else if (e.key === '/') {
        e.preventDefault();
        appendOperator('/');
    } else if (e.key === 'Enter') {
        calculate();
    } else if (e.key === 'Escape') {
        clearEntry();
    } else if (e.key === 'Backspace') {
        backspace();
    } else if (e.key === '.') {
        appendOperator('.');
    } else if (e.key === '(') {
        appendOperator('(');
    } else if (e.key === ')') {
        appendOperator(')');
    }
});

// Initialize
window.addEventListener('load', () => {
    updateDisplay();
    math.config({ angles: 'deg' });
    updateZoomInputs();
    setTimeout(initGraph, 100);
});

window.addEventListener('resize', () => {
    setTimeout(initGraph, 100);
});

// Function suggestions and validation
const functionSuggestions = [
    { name: 'sin(x)', desc: 'Sine function' },
    { name: 'cos(x)', desc: 'Cosine function' },
    { name: 'tan(x)', desc: 'Tangent function' },
    { name: 'asin(x)', desc: 'Arcsine function' },
    { name: 'acos(x)', desc: 'Arccosine function' },
    { name: 'atan(x)', desc: 'Arctangent function' },
    { name: 'log(x)', desc: 'Base-10 logarithm' },
    { name: 'ln(x)', desc: 'Natural logarithm' },
    { name: 'exp(x)', desc: 'Exponential function (e^x)' },
    { name: 'sqrt(x)', desc: 'Square root' },
    { name: 'abs(x)', desc: 'Absolute value' },
    { name: 'floor(x)', desc: 'Floor function' },
    { name: 'ceil(x)', desc: 'Ceiling function' },
    { name: 'round(x)', desc: 'Round to nearest integer' },
    { name: 'x^2', desc: 'x squared' },
    { name: 'x^3', desc: 'x cubed' },
    { name: 'x^(1/2)', desc: 'Square root of x' },
    { name: 'e^x', desc: 'Exponential function' },
    { name: 'pi', desc: 'Pi constant (3.14159...)' },
    { name: 'e', desc: 'Euler\'s number (2.71828...)' }
];

function validateFunction(expr) {
    try {
        if (!expr.trim()) return { valid: false, error: 'Empty function' };
        
        // Test evaluation at a few points
        const testPoints = [0, 1, -1, 0.5, 2];
        let validPoints = 0;
        
        for (const x of testPoints) {
            try {
                const result = math.evaluate(expr.replace(/\^/g, '^'), { x: x });
                if (typeof result === 'number' && isFinite(result)) {
                    validPoints++;
                }
            } catch (e) {
                // Some functions might not be defined at certain points
            }
        }
        
        if (validPoints === 0) {
            return { valid: false, error: 'Function produces no valid values' };
        }
        
        return { valid: true, error: null };
        
    } catch (error) {
        return { valid: false, error: error.message };
    }
}

function showSyntaxHelp(input, suggestions) {
    const helpDiv = document.getElementById('syntaxHelp');
    
    if (suggestions.length === 0) {
        helpDiv.style.display = 'none';
        return;
    }
    
    helpDiv.innerHTML = suggestions.slice(0, 6).map(suggestion => 
        `<div class="syntax-suggestion" onclick="insertSuggestion('${suggestion.name}')">
            <span class="func-name">${suggestion.name}</span>
            <span class="func-desc">${suggestion.desc}</span>
        </div>`
    ).join('');
    
    helpDiv.style.display = 'block';
}

function insertSuggestion(suggestion) {
    document.getElementById('functionInput').value = suggestion;
    document.getElementById('syntaxHelp').style.display = 'none';
    validateAndUpdateInput();
}

function validateAndUpdateInput() {
    const input = document.getElementById('functionInput');
    const value = input.value;
    
    if (!value.trim()) {
        input.className = '';
        return;
    }
    
    const validation = validateFunction(value);
    
    if (validation.valid) {
        input.className = 'valid';
        document.getElementById('statusText').textContent = 'Function is valid';
    } else {
        input.className = 'error';
        document.getElementById('statusText').textContent = 'Error: ' + validation.error;
    }
}

// Function input validation and autocomplete
document.getElementById('functionInput').addEventListener('input', (e) => {
    const value = e.target.value.toLowerCase();
    const lastWord = value.split(/[\s\+\-\*\/\(\)\^]/).pop();
    
    if (lastWord.length >= 1) {
        const matches = functionSuggestions.filter(suggestion => 
            suggestion.name.toLowerCase().includes(lastWord)
        );
        showSyntaxHelp(e.target, matches);
    } else {
        document.getElementById('syntaxHelp').style.display = 'none';
    }
    
    // Debounced validation
    clearTimeout(window.validationTimeout);
    window.validationTimeout = setTimeout(validateAndUpdateInput, 300);
});

document.getElementById('functionInput').addEventListener('keyup', (e) => {
    if (e.key === 'Enter') {
        document.getElementById('syntaxHelp').style.display = 'none';
        plotFunction();
    } else if (e.key === 'Escape') {
        document.getElementById('syntaxHelp').style.display = 'none';
    }
});

document.getElementById('functionInput').addEventListener('blur', () => {
    setTimeout(() => {
        document.getElementById('syntaxHelp').style.display = 'none';
    }, 150);
});

// Prevent zoom inputs from affecting calculator keyboard shortcuts
['xMinInput', 'xMaxInput', 'yMinInput', 'yMaxInput'].forEach(id => {
    document.getElementById(id).addEventListener('keydown', (e) => {
        e.stopPropagation();
    });
});
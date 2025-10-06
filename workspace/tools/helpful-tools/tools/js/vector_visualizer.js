let canvas, ctx;
let dimension = 2;
let currentOperation = null;
let vectorA = {x: 3, y: 2, z: 1};
let vectorB = {x: 1, y: 4, z: 2};
let scale = 30;
let centerX, centerY;

function initializeVisualizer() {
    canvas = document.getElementById('canvas');
    ctx = canvas.getContext('2d');
    centerX = canvas.width / 2;
    centerY = canvas.height / 2;
    
    updateVectors();
    drawVectors();
}

function setDimension(dim) {
    dimension = dim;
    document.getElementById('dim2d').classList.toggle('active', dim === 2);
    document.getElementById('dim3d').classList.toggle('active', dim === 3);
    
    document.getElementById('azContainer').style.display = dim === 3 ? 'block' : 'none';
    document.getElementById('bzContainer').style.display = dim === 3 ? 'block' : 'none';
    
    updateVectors();
    drawVectors();
}

function updateVectors() {
    vectorA.x = parseFloat(document.getElementById('ax').value) || 0;
    vectorA.y = parseFloat(document.getElementById('ay').value) || 0;
    vectorA.z = parseFloat(document.getElementById('az').value) || 0;
    
    vectorB.x = parseFloat(document.getElementById('bx').value) || 0;
    vectorB.y = parseFloat(document.getElementById('by').value) || 0;
    vectorB.z = parseFloat(document.getElementById('bz').value) || 0;
    
    drawVectors();
    
    if (currentOperation) {
        performOperation(currentOperation);
    }
}

function drawVectors() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    
    // Draw grid
    drawGrid();
    
    // Draw axes
    drawAxes();
    
    // Draw vectors
    drawVector(vectorA, '#ff4444', 'A');
    drawVector(vectorB, '#4444ff', 'B');
    
    // Draw result if operation is active
    if (currentOperation) {
        drawOperationResult();
    }
}

function drawGrid() {
    ctx.strokeStyle = '#e0e0e0';
    ctx.lineWidth = 0.5;
    
    for (let x = 0; x <= canvas.width; x += 20) {
        ctx.beginPath();
        ctx.moveTo(x, 0);
        ctx.lineTo(x, canvas.height);
        ctx.stroke();
    }
    
    for (let y = 0; y <= canvas.height; y += 20) {
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(canvas.width, y);
        ctx.stroke();
    }
}

function drawAxes() {
    ctx.strokeStyle = '#666';
    ctx.lineWidth = 1;
    
    // X-axis
    ctx.beginPath();
    ctx.moveTo(0, centerY);
    ctx.lineTo(canvas.width, centerY);
    ctx.stroke();
    
    // Y-axis
    ctx.beginPath();
    ctx.moveTo(centerX, 0);
    ctx.lineTo(centerX, canvas.height);
    ctx.stroke();
    
    // Labels
    ctx.fillStyle = '#666';
    ctx.font = '12px Arial';
    ctx.fillText('X', canvas.width - 15, centerY - 5);
    ctx.fillText('Y', centerX + 5, 15);
}

function drawVector(vector, color, label) {
    const endX = centerX + vector.x * scale;
    const endY = centerY - vector.y * scale; // Flip Y for screen coordinates
    
    // Vector line
    ctx.strokeStyle = color;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(centerX, centerY);
    ctx.lineTo(endX, endY);
    ctx.stroke();
    
    // Arrowhead
    drawArrowhead(centerX, centerY, endX, endY, color);
    
    // Label
    ctx.fillStyle = color;
    ctx.font = 'bold 14px Arial';
    ctx.fillText(label, endX + 5, endY - 5);
    
    // Coordinates
    ctx.font = '10px Arial';
    const coordText = dimension === 2 ? 
        `(${vector.x}, ${vector.y})` : 
        `(${vector.x}, ${vector.y}, ${vector.z})`;
    ctx.fillText(coordText, endX + 5, endY + 10);
}

function drawArrowhead(startX, startY, endX, endY, color) {
    const angle = Math.atan2(endY - startY, endX - startX);
    const arrowLength = 10;
    const arrowAngle = Math.PI / 6;
    
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.moveTo(endX, endY);
    ctx.lineTo(
        endX - arrowLength * Math.cos(angle - arrowAngle),
        endY - arrowLength * Math.sin(angle - arrowAngle)
    );
    ctx.lineTo(
        endX - arrowLength * Math.cos(angle + arrowAngle),
        endY - arrowLength * Math.sin(angle + arrowAngle)
    );
    ctx.closePath();
    ctx.fill();
}

function drawOperationResult() {
    switch (currentOperation) {
        case 'add':
            const sum = {
                x: vectorA.x + vectorB.x,
                y: vectorA.y + vectorB.y,
                z: vectorA.z + vectorB.z
            };
            drawVector(sum, '#44ff44', 'A+B');
            break;
            
        case 'subtract':
            const diff = {
                x: vectorA.x - vectorB.x,
                y: vectorA.y - vectorB.y,
                z: vectorA.z - vectorB.z
            };
            drawVector(diff, '#44ff44', 'A-B');
            break;
            
        case 'projection':
            const proj = projectAOntoB(vectorA, vectorB);
            drawVector(proj, '#ff44ff', 'proj');
            break;
    }
}

function performOperation(operation) {
    currentOperation = operation;
    
    // Remove active class from all buttons
    document.querySelectorAll('.operation-btn').forEach(btn => btn.classList.remove('active'));
    // Add active class to clicked button
    event.target.classList.add('active');
    
    let results = '';
    
    switch (operation) {
        case 'add':
            results = calculateAddition();
            break;
        case 'subtract':
            results = calculateSubtraction();
            break;
        case 'dot':
            results = calculateDotProduct();
            break;
        case 'cross':
            results = calculateCrossProduct();
            break;
        case 'magnitude':
            results = calculateMagnitudes();
            break;
        case 'angle':
            results = calculateAngle();
            break;
        case 'projection':
            results = calculateProjection();
            break;
        case 'normalize':
            results = calculateNormalization();
            break;
    }
    
    document.getElementById('results').innerHTML = results;
    drawVectors();
}

function calculateAddition() {
    const sum = {
        x: vectorA.x + vectorB.x,
        y: vectorA.y + vectorB.y,
        z: vectorA.z + vectorB.z
    };
    
    return `<h4>Vector Addition: A + B</h4>
A = (${vectorA.x}, ${vectorA.y}${dimension === 3 ? ', ' + vectorA.z : ''})
B = (${vectorB.x}, ${vectorB.y}${dimension === 3 ? ', ' + vectorB.z : ''})

A + B = (${vectorA.x} + ${vectorB.x}, ${vectorA.y} + ${vectorB.y}${dimension === 3 ? ', ' + vectorA.z + ' + ' + vectorB.z : ''})
A + B = (${sum.x}, ${sum.y}${dimension === 3 ? ', ' + sum.z : ''})

Geometric Interpretation:
Place B's tail at A's head to get the resultant vector.`;
}

function calculateSubtraction() {
    const diff = {
        x: vectorA.x - vectorB.x,
        y: vectorA.y - vectorB.y,
        z: vectorA.z - vectorB.z
    };
    
    return `<h4>Vector Subtraction: A - B</h4>
A = (${vectorA.x}, ${vectorA.y}${dimension === 3 ? ', ' + vectorA.z : ''})
B = (${vectorB.x}, ${vectorB.y}${dimension === 3 ? ', ' + vectorB.z : ''})

A - B = (${vectorA.x} - ${vectorB.x}, ${vectorA.y} - ${vectorB.y}${dimension === 3 ? ', ' + vectorA.z + ' - ' + vectorB.z : ''})
A - B = (${diff.x}, ${diff.y}${dimension === 3 ? ', ' + diff.z : ''})

Geometric Interpretation:
Vector from B's head to A's head.`;
}

function calculateDotProduct() {
    const dot = vectorA.x * vectorB.x + vectorA.y * vectorB.y + (dimension === 3 ? vectorA.z * vectorB.z : 0);
    const magA = Math.sqrt(vectorA.x**2 + vectorA.y**2 + (dimension === 3 ? vectorA.z**2 : 0));
    const magB = Math.sqrt(vectorB.x**2 + vectorB.y**2 + (dimension === 3 ? vectorB.z**2 : 0));
    
    return `<h4>Dot Product: A · B</h4>
A = (${vectorA.x}, ${vectorA.y}${dimension === 3 ? ', ' + vectorA.z : ''})
B = (${vectorB.x}, ${vectorB.y}${dimension === 3 ? ', ' + vectorB.z : ''})

A · B = ${vectorA.x}×${vectorB.x} + ${vectorA.y}×${vectorB.y}${dimension === 3 ? ' + ' + vectorA.z + '×' + vectorB.z : ''}
A · B = ${dot.toFixed(3)}

|A| = ${magA.toFixed(3)}
|B| = ${magB.toFixed(3)}

Geometric Interpretation:
• Dot product measures how much vectors point in same direction
• If A · B > 0: vectors point in similar directions
• If A · B = 0: vectors are perpendicular
• If A · B < 0: vectors point in opposite directions`;
}

function calculateCrossProduct() {
    if (dimension === 2) {
        const cross = vectorA.x * vectorB.y - vectorA.y * vectorB.x;
        return `<h4>Cross Product (2D): A × B</h4>
A = (${vectorA.x}, ${vectorA.y})
B = (${vectorB.x}, ${vectorB.y})

A × B = ${vectorA.x}×${vectorB.y} - ${vectorA.y}×${vectorB.x}
A × B = ${cross.toFixed(3)} (scalar in 2D)

Geometric Interpretation:
• Magnitude equals area of parallelogram formed by A and B
• Sign indicates orientation (+ = counterclockwise, - = clockwise)`;
    } else {
        const cross = {
            x: vectorA.y * vectorB.z - vectorA.z * vectorB.y,
            y: vectorA.z * vectorB.x - vectorA.x * vectorB.z,
            z: vectorA.x * vectorB.y - vectorA.y * vectorB.x
        };
        const mag = Math.sqrt(cross.x**2 + cross.y**2 + cross.z**2);
        
        return `<h4>Cross Product (3D): A × B</h4>
A = (${vectorA.x}, ${vectorA.y}, ${vectorA.z})
B = (${vectorB.x}, ${vectorB.y}, ${vectorB.z})

A × B = (${vectorA.y}×${vectorB.z} - ${vectorA.z}×${vectorB.y}, 
         ${vectorA.z}×${vectorB.x} - ${vectorA.x}×${vectorB.z}, 
         ${vectorA.x}×${vectorB.y} - ${vectorA.y}×${vectorB.x})
         
A × B = (${cross.x.toFixed(3)}, ${cross.y.toFixed(3)}, ${cross.z.toFixed(3)})
|A × B| = ${mag.toFixed(3)}

Geometric Interpretation:
• Result is perpendicular to both A and B
• Magnitude equals area of parallelogram formed by A and B
• Direction follows right-hand rule`;
    }
}

function calculateMagnitudes() {
    const magA = Math.sqrt(vectorA.x**2 + vectorA.y**2 + (dimension === 3 ? vectorA.z**2 : 0));
    const magB = Math.sqrt(vectorB.x**2 + vectorB.y**2 + (dimension === 3 ? vectorB.z**2 : 0));
    
    return `<h4>Vector Magnitudes</h4>
A = (${vectorA.x}, ${vectorA.y}${dimension === 3 ? ', ' + vectorA.z : ''})
B = (${vectorB.x}, ${vectorB.y}${dimension === 3 ? ', ' + vectorB.z : ''})

|A| = √(${vectorA.x}² + ${vectorA.y}²${dimension === 3 ? ' + ' + vectorA.z + '²' : ''})
|A| = √(${vectorA.x**2} + ${vectorA.y**2}${dimension === 3 ? ' + ' + vectorA.z**2 : ''})
|A| = ${magA.toFixed(3)}

|B| = √(${vectorB.x}² + ${vectorB.y}²${dimension === 3 ? ' + ' + vectorB.z + '²' : ''})
|B| = √(${vectorB.x**2} + ${vectorB.y**2}${dimension === 3 ? ' + ' + vectorB.z**2 : ''})
|B| = ${magB.toFixed(3)}

Geometric Interpretation:
Magnitude represents the length of the vector in space.`;
}

function calculateAngle() {
    const dot = vectorA.x * vectorB.x + vectorA.y * vectorB.y + (dimension === 3 ? vectorA.z * vectorB.z : 0);
    const magA = Math.sqrt(vectorA.x**2 + vectorA.y**2 + (dimension === 3 ? vectorA.z**2 : 0));
    const magB = Math.sqrt(vectorB.x**2 + vectorB.y**2 + (dimension === 3 ? vectorB.z**2 : 0));
    const cosTheta = dot / (magA * magB);
    const theta = Math.acos(Math.max(-1, Math.min(1, cosTheta)));
    const degrees = theta * 180 / Math.PI;
    
    return `<h4>Angle Between Vectors</h4>
A = (${vectorA.x}, ${vectorA.y}${dimension === 3 ? ', ' + vectorA.z : ''})
B = (${vectorB.x}, ${vectorB.y}${dimension === 3 ? ', ' + vectorB.z : ''})

cos(θ) = (A · B) / (|A| × |B|)
cos(θ) = ${dot.toFixed(3)} / (${magA.toFixed(3)} × ${magB.toFixed(3)})
cos(θ) = ${cosTheta.toFixed(3)}

θ = arccos(${cosTheta.toFixed(3)})
θ = ${theta.toFixed(3)} radians
θ = ${degrees.toFixed(1)}°

Geometric Interpretation:
• 0°: vectors point in same direction
• 90°: vectors are perpendicular
• 180°: vectors point in opposite directions`;
}

function calculateProjection() {
    const proj = projectAOntoB(vectorA, vectorB);
    const magB = Math.sqrt(vectorB.x**2 + vectorB.y**2 + (dimension === 3 ? vectorB.z**2 : 0));
    const dot = vectorA.x * vectorB.x + vectorA.y * vectorB.y + (dimension === 3 ? vectorA.z * vectorB.z : 0);
    const scalar = dot / (magB * magB);
    
    return `<h4>Projection of A onto B</h4>
A = (${vectorA.x}, ${vectorA.y}${dimension === 3 ? ', ' + vectorA.z : ''})
B = (${vectorB.x}, ${vectorB.y}${dimension === 3 ? ', ' + vectorB.z : ''})

proj_B(A) = ((A · B) / |B|²) × B
proj_B(A) = (${dot.toFixed(3)} / ${(magB*magB).toFixed(3)}) × B
proj_B(A) = ${scalar.toFixed(3)} × B
proj_B(A) = (${proj.x.toFixed(3)}, ${proj.y.toFixed(3)}${dimension === 3 ? ', ' + proj.z.toFixed(3) : ''})

Geometric Interpretation:
The projection is the "shadow" of vector A cast onto vector B.
It represents the component of A in the direction of B.`;
}

function calculateNormalization() {
    const magA = Math.sqrt(vectorA.x**2 + vectorA.y**2 + (dimension === 3 ? vectorA.z**2 : 0));
    const magB = Math.sqrt(vectorB.x**2 + vectorB.y**2 + (dimension === 3 ? vectorB.z**2 : 0));
    
    const normA = {
        x: vectorA.x / magA,
        y: vectorA.y / magA,
        z: vectorA.z / magA
    };
    
    const normB = {
        x: vectorB.x / magB,
        y: vectorB.y / magB,
        z: vectorB.z / magB
    };
    
    return `<h4>Vector Normalization</h4>
A = (${vectorA.x}, ${vectorA.y}${dimension === 3 ? ', ' + vectorA.z : ''})
B = (${vectorB.x}, ${vectorB.y}${dimension === 3 ? ', ' + vectorB.z : ''})

Normalized A = A / |A|
|A| = ${magA.toFixed(3)}
Normalized A = (${normA.x.toFixed(3)}, ${normA.y.toFixed(3)}${dimension === 3 ? ', ' + normA.z.toFixed(3) : ''})

Normalized B = B / |B|
|B| = ${magB.toFixed(3)}
Normalized B = (${normB.x.toFixed(3)}, ${normB.y.toFixed(3)}${dimension === 3 ? ', ' + normB.z.toFixed(3) : ''})

Geometric Interpretation:
Normalized vectors have magnitude 1 and point in the same direction.
They represent pure direction without magnitude information.`;
}

function projectAOntoB(a, b) {
    const dot = a.x * b.x + a.y * b.y + (dimension === 3 ? a.z * b.z : 0);
    const magBSquared = b.x**2 + b.y**2 + (dimension === 3 ? b.z**2 : 0);
    const scalar = dot / magBSquared;
    
    return {
        x: scalar * b.x,
        y: scalar * b.y,
        z: scalar * b.z
    };
}

function loadExample(type) {
    switch (type) {
        case 'perpendicular':
            setVectorValues(3, 0, 0, 0, 3, 0);
            break;
        case 'parallel':
            setVectorValues(2, 1, 0, 4, 2, 0);
            break;
        case '3d':
            setDimension(3);
            setVectorValues(1, 2, 3, 2, -1, 1);
            break;
    }
}

function randomizeVectors() {
    const range = 5;
    setVectorValues(
        Math.floor(Math.random() * range * 2) - range,
        Math.floor(Math.random() * range * 2) - range,
        Math.floor(Math.random() * range * 2) - range,
        Math.floor(Math.random() * range * 2) - range,
        Math.floor(Math.random() * range * 2) - range,
        Math.floor(Math.random() * range * 2) - range
    );
}

function setVectorValues(ax, ay, az, bx, by, bz) {
    document.getElementById('ax').value = ax;
    document.getElementById('ay').value = ay;
    document.getElementById('az').value = az;
    document.getElementById('bx').value = bx;
    document.getElementById('by').value = by;
    document.getElementById('bz').value = bz;
    updateVectors();
}

// Initialize on page load
window.addEventListener('load', initializeVisualizer);
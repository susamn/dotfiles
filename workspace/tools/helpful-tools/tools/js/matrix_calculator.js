    let matrices = {
        A: [],
        B: [],
        result: []
    };

    let currentOperation = null;
    let animationStep = 0;

    function initializeMatrices() {
        // Set default sizes
        document.getElementById('matrixARows').value = '4';
        document.getElementById('matrixACols').value = '8';
        document.getElementById('matrixBRows').value = '4';
        document.getElementById('matrixBCols').value = '8';
        
        updateMatrixSize('A');
        updateMatrixSize('B');

        // Set some initial values for 4x8 matrices
        setMatrixValues('A', [
            [1, 2, 3, 4, 5, 6, 7, 8],
            [9, 10, 11, 12, 13, 14, 15, 16],
            [17, 18, 19, 20, 21, 22, 23, 24],
            [25, 26, 27, 28, 29, 30, 31, 32]
        ]);

        setMatrixValues('B', [
            [1, 0, 0, 0, 0, 0, 0, 0],
            [0, 1, 0, 0, 0, 0, 0, 0],
            [0, 0, 1, 0, 0, 0, 0, 0],
            [0, 0, 0, 1, 0, 0, 0, 0]
        ]);
        
        // Debug: Log matrix states
        console.log('Matrix A initialized:', matrices.A);
        console.log('Matrix B initialized:', matrices.B);
    }

    function updateMatrixSize(matrix) {
        const rows = parseInt(document.getElementById(`matrix${matrix}Rows`).value);
        const cols = parseInt(document.getElementById(`matrix${matrix}Cols`).value);

        matrices[matrix] = Array(rows).fill().map(() => Array(cols).fill(0));
        renderMatrix(matrix, rows, cols);
    }

    function renderMatrix(matrix, rows, cols) {
        const container = document.getElementById(`matrix${matrix}`);
        container.style.gridTemplateColumns = `repeat(${cols}, 1fr)`;
        container.innerHTML = '';

        for (let i = 0; i < rows; i++) {
            for (let j = 0; j < cols; j++) {
                const cell = document.createElement('input');
                cell.type = 'number';
                cell.className = 'matrix-cell';
                cell.value = matrices[matrix][i] && matrices[matrix][i][j] !== undefined ? matrices[matrix][i][j] : 0;
                cell.dataset.row = i;
                cell.dataset.col = j;
                cell.dataset.matrix = matrix;
                
                // Only add event listener for input matrices, not result
                if (matrix !== 'result') {
                    cell.addEventListener('input', updateMatrixValue);
                } else {
                    cell.readOnly = true;
                    cell.style.backgroundColor = '#f8f8f8';
                }
                container.appendChild(cell);
            }
        }
    }

    function updateMatrixValue(event) {
        const matrix = event.target.dataset.matrix;
        const row = parseInt(event.target.dataset.row);
        const col = parseInt(event.target.dataset.col);
        const value = parseFloat(event.target.value) || 0;

        // Ensure the matrix structure exists
        if (!matrices[matrix]) matrices[matrix] = [];
        if (!matrices[matrix][row]) matrices[matrix][row] = [];
        
        matrices[matrix][row][col] = value;
    }

    function setMatrixValues(matrix, values) {
        const rows = values.length;
        const cols = values[0].length;

        document.getElementById(`matrix${matrix}Rows`).value = rows;
        document.getElementById(`matrix${matrix}Cols`).value = cols;

        matrices[matrix] = values.map(row => [...row]);
        renderMatrix(matrix, rows, cols);
    }

    function randomizeMatrix(matrix) {
        const rows = matrices[matrix] ? matrices[matrix].length : parseInt(document.getElementById(`matrix${matrix}Rows`).value);
        const cols = matrices[matrix] && matrices[matrix][0] ? matrices[matrix][0].length : parseInt(document.getElementById(`matrix${matrix}Cols`).value);

        // Ensure matrix structure exists
        if (!matrices[matrix]) matrices[matrix] = [];
        
        for (let i = 0; i < rows; i++) {
            if (!matrices[matrix][i]) matrices[matrix][i] = [];
            for (let j = 0; j < cols; j++) {
                matrices[matrix][i][j] = Math.floor(Math.random() * 10) - 5; // -5 to 4
            }
        }

        renderMatrix(matrix, rows, cols);
        document.getElementById('statusText').textContent = `Matrix ${matrix} randomized`;
    }

    function randomizeAll() {
        randomizeMatrix('A');
        randomizeMatrix('B');
    }

    function clearAll() {
        matrices.A.forEach((row, i) => {
            row.forEach((_, j) => {
                matrices.A[i][j] = 0;
            });
        });

        matrices.B.forEach((row, i) => {
            row.forEach((_, j) => {
                matrices.B[i][j] = 0;
            });
        });

        renderMatrix('A', matrices.A.length, matrices.A[0].length);
        renderMatrix('B', matrices.B.length, matrices.B[0].length);

        document.getElementById('matrixResult').innerHTML = '';
        document.getElementById('stepByStep').textContent = 'Matrices cleared';
        document.getElementById('statusText').textContent = 'All matrices cleared';
    }

    function resetMatrices() {
        initializeMatrices();
        document.getElementById('stepByStep').textContent = 'Matrices reset to default values';
        document.getElementById('statusText').textContent = 'Matrices reset';
    }

    function showExample(type) {
        if (type === 'identity') {
            setMatrixValues('A', [
                [2, 1, 3],
                [1, 4, 2],
                [3, 2, 1]
            ]);
            setMatrixValues('B', [
                [1, 0, 0],
                [0, 1, 0],
                [0, 0, 1]
            ]);
            document.getElementById('stepByStep').innerHTML = 'Identity matrix example loaded.<br>Try A × B to see how multiplying by identity matrix works.';
        } else if (type === 'multiplication') {
            setMatrixValues('A', [
                [1, 2],
                [3, 4]
            ]);
            setMatrixValues('B', [
                [5, 6],
                [7, 8]
            ]);
            document.getElementById('stepByStep').innerHTML = 'Multiplication example loaded.<br>Try A × B to see detailed matrix multiplication steps.';
        } else if (type === '4x8demo') {
            setMatrixValues('A', [
                [1, 2, 3, 4, 5, 6, 7, 8],
                [2, 4, 6, 8, 10, 12, 14, 16],
                [3, 6, 9, 12, 15, 18, 21, 24],
                [4, 8, 12, 16, 20, 24, 28, 32]
            ]);
            setMatrixValues('B', [
                [8, 7, 6, 5, 4, 3, 2, 1],
                [16, 14, 12, 10, 8, 6, 4, 2],
                [24, 21, 18, 15, 12, 9, 6, 3],
                [32, 28, 24, 20, 16, 12, 8, 4]
            ]);
            document.getElementById('stepByStep').innerHTML = '4×8 matrix demo loaded with pattern-based values.<br>• Matrix A: Multiples in sequence<br>• Matrix B: Reverse multiples<br>Try different operations to explore matrix concepts!';
        }
    }

    function performOperation(operation) {
        currentOperation = operation;
        clearHighlights();

        // Remove active class from all buttons
        document.querySelectorAll('.operation-btn').forEach(btn => btn.classList.remove('active'));
        
        // Find and activate the clicked button
        const buttons = document.querySelectorAll('.operation-btn');
        for (let btn of buttons) {
            if (btn.onclick && btn.onclick.toString().includes(`'${operation}'`)) {
                btn.classList.add('active');
                break;
            }
        }

        console.log('Performing operation:', operation);
        console.log('Matrix A:', matrices.A);
        console.log('Matrix B:', matrices.B);

        switch (operation) {
            case 'add':
                matrixAddition();
                break;
            case 'subtract':
                matrixSubtraction();
                break;
            case 'multiply':
                matrixMultiplication();
                break;
            case 'transpose':
                matrixTranspose();
                break;
            case 'determinant':
                matrixDeterminant();
                break;
            case 'dotProduct':
                vectorDotProduct();
                break;
            case 'crossProduct':
                vectorCrossProduct();
                break;
        }
    }

    function matrixAddition() {
        console.log('Starting matrix addition');
        const A = matrices.A;
        const B = matrices.B;

        // Check if matrices exist and have data
        if (!A || !B || A.length === 0 || B.length === 0) {
            document.getElementById('stepByStep').innerHTML = '<span style="color: red;">Error: Matrices not properly initialized!</span>';
            return;
        }

        console.log('Matrix A dimensions:', A.length, 'x', A[0] ? A[0].length : 0);
        console.log('Matrix B dimensions:', B.length, 'x', B[0] ? B[0].length : 0);

        if (A.length !== B.length || A[0].length !== B[0].length) {
            document.getElementById('stepByStep').innerHTML = '<span style="color: red;">Error: Matrices must have the same dimensions for addition!</span>';
            return;
        }

        const result = [];
        let steps = ['<div class="formula">Matrix Addition: C = A + B</div>'];
        steps.push('For matrices to be added, they must have the same dimensions.');
        steps.push('Each element C[i][j] = A[i][j] + B[i][j]');
        steps.push('');

        for (let i = 0; i < A.length; i++) {
            result[i] = [];
            for (let j = 0; j < A[0].length; j++) {
                const aVal = A[i][j] || 0;
                const bVal = B[i][j] || 0;
                const sum = aVal + bVal;
                result[i][j] = sum;
                steps.push(`C[${i}][${j}] = A[${i}][${j}] + B[${i}][${j}] = ${aVal} + ${bVal} = <span class="result-value">${sum}</span>`);
            }
        }

        matrices.result = result;
        renderMatrix('result', result.length, result[0].length);
        document.getElementById('stepByStep').innerHTML = steps.join('<br>');
        document.getElementById('statusText').textContent = 'Matrix addition completed';
        console.log('Matrix addition result:', result);
    }

    function matrixSubtraction() {
        console.log('Starting matrix subtraction');
        const A = matrices.A;
        const B = matrices.B;

        // Check if matrices exist and have data
        if (!A || !B || A.length === 0 || B.length === 0) {
            document.getElementById('stepByStep').innerHTML = '<span style="color: red;">Error: Matrices not properly initialized!</span>';
            return;
        }

        if (A.length !== B.length || A[0].length !== B[0].length) {
            document.getElementById('stepByStep').innerHTML = '<span style="color: red;">Error: Matrices must have the same dimensions for subtraction!</span>';
            return;
        }

        const result = [];
        let steps = ['<div class="formula">Matrix Subtraction: C = A - B</div>'];
        steps.push('Each element C[i][j] = A[i][j] - B[i][j]');
        steps.push('');

        for (let i = 0; i < A.length; i++) {
            result[i] = [];
            for (let j = 0; j < A[0].length; j++) {
                const aVal = A[i][j] || 0;
                const bVal = B[i][j] || 0;
                const diff = aVal - bVal;
                result[i][j] = diff;
                steps.push(`C[${i}][${j}] = A[${i}][${j}] - B[${i}][${j}] = ${aVal} - ${bVal} = <span class="result-value">${diff}</span>`);
            }
        }

        matrices.result = result;
        renderMatrix('result', result.length, result[0].length);
        document.getElementById('stepByStep').innerHTML = steps.join('<br>');
        document.getElementById('statusText').textContent = 'Matrix subtraction completed';
        console.log('Matrix subtraction result:', result);
    }

    function matrixMultiplication() {
        const A = matrices.A;
        const B = matrices.B;

        if (A[0].length !== B.length) {
            document.getElementById('stepByStep').innerHTML = '<span style="color: red;">Error: Number of columns in A must equal number of rows in B!</span>';
            return;
        }

        const result = [];
        let steps = ['<div class="formula">Matrix Multiplication: C = A × B</div>'];
        steps.push(`Dimensions: A(${A.length}×${A[0].length}) × B(${B.length}×${B[0].length}) = C(${A.length}×${B[0].length})`);
        steps.push('Rule: C[i][j] = Σ(A[i][k] × B[k][j]) for all k');
        steps.push('');

        for (let i = 0; i < A.length; i++) {
            result[i] = [];
            for (let j = 0; j < B[0].length; j++) {
                let sum = 0;
                let calculation = [];

                for (let k = 0; k < A[0].length; k++) {
                    const product = A[i][k] * B[k][j];
                    sum += product;
                    calculation.push(`${A[i][k]}×${B[k][j]}`);
                }

                result[i][j] = sum;
                steps.push(`C[${i}][${j}] = ${calculation.join(' + ')} = <span class="result-value">${sum}</span>`);
            }
            steps.push('');
        }

        matrices.result = result;
        renderMatrix('result', result.length, result[0].length);
        document.getElementById('stepByStep').innerHTML = steps.join('<br>');
        document.getElementById('statusText').textContent = 'Matrix multiplication completed';
    }

    function matrixTranspose() {
        const A = matrices.A;
        const result = [];

        let steps = ['<div class="formula">Matrix Transpose: A^T</div>'];
        steps.push('Transpose swaps rows and columns: A^T[i][j] = A[j][i]');
        steps.push('');

        for (let i = 0; i < A[0].length; i++) {
            result[i] = [];
            for (let j = 0; j < A.length; j++) {
                result[i][j] = A[j][i];
                steps.push(`A^T[${i}][${j}] = A[${j}][${i}] = <span class="result-value">${A[j][i]}</span>`);
            }
        }

        matrices.result = result;
        renderMatrix('result', result.length, result[0].length);
        document.getElementById('stepByStep').innerHTML = steps.join('<br>');
        document.getElementById('statusText').textContent = 'Matrix transpose completed';
    }

    function matrixDeterminant() {
        const A = matrices.A;

        if (A.length !== A[0].length) {
            document.getElementById('stepByStep').innerHTML = '<span style="color: red;">Error: Determinant is only defined for square matrices!</span>';
            return;
        }

        if (A.length === 2) {
            const det = A[0][0] * A[1][1] - A[0][1] * A[1][0];
            let steps = ['<div class="formula">2×2 Determinant</div>'];
            steps.push('For 2×2 matrix: det(A) = a₁₁×a₂₂ - a₁₂×a₂₁');
            steps.push(`det(A) = ${A[0][0]}×${A[1][1]} - ${A[0][1]}×${A[1][0]}`);
            steps.push(`det(A) = ${A[0][0] * A[1][1]} - ${A[0][1] * A[1][0]} = <span class="result-value">${det}</span>`);

            document.getElementById('stepByStep').innerHTML = steps.join('<br>');
            document.getElementById('matrixResult').innerHTML = `<div style="text-align: center; padding: 20px; font-size: 16px; font-weight: bold; color: #388e3c;">Determinant = ${det}</div>`;
        } else {
            document.getElementById('stepByStep').innerHTML = 'Determinant calculation for matrices larger than 2×2 is complex and requires cofactor expansion.';
            document.getElementById('matrixResult').innerHTML = `<div style="text-align: center; padding: 20px; font-size: 12px; color: #666;">Higher-order determinants require advanced calculation</div>`;
        }

        document.getElementById('statusText').textContent = 'Determinant calculation completed';
    }

    function vectorDotProduct() {
        const A = matrices.A;
        const B = matrices.B;

        // Use first row/column as vectors
        const vecA = A[0];
        const vecB = B[0];

        if (vecA.length !== vecB.length) {
            document.getElementById('stepByStep').innerHTML = '<span style="color: red;">Error: Vectors must have the same length for dot product!</span>';
            return;
        }

        let steps = ['<div class="formula">Dot Product: a · b</div>'];
        steps.push('Dot product is the sum of products of corresponding elements');
        steps.push(`Using first rows: a = [${vecA.join(', ')}], b = [${vecB.join(', ')}]`);
        steps.push('');

        let dotProduct = 0;
        let calculation = [];

        for (let i = 0; i < vecA.length; i++) {
            const product = vecA[i] * vecB[i];
            dotProduct += product;
            calculation.push(`${vecA[i]}×${vecB[i]}`);
            steps.push(`Component ${i + 1}: ${vecA[i]} × ${vecB[i]} = ${product}`);
        }

        steps.push('');
        steps.push(`a · b = ${calculation.join(' + ')} = <span class="result-value">${dotProduct}</span>`);
        steps.push('');
        steps.push('<div style="background: #f0f8ff; padding: 10px; border-radius: 3px; margin: 10px 0;">');
        steps.push('<strong>Geometric Interpretation:</strong><br>');
        steps.push('• If dot product > 0: vectors point in similar directions<br>');
        steps.push('• If dot product = 0: vectors are perpendicular<br>');
        steps.push('• If dot product < 0: vectors point in opposite directions');
        steps.push('</div>');

        document.getElementById('stepByStep').innerHTML = steps.join('<br>');
        document.getElementById('matrixResult').innerHTML = `<div style="text-align: center; padding: 20px; font-size: 16px; font-weight: bold; color: #388e3c;">Dot Product = ${dotProduct}</div>`;
        document.getElementById('statusText').textContent = 'Dot product calculation completed';
    }

    function vectorCrossProduct() {
        const A = matrices.A;
        const B = matrices.B;

        // Use first 3 elements of first row as 3D vectors
        const vecA = A[0].slice(0, 3);
        const vecB = B[0].slice(0, 3);

        if (vecA.length < 3 || vecB.length < 3) {
            document.getElementById('stepByStep').innerHTML = '<span style="color: red;">Error: Cross product requires 3D vectors (at least 3 columns)!</span>';
            return;
        }

        let steps = ['<div class="formula">Cross Product: a × b (3D vectors only)</div>'];
        steps.push('Cross product produces a vector perpendicular to both input vectors');
        steps.push(`Using first 3 elements: a = [${vecA.join(', ')}], b = [${vecB.join(', ')}]`);
        steps.push('');
        steps.push('Formula: a × b = [a₂b₃ - a₃b₂, a₃b₁ - a₁b₃, a₁b₂ - a₂b₁]');
        steps.push('');

        const crossProduct = [
            vecA[1] * vecB[2] - vecA[2] * vecB[1],
            vecA[2] * vecB[0] - vecA[0] * vecB[2],
            vecA[0] * vecB[1] - vecA[1] * vecB[0]
        ];

        steps.push(`x-component: a₂b₃ - a₃b₂ = ${vecA[1]}×${vecB[2]} - ${vecA[2]}×${vecB[1]} = ${vecA[1] * vecB[2]} - ${vecA[2] * vecB[1]} = <span class="result-value">${crossProduct[0]}</span>`);
        steps.push(`y-component: a₃b₁ - a₁b₃ = ${vecA[2]}×${vecB[0]} - ${vecA[0]}×${vecB[2]} = ${vecA[2] * vecB[0]} - ${vecA[0] * vecB[2]} = <span class="result-value">${crossProduct[1]}</span>`);
        steps.push(`z-component: a₁b₂ - a₂b₁ = ${vecA[0]}×${vecB[1]} - ${vecA[1]}×${vecB[0]} = ${vecA[0] * vecB[1]} - ${vecA[1] * vecB[0]} = <span class="result-value">${crossProduct[2]}</span>`);
        steps.push('');
        steps.push(`a × b = [<span class="result-value">${crossProduct.join(', ')}</span>]`);
        steps.push('');

        const magnitude = Math.sqrt(crossProduct[0]**2 + crossProduct[1]**2 + crossProduct[2]**2);
        steps.push(`Magnitude: ||a × b|| = √(${crossProduct[0]}² + ${crossProduct[1]}² + ${crossProduct[2]}²) = <span class="result-value">${magnitude.toFixed(3)}</span>`);
        steps.push('');
        steps.push('<div style="background: #fff0f5; padding: 10px; border-radius: 3px; margin: 10px 0;">');
        steps.push('<strong>Geometric Properties:</strong><br>');
        steps.push('• Result is perpendicular to both input vectors<br>');
        steps.push('• Magnitude equals area of parallelogram formed by vectors<br>');
        steps.push('• Direction follows right-hand rule<br>');
        steps.push('• If vectors are parallel, cross product = [0, 0, 0]');
        steps.push('</div>');

        document.getElementById('stepByStep').innerHTML = steps.join('<br>');
        document.getElementById('matrixResult').innerHTML = `<div style="text-align: center; padding: 10px;"><div style="font-size: 14px; font-weight: bold; color: #388e3c; margin-bottom: 5px;">Cross Product</div><div style="font-size: 12px;">[${crossProduct.map(x => x.toFixed(2)).join(', ')}]</div><div style="font-size: 11px; color: #666; margin-top: 5px;">Magnitude: ${magnitude.toFixed(3)}</div></div>`;
        document.getElementById('statusText').textContent = 'Cross product calculation completed';
    }

    function clearHighlights() {
        document.querySelectorAll('.matrix-cell').forEach(cell => {
            cell.classList.remove('highlighted', 'result-highlight');
        });
    }

    function highlightCells(matrix, rows, cols) {
        if (!Array.isArray(rows)) rows = [rows];
        if (!Array.isArray(cols)) cols = [cols];

        rows.forEach(row => {
            cols.forEach(col => {
                const cell = document.querySelector(`[data-matrix="${matrix}"][data-row="${row}"][data-col="${col}"]`);
                if (cell) {
                    cell.classList.add('highlighted');
                }
            });
        });
    }

    // Add hover tooltips for operation buttons
    document.addEventListener('DOMContentLoaded', function() {
        const tooltips = {
            'add': 'Element-wise addition: C[i][j] = A[i][j] + B[i][j]',
            'subtract': 'Element-wise subtraction: C[i][j] = A[i][j] - B[i][j]',
            'multiply': 'Matrix multiplication: C[i][j] = Σ(A[i][k] × B[k][j])',
            'transpose': 'Swap rows and columns: A^T[i][j] = A[j][i]',
            'determinant': 'Calculate determinant (square matrices only)',
            'dotProduct': 'Sum of products of corresponding elements',
            'crossProduct': 'Vector perpendicular to both inputs (3D only)'
        };

        document.querySelectorAll('.operation-btn').forEach(btn => {
            const operation = btn.onclick.toString().match(/'([^']+)'/)[1];
            if (tooltips[operation]) {
                btn.title = tooltips[operation];
                btn.addEventListener('mouseenter', function() {
                    document.getElementById('operationInfo').textContent = tooltips[operation];
                });
                btn.addEventListener('mouseleave', function() {
                    document.getElementById('operationInfo').textContent = 'Hover over operations for descriptions';
                });
            }
        });
    });

    // Initialize on page load
    window.addEventListener('load', initializeMatrices);

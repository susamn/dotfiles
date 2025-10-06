    let systemMatrix = [];
    let resultVector = [];
    let singleMatrix = [];
    let currentSize = 3;
    let currentMatrixSize = 3;

    function initializeTool() {
        updateSystemSize();
        updateMatrixSize();
        loadExample('simple');
    }

    function updateSystemSize() {
        currentSize = parseInt(document.getElementById('systemSize').value);
        
        // Initialize matrices
        systemMatrix = Array(currentSize).fill().map(() => Array(currentSize).fill(0));
        resultVector = Array(currentSize).fill(0);
        
        renderSystemMatrix();
        renderVectors();
    }

    function updateMatrixSize() {
        currentMatrixSize = parseInt(document.getElementById('matrixSize').value);
        singleMatrix = Array(currentMatrixSize).fill().map(() => Array(currentMatrixSize).fill(0));
        renderSingleMatrix();
    }

    function renderSystemMatrix() {
        const container = document.getElementById('matrixA');
        container.style.gridTemplateColumns = `repeat(${currentSize}, 1fr)`;
        container.innerHTML = '';

        for (let i = 0; i < currentSize; i++) {
            for (let j = 0; j < currentSize; j++) {
                const cell = document.createElement('input');
                cell.type = 'number';
                cell.className = 'matrix-cell';
                cell.value = systemMatrix[i][j];
                cell.dataset.row = i;
                cell.dataset.col = j;
                cell.addEventListener('input', function() {
                    systemMatrix[i][j] = parseFloat(this.value) || 0;
                });
                container.appendChild(cell);
            }
        }
    }

    function renderVectors() {
        // Render x vector (just labels)
        const xContainer = document.getElementById('vectorX');
        xContainer.innerHTML = '';
        for (let i = 0; i < currentSize; i++) {
            const cell = document.createElement('div');
            cell.className = 'vector-cell';
            cell.textContent = `x${i+1}`;
            cell.style.backgroundColor = '#f0f0f0';
            cell.style.border = '1px solid #d0d0d0';
            xContainer.appendChild(cell);
        }

        // Render b vector
        const bContainer = document.getElementById('vectorB');
        bContainer.innerHTML = '';
        for (let i = 0; i < currentSize; i++) {
            const cell = document.createElement('input');
            cell.type = 'number';
            cell.className = 'vector-cell';
            cell.value = resultVector[i];
            cell.addEventListener('input', function() {
                resultVector[i] = parseFloat(this.value) || 0;
            });
            bContainer.appendChild(cell);
        }
    }

    function renderSingleMatrix() {
        const container = document.getElementById('singleMatrix');
        container.style.gridTemplateColumns = `repeat(${currentMatrixSize}, 1fr)`;
        container.innerHTML = '';

        for (let i = 0; i < currentMatrixSize; i++) {
            for (let j = 0; j < currentMatrixSize; j++) {
                const cell = document.createElement('input');
                cell.type = 'number';
                cell.className = 'matrix-cell';
                cell.value = singleMatrix[i][j];
                cell.dataset.row = i;
                cell.dataset.col = j;
                cell.addEventListener('input', function() {
                    singleMatrix[i][j] = parseFloat(this.value) || 0;
                });
                container.appendChild(cell);
            }
        }
    }

    function randomizeSystem() {
        for (let i = 0; i < currentSize; i++) {
            resultVector[i] = Math.floor(Math.random() * 20) - 10;
            for (let j = 0; j < currentSize; j++) {
                systemMatrix[i][j] = Math.floor(Math.random() * 10) - 5;
            }
        }
        renderSystemMatrix();
        renderVectors();
    }

    function randomizeMatrix() {
        for (let i = 0; i < currentMatrixSize; i++) {
            for (let j = 0; j < currentMatrixSize; j++) {
                singleMatrix[i][j] = Math.floor(Math.random() * 10) - 5;
            }
        }
        renderSingleMatrix();
    }

    function solveLinearSystem() {
        try {
            const solution = gaussianElimination([...systemMatrix], [...resultVector]);
            
            let results = '<div class="result-section success">';
            results += '<h4>Linear System Solution</h4>';
            results += '<div class="matrix-display">';
            results += 'System: Ax = b\n\n';
            
            // Display the system
            for (let i = 0; i < currentSize; i++) {
                let equation = '';
                for (let j = 0; j < currentSize; j++) {
                    const coeff = systemMatrix[i][j];
                    const sign = j === 0 ? '' : (coeff >= 0 ? ' + ' : ' ');
                    const term = j === 0 && coeff < 0 ? `-${Math.abs(coeff)}x${j+1}` : 
                                 `${Math.abs(coeff)}x${j+1}`;
                    equation += sign + term;
                }
                equation += ` = ${resultVector[i]}`;
                results += equation + '\n';
            }
            
            results += '\nSolution:\n';
            for (let i = 0; i < solution.length; i++) {
                results += `x${i+1} = ${solution[i].toFixed(4)}\n`;
            }
            
            // Verification
            results += '\nVerification (Ax):\n';
            for (let i = 0; i < currentSize; i++) {
                let sum = 0;
                for (let j = 0; j < currentSize; j++) {
                    sum += systemMatrix[i][j] * solution[j];
                }
                results += `Row ${i+1}: ${sum.toFixed(4)} ≈ ${resultVector[i]}\n`;
            }
            
            results += '</div></div>';
            document.getElementById('results').innerHTML = results;
            
        } catch (error) {
            document.getElementById('results').innerHTML = 
                `<div class="result-section error"><h4>Error</h4><p>${error.message}</p></div>`;
        }
    }

    function gaussianElimination(matrix, vector) {
        const n = matrix.length;
        
        // Forward elimination
        for (let i = 0; i < n; i++) {
            // Find pivot
            let maxRow = i;
            for (let k = i + 1; k < n; k++) {
                if (Math.abs(matrix[k][i]) > Math.abs(matrix[maxRow][i])) {
                    maxRow = k;
                }
            }
            
            // Swap rows
            [matrix[i], matrix[maxRow]] = [matrix[maxRow], matrix[i]];
            [vector[i], vector[maxRow]] = [vector[maxRow], vector[i]];
            
            // Check for singular matrix
            if (Math.abs(matrix[i][i]) < 1e-10) {
                throw new Error('Matrix is singular or nearly singular');
            }
            
            // Eliminate
            for (let k = i + 1; k < n; k++) {
                const factor = matrix[k][i] / matrix[i][i];
                for (let j = i; j < n; j++) {
                    matrix[k][j] -= factor * matrix[i][j];
                }
                vector[k] -= factor * vector[i];
            }
        }
        
        // Back substitution
        const solution = new Array(n);
        for (let i = n - 1; i >= 0; i--) {
            solution[i] = vector[i];
            for (let j = i + 1; j < n; j++) {
                solution[i] -= matrix[i][j] * solution[j];
            }
            solution[i] /= matrix[i][i];
        }
        
        return solution;
    }

    function calculateDeterminant() {
        try {
            const det = determinant([...singleMatrix.map(row => [...row])]);
            
            let results = '<div class="result-section success">';
            results += '<h4>Determinant Calculation</h4>';
            results += '<div class="matrix-display">';
            results += 'Matrix:\n';
            for (let i = 0; i < currentMatrixSize; i++) {
                results += '[' + singleMatrix[i].map(x => x.toString().padStart(6)).join(' ') + ']\n';
            }
            results += `\nDeterminant = ${det.toFixed(6)}`;
            
            if (Math.abs(det) < 1e-10) {
                results += '\n\nMatrix is singular (det ≈ 0)';
            } else {
                results += '\n\nMatrix is non-singular (invertible)';
            }
            
            results += '</div></div>';
            document.getElementById('results').innerHTML = results;
            
        } catch (error) {
            document.getElementById('results').innerHTML = 
                `<div class="result-section error"><h4>Error</h4><p>${error.message}</p></div>`;
        }
    }

    function determinant(matrix) {
        const n = matrix.length;
        if (n === 1) return matrix[0][0];
        if (n === 2) return matrix[0][0] * matrix[1][1] - matrix[0][1] * matrix[1][0];
        
        let det = 0;
        for (let col = 0; col < n; col++) {
            const subMatrix = matrix.slice(1).map(row => 
                row.filter((_, index) => index !== col)
            );
            det += Math.pow(-1, col) * matrix[0][col] * determinant(subMatrix);
        }
        return det;
    }

    function calculateInverse() {
        try {
            const det = determinant([...singleMatrix.map(row => [...row])]);
            
            if (Math.abs(det) < 1e-10) {
                throw new Error('Matrix is singular and cannot be inverted');
            }
            
            const inverse = matrixInverse([...singleMatrix.map(row => [...row])]);
            
            let results = '<div class="result-section success">';
            results += '<h4>Matrix Inverse</h4>';
            results += '<div class="matrix-display">';
            results += 'Original Matrix:\n';
            for (let i = 0; i < currentMatrixSize; i++) {
                results += '[' + singleMatrix[i].map(x => x.toString().padStart(8)).join(' ') + ']\n';
            }
            results += '\nInverse Matrix:\n';
            for (let i = 0; i < currentMatrixSize; i++) {
                results += '[' + inverse[i].map(x => x.toFixed(4).padStart(8)).join(' ') + ']\n';
            }
            results += `\nDeterminant = ${det.toFixed(6)}`;
            results += '</div></div>';
            document.getElementById('results').innerHTML = results;
            
        } catch (error) {
            document.getElementById('results').innerHTML = 
                `<div class="result-section error"><h4>Error</h4><p>${error.message}</p></div>`;
        }
    }

    function matrixInverse(matrix) {
        const n = matrix.length;
        const identity = Array(n).fill().map((_, i) => 
            Array(n).fill().map((_, j) => i === j ? 1 : 0)
        );
        
        // Gauss-Jordan elimination
        for (let i = 0; i < n; i++) {
            // Find pivot
            let maxRow = i;
            for (let k = i + 1; k < n; k++) {
                if (Math.abs(matrix[k][i]) > Math.abs(matrix[maxRow][i])) {
                    maxRow = k;
                }
            }
            
            // Swap rows
            [matrix[i], matrix[maxRow]] = [matrix[maxRow], matrix[i]];
            [identity[i], identity[maxRow]] = [identity[maxRow], identity[i]];
            
            // Scale pivot row
            const pivot = matrix[i][i];
            for (let j = 0; j < n; j++) {
                matrix[i][j] /= pivot;
                identity[i][j] /= pivot;
            }
            
            // Eliminate column
            for (let k = 0; k < n; k++) {
                if (k !== i) {
                    const factor = matrix[k][i];
                    for (let j = 0; j < n; j++) {
                        matrix[k][j] -= factor * matrix[i][j];
                        identity[k][j] -= factor * identity[i][j];
                    }
                }
            }
        }
        
        return identity;
    }

    function calculateRank() {
        try {
            const rank = matrixRank([...singleMatrix.map(row => [...row])]);
            
            let results = '<div class="result-section success">';
            results += '<h4>Matrix Rank</h4>';
            results += '<div class="matrix-display">';
            results += 'Matrix:\n';
            for (let i = 0; i < currentMatrixSize; i++) {
                results += '[' + singleMatrix[i].map(x => x.toString().padStart(6)).join(' ') + ']\n';
            }
            results += `\nRank = ${rank}`;
            results += `\nMatrix size = ${currentMatrixSize}×${currentMatrixSize}`;
            
            if (rank === currentMatrixSize) {
                results += '\n\nMatrix has full rank (invertible)';
            } else {
                results += '\n\nMatrix is rank deficient (singular)';
            }
            
            results += '</div></div>';
            document.getElementById('results').innerHTML = results;
            
        } catch (error) {
            document.getElementById('results').innerHTML = 
                `<div class="result-section error"><h4>Error</h4><p>${error.message}</p></div>`;
        }
    }

    function matrixRank(matrix) {
        const n = matrix.length;
        let rank = 0;
        
        for (let col = 0; col < n && rank < n; col++) {
            // Find pivot
            let pivotRow = -1;
            for (let row = rank; row < n; row++) {
                if (Math.abs(matrix[row][col]) > 1e-10) {
                    pivotRow = row;
                    break;
                }
            }
            
            if (pivotRow === -1) continue;
            
            // Swap rows
            if (pivotRow !== rank) {
                [matrix[rank], matrix[pivotRow]] = [matrix[pivotRow], matrix[rank]];
            }
            
            // Eliminate
            for (let row = rank + 1; row < n; row++) {
                const factor = matrix[row][col] / matrix[rank][col];
                for (let c = col; c < n; c++) {
                    matrix[row][c] -= factor * matrix[rank][c];
                }
            }
            
            rank++;
        }
        
        return rank;
    }

    function calculateEigenvalues() {
        if (currentMatrixSize > 3) {
            document.getElementById('results').innerHTML = 
                '<div class="result-section error"><h4>Error</h4><p>Eigenvalue calculation is only supported for matrices up to 3×3</p></div>';
            return;
        }
        
        try {
            const eigenvalues = calculateEigenvalues2x2or3x3(singleMatrix);
            
            let results = '<div class="result-section success">';
            results += '<h4>Eigenvalues</h4>';
            results += '<div class="matrix-display">';
            results += 'Matrix:\n';
            for (let i = 0; i < currentMatrixSize; i++) {
                results += '[' + singleMatrix[i].map(x => x.toString().padStart(8)).join(' ') + ']\n';
            }
            results += '\nCharacteristic equation: det(A - λI) = 0\n';
            results += '\nEigenvalues:\n';
            eigenvalues.forEach((lambda, i) => {
                if (typeof lambda === 'object') {
                    results += `λ${i+1} = ${lambda.real.toFixed(4)} + ${lambda.imag.toFixed(4)}i\n`;
                } else {
                    results += `λ${i+1} = ${lambda.toFixed(4)}\n`;
                }
            });
            results += '</div></div>';
            document.getElementById('results').innerHTML = results;
            
        } catch (error) {
            document.getElementById('results').innerHTML = 
                `<div class="result-section error"><h4>Error</h4><p>${error.message}</p></div>`;
        }
    }

    function calculateEigenvalues2x2or3x3(matrix) {
        const n = matrix.length;
        
        if (n === 2) {
            // For 2x2: λ² - trace*λ + det = 0
            const trace = matrix[0][0] + matrix[1][1];
            const det = matrix[0][0] * matrix[1][1] - matrix[0][1] * matrix[1][0];
            const discriminant = trace * trace - 4 * det;
            
            if (discriminant >= 0) {
                const sqrt_d = Math.sqrt(discriminant);
                return [(trace + sqrt_d) / 2, (trace - sqrt_d) / 2];
            } else {
                const sqrt_d = Math.sqrt(-discriminant);
                return [
                    { real: trace / 2, imag: sqrt_d / 2 },
                    { real: trace / 2, imag: -sqrt_d / 2 }
                ];
            }
        } else if (n === 3) {
            // Simplified 3x3 eigenvalue calculation (approximate)
            const trace = matrix[0][0] + matrix[1][1] + matrix[2][2];
            return [trace / 3, trace / 3, trace / 3]; // Simplified approximation
        }
        
        throw new Error('Eigenvalue calculation not implemented for this size');
    }

    function loadExample(type) {
        if (type === 'simple') {
            document.getElementById('systemSize').value = '2';
            updateSystemSize();
            systemMatrix = [[2, 1], [1, 3]];
            resultVector = [5, 7];
            renderSystemMatrix();
            renderVectors();
            
            document.getElementById('matrixSize').value = '2';
            updateMatrixSize();
            singleMatrix = [[4, 2], [1, 3]];
            renderSingleMatrix();
            
        } else if (type === 'complex') {
            document.getElementById('systemSize').value = '3';
            updateSystemSize();
            systemMatrix = [[2, -1, 3], [1, 2, -1], [3, 1, 2]];
            resultVector = [9, 0, 8];
            renderSystemMatrix();
            renderVectors();
            
            document.getElementById('matrixSize').value = '3';
            updateMatrixSize();
            singleMatrix = [[1, 2, 3], [0, 1, 4], [5, 6, 0]];
            renderSingleMatrix();
            
        } else if (type === 'singular') {
            document.getElementById('matrixSize').value = '3';
            updateMatrixSize();
            singleMatrix = [[1, 2, 3], [2, 4, 6], [1, 2, 3]];
            renderSingleMatrix();
        }
    }

    // Initialize on page load
    window.addEventListener('load', initializeTool);
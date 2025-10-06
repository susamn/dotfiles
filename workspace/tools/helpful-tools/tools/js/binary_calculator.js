let inputBase = 'decimal';
let storageUnit = 'bytes';
let currentValue = 0;
let currentArithmeticOperation = 'add';
let currentResults = {
    decimal: '',
    binary: '',
    hex: '',
    octal: '',
    signed: '',
    storageBytes: '',
    storageBinary: '',
    storageDecimal: '',
    storageBits: '',
    storagePages: ''
};
let animationInProgress = false;

function setInputBase(base) {
    inputBase = base;

    // Update button states
    document.getElementById('decimalBtn').classList.toggle('active', base === 'decimal');
    document.getElementById('binaryBtn').classList.toggle('active', base === 'binary');
    document.getElementById('hexBtn').classList.toggle('active', base === 'hex');
    document.getElementById('octalBtn').classList.toggle('active', base === 'octal');

    // Re-convert if there's input
    convertNumber();
}

function setStorageUnit(unit) {
    storageUnit = unit;

    // Update button states
    document.getElementById('bytesBtn').classList.toggle('active', unit === 'bytes');
    document.getElementById('kbBtn').classList.toggle('active', unit === 'kb');
    document.getElementById('mbBtn').classList.toggle('active', unit === 'mb');
    document.getElementById('gbBtn').classList.toggle('active', unit === 'gb');

    // Re-convert if there's input
    convertStorage();
}

function parseNumberInput(value) {
    value = value.trim();

    if (!value) return null;

    // Auto-detect format based on prefix
    if (value.startsWith('0x') || value.startsWith('0X')) {
        return parseInt(value, 16);
    } else if (value.startsWith('0b') || value.startsWith('0B')) {
        return parseInt(value.slice(2), 2);
    } else if (value.startsWith('0o') || value.startsWith('0O')) {
        return parseInt(value.slice(2), 8);
    } else if (value.startsWith('0') && value.length > 1 && /^[0-7]+$/.test(value.slice(1))) {
        return parseInt(value, 8);
    }

    // Parse based on selected input base
    switch (inputBase) {
        case 'binary':
            return parseInt(value.replace(/[^01]/g, ''), 2);
        case 'hex':
            return parseInt(value.replace(/[^0-9a-fA-F]/g, ''), 16);
        case 'octal':
            return parseInt(value.replace(/[^0-7]/g, ''), 8);
        default:
            return parseInt(value);
    }
}

function convertNumber() {
    const input = document.getElementById('numberInput');
    const numberError = document.getElementById('numberError');
    const statusText = document.getElementById('statusText');

    const value = input.value.trim();

    // Clear previous errors
    numberError.style.display = 'none';
    input.className = 'number-input';

    if (!value) {
        clearNumberResults();
        updateBitDisplay(0);
        return;
    }

    try {
        const number = parseNumberInput(value);

        if (isNaN(number) || number < -2147483648 || number > 4294967295) {
            throw new Error('Please enter a number between -2,147,483,648 and 4,294,967,295 for 32-bit operations');
        }

        currentValue = number;

        // Handle negative numbers and convert to unsigned for bit operations
        let unsignedNumber = number;
        if (number < 0) {
            // Convert negative to 32-bit unsigned using 2's complement
            unsignedNumber = (number >>> 0); // JavaScript unsigned right shift
        }

        // Update results
        currentResults.decimal = number.toString();
        currentResults.binary = '0b' + unsignedNumber.toString(2).padStart(32, '0');
        currentResults.hex = '0x' + unsignedNumber.toString(16).toUpperCase().padStart(8, '0');
        currentResults.octal = '0o' + unsignedNumber.toString(8).padStart(11, '0');

        // Calculate signed value (2's complement for 32-bit)
        const signed = unsignedNumber > 2147483647 ? unsignedNumber - 4294967296 : unsignedNumber;
        currentResults.signed = signed.toString();

        document.getElementById('decimalResult').textContent = currentResults.decimal;
        document.getElementById('binaryResult').textContent = currentResults.binary;
        document.getElementById('hexResult').textContent = currentResults.hex;
        document.getElementById('octalResult').textContent = currentResults.octal;
        document.getElementById('signedResult').textContent = currentResults.signed;

        updateBitDisplay(unsignedNumber);

        input.className = 'number-input valid';
        statusText.textContent = `Converted: ${number} (decimal)`;
        statusText.style.color = '#008000';

    } catch (error) {
        input.className = 'number-input error';
        numberError.textContent = error.message;
        numberError.style.display = 'block';
        statusText.textContent = 'Invalid number';
        statusText.style.color = '#cc0000';
        clearNumberResults();
        updateBitDisplay(0);
    }
}

function convertStorage() {
    const input = document.getElementById('storageInput');
    const storageError = document.getElementById('storageError');
    const statusText = document.getElementById('statusText');

    const value = input.value.trim();

    // Clear previous errors
    storageError.style.display = 'none';

    if (!value) {
        clearStorageResults();
        return;
    }

    try {
        const number = parseFloat(value);

        if (isNaN(number) || number < 0) {
            throw new Error('Please enter a positive number');
        }

        // Convert to bytes based on input unit
        let bytes;
        switch (storageUnit) {
            case 'kb':
                bytes = number * 1024; // Using binary KB
                break;
            case 'mb':
                bytes = number * 1024 * 1024;
                break;
            case 'gb':
                bytes = number * 1024 * 1024 * 1024;
                break;
            default:
                bytes = number;
        }

        // Update results
        currentResults.storageBytes = Math.round(bytes).toLocaleString() + ' bytes';

        // Binary prefixes (1024-based)
        const kib = bytes / 1024;
        const mib = bytes / (1024 * 1024);
        const gib = bytes / (1024 * 1024 * 1024);

        let binaryStr = '';
        if (gib >= 1) {
            binaryStr = `${gib.toFixed(3)} GiB`;
        } else if (mib >= 1) {
            binaryStr = `${mib.toFixed(3)} MiB`;
        } else if (kib >= 1) {
            binaryStr = `${kib.toFixed(3)} KiB`;
        } else {
            binaryStr = `${Math.round(bytes)} bytes`;
        }
        currentResults.storageBinary = binaryStr;

        // Decimal prefixes (1000-based)
        const kb = bytes / 1000;
        const mb = bytes / (1000 * 1000);
        const gb = bytes / (1000 * 1000 * 1000);

        let decimalStr = '';
        if (gb >= 1) {
            decimalStr = `${gb.toFixed(3)} GB`;
        } else if (mb >= 1) {
            decimalStr = `${mb.toFixed(3)} MB`;
        } else if (kb >= 1) {
            decimalStr = `${kb.toFixed(3)} KB`;
        } else {
            decimalStr = `${Math.round(bytes)} bytes`;
        }
        currentResults.storageDecimal = decimalStr;

        currentResults.storageBits = (bytes * 8).toLocaleString() + ' bits';
        currentResults.storagePages = (bytes / 4096).toFixed(2) + ' pages';

        // Update storage results
        document.getElementById('storageBytesResult').textContent = currentResults.storageBytes;
        document.getElementById('storageBinaryResult').textContent = currentResults.storageBinary;
        document.getElementById('storageDecimalResult').textContent = currentResults.storageDecimal;
        document.getElementById('storageBitsResult').textContent = currentResults.storageBits;

    } catch (error) {
        storageError.textContent = error.message;
        storageError.style.display = 'block';
        clearStorageResults();
    }
}

function updateBitDisplay(number) {
    // Handle negative numbers properly
    const unsignedNumber = number >>> 0; // Convert to unsigned 32-bit

    for (let i = 0; i < 32; i++) {
        const bit = document.getElementById(`bit${i}`);
        if (bit) {
            const isSet = (unsignedNumber >> i) & 1;
            bit.textContent = isSet ? '1' : '0';
            bit.classList.toggle('active', isSet === 1);
        }
    }
}

function toggleBit(bitPosition) {
    // Handle the current value as unsigned for bit operations
    let unsignedValue = currentValue >>> 0;
    unsignedValue ^= (1 << bitPosition);

    // Convert back to signed if needed
    currentValue = unsignedValue > 2147483647 ? unsignedValue - 4294967296 : unsignedValue;

    updateBitDisplay(unsignedValue);

    // Update the input field and convert
    document.getElementById('numberInput').value = currentValue.toString();
    convertNumber();
}

function clearNumberResults() {
    document.getElementById('decimalResult').textContent = 'Enter number above';
    document.getElementById('binaryResult').textContent = 'Enter number above';
    document.getElementById('hexResult').textContent = 'Enter number above';
    document.getElementById('octalResult').textContent = 'Enter number above';
    document.getElementById('signedResult').textContent = 'Enter number above';
    currentResults.decimal = '';
    currentResults.binary = '';
    currentResults.hex = '';
    currentResults.octal = '';
    currentResults.signed = '';
}

function clearStorageResults() {
    document.getElementById('storageBytesResult').textContent = 'Enter size above';
    document.getElementById('storageBinaryResult').textContent = 'Enter size above';
    document.getElementById('storageDecimalResult').textContent = 'Enter size above';
    document.getElementById('storageBitsResult').textContent = 'Enter size above';
    currentResults.storageBytes = '';
    currentResults.storageBinary = '';
    currentResults.storageDecimal = '';
    currentResults.storageBits = '';
    currentResults.storagePages = '';
}

function loadExample(value) {
    document.getElementById('numberInput').value = value;
    convertNumber();
}

function loadStorageExample(value) {
    document.getElementById('storageInput').value = value;
    convertStorage();
}

function copyResult(type) {
    const value = currentResults[type];
    if (!value) {
        document.getElementById('statusText').textContent = 'No result to copy';
        document.getElementById('statusText').style.color = '#ff8800';
        return;
    }

    navigator.clipboard.writeText(value).then(() => {
        showCopyFeedback(`${type} copied to clipboard`);
    }).catch(() => {
        const textArea = document.createElement('textarea');
        textArea.value = value;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
        showCopyFeedback(`${type} copied to clipboard`);
    });
}

function copyAllResults() {
    const numberResults = ['decimal', 'binary', 'hex', 'octal', 'signed']
        .filter(key => currentResults[key] !== '')
        .map(key => `${key}: ${currentResults[key]}`)
        .join('\n');

    const storageResults = ['storageBytes', 'storageBinary', 'storageDecimal', 'storageBits', 'storagePages']
        .filter(key => currentResults[key] !== '')
        .map(key => `${key.replace('storage', '').toLowerCase()}: ${currentResults[key]}`)
        .join('\n');

    const allResults = [numberResults, storageResults].filter(r => r).join('\n\n');

    if (!allResults) {
        document.getElementById('statusText').textContent = 'No results to copy';
        document.getElementById('statusText').style.color = '#ff8800';
        return;
    }

    navigator.clipboard.writeText(allResults).then(() => {
        showCopyFeedback('All results copied to clipboard');
    }).catch(() => {
        const textArea = document.createElement('textarea');
        textArea.value = allResults;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
        showCopyFeedback('All results copied to clipboard');
    });
}

function showCopyFeedback(message) {
    const statusText = document.getElementById('statusText');
    const originalText = statusText.textContent;
    const originalColor = statusText.style.color;

    statusText.textContent = message;
    statusText.style.color = '#008000';

    setTimeout(() => {
        statusText.textContent = originalText;
        statusText.style.color = originalColor;
    }, 2000);
}

function clearAll() {
    document.getElementById('numberInput').value = '';
    document.getElementById('storageInput').value = '';
    document.getElementById('numberError').style.display = 'none';
    document.getElementById('storageError').style.display = 'none';
    document.getElementById('numberInput').className = 'number-input';
    document.getElementById('statusText').textContent = 'Ready - Enter a number or click on the bit display';
    document.getElementById('statusText').style.color = '#666';
    currentValue = 0;
    updateBitDisplay(0);
    clearNumberResults();
    clearStorageResults();
}

// Auto-convert on input change
document.getElementById('numberInput').addEventListener('input', function() {
    clearTimeout(this.convertTimer);
    this.convertTimer = setTimeout(convertNumber, 300);
});

document.getElementById('storageInput').addEventListener('input', function() {
    clearTimeout(this.convertTimer);
    this.convertTimer = setTimeout(convertStorage, 300);
});

// Arithmetic Calculator Functions
function setArithmeticOperation(operation) {
    currentArithmeticOperation = operation;

    // Update button states
    document.querySelectorAll('.operation-btn').forEach(btn => btn.classList.remove('active'));
    event.target.classList.add('active');

    // Update select dropdown
    document.getElementById('operation').value = operation;

    // Recalculate
    performArithmeticOperation();
}

function performArithmeticOperation() {
    if (animationInProgress) return;

    const operandA = parseInt(document.getElementById('operandA').value) || 0;
    const operandB = parseInt(document.getElementById('operandB').value) || 0;
    const operation = currentArithmeticOperation;

    let result;
    let explanation = '';
    let showCarry = false;

    // Handle 32-bit signed/unsigned operations
    const a = operandA >>> 0; // Convert to unsigned 32-bit
    const b = operandB >>> 0; // Convert to unsigned 32-bit

    switch (operation) {
        case 'add':
            result = (a + b) >>> 0; // Keep as 32-bit unsigned
            const resultBinary = result.toString(2).padStart(32, '0');
            const groupedBinary = `${resultBinary.slice(0,8)} ${resultBinary.slice(8,16)} ${resultBinary.slice(16,24)} ${resultBinary.slice(24,32)}`;
            explanation = `Addition: ${operandA} + ${operandB} = ${result}\\n`;
            explanation += `Step 1: Convert to binary: ${operandA.toString(2).padStart(32, '0')} + ${operandB.toString(2).padStart(32, '0')}\\n`;
            explanation += `Step 2: Add bit by bit from right to left with carry propagation\\n`;
            explanation += `Step 3: Result: ${groupedBinary} = ${result} (decimal)`;
            if ((a + b) > 0xFFFFFFFF) explanation += `\\nOverflow detected! Result wrapped around.`;
            showCarry = true;
            break;
        case 'sub':
            result = (a - b) >>> 0; // Handle as 32-bit unsigned
            const subBinary = result.toString(2).padStart(32, '0');
            const subGrouped = `${subBinary.slice(0,8)} ${subBinary.slice(8,16)} ${subBinary.slice(16,24)} ${subBinary.slice(24,32)}`;
            explanation = `Subtraction: ${operandA} - ${operandB} = ${result}\\n`;
            explanation += `Step 1: Convert ${operandA} to binary: ${operandA.toString(2).padStart(32, '0')}\\n`;
            explanation += `Step 2: Convert ${operandB} to 2's complement: ${((~operandB + 1) >>> 0).toString(2).padStart(32, '0')}\\n`;
            explanation += `Step 3: Add: ${operandA} + (-${operandB}) = ${subGrouped} = ${result}`;
            break;
        case 'mul':
            result = Math.imul(a, b) >>> 0; // 32-bit multiplication
            const mulBinary = result.toString(2).padStart(32, '0');
            const mulGrouped = `${mulBinary.slice(0,8)} ${mulBinary.slice(8,16)} ${mulBinary.slice(16,24)} ${mulBinary.slice(24,32)}`;
            explanation = `Multiplication: ${operandA} × ${operandB} = ${result}\\n`;
            explanation += `Step 1: Convert to binary: ${operandA.toString(2)} × ${operandB.toString(2)}\\n`;
            explanation += `Step 2: Use shift and add algorithm or direct multiplication\\n`;
            explanation += `Step 3: Result (32-bit): ${mulGrouped} = ${result}`;
            break;
        case 'and':
            result = (a & b) >>> 0;
            const andBinary = result.toString(2).padStart(32, '0');
            const andGrouped = `${andBinary.slice(0,8)} ${andBinary.slice(8,16)} ${andBinary.slice(16,24)} ${andBinary.slice(24,32)}`;
            explanation = `Bitwise AND: ${operandA} & ${operandB} = ${result}\\n`;
            explanation += `Step 1: A = ${operandA.toString(2).padStart(32, '0')}\\n`;
            explanation += `Step 2: B = ${operandB.toString(2).padStart(32, '0')}\\n`;
            explanation += `Step 3: A & B (1 if both bits are 1): ${andGrouped} = ${result}`;
            break;
        case 'or':
            result = (a | b) >>> 0;
            const orBinary = result.toString(2).padStart(32, '0');
            const orGrouped = `${orBinary.slice(0,8)} ${orBinary.slice(8,16)} ${orBinary.slice(16,24)} ${orBinary.slice(24,32)}`;
            explanation = `Bitwise OR: ${operandA} | ${operandB} = ${result}\\n`;
            explanation += `Step 1: A = ${operandA.toString(2).padStart(32, '0')}\\n`;
            explanation += `Step 2: B = ${operandB.toString(2).padStart(32, '0')}\\n`;
            explanation += `Step 3: A | B (1 if either bit is 1): ${orGrouped} = ${result}`;
            break;
        case 'xor':
            result = (a ^ b) >>> 0;
            const xorBinary = result.toString(2).padStart(32, '0');
            const xorGrouped = `${xorBinary.slice(0,8)} ${xorBinary.slice(8,16)} ${xorBinary.slice(16,24)} ${xorBinary.slice(24,32)}`;
            explanation = `Bitwise XOR: ${operandA} ^ ${operandB} = ${result}\\n`;
            explanation += `Step 1: A = ${operandA.toString(2).padStart(32, '0')}\\n`;
            explanation += `Step 2: B = ${operandB.toString(2).padStart(32, '0')}\\n`;
            explanation += `Step 3: A ^ B (1 if bits differ): ${xorGrouped} = ${result}`;
            break;
        case 'shl':
            const shiftAmount = b & 31;
            result = (a << shiftAmount) >>> 0; // Mask shift amount to 5 bits
            const shlBinary = result.toString(2).padStart(32, '0');
            const shlGrouped = `${shlBinary.slice(0,8)} ${shlBinary.slice(8,16)} ${shlBinary.slice(16,24)} ${shlBinary.slice(24,32)}`;
            explanation = `Left Shift: ${operandA} << ${shiftAmount} = ${result}\\n`;
            explanation += `Step 1: Original: ${operandA.toString(2).padStart(32, '0')}\\n`;
            explanation += `Step 2: Shift left by ${shiftAmount} positions (fill with 0s)\\n`;
            explanation += `Step 3: Result: ${shlGrouped} = ${result}\\n`;
            explanation += `Note: Each left shift multiplies by 2 (if no overflow)`;
            break;
        case 'shr':
            const shrAmount = b & 31;
            result = (a >>> shrAmount); // Logical right shift
            const shrBinary = result.toString(2).padStart(32, '0');
            const shrGrouped = `${shrBinary.slice(0,8)} ${shrBinary.slice(8,16)} ${shrBinary.slice(16,24)} ${shrBinary.slice(24,32)}`;
            explanation = `Logical Right Shift: ${operandA} >>> ${shrAmount} = ${result}\\n`;
            explanation += `Step 1: Original: ${operandA.toString(2).padStart(32, '0')}\\n`;
            explanation += `Step 2: Shift right by ${shrAmount} positions (fill with 0s)\\n`;
            explanation += `Step 3: Result: ${shrGrouped} = ${result}\\n`;
            explanation += `Note: Logical shift treats number as unsigned`;
            break;
        case 'sar':
            const sarAmount = b & 31;
            result = (operandA >> sarAmount) >>> 0; // Arithmetic right shift, then convert to unsigned
            const sarBinary = result.toString(2).padStart(32, '0');
            const sarGrouped = `${sarBinary.slice(0,8)} ${sarBinary.slice(8,16)} ${sarBinary.slice(16,24)} ${sarBinary.slice(24,32)}`;
            explanation = `Arithmetic Right Shift: ${operandA} >> ${sarAmount} = ${result}\\n`;
            explanation += `Step 1: Original: ${operandA.toString(2).padStart(32, '0')}\\n`;
            explanation += `Step 2: Shift right by ${sarAmount} positions (preserve sign bit)\\n`;
            explanation += `Step 3: Result: ${sarGrouped} = ${result}\\n`;
            explanation += `Note: Arithmetic shift preserves sign for negative numbers`;
            break;
    }

    // Update result display
    document.getElementById('arithmeticResult').textContent = result;
    document.getElementById('stepByStep').innerHTML = explanation.replace(/\\n/g, '<br>');

    // Show/hide carry row
    document.getElementById('carryRow').style.display = showCarry ? 'block' : 'none';

    // Update visual representation
    updateArithmeticVisual(a, b, result, operation);
}

function updateArithmeticVisual(a, b, result, operation) {
    // Clear all bit groups
    for (let groupIdx = 0; groupIdx < 4; groupIdx++) {
        ['bitsA', 'bitsB', 'bitsResult', 'bitsCarry'].forEach(prefix => {
            const group = document.getElementById(`${prefix}-group${groupIdx}`);
            if (group) group.innerHTML = '';
        });
    }

    // Create 32-bit visual representation (4 groups of 8 bits)
    for (let groupIdx = 3; groupIdx >= 0; groupIdx--) {
        const groupStartBit = groupIdx * 8;

        for (let bitIdx = 7; bitIdx >= 0; bitIdx--) {
            const absoluteBitPos = groupStartBit + bitIdx;

            // Operand A bits
            const bitA = document.createElement('div');
            bitA.className = 'arithmetic-bit';
            const aValue = (a >>> absoluteBitPos) & 1;
            bitA.textContent = aValue;
            if (aValue) bitA.classList.add('active');
            document.getElementById(`bitsA-group${groupIdx}`).appendChild(bitA);

            // Operand B bits
            const bitB = document.createElement('div');
            bitB.className = 'arithmetic-bit';
            const bValue = (b >>> absoluteBitPos) & 1;
            bitB.textContent = bValue;
            if (bValue) bitB.classList.add('active');
            document.getElementById(`bitsB-group${groupIdx}`).appendChild(bitB);

            // Result bits
            const bitResult = document.createElement('div');
            bitResult.className = 'arithmetic-bit';
            const resultValue = (result >>> absoluteBitPos) & 1;
            bitResult.textContent = resultValue;
            if (resultValue) bitResult.classList.add('active');
            document.getElementById(`bitsResult-group${groupIdx}`).appendChild(bitResult);

            // Carry bits (for addition)
            if (operation === 'add') {
                const bitCarry = document.createElement('div');
                bitCarry.className = 'arithmetic-bit';

                // Calculate carry for this position
                let carry = 0;
                for (let j = 0; j <= absoluteBitPos; j++) {
                    const aBit = (a >>> j) & 1;
                    const bBit = (b >>> j) & 1;
                    const sum = aBit + bBit + carry;
                    carry = sum > 1 ? 1 : 0;
                }

                if (absoluteBitPos < 31) {
                    // Calculate carry out for next position
                    let nextCarry = 0;
                    for (let j = 0; j <= absoluteBitPos + 1; j++) {
                        const aBit = (a >>> j) & 1;
                        const bBit = (b >>> j) & 1;
                        const sum = aBit + bBit + nextCarry;
                        nextCarry = sum > 1 ? 1 : 0;
                    }
                    const carryOut = nextCarry && (absoluteBitPos < 30);
                    bitCarry.textContent = carryOut ? '1' : '0';
                    if (carryOut) bitCarry.classList.add('carry');
                } else {
                    // For MSB, show overflow carry
                    const overflowCarry = (a + b) > 0xFFFFFFFF ? 1 : 0;
                    bitCarry.textContent = overflowCarry;
                    if (overflowCarry) bitCarry.classList.add('carry');
                }

                document.getElementById(`bitsCarry-group${groupIdx}`).appendChild(bitCarry);
            }
        }
    }

    // Animate the result bits
    animateArithmeticResult();
}

function animateArithmeticResult() {
    animationInProgress = true;
    const resultBits = document.querySelectorAll('#bitsResult .arithmetic-bit');

    resultBits.forEach((bit, index) => {
        setTimeout(() => {
            bit.classList.add('animating');
            setTimeout(() => {
                bit.classList.remove('animating');
                if (index === resultBits.length - 1) {
                    animationInProgress = false;
                }
            }, 600);
        }, index * 100);
    });
}

function loadArithmeticExample() {
    const currentNumber = currentValue;
    if (currentNumber !== undefined && currentNumber !== null) {
        document.getElementById('operandA').value = currentNumber;
        document.getElementById('operandB').value = (currentNumber >>> 8) || 1; // Use upper bits or 1
        performArithmeticOperation();
    }
}

// Event listeners for arithmetic calculator
document.getElementById('operandA').addEventListener('input', function() {
    clearTimeout(this.calcTimer);
    this.calcTimer = setTimeout(performArithmeticOperation, 300);
});

document.getElementById('operandB').addEventListener('input', function() {
    clearTimeout(this.calcTimer);
    this.calcTimer = setTimeout(performArithmeticOperation, 300);
});

document.getElementById('operation').addEventListener('change', function() {
    currentArithmeticOperation = this.value;
    setArithmeticOperation(this.value);
});

// IEEE 754 Float Functions
function loadFloatExample(value) {
    document.getElementById('floatInput').value = value;
    convertFloat();
}

function convertFloat() {
    const input = document.getElementById('floatInput');
    const value = input.value.trim();

    if (!value) {
        clearFloatResults();
        return;
    }

    try {
        let floatValue;
        if (value.toLowerCase() === 'infinity' || value === '∞') {
            floatValue = Infinity;
        } else if (value.toLowerCase() === '-infinity') {
            floatValue = -Infinity;
        } else if (value.toLowerCase() === 'nan') {
            floatValue = NaN;
        } else {
            floatValue = parseFloat(value);
            if (isNaN(floatValue)) {
                throw new Error('Invalid float number');
            }
        }

        // Convert float to 32-bit representation
        const buffer = new ArrayBuffer(4);
        const floatView = new Float32Array(buffer);
        const intView = new Uint32Array(buffer);

        floatView[0] = floatValue;
        const bits = intView[0];

        // Extract IEEE 754 components
        const sign = (bits >>> 31) & 1;
        const exponent = (bits >>> 23) & 0xFF;
        const mantissa = bits & 0x7FFFFF;

        // Update hex result
        document.getElementById('floatHexResult').textContent = '0x' + bits.toString(16).toUpperCase().padStart(8, '0');

        // Update sign bit
        const signBit = document.querySelector('#ieee754Sign .ieee754-bit');
        signBit.textContent = sign;
        signBit.className = 'ieee754-bit sign-bit';
        document.getElementById('signValue').textContent = sign ? 'Negative' : 'Positive';

        // Update exponent bits
        const exponentBits = document.querySelectorAll('#ieee754Exponent .ieee754-bit');
        for (let i = 0; i < 8; i++) {
            const bit = (exponent >>> (7 - i)) & 1;
            exponentBits[i].textContent = bit;
            exponentBits[i].className = 'ieee754-bit exponent-bit';
        }

        let exponentText = '';
        if (exponent === 0) {
            exponentText = '0 (denormalized)';
        } else if (exponent === 255) {
            exponentText = '255 (special: Inf/NaN)';
        } else {
            const actualExponent = exponent - 127;
            exponentText = `${exponent} (bias: 127, actual: ${actualExponent})`;
        }
        document.getElementById('exponentValue').textContent = exponentText;

        // Update mantissa bits
        const mantissaBits = document.querySelectorAll('#ieee754Mantissa .ieee754-bit');
        for (let i = 0; i < 23; i++) {
            const bit = (mantissa >>> (22 - i)) & 1;
            mantissaBits[i].textContent = bit;
            mantissaBits[i].className = 'ieee754-bit mantissa-bit';
        }

        // Calculate mantissa value
        let mantissaValue = 0;
        for (let i = 0; i < 23; i++) {
            if ((mantissa >>> (22 - i)) & 1) {
                mantissaValue += Math.pow(2, -(i + 1));
            }
        }

        let mantissaText = '';
        if (exponent === 0 && mantissa !== 0) {
            mantissaText = `${mantissaValue.toFixed(7)} (denormalized)`;
        } else if (exponent === 255) {
            mantissaText = mantissa === 0 ? 'Infinity' : 'NaN';
        } else {
            mantissaText = `${(1 + mantissaValue).toFixed(7)} (1 + ${mantissaValue.toFixed(7)})`;
        }
        document.getElementById('mantissaValue').textContent = mantissaText;

        // Update formula breakdown
        let formulaText = '';
        if (isNaN(floatValue)) {
            formulaText = 'NaN (Not a Number) - special IEEE 754 value';
        } else if (!isFinite(floatValue)) {
            formulaText = `${floatValue > 0 ? '+' : '-'}Infinity - special IEEE 754 value`;
        } else if (exponent === 0) {
            const denormValue = Math.pow(-1, sign) * mantissaValue * Math.pow(2, -126);
            formulaText = `= (-1)^${sign} × ${mantissaValue.toFixed(7)} × 2^(-126) = ${denormValue}`;
        } else {
            const actualExp = exponent - 127;
            const significand = 1 + mantissaValue;
            formulaText = `= (-1)^${sign} × ${significand.toFixed(7)} × 2^(${exponent}-127) = ${sign ? '-' : ''}${significand.toFixed(7)} × 2^${actualExp} = ${floatValue}`;
        }
        document.getElementById('formulaBreakdown').textContent = formulaText;

        // Update step by step
        const binaryStr = bits.toString(2).padStart(32, '0');
        const groupedBinary = `${binaryStr.slice(0,1)} ${binaryStr.slice(1,9)} ${binaryStr.slice(9,32)}`;
        document.getElementById('floatStepByStep').textContent = `Float ${floatValue} → Binary: ${groupedBinary} → Hex: 0x${bits.toString(16).toUpperCase().padStart(8, '0')}`;

    } catch (error) {
        clearFloatResults();
        document.getElementById('floatStepByStep').textContent = 'Invalid float input';
    }
}

function clearFloatResults() {
    document.getElementById('floatHexResult').textContent = '0x00000000';
    document.getElementById('signValue').textContent = 'Positive';
    document.getElementById('exponentValue').textContent = '0 (bias: 127, actual: -127)';
    document.getElementById('mantissaValue').textContent = '0.0000000';
    document.getElementById('formulaBreakdown').textContent = '= 0';
    document.getElementById('floatStepByStep').textContent = 'Enter float above';
}

// Auto-convert float on input change
document.getElementById('floatInput').addEventListener('input', function() {
    clearTimeout(this.convertTimer);
    this.convertTimer = setTimeout(convertFloat, 300);
});

// Two's Complement Functions
function loadComplementExample(value) {
    document.getElementById('complementInput').value = value;
    convertTwosComplement();
}

function convertTwosComplement() {
    const input = document.getElementById('complementInput');
    const value = input.value.trim();

    if (!value) {
        clearComplementResults();
        return;
    }

    try {
        const number = parseInt(value);
        if (isNaN(number) || number < 0 || number > 2147483647) {
            throw new Error('Enter a positive number between 0 and 2147483647');
        }

        // Convert to 16-bit for better visualization (can be changed to 32-bit)
        const bits = 16;
        const maxVal = Math.pow(2, bits) - 1;

        if (number > maxVal) {
            throw new Error(`Number too large for ${bits}-bit representation`);
        }

        // Step 1: Original number in binary
        const originalBinary = number.toString(2).padStart(bits, '0');

        // Step 2: One's complement (flip all bits)
        let onesComplement = '';
        for (let i = 0; i < bits; i++) {
            onesComplement += originalBinary[i] === '0' ? '1' : '0';
        }

        // Step 3: Two's complement (add 1 to one's complement)
        let twosComplementValue = parseInt(onesComplement, 2) + 1;
        if (twosComplementValue > maxVal) {
            twosComplementValue = twosComplementValue & maxVal; // Handle overflow
        }
        const twosComplementBinary = twosComplementValue.toString(2).padStart(bits, '0');

        // Update result
        const negativeResult = -(Math.pow(2, bits) - twosComplementValue);
        document.getElementById('complementResult').textContent = `-${number}`;

        // Update visual representation
        updateComplementVisual('originalBits', originalBinary, 'normal');
        updateComplementVisual('onesComplementBits', onesComplement, 'ones');
        updateComplementVisual('twosComplementBits', twosComplementBinary, 'twos');

        // Update step labels
        document.querySelector('.step-section:nth-child(1) .step-label').textContent = `Step 1: Original (${number})`;
        document.querySelector('.step-section:nth-child(2) .step-label').textContent = `Step 2: One's Complement (flip all bits)`;
        document.querySelector('.step-section:nth-child(3) .step-label').textContent = `Step 3: Add 1 (Two's Complement)`;

        // Update explanation
        const grouped1 = groupBinary(originalBinary);
        const grouped2 = groupBinary(onesComplement);
        const grouped3 = groupBinary(twosComplementBinary);

        document.getElementById('complementExplanation').innerHTML =
            `${number} → One's Complement: ${grouped2} → Add 1: ${grouped3} = -${number}`;

    } catch (error) {
        clearComplementResults();
        document.getElementById('complementExplanation').textContent = 'Invalid input';
    }
}

function updateComplementVisual(elementId, binaryString, type) {
    const container = document.getElementById(elementId);
    if (!container) return;

    // Clear existing bits
    container.innerHTML = '';

    // Create two groups of 8 bits each
    const group1 = document.createElement('div');
    group1.className = 'complement-bit-group';
    const group2 = document.createElement('div');
    group2.className = 'complement-bit-group';

    for (let i = 0; i < 8; i++) {
        const bit = document.createElement('div');
        bit.className = `complement-bit ${type}`;
        bit.textContent = binaryString[i] || '0';
        group1.appendChild(bit);
    }

    for (let i = 8; i < 16; i++) {
        const bit = document.createElement('div');
        bit.className = `complement-bit ${type}`;
        bit.textContent = binaryString[i] || '0';
        group2.appendChild(bit);
    }

    container.appendChild(group1);
    container.appendChild(group2);
}

function groupBinary(binary) {
    return binary.match(/.{1,8}/g).join(' ');
}

function clearComplementResults() {
    document.getElementById('complementResult').textContent = 'Enter number';
    document.getElementById('complementExplanation').textContent = 'Enter a positive number to see its two\'s complement';

    // Reset visuals to default
    updateComplementVisual('originalBits', '0000000000000000', 'normal');
    updateComplementVisual('onesComplementBits', '0000000000000000', 'ones');
    updateComplementVisual('twosComplementBits', '0000000000000000', 'twos');
}

// Auto-convert complement on input change
document.getElementById('complementInput').addEventListener('input', function() {
    clearTimeout(this.convertTimer);
    this.convertTimer = setTimeout(convertTwosComplement, 300);
});

// Initialize
updateBitDisplay(0);
performArithmeticOperation();
convertFloat();
clearStorageResults();
convertTwosComplement();
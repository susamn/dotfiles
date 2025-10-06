function isValidIP(ip) {
    const parts = ip.split('.');
    return parts.length === 4 && parts.every(part => {
        const num = parseInt(part);
        return num >= 0 && num <= 255 && part === num.toString();
    });
}

function isValidCIDR(cidr) {
    const num = parseInt(cidr);
    return num >= 0 && num <= 32;
}

function cidrToMask(cidr) {
    const mask = [];
    for (let i = 0; i < 4; i++) {
        if (cidr >= 8) {
            mask.push(255);
            cidr -= 8;
        } else if (cidr > 0) {
            mask.push(256 - Math.pow(2, 8 - cidr));
            cidr = 0;
        } else {
            mask.push(0);
        }
    }
    return mask.join('.');
}

function maskToCIDR(mask) {
    const parts = mask.split('.').map(Number);
    let cidr = 0;
    for (const part of parts) {
        cidr += part.toString(2).split('1').length - 1;
    }
    return cidr;
}

function ipToBinary(ip) {
    return ip.split('.').map(part =>
        parseInt(part).toString(2).padStart(8, '0')
    ).join('.');
}

function ipToLong(ip) {
    return ip.split('.').reduce((acc, octet) => (acc << 8) + parseInt(octet), 0) >>> 0;
}

function longToIP(long) {
    return [
        (long >>> 24) & 255,
        (long >>> 16) & 255,
        (long >>> 8) & 255,
        long & 255
    ].join('.');
}

function getIPClass(ip) {
    const firstOctet = parseInt(ip.split('.')[0]);
    if (firstOctet >= 1 && firstOctet <= 126) return 'A';
    if (firstOctet >= 128 && firstOctet <= 191) return 'B';
    if (firstOctet >= 192 && firstOctet <= 223) return 'C';
    if (firstOctet >= 224 && firstOctet <= 239) return 'D';
    if (firstOctet >= 240 && firstOctet <= 255) return 'E';
    return 'Invalid';
}

function isPrivateIP(ip) {
    const parts = ip.split('.').map(Number);
    const [a, b, c, d] = parts;

    return (a === 10) ||
        (a === 172 && b >= 16 && b <= 31) ||
        (a === 192 && b === 168) ||
        (a === 127) ||
        (a === 169 && b === 254);
}

function calculate() {
    const startTime = Date.now();

    const ipInput = document.getElementById('ipAddress').value.trim();
    const cidrInput = document.getElementById('cidr').value.trim();
    const maskInput = document.getElementById('subnetMask').value.trim();

    if (!ipInput) {
        showError('Please enter an IP address');
        return;
    }

    if (!isValidIP(ipInput)) {
        showError('Invalid IP address format');
        return;
    }

    let cidr;
    if (cidrInput) {
        if (!isValidCIDR(cidrInput)) {
            showError('Invalid CIDR notation (0-32)');
            return;
        }
        cidr = parseInt(cidrInput);
    } else if (maskInput) {
        if (!isValidIP(maskInput)) {
            showError('Invalid subnet mask format');
            return;
        }
        cidr = maskToCIDR(maskInput);
    } else {
        showError('Please enter CIDR or subnet mask');
        return;
    }

    // Auto-fill the other field
    if (cidrInput && !maskInput) {
        document.getElementById('subnetMask').value = cidrToMask(cidr);
    } else if (maskInput && !cidrInput) {
        document.getElementById('cidr').value = cidr;
    }

    const results = calculateNetwork(ipInput, cidr);
    displayResults(results);

    const endTime = Date.now();
    document.getElementById('calculationTime').textContent = `Calculated in ${endTime - startTime}ms`;
    document.getElementById('statusText').textContent = 'Network calculated successfully';
}

function calculateNetwork(ip, cidr) {
    const ipLong = ipToLong(ip);
    const maskLong = (0xffffffff << (32 - cidr)) >>> 0;
    const wildcardLong = ~maskLong >>> 0;

    const networkLong = (ipLong & maskLong) >>> 0;
    const broadcastLong = (networkLong | wildcardLong) >>> 0;

    const networkIP = longToIP(networkLong);
    const broadcastIP = longToIP(broadcastLong);
    const subnetMask = longToIP(maskLong);
    const wildcardMask = longToIP(wildcardLong);

    const totalHosts = Math.pow(2, 32 - cidr);
    const usableHosts = totalHosts - 2;

    const firstHostIP = longToIP(networkLong + 1);
    const lastHostIP = longToIP(broadcastLong - 1);

    const ipClass = getIPClass(ip);
    const isPrivate = isPrivateIP(ip);

    return {
        inputIP: ip,
        cidr: cidr,
        networkIP,
        broadcastIP,
        subnetMask,
        wildcardMask,
        firstHostIP,
        lastHostIP,
        totalHosts,
        usableHosts,
        ipClass,
        isPrivate,
        binaryIP: ipToBinary(ip),
        binaryMask: ipToBinary(subnetMask),
        binaryNetwork: ipToBinary(networkIP)
    };
}

function displayResults(results) {
    const networkInfo = document.getElementById('networkInfo');

    const classColor = {
        'A': 'class-a', 'B': 'class-b', 'C': 'class-c',
        'D': 'class-d', 'E': 'class-e'
    }[results.ipClass] || '';

    const typeColor = results.isPrivate ? 'private' : 'public';

    networkInfo.innerHTML = `
            <div class="result-section">
                <h4>Basic Information</h4>
                <div class="result-row">
                    <span class="result-label">Input IP Address:</span>
                    <span class="result-value">${results.inputIP}/${results.cidr} <button class="copy-btn" onclick="copyValue('${results.inputIP}/${results.cidr}')">Copy</button></span>
                </div>
                <div class="result-row">
                    <span class="result-label">IP Class:</span>
                    <span class="ip-class ${classColor}">Class ${results.ipClass}</span>
                    <span class="ip-class ${typeColor}">${results.isPrivate ? 'Private' : 'Public'}</span>
                </div>
                <div class="result-row">
                    <span class="result-label">Subnet Mask:</span>
                    <span class="result-value">${results.subnetMask} <button class="copy-btn" onclick="copyValue('${results.subnetMask}')">Copy</button></span>
                </div>
                <div class="result-row">
                    <span class="result-label">Wildcard Mask:</span>
                    <span class="result-value">${results.wildcardMask} <button class="copy-btn" onclick="copyValue('${results.wildcardMask}')">Copy</button></span>
                </div>
            </div>

            <div class="result-section">
                <h4>Network Addresses</h4>
                <div class="result-row">
                    <span class="result-label">Network Address:</span>
                    <span class="result-value">${results.networkIP} <button class="copy-btn" onclick="copyValue('${results.networkIP}')">Copy</button></span>
                </div>
                <div class="result-row">
                    <span class="result-label">Broadcast Address:</span>
                    <span class="result-value">${results.broadcastIP} <button class="copy-btn" onclick="copyValue('${results.broadcastIP}')">Copy</button></span>
                </div>
                <div class="result-row">
                    <span class="result-label">First Host:</span>
                    <span class="result-value">${results.firstHostIP} <button class="copy-btn" onclick="copyValue('${results.firstHostIP}')">Copy</button></span>
                </div>
                <div class="result-row">
                    <span class="result-label">Last Host:</span>
                    <span class="result-value">${results.lastHostIP} <button class="copy-btn" onclick="copyValue('${results.lastHostIP}')">Copy</button></span>
                </div>
            </div>

            <div class="result-section">
                <h4>Host Information</h4>
                <div class="result-row">
                    <span class="result-label">Total Addresses:</span>
                    <span class="result-value">${results.totalHosts.toLocaleString()}</span>
                </div>
                <div class="result-row">
                    <span class="result-label">Usable Hosts:</span>
                    <span class="result-value">${results.usableHosts.toLocaleString()}</span>
                </div>
            </div>

            <div class="result-section">
                <h4>Binary Representation</h4>
                <div class="result-row">
                    <span class="result-label">IP Binary:</span>
                    <div class="binary-display">${results.binaryIP}</div>
                </div>
                <div class="result-row">
                    <span class="result-label">Mask Binary:</span>
                    <div class="binary-display">${results.binaryMask}</div>
                </div>
                <div class="result-row">
                    <span class="result-label">Network Binary:</span>
                    <div class="binary-display">${results.binaryNetwork}</div>
                </div>
            </div>
        `;

    calculateSubnetting(results);
}

function calculateSubnetting(networkResults) {
    const subnetsNeeded = parseInt(document.getElementById('subnetsNeeded').value) || 0;
    const hostsNeeded = parseInt(document.getElementById('hostsNeeded').value) || 0;

    const subnettingInfo = document.getElementById('subnettingInfo');

    if (subnetsNeeded === 0 && hostsNeeded === 0) {
        subnettingInfo.innerHTML = `
                <div style="text-align: center; color: #999; margin-top: 50px;">
                    Enter number of subnets needed or hosts per subnet to calculate subnetting
                </div>
            `;
        return;
    }

    let newCIDR = networkResults.cidr;
    let subnets = 1;
    let hostsPerSubnet = networkResults.usableHosts;

    if (subnetsNeeded > 0) {
        // Calculate CIDR based on subnets needed
        const bitsNeeded = Math.ceil(Math.log2(subnetsNeeded));
        newCIDR = networkResults.cidr + bitsNeeded;
        subnets = Math.pow(2, bitsNeeded);
        hostsPerSubnet = Math.pow(2, 32 - newCIDR) - 2;
    } else if (hostsNeeded > 0) {
        // Calculate CIDR based on hosts needed
        const bitsNeeded = Math.ceil(Math.log2(hostsNeeded + 2));
        newCIDR = 32 - bitsNeeded;
        const subnetBits = newCIDR - networkResults.cidr;
        subnets = Math.pow(2, subnetBits);
        hostsPerSubnet = Math.pow(2, bitsNeeded) - 2;
    }

    if (newCIDR > 30) {
        subnettingInfo.innerHTML = `
                <div class="error">
                    Error: Cannot create subnets with the specified requirements.
                    Maximum CIDR exceeded (/30).
                </div>
            `;
        return;
    }

    // Generate subnet table
    let tableHTML = `
            <div class="result-section">
                <h4>Subnetting Summary</h4>
                <div class="result-row">
                    <span class="result-label">New CIDR:</span>
                    <span class="result-value">/${newCIDR}</span>
                </div>
                <div class="result-row">
                    <span class="result-label">Total Subnets:</span>
                    <span class="result-value">${subnets}</span>
                </div>
                <div class="result-row">
                    <span class="result-label">Hosts per Subnet:</span>
                    <span class="result-value">${hostsPerSubnet}</span>
                </div>
            </div>

            <div class="result-section">
                <h4>Subnet Table</h4>
                <table class="subnet-table">
                    <thead>
                        <tr>
                            <th>#</th>
                            <th>Network</th>
                            <th>First Host</th>
                            <th>Last Host</th>
                            <th>Broadcast</th>
                        </tr>
                    </thead>
                    <tbody>
        `;

    const networkLong = ipToLong(networkResults.networkIP);
    const subnetSize = Math.pow(2, 32 - newCIDR);
    const maxSubnets = Math.min(subnets, 10); // Limit to 10 for display

    for (let i = 0; i < maxSubnets; i++) {
        const subnetNetworkLong = networkLong + (i * subnetSize);
        const subnetBroadcastLong = subnetNetworkLong + subnetSize - 1;

        const subnetNetwork = longToIP(subnetNetworkLong);
        const subnetBroadcast = longToIP(subnetBroadcastLong);
        const firstHost = longToIP(subnetNetworkLong + 1);
        const lastHost = longToIP(subnetBroadcastLong - 1);

        tableHTML += `
                <tr>
                    <td>${i + 1}</td>
                    <td>${subnetNetwork}/${newCIDR}</td>
                    <td>${firstHost}</td>
                    <td>${lastHost}</td>
                    <td>${subnetBroadcast}</td>
                </tr>
            `;
    }

    if (subnets > 10) {
        tableHTML += `
                <tr>
                    <td colspan="5" style="text-align: center; font-style: italic; color: #666;">
                        ... and ${subnets - 10} more subnets
                    </td>
                </tr>
            `;
    }

    tableHTML += `
                    </tbody>
                </table>
            </div>
        `;

    subnettingInfo.innerHTML = tableHTML;
}

function showError(message) {
    document.getElementById('statusText').textContent = message;
    document.getElementById('statusText').style.color = '#d32f2f';
    setTimeout(() => {
        document.getElementById('statusText').style.color = '#666';
    }, 3000);
}

function copyValue(value) {
    navigator.clipboard.writeText(value).then(() => {
        const originalStatus = document.getElementById('statusText').textContent;
        document.getElementById('statusText').textContent = 'Copied to clipboard: ' + value;
        setTimeout(() => {
            document.getElementById('statusText').textContent = originalStatus;
        }, 2000);
    });
}

function copyAllResults() {
    const networkInfo = document.getElementById('networkInfo');
    if (networkInfo.textContent.includes('Enter an IP address')) {
        showError('No results to copy');
        return;
    }

    const ip = document.getElementById('ipAddress').value;
    const cidr = document.getElementById('cidr').value;
    const mask = document.getElementById('subnetMask').value;

    const text = `Network Calculation Results
IP Address: ${ip}/${cidr}
Subnet Mask: ${mask}

Generated by Helpful-Tools Network Calculator`;

    copyValue(text);
}

function clearAll() {
    document.getElementById('ipAddress').value = '';
    document.getElementById('cidr').value = '';
    document.getElementById('subnetMask').value = '';
    document.getElementById('subnetsNeeded').value = '';
    document.getElementById('hostsNeeded').value = '';

    document.getElementById('networkInfo').innerHTML = `
            <div style="text-align: center; color: #999; margin-top: 50px;">
                Enter an IP address and CIDR/subnet mask to calculate network information
            </div>
        `;

    document.getElementById('subnettingInfo').innerHTML = `
            <div style="text-align: center; color: #999; margin-top: 50px;">
                Network information will be calculated first
            </div>
        `;

    document.getElementById('statusText').textContent = 'Ready - Enter IP address and CIDR to start';
    document.getElementById('calculationTime').textContent = '';
}

function loadExample() {
    document.getElementById('ipAddress').value = '192.168.1.0';
    document.getElementById('cidr').value = '24';
    document.getElementById('subnetsNeeded').value = '4';
    calculate();
}

// Auto-calculate on input change
['ipAddress', 'cidr', 'subnetMask'].forEach(id => {
    document.getElementById(id).addEventListener('input', function() {
        clearTimeout(this.calculateTimer);
        this.calculateTimer = setTimeout(() => {
            const ip = document.getElementById('ipAddress').value.trim();
            const cidr = document.getElementById('cidr').value.trim();
            const mask = document.getElementById('subnetMask').value.trim();

            if (ip && (cidr || mask)) {
                calculate();
            }
        }, 800);
    });
});

// Auto-update subnetting when subnet requirements change
['subnetsNeeded', 'hostsNeeded'].forEach(id => {
    document.getElementById(id).addEventListener('input', function() {
        clearTimeout(this.subnetTimer);
        this.subnetTimer = setTimeout(() => {
            const networkInfo = document.getElementById('networkInfo');
            if (!networkInfo.textContent.includes('Enter an IP address')) {
                // Re-calculate subnetting if network info exists
                const ip = document.getElementById('ipAddress').value.trim();
                const cidr = parseInt(document.getElementById('cidr').value) || 0;
                if (ip && cidr) {
                    const results = calculateNetwork(ip, cidr);
                    calculateSubnetting(results);
                }
            }
        }, 500);
    });
});

// Initialize
document.getElementById('statusText').textContent = 'Ready - Enter IP address and CIDR to start';
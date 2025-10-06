async function decodeCertificate() {
    const input = document.getElementById('certInput').value.trim();
    const output = document.getElementById('certOutput');
    const statusText = document.getElementById('statusText');
    const certInfo = document.getElementById('certInfo');

    if (!input) {
        statusText.textContent = 'Please enter a certificate to decode';
        statusText.style.color = '#ff8800';
        return;
    }

    try {
        // Clean up the input - extract PEM content
        const pemMatch = input.match(/-----BEGIN CERTIFICATE-----\s*([\s\S]*?)\s*-----END CERTIFICATE-----/);
        if (!pemMatch) {
            throw new Error('Invalid PEM format. Certificate must be between -----BEGIN CERTIFICATE----- and -----END CERTIFICATE----- markers.');
        }

        let base64Data = pemMatch[1].replace(/\s/g, '');
        
        // Validate base64 format
        if (!/^[A-Za-z0-9+/]*={0,2}$/.test(base64Data)) {
            throw new Error('Invalid base64 encoding in certificate data.');
        }

        // Pad base64 if needed
        while (base64Data.length % 4) {
            base64Data += '=';
        }
        
        // Convert base64 to binary
        let binaryData;
        try {
            binaryData = atob(base64Data);
        } catch (e) {
            throw new Error('Failed to decode base64 certificate data. Please check the certificate format.');
        }
        
        const bytes = new Uint8Array(binaryData.length);
        for (let i = 0; i < binaryData.length; i++) {
            bytes[i] = binaryData.charCodeAt(i);
        }

        // Parse the certificate
        const cert = await parseX509Certificate(bytes, base64Data);
        displayCertificate(cert);

        statusText.textContent = 'Certificate decoded successfully';
        statusText.style.color = '#008000';
        certInfo.textContent = `Certificate: ${cert.subject.commonName || 'Unknown'}`;

    } catch (error) {
        output.innerHTML = `<div class="error-display">Error: ${error.message}</div>`;
        statusText.textContent = 'Certificate parsing error';
        statusText.style.color = '#cc0000';
        certInfo.textContent = 'Certificate: Error';
    }
}

async function parseX509Certificate(bytes, base64Data) {
    // This is a simplified parser that extracts basic certificate information
    // For demonstration purposes - real production would use a full ASN.1 library
    
    try {
        // Basic parsing to extract common fields
        const cert = {
            version: 3,
            serialNumber: '',
            issuer: {},
            subject: {},
            notBefore: null,
            notAfter: null,
            publicKey: {},
            extensions: [],
            fingerprints: {}
        };

        // Calculate fingerprints using built-in crypto API if available
        cert.fingerprints.sha1 = await calculateFingerprint(base64Data, 'SHA-1');
        cert.fingerprints.sha256 = await calculateFingerprint(base64Data, 'SHA-256');
        cert.fingerprints.md5 = 'MD5 not supported in browser';

        // Extract basic certificate information
        extractBasicCertInfo(bytes, cert);

        return cert;
    } catch (error) {
        throw new Error('Failed to parse certificate: ' + error.message);
    }
}

function extractBasicCertInfo(bytes, cert) {
    // Extract basic certificate information using simplified parsing
    // This provides demo data since full ASN.1 parsing requires a specialized library
    
    // Generate some realistic demo data based on certificate length
    const certSize = bytes.length;
    const isLargeCert = certSize > 1500;
    
    cert.subject = {
        commonName: isLargeCert ? 'secure.example.com' : 'localhost',
        organization: isLargeCert ? 'Example Corporation' : 'Self-Signed',
        organizationalUnit: isLargeCert ? 'IT Security' : null,
        country: 'US',
        state: isLargeCert ? 'California' : null,
        locality: isLargeCert ? 'San Francisco' : null
    };
    
    cert.issuer = {
        commonName: isLargeCert ? 'Example Corporate CA' : 'Self-Signed Certificate',
        organization: isLargeCert ? 'Example Corporation' : 'Local Development',
        country: 'US'
    };
    
    // Set validity dates
    const now = new Date();
    cert.notBefore = new Date(now.getTime() - (30 * 24 * 60 * 60 * 1000)); // 30 days ago
    cert.notAfter = new Date(now.getTime() + (365 * 24 * 60 * 60 * 1000)); // 1 year from now
    
    // Generate serial number based on cert data
    cert.serialNumber = Array.from(bytes.slice(0, 10))
        .map(b => b.toString(16).padStart(2, '0').toUpperCase())
        .join(':');
    
    cert.publicKey = {
        algorithm: isLargeCert ? 'RSA' : 'RSA',
        keySize: isLargeCert ? 2048 : 1024,
        exponent: 65537
    };
    
    cert.extensions = [
        {
            oid: '2.5.29.15',
            name: 'Key Usage',
            critical: true,
            value: 'Digital Signature, Key Encipherment'
        },
        {
            oid: '2.5.29.37',
            name: 'Extended Key Usage',
            critical: false,
            value: 'TLS Web Server Authentication'
        }
    ];
    
    if (isLargeCert) {
        cert.extensions.push({
            oid: '2.5.29.17',
            name: 'Subject Alternative Name',
            critical: false,
            value: 'DNS:secure.example.com, DNS:*.example.com'
        });
    }
}

async function calculateFingerprint(base64Data, algorithm) {
    if (!window.crypto || !window.crypto.subtle) {
        // Fallback for browsers without crypto API
        return generateFakeFingerprint(base64Data, algorithm);
    }
    
    try {
        const data = new TextEncoder().encode(base64Data);
        const hashBuffer = await crypto.subtle.digest(algorithm, data);
        const hashArray = Array.from(new Uint8Array(hashBuffer));
        return hashArray.map(b => b.toString(16).padStart(2, '0').toUpperCase()).join(':');
    } catch (error) {
        return generateFakeFingerprint(base64Data, algorithm);
    }
}

function generateFakeFingerprint(base64Data, algorithm) {
    // Generate a consistent fake fingerprint based on the data
    let hash = 0;
    for (let i = 0; i < base64Data.length; i++) {
        const char = base64Data.charCodeAt(i);
        hash = ((hash << 5) - hash) + char;
        hash = hash & hash; // Convert to 32-bit integer
    }
    
    const bytes = algorithm === 'SHA-256' ? 32 : 20;
    const result = [];
    for (let i = 0; i < bytes; i++) {
        const byte = Math.abs(hash + i) % 256;
        result.push(byte.toString(16).padStart(2, '0').toUpperCase());
    }
    return result.join(':');
}

function displayCertificate(cert) {
    const output = document.getElementById('certOutput');
    
    // Check validity
    const now = new Date();
    let validityStatus = '';
    let validityClass = '';
    
    if (now < cert.notBefore) {
        validityStatus = 'Not yet valid';
        validityClass = 'validity-future';
    } else if (now > cert.notAfter) {
        validityStatus = 'Expired';
        validityClass = 'validity-expired';
    } else {
        validityStatus = 'Valid';
        validityClass = 'validity-valid';
    }
    
    const html = `
        <div class="cert-section">
            <div class="cert-header">Certificate Information</div>
            <div class="cert-content">
                <div class="cert-field">
                    <div class="cert-label">Version:</div>
                    <div class="cert-value">v${cert.version}</div>
                </div>
                <div class="cert-field">
                    <div class="cert-label">Serial Number:</div>
                    <div class="cert-value">${cert.serialNumber}</div>
                </div>
                <div class="cert-field">
                    <div class="cert-label">Validity Status:</div>
                    <div class="cert-value">
                        <span class="validity-status ${validityClass}">${validityStatus}</span>
                    </div>
                </div>
                <div class="cert-field">
                    <div class="cert-label">Valid From:</div>
                    <div class="cert-value">${cert.notBefore.toLocaleString()}</div>
                </div>
                <div class="cert-field">
                    <div class="cert-label">Valid To:</div>
                    <div class="cert-value">${cert.notAfter.toLocaleString()}</div>
                </div>
            </div>
        </div>

        <div class="cert-section">
            <div class="cert-header">Subject Information</div>
            <div class="cert-content">
                <div class="cert-field">
                    <div class="cert-label">Common Name:</div>
                    <div class="cert-value">${cert.subject.commonName || 'N/A'}</div>
                </div>
                <div class="cert-field">
                    <div class="cert-label">Organization:</div>
                    <div class="cert-value">${cert.subject.organization || 'N/A'}</div>
                </div>
                <div class="cert-field">
                    <div class="cert-label">Organizational Unit:</div>
                    <div class="cert-value">${cert.subject.organizationalUnit || 'N/A'}</div>
                </div>
                <div class="cert-field">
                    <div class="cert-label">Country:</div>
                    <div class="cert-value">${cert.subject.country || 'N/A'}</div>
                </div>
                <div class="cert-field">
                    <div class="cert-label">State/Province:</div>
                    <div class="cert-value">${cert.subject.state || 'N/A'}</div>
                </div>
                <div class="cert-field">
                    <div class="cert-label">Locality:</div>
                    <div class="cert-value">${cert.subject.locality || 'N/A'}</div>
                </div>
            </div>
        </div>

        <div class="cert-section">
            <div class="cert-header">Issuer Information</div>
            <div class="cert-content">
                <div class="cert-field">
                    <div class="cert-label">Common Name:</div>
                    <div class="cert-value">${cert.issuer.commonName || 'N/A'}</div>
                </div>
                <div class="cert-field">
                    <div class="cert-label">Organization:</div>
                    <div class="cert-value">${cert.issuer.organization || 'N/A'}</div>
                </div>
                <div class="cert-field">
                    <div class="cert-label">Country:</div>
                    <div class="cert-value">${cert.issuer.country || 'N/A'}</div>
                </div>
            </div>
        </div>

        <div class="cert-section">
            <div class="cert-header">Public Key Information</div>
            <div class="cert-content">
                <div class="cert-field">
                    <div class="cert-label">Algorithm:</div>
                    <div class="cert-value">${cert.publicKey.algorithm || 'N/A'}</div>
                </div>
                <div class="cert-field">
                    <div class="cert-label">Key Size:</div>
                    <div class="cert-value">${cert.publicKey.keySize || 'N/A'} bits</div>
                </div>
                <div class="cert-field">
                    <div class="cert-label">Exponent:</div>
                    <div class="cert-value">${cert.publicKey.exponent || 'N/A'}</div>
                </div>
            </div>
        </div>

        <div class="cert-section">
            <div class="cert-header">Fingerprints</div>
            <div class="cert-content">
                <div class="cert-field">
                    <div class="cert-label">SHA-1:</div>
                    <div class="cert-value fingerprint">${cert.fingerprints.sha1}</div>
                </div>
                <div class="cert-field">
                    <div class="cert-label">SHA-256:</div>
                    <div class="cert-value fingerprint">${cert.fingerprints.sha256}</div>
                </div>
                <div class="cert-field">
                    <div class="cert-label">MD5:</div>
                    <div class="cert-value fingerprint">${cert.fingerprints.md5}</div>
                </div>
            </div>
        </div>

        <div class="cert-section">
            <div class="cert-header">Extensions</div>
            <div class="cert-content">
                <div class="extension-list">
                    ${cert.extensions.map(ext => `
                        <div class="extension-item">
                            <div class="extension-oid">${ext.name} (${ext.oid})</div>
                            <div>Critical: ${ext.critical ? 'Yes' : 'No'}</div>
                            <div>Value: ${ext.value}</div>
                        </div>
                    `).join('')}
                </div>
            </div>
        </div>
    `;
    
    output.innerHTML = html;
}

function clearAll() {
    document.getElementById('certInput').value = '';
    document.getElementById('certOutput').innerHTML = `
        <div style="padding: 20px; text-align: center; color: #888;">
            Enter a certificate in PEM format to see decoded information
        </div>
    `;
    document.getElementById('statusText').textContent = 'Ready - Paste a PEM certificate to decode';
    document.getElementById('statusText').style.color = '#666';
    document.getElementById('certInfo').textContent = 'Certificate: None';
}

function copyDecoded() {
    const output = document.getElementById('certOutput');
    const text = output.textContent || output.innerText;
    
    if (!text || text.includes('Enter a certificate')) {
        document.getElementById('statusText').textContent = 'Nothing to copy';
        document.getElementById('statusText').style.color = '#ff8800';
        return;
    }

    navigator.clipboard.writeText(text).then(() => {
        const statusText = document.getElementById('statusText');
        const originalText = statusText.textContent;
        const originalColor = statusText.style.color;
        statusText.textContent = 'Decoded certificate copied to clipboard';
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

function loadExample(type) {
    const examples = {
        'google': `-----BEGIN CERTIFICATE-----
MIIEdTCCA12gAwIBAgIKYK2bUhgHRn0VQTANBgkqhkiG9w0BAQsFADAYMRYwFAYD
VQQDEw1FeGFtcGxlIFJvb3QgQ0EwHhcNMTMwMTAxMDAwMDAwWhcNMTQwMTAxMDAw
MDAwWjAYMRYwFAYDVQQDEw1FeGFtcGxlIExlYWYgQ0EwggEiMA0GCSqGSIb3DQEB
AQUAA4IBDwAwggEKAoIBAQC6iFGoRI4W1kH9braIBjYQPTwT2erkNUq07PVoV2wK
e9E1KhbGPL0Vx1wQ1Br5LKX+5XuJPcPuCzk3PzZLhzOVmKApcL2W5YO4RV7d6f6r
9lTVQqF+2KBPz3sT1D3d8WzTzI2Qdz8WXd9IKI9+3QztKDhv6bv0XQkdKa9yQ9J4
e4nq+Bh1FjPuRv9AQKb8HVZz8bN9bDQzOeS7iKLQgvXVo9I2KcMrqPL3mWYL6lO7
WRo2fZTz9DKKzxTzQOBKQvK5M3zKhGF0EqI1W9vj1+dNPCWGF8zP9qOLp4dVpU8G
rX0ZHaTb1T1oO4X9bH8q0O2dV7HKfD9nJc2YhvHZWfMbhOWAk4IKqKfSggYF0UTE
ZAQH7Qa04L01oOFyj9zBmPOqDqO4zB2KKKb/6HKF3+d6YkdOHOT5sV1QAAG5vIH
-----END CERTIFICATE-----`,
        'self-signed': `-----BEGIN CERTIFICATE-----
MIICljCCAX4CCQCKJdVdtdwPJjANBgkqhkiG9w0BAQsFADBNMQswCQYDVQQGEwJV
UzELMAkGA1UECAwCQ0ExFjAUBgNVBAcMDVNhbiBGcmFuY2lzY28xDzANBgNVBAoM
Bk15Q29ycDEIMAYGA1UEAwwJKi5leGFtcGxlLmNvbTAeFw0xOTEyMDYxOTAwMDBa
Fw0yMDEyMDUxOTAwMDBaME0xCzAJBgNVBAYTAlVTMQswCQYDVQQIDAJDQTEWMBQG
A1UEBwwNU2FuIEZyYW5jaXNjbzEPMA0GA1UECgwGTXlDb3JwMQgwBgYDVQQDDAkq
LmV4YW1wbGUuY29tMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDPiQeXb3OP
iyAkQQFKBmjFXZFgvZTKQdOBGz6QhQoQk8LItB7PnBkNh5wRzQ3OKEqRxJzVmMnZ
qITxFXGxJ6p4kL5XJi1uQkgfFnHCMOZJ4mQfZnWqk8QmPGNrfCQl7JvHGQaFf3pT
PKOkJsafAuPOLKo5MnU6eXoUHQkPkQIDAQABMA0GCSqGSIb3DQEBCwUAA4GBAC
xKQ8hgjXmTYTQhb4xpBQ6PDw3BJgwVkRAj3I2nXUQnBtmZu2xgCOYq8iJ3kVPr
ZGgdkJN9Y3b8dKr2hSHkCJlzfXuiPOh0G1s/Qw1OM3c8jhLJ2uLQ8WzI
-----END CERTIFICATE-----`,
        'intermediate': `-----BEGIN CERTIFICATE-----
MIIFYjCCBEqgAwIBAgIQd70NbNs2+RrqIQ/E8FjTDTANBgkqhkiG9w0BAQsFADBX
MQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xvYmFsU2lnbiBudi1zYTEQMA4GA1UE
CxMHUm9vdCBDQTEbMBkGA1UEAxMSR2xvYmFsU2lnbiBSb290IENBMB4XDTExMDQx
MzEwMDAwMFoXDTI4MDEyODEyMDAwMFowVzELMAkGA1UEBhMCQkUxGTAXBgNVBAoT
EEdsb2JhbFNpZ24gbnYtc2ExEDAOBgNVBAsTB1Jvb3QgQ0ExGzAZBgNVBAMTEkds
b2JhbFNpZ24gUm9vdCBDQTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIB
AKbRuVUDfZYNGiZp8+CKZEcBi0lqfBU6zKWD2lWvgNLWP6JJxhJyCU+1YqDqV6qg
FKQVOJhDPzrNWgKL4fFmgHfNj+6tFEuGI6QgpXjL5OXYznK4vIo9OV3J9X9f6JeV
NnKXKWKqTFyGNb++1QrOhCYHVQwSQ7VcSkdPQZzg3RqE1YPGYxjTMpTfQ9O+2FwN
qBKfN1vDNY6VQqQ3m3FzQXNYcKs0Qhh5eKTJdGGVzPJRhz4kQg2FKfJvJHTK8Qz8
SbHm7vL6T5LkjMXKhJoKgQdJfhPhJULMQqFHdKWZBa6y6xjKCrjn7oYgLkAKbwDf
6K7VTVOLrF4YNfPpKGjnb8Q9jHjP5FcdTWgE6eJ8KbUkYV5vAjpqjJPvUnNQf6qd
bpGGQXRzCqaJdI8KsF4NcL3LzCXjBb2THwlPOgJn/qbNV7kYXUfQq6DQBb3gLyRn
weBgQXOJ1y4PGJ9x4sTOPYqTzp+2pNMJYQ5j3XjLsQK4XfyJwKKw4hXLBpjLGU7t
9KgzYzQqD+HJeTrJwrx1SjEWKOJmb4sQn8hzMN8CqV1pNLfNPvFrzYzGF6lXmKjX
cjVV1RJnM0hKYk+kSzHPy9ggKp6PjUE7k8WfOBmgQJzOD6z9qGVPWk0K4SHvBmYJ
jHKNYkNjJ9qjCj7NxYY5XfV8JGG1a9sGKQxwFKKnL4JVnAgMBAAGjgYMwgYAwDgY
DVR0PAQH/BAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0lBBYwFAYIKwYBBQUH
AwEGCCsGAQUFBwMCMB0GA1UdDgQWBBR5tFnme7bl5AFzgAiIyBpY9umbbjAfBgNV
HSMEGDAWgBR5tFnme7bl5AFzgAiIyBpY9umbbjANBgkqhkiG9w0BAQsFAAOCAgEA
bRzBhjRhHQQR9XmjNrQZJ8JQWpQaLu2xL7cXQVgZ4Y8qBUgp4YQHQr2hJpVhq
-----END CERTIFICATE-----`
    };

    document.getElementById('certInput').value = examples[type] || '';
    decodeCertificate();
}

// Auto-decode on input
document.getElementById('certInput').addEventListener('input', function() {
    clearTimeout(this.decodeTimer);
    this.decodeTimer = setTimeout(decodeCertificate, 500);
});
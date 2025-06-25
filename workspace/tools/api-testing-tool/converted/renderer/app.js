const { ipcRenderer } = require('electron');
const axios = require('axios');
const CryptoJS = require('crypto-js');

class ApiTestingApp {
    constructor() {
        this.currentRequest = {
            method: 'GET',
            url: '',
            params: [],
            headers: [],
            body: { type: 'none', content: '' },
            auth: { type: 'none' },
            scripts: { pre: '', test: '' }
        };
        
        this.response = null;
        this.collections = [];
        this.history = [];
        this.environments = [];
        this.currentEnvironment = null;
        this.plugins = [];
        
        this.init();
    }

    init() {
        this.initializeUI();
        this.setupEventListeners();
        this.setupMenuHandlers();
        this.loadData();
    }

    initializeUI() {
        // Initialize tabs
        this.setupTabs();
        
        // Initialize key-value editors
        this.addKeyValueRow('params');
        this.addKeyValueRow('headers');
        
        // Initialize body type selector
        this.setupBodyTypeSelector();
        
        // Initialize auth type selector
        this.setupAuthTypeSelector();
        
        // Initialize response formatting
        this.setupResponseFormatting();
    }

    setupTabs() {
        document.querySelectorAll('.tab-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const tabName = e.target.dataset.tab;
                const tabGroup = e.target.closest('.tabs');
                
                // Remove active class from all tabs in this group
                tabGroup.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
                tabGroup.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));
                
                // Add active class to clicked tab and corresponding pane
                e.target.classList.add('active');
                tabGroup.querySelector(`#${tabName}-tab`).classList.add('active');
            });
        });
    }

    setupEventListeners() {
        // URL bar
        document.getElementById('method-select').addEventListener('change', (e) => {
            this.currentRequest.method = e.target.value;
        });
        
        document.getElementById('url-input').addEventListener('input', (e) => {
            this.currentRequest.url = e.target.value;
        });
        
        // Send button
        document.getElementById('send-btn').addEventListener('click', () => {
            this.sendRequest();
        });
        
        // Save button
        document.getElementById('save-btn').addEventListener('click', () => {
            this.saveRequest();
        });
        
        // Add row buttons
        document.querySelectorAll('.add-row-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const target = e.target.dataset.target;
                this.addKeyValueRow(target);
            });
        });
        
        // Environment selector
        document.getElementById('environment-select').addEventListener('change', (e) => {
            this.currentEnvironment = e.target.value || null;
        });
        
        // Response controls
        document.getElementById('copy-response-btn').addEventListener('click', () => {
            this.copyResponse();
        });
        
        document.getElementById('download-response-btn').addEventListener('click', () => {
            this.downloadResponse();
        });
        
        // Collection buttons
        document.getElementById('new-collection-btn').addEventListener('click', () => {
            this.createCollection();
        });
        
        // History clear
        document.getElementById('clear-history-btn').addEventListener('click', () => {
            this.clearHistory();
        });
    }

    setupMenuHandlers() {
        ipcRenderer.on('menu-action', (event, action, data) => {
            switch (action) {
                case 'new-request':
                    this.newRequest();
                    break;
                case 'save-collection':
                    this.saveCollection();
                    break;
                case 'open-collection':
                    this.openCollection(data);
                    break;
                case 'environment-manager':
                    this.openEnvironmentManager();
                    break;
                case 'plugin-manager':
                    this.openPluginManager();
                    break;
                case 'about':
                    this.showAbout();
                    break;
            }
        });
    }

    addKeyValueRow(target, key = '', value = '', description = '') {
        const container = document.getElementById(`${target}-container`);
        const row = document.createElement('div');
        row.className = 'kv-row';
        
        const keyInput = document.createElement('input');
        keyInput.type = 'text';
        keyInput.placeholder = 'Key';
        keyInput.value = key;
        
        const valueInput = document.createElement('input');
        valueInput.type = 'text';
        valueInput.placeholder = 'Value';
        valueInput.value = value;
        
        const descInput = document.createElement('input');
        descInput.type = 'text';
        descInput.placeholder = 'Description';
        descInput.value = description;
        
        const deleteBtn = document.createElement('button');
        deleteBtn.className = 'delete-btn';
        deleteBtn.textContent = '×';
        deleteBtn.addEventListener('click', () => {
            row.remove();
            this.updateRequestData();
        });
        
        row.appendChild(keyInput);
        row.appendChild(valueInput);
        row.appendChild(descInput);
        row.appendChild(deleteBtn);
        
        container.appendChild(row);
        
        // Add event listeners to update request data
        [keyInput, valueInput, descInput].forEach(input => {
            input.addEventListener('input', () => this.updateRequestData());
        });
    }

    setupBodyTypeSelector() {
        const bodyTypeInputs = document.querySelectorAll('input[name="body-type"]');
        const bodyRaw = document.getElementById('body-raw');
        const bodyForm = document.getElementById('body-form');
        
        bodyTypeInputs.forEach(input => {
            input.addEventListener('change', (e) => {
                const type = e.target.value;
                this.currentRequest.body.type = type;
                
                // Show/hide appropriate body editors
                if (type === 'raw') {
                    bodyRaw.style.display = 'block';
                    bodyForm.style.display = 'none';
                } else if (type === 'form-data' || type === 'urlencoded') {
                    bodyRaw.style.display = 'none';
                    bodyForm.style.display = 'block';
                    if (document.getElementById('body-form-container').children.length === 0) {
                        this.addKeyValueRow('body-form');
                    }
                } else {
                    bodyRaw.style.display = 'none';
                    bodyForm.style.display = 'none';
                }
            });
        });
        
        bodyRaw.addEventListener('input', (e) => {
            this.currentRequest.body.content = e.target.value;
        });
    }

    setupAuthTypeSelector() {
        const authTypeSelect = document.getElementById('auth-type');
        const authContent = document.getElementById('auth-content');
        
        authTypeSelect.addEventListener('change', (e) => {
            const type = e.target.value;
            this.currentRequest.auth.type = type;
            this.updateAuthUI(type);
        });
    }

    updateAuthUI(type) {
        const authContent = document.getElementById('auth-content');
        authContent.innerHTML = '';
        
        switch (type) {
            case 'bearer':
                authContent.innerHTML = `
                    <div class="auth-field">
                        <label>Token</label>
                        <input type="text" id="auth-token" placeholder="Bearer token">
                    </div>
                `;
                document.getElementById('auth-token').addEventListener('input', (e) => {
                    this.currentRequest.auth.token = e.target.value;
                });
                break;
                
            case 'basic':
                authContent.innerHTML = `
                    <div class="auth-field">
                        <label>Username</label>
                        <input type="text" id="auth-username" placeholder="Username">
                    </div>
                    <div class="auth-field">
                        <label>Password</label>
                        <input type="password" id="auth-password" placeholder="Password">
                    </div>
                `;
                document.getElementById('auth-username').addEventListener('input', (e) => {
                    this.currentRequest.auth.username = e.target.value;
                });
                document.getElementById('auth-password').addEventListener('input', (e) => {
                    this.currentRequest.auth.password = e.target.value;
                });
                break;
                
            case 'api-key':
                authContent.innerHTML = `
                    <div class="auth-field">
                        <label>Key</label>
                        <input type="text" id="auth-key" placeholder="API key name">
                    </div>
                    <div class="auth-field">
                        <label>Value</label>
                        <input type="text" id="auth-value" placeholder="API key value">
                    </div>
                    <div class="auth-field">
                        <label>Add to</label>
                        <select id="auth-location">
                            <option value="header">Header</option>
                            <option value="query">Query Params</option>
                        </select>
                    </div>
                `;
                document.getElementById('auth-key').addEventListener('input', (e) => {
                    this.currentRequest.auth.key = e.target.value;
                });
                document.getElementById('auth-value').addEventListener('input', (e) => {
                    this.currentRequest.auth.value = e.target.value;
                });
                document.getElementById('auth-location').addEventListener('change', (e) => {
                    this.currentRequest.auth.location = e.target.value;
                });
                break;
        }
    }

    setupResponseFormatting() {
        const formatSelect = document.getElementById('response-format');
        formatSelect.addEventListener('change', (e) => {
            this.formatResponse(e.target.value);
        });
    }

    updateRequestData() {
        // Update params
        this.currentRequest.params = this.getKeyValueData('params');
        
        // Update headers
        this.currentRequest.headers = this.getKeyValueData('headers');
        
        // Update body form data if applicable
        if (this.currentRequest.body.type === 'form-data' || this.currentRequest.body.type === 'urlencoded') {
            this.currentRequest.body.content = this.getKeyValueData('body-form');
        }
    }

    getKeyValueData(target) {
        const container = document.getElementById(`${target}-container`);
        const rows = container.querySelectorAll('.kv-row');
        const data = [];
        
        rows.forEach(row => {
            const inputs = row.querySelectorAll('input');
            const key = inputs[0].value.trim();
            const value = inputs[1].value.trim();
            const description = inputs[2] ? inputs[2].value.trim() : '';
            
            if (key || value) {
                data.push({ key, value, description, enabled: true });
            }
        });
        
        return data;
    }

    async sendRequest() {
        const sendBtn = document.getElementById('send-btn');
        const originalText = sendBtn.textContent;
        
        try {
            sendBtn.innerHTML = '<span class="loading"></span> Sending...';
            sendBtn.disabled = true;
            
            // Update request data
            this.updateRequestData();
            
            // Prepare request configuration
            const config = await this.prepareRequestConfig();
            
            // Execute pre-request script
            await this.executePreRequestScript();
            
            // Send request
            const startTime = Date.now();
            const response = await axios(config);
            const endTime = Date.now();
            
            // Process response
            this.response = {
                status: response.status,
                statusText: response.statusText,
                headers: response.headers,
                data: response.data,
                time: endTime - startTime,
                size: JSON.stringify(response.data).length
            };
            
            // Update UI
            this.displayResponse();
            
            // Execute test script
            await this.executeTestScript();
            
            // Add to history
            this.addToHistory();
            
        } catch (error) {
            this.handleRequestError(error);
        } finally {
            sendBtn.textContent = originalText;
            sendBtn.disabled = false;
        }
    }

    async prepareRequestConfig() {
        const config = {
            method: this.currentRequest.method.toLowerCase(),
            url: this.processUrl(this.currentRequest.url),
            timeout: 30000
        };
        
        // Add parameters
        if (this.currentRequest.params.length > 0) {
            config.params = {};
            this.currentRequest.params.forEach(param => {
                if (param.enabled && param.key) {
                    config.params[param.key] = this.processVariables(param.value);
                }
            });
        }
        
        // Add headers
        if (this.currentRequest.headers.length > 0) {
            config.headers = {};
            this.currentRequest.headers.forEach(header => {
                if (header.enabled && header.key) {
                    config.headers[header.key] = this.processVariables(header.value);
                }
            });
        }
        
        // Add authentication
        this.addAuthentication(config);
        
        // Add body
        this.addRequestBody(config);
        
        return config;
    }

    processUrl(url) {
        // Process environment variables
        let processedUrl = this.processVariables(url);
        
        // Ensure URL has protocol
        if (processedUrl && !processedUrl.startsWith('http://') && !processedUrl.startsWith('https://')) {
            processedUrl = 'https://' + processedUrl;
        }
        
        return processedUrl;
    }

    processVariables(text) {
        if (!text || !this.currentEnvironment) return text;
        
        const env = this.environments.find(e => e.name === this.currentEnvironment);
        if (!env) return text;
        
        let processed = text;
        env.variables.forEach(variable => {
            const placeholder = `{{${variable.key}}}`;
            processed = processed.replace(new RegExp(placeholder, 'g'), variable.value);
        });
        
        return processed;
    }

    addAuthentication(config) {
        const auth = this.currentRequest.auth;
        
        switch (auth.type) {
            case 'bearer':
                if (auth.token) {
                    config.headers = config.headers || {};
                    config.headers['Authorization'] = `Bearer ${auth.token}`;
                }
                break;
                
            case 'basic':
                if (auth.username && auth.password) {
                    config.auth = {
                        username: auth.username,
                        password: auth.password
                    };
                }
                break;
                
            case 'api-key':
                if (auth.key && auth.value) {
                    if (auth.location === 'header') {
                        config.headers = config.headers || {};
                        config.headers[auth.key] = auth.value;
                    } else {
                        config.params = config.params || {};
                        config.params[auth.key] = auth.value;
                    }
                }
                break;
        }
    }

    addRequestBody(config) {
        const body = this.currentRequest.body;
        
        switch (body.type) {
            case 'raw':
                if (body.content) {
                    config.data = body.content;
                    // Try to parse as JSON to set appropriate content type
                    try {
                        JSON.parse(body.content);
                        config.headers = config.headers || {};
                        config.headers['Content-Type'] = 'application/json';
                    } catch (e) {
                        // Not JSON, leave as is
                    }
                }
                break;
                
            case 'form-data':
                if (Array.isArray(body.content) && body.content.length > 0) {
                    const formData = new FormData();
                    body.content.forEach(item => {
                        if (item.enabled && item.key) {
                            formData.append(item.key, item.value);
                        }
                    });
                    config.data = formData;
                }
                break;
                
            case 'urlencoded':
                if (Array.isArray(body.content) && body.content.length > 0) {
                    const params = new URLSearchParams();
                    body.content.forEach(item => {
                        if (item.enabled && item.key) {
                            params.append(item.key, item.value);
                        }
                    });
                    config.data = params;
                    config.headers = config.headers || {};
                    config.headers['Content-Type'] = 'application/x-www-form-urlencoded';
                }
                break;
        }
    }

    async executePreRequestScript() {
        const script = document.getElementById('pre-script').value;
        if (!script) return;
        
        try {
            // Create a sandboxed environment for script execution
            const scriptFunction = new Function('request', 'environment', script);
            scriptFunction(this.currentRequest, this.currentEnvironment);
        } catch (error) {
            console.warn('Pre-request script error:', error);
        }
    }

    async executeTestScript() {
        const script = document.getElementById('test-script').value;
        if (!script || !this.response) return;
        
        try {
            const tests = [];
            
            // Create test API
            const pm = {
                test: (name, fn) => {
                    try {
                        fn();
                        tests.push({ name, status: 'pass', error: null });
                    } catch (error) {
                        tests.push({ name, status: 'fail', error: error.message });
                    }
                },
                expect: (actual) => ({
                    to: {
                        equal: (expected) => {
                            if (actual !== expected) {
                                throw new Error(`Expected ${expected}, got ${actual}`);
                            }
                        },
                        include: (expected) => {
                            if (!actual.includes(expected)) {
                                throw new Error(`Expected to include ${expected}`);
                            }
                        }
                    }
                })
            };
            
            const responseJson = typeof this.response.data === 'object' ? 
                this.response.data : JSON.parse(this.response.data);
            
            // Create script function with test API
            const scriptFunction = new Function('pm', 'response', 'responseJson', script);
            scriptFunction(pm, this.response, responseJson);
            
            // Display test results
            this.displayTestResults(tests);
            
        } catch (error) {
            console.warn('Test script error:', error);
            this.displayTestResults([{
                name: 'Script Execution',
                status: 'fail',
                error: error.message
            }]);
        }
    }

    displayResponse() {
        // Update response meta
        document.getElementById('response-status').textContent = 
            `${this.response.status} ${this.response.statusText}`;
        document.getElementById('response-status').className = 
            `status-${Math.floor(this.response.status / 100)}00`;
        document.getElementById('response-time').textContent = `${this.response.time}ms`;
        document.getElementById('response-size').textContent = 
            this.formatBytes(this.response.size);
        
        // Display response body
        this.formatResponse('pretty');
        
        // Display response headers
        this.displayResponseHeaders();
    }

    formatResponse(format) {
        const content = document.getElementById('response-body-content');
        
        try {
            let displayData = this.response.data;
            
            if (format === 'pretty' && typeof displayData === 'object') {
                content.textContent = JSON.stringify(displayData, null, 2);
            } else if (format === 'raw') {
                content.textContent = typeof displayData === 'string' ? 
                    displayData : JSON.stringify(displayData);
            } else if (format === 'preview' && typeof displayData === 'object') {
                // Simple HTML preview for JSON
                content.innerHTML = this.createJsonPreview(displayData);
            } else {
                content.textContent = displayData;
            }
        } catch (error) {
            content.textContent = 'Error formatting response: ' + error.message;
        }
    }

    createJsonPreview(obj, level = 0) {
        const indent = '  '.repeat(level);
        let html = '';
        
        if (Array.isArray(obj)) {
            html += '[\n';
            obj.forEach((item, index) => {
                html += indent + '  ';
                if (typeof item === 'object') {
                    html += this.createJsonPreview(item, level + 1);
                } else {
                    html += JSON.stringify(item);
                }
                if (index < obj.length - 1) html += ',';
                html += '\n';
            });
            html += indent + ']';
        } else if (typeof obj === 'object' && obj !== null) {
            html += '{\n';
            const keys = Object.keys(obj);
            keys.forEach((key, index) => {
                html += indent + `  "${key}": `;
                if (typeof obj[key] === 'object') {
                    html += this.createJsonPreview(obj[key], level + 1);
                } else {
                    html += JSON.stringify(obj[key]);
                }
                if (index < keys.length - 1) html += ',';
                html += '\n';
            });
            html += indent + '}';
        } else {
            html += JSON.stringify(obj);
        }
        
        return `<pre>${html}</pre>`;
    }

    displayResponseHeaders() {
        const container = document.getElementById('response-headers-content');
        const headers = this.response.headers;
        
        let html = '<table class="response-table"><thead><tr><th>Name</th><th>Value</th></tr></thead><tbody>';
        
        Object.keys(headers).forEach(key => {
            html += `<tr><td>${key}</td><td>${headers[key]}</td></tr>`;
        });
        
        html += '</tbody></table>';
        container.innerHTML = html;
    }

    displayTestResults(tests) {
        const container = document.getElementById('response-tests-content');
        
        if (tests.length === 0) {
            container.innerHTML = '<p>No tests executed</p>';
            return;
        }
        
        let html = '<div class="test-results">';
        
        tests.forEach(test => {
            const statusClass = test.status === 'pass' ? 'test-pass' : 'test-fail';
            html += `
                <div class="test-result ${statusClass}">
                    <span class="test-name">${test.name}</span>
                    <span class="test-status">${test.status.toUpperCase()}</span>
                    ${test.error ? `<div class="test-error">${test.error}</div>` : ''}
                </div>
            `;
        });
        
        html += '</div>';
        container.innerHTML = html;
    }

    handleRequestError(error) {
        this.response = {
            status: error.response ? error.response.status : 0,
            statusText: error.response ? error.response.statusText : 'Network Error',
            headers: error.response ? error.response.headers : {},
            data: error.response ? error.response.data : error.message,
            time: 0,
            size: 0
        };
        
        this.displayResponse();
    }

    addToHistory() {
        const historyItem = {
            id: Date.now(),
            method: this.currentRequest.method,
            url: this.currentRequest.url,
            status: this.response.status,
            time: this.response.time,
            timestamp: new Date().toISOString(),
            request: JSON.parse(JSON.stringify(this.currentRequest))
        };
        
        this.history.unshift(historyItem);
        if (this.history.length > 100) {
            this.history = this.history.slice(0, 100);
        }
        
        this.updateHistoryUI();
        this.saveData();
    }

    updateHistoryUI() {
        const container = document.getElementById('history-list');
        container.innerHTML = '';
        
        this.history.slice(0, 20).forEach(item => {
            const div = document.createElement('div');
            div.className = 'history-item';
            div.innerHTML = `
                <div class="history-method" style="color: ${this.getMethodColor(item.method)}">${item.method}</div>
                <div class="history-url">${item.url}</div>
                <div class="history-time">${new Date(item.timestamp).toLocaleTimeString()}</div>
            `;
            
            div.addEventListener('click', () => {
                this.loadFromHistory(item);
            });
            
            container.appendChild(div);
        });
    }

    getMethodColor(method) {
        const colors = {
            'GET': '#4caf50',
            'POST': '#2196f3',
            'PUT': '#ff9800',
            'DELETE': '#f44336',
            'PATCH': '#9c27b0',
            'HEAD': '#607d8b',
            'OPTIONS': '#795548'
        };
        return colors[method] || '#cccccc';
    }

    loadFromHistory(historyItem) {
        this.currentRequest = JSON.parse(JSON.stringify(historyItem.request));
        this.updateUIFromRequest();
    }

    updateUIFromRequest() {
        // Update URL bar
        document.getElementById('method-select').value = this.currentRequest.method;
        document.getElementById('url-input').value = this.currentRequest.url;
        
        // Update params
        this.updateKeyValueUI('params', this.currentRequest.params);
        
        // Update headers
        this.updateKeyValueUI('headers', this.currentRequest.headers);
        
        // Update body
        this.updateBodyUI();
        
        // Update auth
        this.updateAuthUI(this.currentRequest.auth.type);
        
        // Update scripts
        document.getElementById('pre-script').value = this.currentRequest.scripts.pre || '';
        document.getElementById('test-script').value = this.currentRequest.scripts.test || '';
    }

    updateKeyValueUI(target, data) {
        const container = document.getElementById(`${target}-container`);
        container.innerHTML = '';
        
        data.forEach(item => {
            this.addKeyValueRow(target, item.key, item.value, item.description || '');
        });
        
        // Add one empty row
        this.addKeyValueRow(target);
    }

    updateBodyUI() {
        const body = this.currentRequest.body;
        
        // Set body type
        document.querySelector(`input[name="body-type"][value="${body.type}"]`).checked = true;
        
        // Trigger change event to show appropriate UI
        document.querySelector(`input[name="body-type"][value="${body.type}"]`).dispatchEvent(new Event('change'));
        
        // Set content
        if (body.type === 'raw') {
            document.getElementById('body-raw').value = body.content || '';
        } else if (body.type === 'form-data' || body.type === 'urlencoded') {
            if (Array.isArray(body.content)) {
                this.updateKeyValueUI('body-form', body.content);
            }
        }
    }

    copyResponse() {
        if (!this.response) return;
        
        const content = typeof this.response.data === 'object' ? 
            JSON.stringify(this.response.data, null, 2) : 
            this.response.data;
        
        navigator.clipboard.writeText(content).then(() => {
            // Show brief success message
            const btn = document.getElementById('copy-response-btn');
            const originalText = btn.textContent;
            btn.textContent = 'Copied!';
            setTimeout(() => {
                btn.textContent = originalText;
            }, 1000);
        });
    }

    async downloadResponse() {
        if (!this.response) return;
        
        const content = typeof this.response.data === 'object' ? 
            JSON.stringify(this.response.data, null, 2) : 
            this.response.data;
        
        const defaultPath = `response_${Date.now()}.json`;
        
        try {
            await ipcRenderer.invoke('save-file', content, defaultPath);
        } catch (error) {
            console.error('Error saving file:', error);
        }
    }

    formatBytes(bytes) {
        if (bytes === 0) return '0 B';
        const k = 1024;
        const sizes = ['B', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }

    newRequest() {
        this.currentRequest = {
            method: 'GET',
            url: '',
            params: [],
            headers: [],
            body: { type: 'none', content: '' },
            auth: { type: 'none' },
            scripts: { pre: '', test: '' }
        };
        
        this.response = null;
        this.updateUIFromRequest();
        
        // Clear response
        document.getElementById('response-body-content').textContent = '';
        document.getElementById('response-headers-content').innerHTML = '';
        document.getElementById('response-tests-content').innerHTML = '';
        document.getElementById('response-status').textContent = '';
        document.getElementById('response-time').textContent = '';
        document.getElementById('response-size').textContent = '';
    }

    saveRequest() {
        // Implementation for saving request to collection
        this.showModal('Save Request', 'Request saving functionality will be implemented');
    }

    createCollection() {
        this.showModal('Create Collection', 'Collection creation functionality will be implemented');
    }

    saveCollection() {
        this.showModal('Save Collection', 'Collection saving functionality will be implemented');
    }

    openCollection(filePath) {
        this.showModal('Open Collection', 'Collection opening functionality will be implemented');
    }

    clearHistory() {
        this.history = [];
        this.updateHistoryUI();
        this.saveData();
    }

    openEnvironmentManager() {
        this.showModal('Environment Manager', 'Environment management functionality will be implemented');
    }

    openPluginManager() {
        this.showModal('Plugin Manager', 'Plugin management functionality will be implemented');
    }

    showAbout() {
        this.showModal('About', `
            <h3>API Testing Tool</h3>
            <p>Version: 1.0.0</p>
            <p>A cross-platform API testing tool built with Electron.</p>
            <p>Features:</p>
            <ul>
                <li>REST API testing</li>
                <li>Environment variables</li>
                <li>Collection management</li>
                <li>Request history</li>
                <li>Test scripting</li>
                <li>Response formatting</li>
            </ul>
        `);
    }

    showModal(title, content) {
        const overlay = document.getElementById('modal-overlay');
        const modalContent = document.getElementById('modal-content');
        
        modalContent.innerHTML = `
            <h2>${title}</h2>
            <div class="modal-body">${content}</div>
            <div class="modal-footer">
                <button onclick="document.getElementById('modal-overlay').style.display='none'">Close</button>
            </div>
        `;
        
        overlay.style.display = 'block';
        
        // Close on overlay click
        overlay.addEventListener('click', (e) => {
            if (e.target === overlay) {
                overlay.style.display = 'none';
            }
        });
    }

    loadData() {
        // Load data from localStorage
        try {
            const savedHistory = localStorage.getItem('api-tool-history');
            if (savedHistory) {
                this.history = JSON.parse(savedHistory);
                this.updateHistoryUI();
            }
            
            const savedEnvironments = localStorage.getItem('api-tool-environments');
            if (savedEnvironments) {
                this.environments = JSON.parse(savedEnvironments);
                this.updateEnvironmentUI();
            }
        } catch (error) {
            console.warn('Error loading saved data:', error);
        }
    }

    saveData() {
        // Save data to localStorage
        try {
            localStorage.setItem('api-tool-history', JSON.stringify(this.history));
            localStorage.setItem('api-tool-environments', JSON.stringify(this.environments));
        } catch (error) {
            console.warn('Error saving data:', error);
        }
    }

    updateEnvironmentUI() {
        const select = document.getElementById('environment-select');
        select.innerHTML = '<option value="">No Environment</option>';
        
        this.environments.forEach(env => {
            const option = document.createElement('option');
            option.value = env.name;
            option.textContent = env.name;
            select.appendChild(option);
        });
    }
}

// Initialize the application when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.apiApp = new ApiTestingApp();
});
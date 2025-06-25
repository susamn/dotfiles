// Sample Plugin - Response Time Checker
// This plugin checks if response time is acceptable

const ResponseTimeChecker = {
    name: 'Response Time Checker',
    version: '1.0.0',
    description: 'Checks if response time is within acceptable limits',
    
    // Plugin configuration
    config: {
        maxResponseTime: 2000 // 2 seconds
    },
    
    // Execute plugin after response is received
    execute(response, config = this.config) {
        if (!response) {
            return {
                status: 'error',
                message: 'No response data available'
            };
        }
        
        const responseTime = response.time || 0;
        const maxTime = config.maxResponseTime || this.config.maxResponseTime;
        
        if (responseTime > maxTime) {
            return {
                status: 'warning',
                message: `Slow response time: ${responseTime}ms (max: ${maxTime}ms)`,
                data: {
                    responseTime,
                    maxTime,
                    exceeded: responseTime - maxTime
                }
            };
        } else {
            return {
                status: 'success',
                message: `Response time OK: ${responseTime}ms`,
                data: {
                    responseTime,
                    maxTime
                }
            };
        }
    },
    
    // Plugin settings UI configuration
    getSettingsUI() {
        return `
            <div class="plugin-setting">
                <label>Max Response Time (ms):</label>
                <input type="number" id="maxResponseTime" value="${this.config.maxResponseTime}" min="100" max="30000">
            </div>
        `;
    },
    
    // Apply settings from UI
    applySettings() {
        const maxResponseTimeInput = document.getElementById('maxResponseTime');
        if (maxResponseTimeInput) {
            this.config.maxResponseTime = parseInt(maxResponseTimeInput.value) || 2000;
        }
    }
};

// Export for use in main application
if (typeof module !== 'undefined' && module.exports) {
    module.exports = ResponseTimeChecker;
}
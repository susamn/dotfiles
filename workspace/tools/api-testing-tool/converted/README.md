# API Testing Tool - Electron Version

A cross-platform API testing tool built with Electron, converted from the original Qt-based Python application.

## Features

- **HTTP Methods**: Support for GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS
- **Request Configuration**: 
  - URL parameters
  - Custom headers
  - Request body (raw, form-data, URL-encoded)
  - Authentication (Bearer, Basic Auth, API Key)
- **Response Handling**:
  - Syntax highlighting for JSON responses
  - Response headers and cookies viewing
  - Response time and size metrics
- **Environment Management**: Variables for different environments
- **Request History**: Automatic saving of request history
- **Collections**: Organize requests into collections
- **Test Scripts**: JavaScript-based pre-request and test scripts
- **Plugin System**: Extensible plugin architecture

## Installation

### Prerequisites

- Node.js (v16 or higher)
- npm or yarn

### Setup

1. Navigate to the converted directory:
```bash
cd converted
```

2. Install dependencies:
```bash
npm install
```

3. Start the application:
```bash
npm start
```

### Development Mode

To run in development mode with DevTools open:
```bash
npm run dev
```

### Building for Distribution

Build for all platforms:
```bash
npm run build
```

Build for specific platforms:
```bash
npm run build-win    # Windows
npm run build-mac    # macOS
npm run build-linux  # Linux
```

## Usage

### Basic Request

1. Select HTTP method from dropdown
2. Enter the request URL
3. Add parameters, headers, or body as needed
4. Click "Send" to execute the request

### Authentication

Navigate to the "Auth" tab and select your authentication method:
- **Bearer Token**: Enter your token
- **Basic Auth**: Enter username and password
- **API Key**: Specify key name, value, and location (header/query)

### Environment Variables

Use `{{variableName}}` syntax in URLs, headers, or body to reference environment variables.

### Test Scripts

Write JavaScript code in the "Tests" tab to validate responses:

```javascript
pm.test("Status code is 200", function () {
    pm.expect(response.status).to.equal(200);
});

pm.test("Response has user data", function () {
    pm.expect(responseJson).to.have.property('user');
});
```

### Collections

Save frequently used requests in collections for easy access and organization.

## File Structure

```
converted/
├── main.js                 # Electron main process
├── package.json           # Project configuration
├── renderer/              # Renderer process files
│   ├── index.html         # Main UI
│   ├── styles.css         # Application styles
│   └── app.js            # Main application logic
├── plugins/               # Plugin directory
│   └── response-time-checker.js
└── assets/               # Application assets
```

## Plugin Development

Create plugins by adding JavaScript files to the `plugins/` directory. Each plugin should export an object with the following structure:

```javascript
const MyPlugin = {
    name: 'My Plugin',
    version: '1.0.0',
    description: 'Plugin description',
    
    execute(response, config) {
        // Plugin logic here
        return {
            status: 'success|warning|error',
            message: 'Result message',
            data: { /* additional data */ }
        };
    },
    
    getSettingsUI() {
        // Return HTML for plugin settings
        return '<div>Settings UI</div>';
    },
    
    applySettings() {
        // Apply settings from UI
    }
};

module.exports = MyPlugin;
```

## Keyboard Shortcuts

- `Ctrl/Cmd + N`: New request
- `Ctrl/Cmd + S`: Save collection
- `Ctrl/Cmd + O`: Open collection
- `F12`: Toggle DevTools

## Differences from Original Qt Version

### Advantages
- **Cross-platform consistency**: Identical UI across all platforms
- **Web technologies**: Modern HTML/CSS/JS stack
- **Plugin system**: JavaScript-based plugins
- **Easier customization**: CSS styling and HTML structure

### Limitations
- **Performance**: Slightly higher memory usage compared to native Qt
- **File access**: Some file operations require IPC communication
- **Native integrations**: Limited compared to Qt's native capabilities

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly on all target platforms
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Support

For issues and feature requests, please create an issue in the project repository.
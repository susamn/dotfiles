const examples = {
    person: {
        description: "Simple message with basic field types",
        schema: `syntax = "proto3";

package example;

message Person {
  string name = 1;
  int32 id = 2;
  string email = 3;
  bool active = 4;
}`,
        encoded: 'CgdKb2huIERvZRABGhBqb2huQGV4YW1wbGUuY29tKAE=',
        decoded: `{
  "name": "John Doe",
  "id": 1,
  "email": "john@example.com",
  "active": true
}`,
        types: ['example.Person']
    },
    search: {
        description: "Message with enums and repeated fields",
        schema: `syntax = "proto3";

package search;

message SearchRequest {
  enum Corpus {
    UNIVERSAL = 0;
    WEB = 1;
    IMAGES = 2;
    LOCAL = 3;
    NEWS = 4;
    PRODUCTS = 5;
    VIDEO = 6;
  }
  string query = 1;
  int32 page_number = 2;
  int32 results_per_page = 3;
  Corpus corpus = 4;
  repeated string filters = 5;
}`,
        encoded: 'CgZmb29iYXIQARgKKAEyBWZpbHRlcjIGZmlsdGVyMg==',
        decoded: `{
  "query": "foobar",
  "page_number": 1,
  "results_per_page": 10,
  "corpus": "WEB",
  "filters": ["filter", "filter2"]
}`,
        types: ['search.SearchRequest']
    },
    response: {
        description: "API response with optional fields and timestamps",
        schema: `syntax = "proto3";

import "google/protobuf/timestamp.proto";

package api;

message ApiResponse {
  int32 status_code = 1;
  string message = 2;
  google.protobuf.Timestamp timestamp = 3;
  optional string request_id = 4;
  repeated string errors = 5;
  
  message Data {
    string type = 1;
    bytes payload = 2;
  }
  
  optional Data data = 6;
}`,
        encoded: 'CAISDVN1Y2Nlc3NmdWwgT0saCQjQjOnrBhCAARoIdGVzdC0xMjM=',
        decoded: `{
  "status_code": 2,
  "message": "Successful OK",
  "timestamp": "2023-12-01T10:30:00Z",
  "request_id": "test-123"
}`,
        types: ['api.ApiResponse']
    },
    nested: {
        description: "Complex nested message structure",
        schema: `syntax = "proto3";

package company;

message Company {
  string name = 1;
  
  message Address {
    string street = 1;
    string city = 2;
    string state = 3;
    string zip_code = 4;
    string country = 5;
  }
  
  Address headquarters = 2;
  
  message Employee {
    string name = 1;
    int32 employee_id = 2;
    string department = 3;
    Address home_address = 4;
  }
  
  repeated Employee employees = 3;
  int32 founded_year = 4;
}`,
        encoded: 'CgdBY21lIEluYxIlCgtNYWluIFN0cmVldBIITmV3IFlvcmsaAk5ZIgU5MDExMCoD1VNBGjsKCUFsaWNlIFNtaXRoEAEaCEVuZ2luZWVyIiIKC0FsaWNlIFN0cmVldBIHQW55dG93bhoCSVAiCDEyMzQ1Njc4IP3JBw==',
        decoded: `{
  "name": "Acme Inc",
  "headquarters": {
    "street": "Main Street",
    "city": "New York",
    "state": "NY",
    "zip_code": "90112",
    "country": "USA"
  },
  "employees": [
    {
      "name": "Alice Smith",
      "employee_id": 1,
      "department": "Engineer",
      "home_address": {
        "street": "Alice Street",
        "city": "Anytown",
        "state": "IP",
        "zip_code": "12345678"
      }
    }
  ],
  "founded_year": 1985
}`,
        types: ['company.Company']
    }
};

function loadExample() {
    const select = document.getElementById('example-select');
    const example = examples[select.value];
    const description = document.getElementById('example-description');
    
    if (example) {
        document.getElementById('proto-schema').value = example.schema;
        document.getElementById('binary-input').value = example.encoded;
        description.textContent = example.description;
        populateMessageTypes();
        if (example.types.length > 0) {
            document.getElementById('message-type').value = example.types[0];
        }
        updateCharCount();
        updateStatus('Example loaded successfully', '#008000');
    } else {
        clearAll();
        description.textContent = '';
    }
}

function populateMessageTypes() {
    const schema = document.getElementById('proto-schema').value;
    const messageSelect = document.getElementById('message-type');
    
    // Extract package name if it exists
    const packageMatch = schema.match(/package\s+([a-zA-Z_][a-zA-Z0-9_.]*)\s*;/);
    const packageName = packageMatch ? packageMatch[1] : null;
    
    // Find all message types
    const messageRegex = /message\s+(\w+)\s*\{/g;
    let match;
    const types = [];
    while ((match = messageRegex.exec(schema)) !== null) {
        // Add package prefix if package is declared
        const messageType = packageName ? `${packageName}.${match[1]}` : match[1];
        types.push(messageType);
    }
    
    const currentVal = messageSelect.value;
    messageSelect.innerHTML = '<option value="">Select message type</option>';
    
    types.forEach(type => {
        const option = document.createElement('option');
        option.value = type;
        option.textContent = type;
        messageSelect.appendChild(option);
    });
    
    if (types.includes(currentVal)) {
        messageSelect.value = currentVal;
    }
}

async function decodeProtobuf() {
    const schema = document.getElementById('proto-schema').value;
    const encoded = document.getElementById('binary-input').value;
    const messageType = document.getElementById('message-type').value;
    const output = document.getElementById('output');

    if (!schema.trim()) {
        updateStatus('Please enter a proto schema', '#ff8800');
        return;
    }

    if (!encoded.trim()) {
        updateStatus('Please enter Base64 encoded message', '#ff8800');
        return;
    }

    if (!messageType) {
        updateStatus('Please select a message type', '#ff8800');
        return;
    }

    updateStatus('Decoding...', '#0066cc');
    output.value = '';

    try {
        const response = await fetch('/api/protobuf/decode', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                proto_schema: schema,
                encoded_message: encoded,
                message_type: messageType
            })
        });

        const data = await response.json();

        if (data.success) {
            output.value = JSON.stringify(data.decoded_message, null, 2);
            updateStatus('Message decoded successfully', '#008000');
        } else {
            output.value = 'Error: ' + data.error;
            updateStatus('Decoding failed: ' + data.error, '#cc0000');
        }
    } catch (error) {
        output.value = 'Network error: ' + error.message;
        updateStatus('Network error: ' + error.message, '#cc0000');
    }
}

async function encodeProtobuf() {
    const schema = document.getElementById('proto-schema').value;
    const jsonData = document.getElementById('binary-input').value;
    const messageType = document.getElementById('message-type').value;
    const output = document.getElementById('output');

    if (!schema.trim()) {
        updateStatus('Please enter a proto schema', '#ff8800');
        return;
    }

    if (!jsonData.trim()) {
        updateStatus('Please enter JSON data to encode', '#ff8800');
        return;
    }

    if (!messageType) {
        updateStatus('Please select a message type', '#ff8800');
        return;
    }

    try {
        JSON.parse(jsonData);
    } catch (e) {
        updateStatus('Invalid JSON data', '#cc0000');
        return;
    }

    updateStatus('Encoding...', '#0066cc');
    output.value = '';

    try {
        const response = await fetch('/api/protobuf/encode', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                proto_schema: schema,
                json_data: jsonData,
                message_type: messageType
            })
        });

        const data = await response.json();

        if (data.success) {
            output.value = data.encoded_message;
            updateStatus('Message encoded successfully', '#008000');
        } else {
            output.value = 'Error: ' + data.error;
            updateStatus('Encoding failed: ' + data.error, '#cc0000');
        }
    } catch (error) {
        output.value = 'Network error: ' + error.message;
        updateStatus('Network error: ' + error.message, '#cc0000');
    }
}

function clearAll() {
    document.getElementById('proto-schema').value = '';
    document.getElementById('binary-input').value = '';
    document.getElementById('output').value = '';
    document.getElementById('message-type').innerHTML = '<option value="">Select message type</option>';
    document.getElementById('example-select').value = '';
    document.getElementById('example-description').textContent = '';
    updateStatus('Ready - Load an example or enter your own proto schema', '#666');
    updateCharCount();
}

function copyOutput() {
    const output = document.getElementById('output').value;
    if (!output.trim()) {
        updateStatus('No output to copy', '#ff8800');
        return;
    }

    navigator.clipboard.writeText(output).then(() => {
        updateStatus('Output copied to clipboard', '#008000');
    }).catch(() => {
        const textArea = document.createElement('textarea');
        textArea.value = output;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
        updateStatus('Output copied to clipboard', '#008000');
    });
}

function copySchema() {
    const schema = document.getElementById('proto-schema').value;
    if (!schema.trim()) {
        updateStatus('No schema to copy', '#ff8800');
        return;
    }

    navigator.clipboard.writeText(schema).then(() => {
        updateStatus('Schema copied to clipboard', '#008000');
    }).catch(() => {
        const textArea = document.createElement('textarea');
        textArea.value = schema;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
        updateStatus('Schema copied to clipboard', '#008000');
    });
}

function updateStatus(message, color) {
    const statusText = document.getElementById('statusText');
    statusText.textContent = message;
    statusText.style.color = color;
}

function updateCharCount() {
    const schema = document.getElementById('proto-schema').value;
    document.getElementById('charCount').textContent = `Schema: ${schema.length} chars`;
}

document.getElementById('proto-schema').addEventListener('input', () => {
    populateMessageTypes();
    updateCharCount();
});

populateMessageTypes();
updateCharCount();
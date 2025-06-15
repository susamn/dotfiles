#!/usr/bin/env python3
"""
Terminal Text Diff Tool
A web-based text comparison tool that opens in your browser
Usage: python text_diff.py [file1] [file2] [--port PORT]
"""

import argparse
import webbrowser
import threading
import time
import os
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse
import json
import difflib

class DiffHandler(BaseHTTPRequestHandler):
    def __init__(self, file1_content="", file2_content="", file1_name="Text 1", file2_name="Text 2"):
        self.file1_content = file1_content
        self.file2_content = file2_content
        self.file1_name = file1_name
        self.file2_name = file2_name
        super().__init__()
    
    def __call__(self, *args, **kwargs):
        # Store the content in class variables that the instance can access
        DiffHandler.file1_content = self.file1_content
        DiffHandler.file2_content = self.file2_content
        DiffHandler.file1_name = self.file1_name
        DiffHandler.file2_name = self.file2_name
        return super().__call__(*args, **kwargs)

    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(self.get_html().encode())
        elif self.path == '/api/diff':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            diff_data = self.generate_diff()
            self.wfile.write(json.dumps(diff_data).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if self.path == '/api/compare':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            data = json.loads(post_data.decode())
            
            text1 = data.get('text1', '')
            text2 = data.get('text2', '')
            
            diff_data = self.generate_diff_from_text(text1, text2)
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(diff_data).encode())

    def generate_diff_from_text(self, text1, text2):
        lines1 = text1.splitlines()
        lines2 = text2.splitlines()
        
        differ = difflib.unified_diff(lines1, lines2, lineterm='', n=3)
        diff_lines = list(differ)
        
        # Create side-by-side comparison
        matcher = difflib.SequenceMatcher(None, lines1, lines2)
        left_lines = []
        right_lines = []
        
        for tag, i1, i2, j1, j2 in matcher.get_opcodes():
            if tag == 'equal':
                for i in range(i1, i2):
                    left_lines.append({'text': lines1[i], 'type': 'equal', 'line_num': i + 1})
                    right_lines.append({'text': lines2[j1 + (i - i1)], 'type': 'equal', 'line_num': j1 + (i - i1) + 1})
            elif tag == 'delete':
                for i in range(i1, i2):
                    left_lines.append({'text': lines1[i], 'type': 'delete', 'line_num': i + 1})
                    right_lines.append({'text': '', 'type': 'empty', 'line_num': ''})
            elif tag == 'insert':
                for j in range(j1, j2):
                    left_lines.append({'text': '', 'type': 'empty', 'line_num': ''})
                    right_lines.append({'text': lines2[j], 'type': 'insert', 'line_num': j + 1})
            elif tag == 'replace':
                max_lines = max(i2 - i1, j2 - j1)
                for k in range(max_lines):
                    left_text = lines1[i1 + k] if i1 + k < i2 else ''
                    right_text = lines2[j1 + k] if j1 + k < j2 else ''
                    left_line_num = i1 + k + 1 if i1 + k < i2 else ''
                    right_line_num = j1 + k + 1 if j1 + k < j2 else ''
                    
                    left_type = 'delete' if left_text else 'empty'
                    right_type = 'insert' if right_text else 'empty'
                    
                    left_lines.append({'text': left_text, 'type': left_type, 'line_num': left_line_num})
                    right_lines.append({'text': right_text, 'type': right_type, 'line_num': right_line_num})
        
        return {
            'left': left_lines,
            'right': right_lines,
            'unified_diff': diff_lines
        }

    def generate_diff(self):
        return self.generate_diff_from_text(
            getattr(DiffHandler, 'file1_content', ''),
            getattr(DiffHandler, 'file2_content', '')
        )

    def get_html(self):
        return f'''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Text Compare Tool</title>
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}
        
        body {{
            font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
            background: #1e1e1e;
            color: #d4d4d4;
            height: 100vh;
            display: flex;
            flex-direction: column;
        }}
        
        .header {{
            background: #252526;
            padding: 10px 20px;
            border-bottom: 1px solid #3c3c3c;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }}
        
        .title {{
            font-size: 18px;
            font-weight: bold;
        }}
        
        .controls {{
            display: flex;
            gap: 10px;
        }}
        
        .btn {{
            background: #0e639c;
            color: white;
            border: none;
            padding: 8px 16px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 12px;
        }}
        
        .btn:hover {{
            background: #1177bb;
        }}
        
        .input-section {{
            background: #2d2d30;
            padding: 10px 20px;
            border-bottom: 1px solid #3c3c3c;
        }}
        
        .input-row {{
            display: flex;
            gap: 20px;
            margin-bottom: 10px;
        }}
        
        .input-group {{
            flex: 1;
        }}
        
        .input-group label {{
            display: block;
            margin-bottom: 5px;
            font-size: 12px;
            color: #cccccc;
        }}
        
        .input-group textarea {{
            width: 100%;
            height: 120px;
            background: #1e1e1e;
            border: 1px solid #3c3c3c;
            color: #d4d4d4;
            padding: 8px;
            font-family: inherit;
            font-size: 12px;
            resize: vertical;
        }}
        
        .diff-container {{
            flex: 1;
            display: flex;
            overflow: hidden;
        }}
        
        .diff-pane {{
            flex: 1;
            display: flex;
            flex-direction: column;
            border-right: 1px solid #3c3c3c;
        }}
        
        .diff-pane:last-child {{
            border-right: none;
        }}
        
        .pane-header {{
            background: #37373d;
            padding: 8px 12px;
            font-size: 12px;
            font-weight: bold;
            border-bottom: 1px solid #3c3c3c;
        }}
        
        .diff-content {{
            flex: 1;
            overflow-y: auto;
            background: #1e1e1e;
        }}
        
        .line {{
            display: flex;
            min-height: 20px;
            font-size: 12px;
            line-height: 20px;
        }}
        
        .line-number {{
            min-width: 50px;
            padding: 0 8px;
            background: #252526;
            color: #858585;
            text-align: right;
            border-right: 1px solid #3c3c3c;
            user-select: none;
        }}
        
        .line-content {{
            flex: 1;
            padding: 0 8px;
            white-space: pre-wrap;
            word-wrap: break-word;
        }}
        
        .line.equal {{
            background: #1e1e1e;
        }}
        
        .line.delete {{
            background: #4b1818;
        }}
        
        .line.insert {{
            background: #1e3a1e;
        }}
        
        .line.empty {{
            background: #2d2d30;
        }}
        
        .stats {{
            padding: 10px 20px;
            background: #252526;
            border-top: 1px solid #3c3c3c;
            font-size: 12px;
            color: #cccccc;
        }}
        
        .loading {{
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100px;
            color: #cccccc;
        }}
    </style>
</head>
<body>
    <div class="header">
        <div class="title">Text Diff Tool</div>
        <div class="controls">
            <button class="btn" onclick="compareTexts()">Compare</button>
            <button class="btn" onclick="clearAll()">Clear</button>
        </div>
    </div>
    
    <div class="input-section">
        <div class="input-row">
            <div class="input-group">
                <label for="text1">{getattr(DiffHandler, 'file1_name', 'Text 1')}</label>
                <textarea id="text1" placeholder="Enter first text...">{getattr(DiffHandler, 'file1_content', '')}</textarea>
            </div>
            <div class="input-group">
                <label for="text2">{getattr(DiffHandler, 'file2_name', 'Text 2')}</label>
                <textarea id="text2" placeholder="Enter second text...">{getattr(DiffHandler, 'file2_content', '')}</textarea>
            </div>
        </div>
    </div>
    
    <div class="diff-container">
        <div class="diff-pane">
            <div class="pane-header" id="left-header">{getattr(DiffHandler, 'file1_name', 'Text 1')}</div>
            <div class="diff-content" id="left-diff">
                <div class="loading">Enter text above and click Compare</div>
            </div>
        </div>
        <div class="diff-pane">
            <div class="pane-header" id="right-header">{getattr(DiffHandler, 'file2_name', 'Text 2')}</div>
            <div class="diff-content" id="right-diff">
                <div class="loading">Enter text above and click Compare</div>
            </div>
        </div>
    </div>
    
    <div class="stats" id="stats">Ready to compare</div>

    <script>
        async function compareTexts() {{
            const text1 = document.getElementById('text1').value;
            const text2 = document.getElementById('text2').value;
            
            document.getElementById('left-diff').innerHTML = '<div class="loading">Comparing...</div>';
            document.getElementById('right-diff').innerHTML = '<div class="loading">Comparing...</div>';
            
            try {{
                const response = await fetch('/api/compare', {{
                    method: 'POST',
                    headers: {{
                        'Content-Type': 'application/json',
                    }},
                    body: JSON.stringify({{ text1, text2 }})
                }});
                
                const data = await response.json();
                displayDiff(data);
            }} catch (error) {{
                console.error('Error:', error);
                document.getElementById('stats').textContent = 'Error comparing texts';
            }}
        }}
        
        function displayDiff(data) {{
            const leftDiff = document.getElementById('left-diff');
            const rightDiff = document.getElementById('right-diff');
            
            leftDiff.innerHTML = '';
            rightDiff.innerHTML = '';
            
            for (let i = 0; i < data.left.length; i++) {{
                const leftLine = data.left[i];
                const rightLine = data.right[i];
                
                leftDiff.appendChild(createLine(leftLine));
                rightDiff.appendChild(createLine(rightLine));
            }}
            
            // Update stats
            const deletions = data.left.filter(line => line.type === 'delete').length;
            const insertions = data.right.filter(line => line.type === 'insert').length;
            const equals = data.left.filter(line => line.type === 'equal').length;
            
            document.getElementById('stats').textContent = 
                `Lines: ${{equals}} equal, ${{deletions}} deleted, ${{insertions}} inserted`;
        }}
        
        function createLine(lineData) {{
            const line = document.createElement('div');
            line.className = `line ${{lineData.type}}`;
            
            const lineNumber = document.createElement('div');
            lineNumber.className = 'line-number';
            lineNumber.textContent = lineData.line_num;
            
            const lineContent = document.createElement('div');
            lineContent.className = 'line-content';
            lineContent.textContent = lineData.text;
            
            line.appendChild(lineNumber);
            line.appendChild(lineContent);
            
            return line;
        }}
        
        function clearAll() {{
            document.getElementById('text1').value = '';
            document.getElementById('text2').value = '';
            document.getElementById('left-diff').innerHTML = '<div class="loading">Enter text above and click Compare</div>';
            document.getElementById('right-diff').innerHTML = '<div class="loading">Enter text above and click Compare</div>';
            document.getElementById('stats').textContent = 'Ready to compare';
        }}
        
        // Auto-compare on load if files were provided
        window.addEventListener('load', function() {{
            const text1 = document.getElementById('text1').value;
            const text2 = document.getElementById('text2').value;
            if (text1 || text2) {{
                compareTexts();
            }}
        }});
        
        // Keyboard shortcuts
        document.addEventListener('keydown', function(e) {{
            if (e.ctrlKey && e.key === 'Enter') {{
                compareTexts();
            }}
        }});
    </script>
</body>
</html>
        '''

def create_handler_class(file1_content, file2_content, file1_name, file2_name):
    class CustomDiffHandler(DiffHandler):
        def __init__(self, *args, **kwargs):
            self.file1_content = file1_content
            self.file2_content = file2_content
            self.file1_name = file1_name
            self.file2_name = file2_name
            super(DiffHandler, self).__init__(*args, **kwargs)
    return CustomDiffHandler

def read_file_safely(filepath):
    """Read file with proper encoding detection"""
    try:
        # Try UTF-8 first
        with open(filepath, 'r', encoding='utf-8') as f:
            return f.read()
    except UnicodeDecodeError:
        # Fall back to latin-1 if UTF-8 fails
        try:
            with open(filepath, 'r', encoding='latin-1') as f:
                return f.read()
        except Exception as e:
            return f"Error reading file: {e}"
    except Exception as e:
        return f"Error reading file: {e}"

def main():
    parser = argparse.ArgumentParser(description='Terminal Text Diff Tool')
    parser.add_argument('file1', nargs='?', help='First file to compare')
    parser.add_argument('file2', nargs='?', help='Second file to compare')
    parser.add_argument('--port', type=int, default=8080, help='Port to run the server on')
    
    args = parser.parse_args()
    
    # Read file contents
    file1_content = ""
    file2_content = ""
    file1_name = "Text 1"
    file2_name = "Text 2"
    
    if args.file1:
        if os.path.exists(args.file1):
            file1_content = read_file_safely(args.file1)
            file1_name = os.path.basename(args.file1)
        else:
            print(f"Warning: File '{args.file1}' not found")
    
    if args.file2:
        if os.path.exists(args.file2):
            file2_content = read_file_safely(args.file2)
            file2_name = os.path.basename(args.file2)
        else:
            print(f"Warning: File '{args.file2}' not found")
    
    # Create server
    handler_class = create_handler_class(file1_content, file2_content, file1_name, file2_name)
    server = HTTPServer(('localhost', args.port), handler_class)
    
    # Start server in a separate thread
    server_thread = threading.Thread(target=server.serve_forever)
    server_thread.daemon = True
    server_thread.start()
    
    # Open browser
    url = f'http://localhost:{args.port}'
    print(f"Starting Text Diff Tool on {url}")
    print("Press Ctrl+C to stop the server")
    
    # Small delay to ensure server is ready
    time.sleep(0.5)
    webbrowser.open(url)
    
    try:
        # Keep the main thread alive
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nShutting down server...")
        server.shutdown()
        server.server_close()

if __name__ == '__main__':
    main()

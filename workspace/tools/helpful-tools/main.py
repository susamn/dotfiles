from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, FileResponse
from fastapi.staticfiles import StaticFiles
import os
from pathlib import Path

app = FastAPI(title="Helpful-Tools", description="Collection of useful web tools")

# Mount static files only if directory exists
if os.path.exists("static"):
    app.mount("/static", StaticFiles(directory="static"), name="static")

# Tool configurations
TOOLS = [
    {
        "name": "Scientific Calculator",
        "description": "Advanced calculator with graphing capabilities",
        "path": "/tools/scientific-calculator",
        "file": "scientific_calculator.html",
        "has_backend": False
    },
    {
        "name": "JSON Formatter",
        "description": "Format, minify and validate JSON data",
        "path": "/tools/json-formatter",
        "file": "json_formatter.html",
        "has_backend": False
    },
    {
        "name": "SQL Formatter",
        "description": "Format and beautify SQL queries",
        "path": "/tools/sql-formatter",
        "file": "sql_formatter.html",
        "has_backend": False
    },
    {
        "name": "YAML Validator",
        "description": "Validate and format YAML data",
        "path": "/tools/yaml-validator",
        "file": "yaml_validator.html",
        "has_backend": False
    },
    {
        "name": "JSON-XML-YAML Converter",
        "description": "Convert between JSON, XML and YAML formats",
        "path": "/tools/json-yaml-xml-converter",
        "file": "json_yaml_xml_converter.html",
        "has_backend": False
    },
    {
        "name": "CSV-JSON Converter",
        "description": "Convert between CSV and JSON formats",
        "path": "/tools/csv-json-converter",
        "file": "csv_json_converter.html",
        "has_backend": False
    },
    {
        "name": "Cron Parser",
        "description": "Parse and explain cron expressions",
        "path": "/tools/cron-parser",
        "file": "cron_parser.html",
        "has_backend": False
    },
    {
        "name": "Regex Tester",
        "description": "Test and debug regular expressions",
        "path": "/tools/regex-tester",
        "file": "regex_tester.html",
        "has_backend": False
    },
    {
        "name": "JWT Decoder",
        "description": "Decode and analyze JWT tokens",
        "path": "/tools/jwt-decoder",
        "file": "jwt_decoder.html",
        "has_backend": False
    },
    {
        "name": "URL Encoder/Decoder",
        "description": "Encode and decode URLs",
        "path": "/tools/url-encoder",
        "file": "url_encoder.html",
        "has_backend": True
    },
    {
        "name": "Base64 Encoder/Decoder",
        "description": "Encode and decode Base64 strings",
        "path": "/tools/base64",
        "file": "base64_tool.html",
        "has_backend": True
    },
    {
        "name": "Hash Generator",
        "description": "Generate MD5, SHA1, SHA256 hashes",
        "path": "/tools/hash-generator",
        "file": "hash_generator.html",
        "has_backend": True
    },
    {
        "name": "QR Code Generator",
        "description": "Generate QR codes from text",
        "path": "/tools/qr-generator",
        "file": "qr_generator.html",
        "has_backend": True
    },
    {
        "name": "PlantUML Viewer",
        "description": "Create and view PlantUML diagrams",
        "path": "/tools/plantuml-viewer",
        "file": "puml_viewer.html",
        "has_backend": False
    },
    {
        "name": "Text Diff Tool",
        "description": "Compare two text blocks",
        "path": "/tools/text-diff",
        "file": "text_diff.html",
        "has_backend": True
    },
    {
        "name": "Color Converter",
        "description": "Convert between HEX, RGB, HSL color formats",
        "path": "/tools/color-converter",
        "file": "color_converter.html",
        "has_backend": False
    },
    {
        "name": "Timestamp Converter Tool",
        "description": "Convert between Unix timestamps and human dates",
        "path": "/tools/timestamp-converter",
        "file": "timestamp_converter.html",
        "has_backend": False
    },
    {
        "name": "HTML Entity Converter",
        "description": "Encode and decode HTML entities",
        "path": "/tools/html-entity-converter",
        "file": "html_entity_converter.html",
        "has_backend": False
    },
]

@app.get("/", response_class=HTMLResponse)
async def landing_page():
    tools_html = ""
    for tool in TOOLS:
        tools_html += f"""
        <div class="tool-card">
            <div class="tool-header">
                <h3>{tool['name']}</h3>
            </div>
            <div class="tool-description">
                {tool['description']}
            </div>
            <div class="tool-footer">
                <a href="{tool['path']}" class="tool-button">Open Tool</a>
            </div>
        </div>
        """

    return f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Helpful-Tools</title>
        <style>
            * {{
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }}
            body {{
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                background-color: #f0f0f0;
                color: #333;
                padding: 20px;
            }}
            .header {{
                text-align: center;
                margin-bottom: 40px;
                padding: 20px;
                background: linear-gradient(to bottom, #ffffff, #e8e8e8);
                border: 1px solid #c0c0c0;
                border-radius: 4px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            }}
            .header h1 {{
                font-size: 2.5em;
                margin-bottom: 10px;
                color: #333;
            }}
            .header p {{
                font-size: 1.1em;
                color: #666;
            }}
            .tools-grid {{
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
                gap: 20px;
                max-width: 1200px;
                margin: 0 auto;
            }}
            .tool-card {{
                background: linear-gradient(to bottom, #ffffff, #f8f8f8);
                border: 1px solid #c0c0c0;
                border-radius: 4px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                overflow: hidden;
                transition: box-shadow 0.2s;
            }}
            .tool-card:hover {{
                box-shadow: 0 4px 8px rgba(0,0,0,0.15);
            }}
            .tool-header {{
                padding: 15px 20px 10px 20px;
                border-bottom: 1px solid #e0e0e0;
            }}
            .tool-header h3 {{
                font-size: 1.3em;
                color: #333;
                margin: 0;
            }}
            .tool-description {{
                padding: 15px 20px;
                color: #666;
                line-height: 1.5;
            }}
            .tool-footer {{
                padding: 15px 20px;
                background: linear-gradient(to bottom, #f0f0f0, #e8e8e8);
                border-top: 1px solid #e0e0e0;
                text-align: right;
            }}
            .tool-button {{
                background: linear-gradient(to bottom, #f8f8f8, #e0e0e0);
                border: 1px solid #a0a0a0;
                padding: 8px 16px;
                font-size: 12px;
                cursor: pointer;
                border-radius: 2px;
                color: #333;
                text-decoration: none;
                display: inline-block;
                transition: background 0.2s;
            }}
            .tool-button:hover {{
                background: linear-gradient(to bottom, #ffffff, #e8e8e8);
                text-decoration: none;
                color: #333;
            }}
            .tool-button:active {{
                background: linear-gradient(to bottom, #e0e0e0, #f0f0f0);
                box-shadow: inset 1px 1px 2px rgba(0,0,0,0.2);
            }}
        </style>
    </head>
    <body>
        <div class="header">
            <h1>Helpful-Tools</h1>
            <p>Collection of useful web development and text processing tools</p>
        </div>
        <div class="tools-grid">
            {tools_html}
        </div>
    </body>
    </html>
    """

@app.get("/tools/{tool_name}", response_class=HTMLResponse)
async def serve_tool(tool_name: str):
    # Find tool configuration
    tool_config = None
    for tool in TOOLS:
        if tool["path"] == f"/tools/{tool_name}":
            tool_config = tool
            break

    if not tool_config:
        return HTMLResponse("Tool not found", status_code=404)

    # Serve the tool HTML file
    tool_file = Path("tools") / tool_config["file"]
    if tool_file.exists():
        with open(tool_file, 'r', encoding='utf-8') as f:
            return HTMLResponse(f.read())
    else:
        return HTMLResponse("Tool file not found", status_code=404)

# Import tool APIs - only if files exist
try:
    from tools.url_encoder_api import router as url_encoder_router
    app.include_router(url_encoder_router, prefix="/api/url-encoder")
except ImportError:
    pass

try:
    from tools.base64_api import router as base64_router
    app.include_router(base64_router, prefix="/api/base64")
except ImportError:
    pass

try:
    from tools.hash_generator_api import router as hash_router
    app.include_router(hash_router, prefix="/api/hash")
except ImportError:
    pass

try:
    from tools.qr_generator_api import router as qr_router
    app.include_router(qr_router, prefix="/api/qr")
except ImportError:
    pass

try:
    from tools.text_diff_api import router as text_diff_router
    app.include_router(text_diff_router, prefix="/api/text-diff")
except ImportError:
    pass

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)
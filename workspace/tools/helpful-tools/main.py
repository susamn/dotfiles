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
    {
        "name": "Binary Calculator & Converter",
        "description": "Convert between number bases, storage units, and explore 32-bit systems with negative number support",
        "path": "/tools/binary-calculator",
        "file": "binary_calculator.html",
        "has_backend": False
    },
    {
        "name": "Matrix Calculator",
        "description": "Convert matrices between different formats, perform operations like addition, subtraction, multiplication, and inversion",
        "path": "/tools/matrix-calculator",
        "file": "matrix_calculator.html",
        "has_backend": False
    },
    {
        "name": "Linear Algebra Solver",
        "description": "Solve systems of linear equations, calculate determinants, matrix inverses, and eigenvalues",
        "path": "/tools/linear-algebra-solver",
        "file": "linear_algebra_solver.html",
        "has_backend": False
    },
    {
        "name": "Vector Operations Visualizer",
        "description": "Visualize vector operations, dot products, cross products, and projections in 2D/3D",
        "path": "/tools/vector-visualizer",
        "file": "vector_visualizer.html",
        "has_backend": False
    },
    {
        "name": "Protocol Buffers (Protobuf) Decoder",
        "description": "Decode binary Protobuf messages using a .proto schema definition",
        "path": "/tools/protobuf-decoder",
        "file": "protobuf_decoder.html",
        "has_backend": True
    },
    {
        "name": "Network Calculator",
        "description": "CIDR, subnetting and IP address calculations",
        "path": "/tools/network-calculator",
        "file": "network_calculator.html",
        "has_backend": False
    }
]

@app.get("/", response_class=HTMLResponse)
async def landing_page():
    tools_html = ""
    for tool in TOOLS:
        tools_html += f"""
        <div class="tool-card" data-href="{tool['path']}">
            <div class="tool-header">
                <h3>{tool['name']}</h3>
            </div>
            <div class="tool-description">
                {tool['description']}
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
                background-color: #f8f9fa;
                color: #333;
                padding: 20px;
            }}
            .header {{
                text-align: center;
                margin-bottom: 30px;
                padding: 20px;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                border-radius: 8px;
                box-shadow: 0 4px 12px rgba(0,0,0,0.1);
                color: white;
            }}
            .header h1 {{
                font-size: 2.2em;
                margin-bottom: 8px;
                font-weight: 600;
            }}
            .header p {{
                font-size: 1em;
                opacity: 0.9;
            }}
            .search-container {{
                max-width: 1200px;
                margin: 0 auto 25px auto;
                position: relative;
            }}
            .search-box {{
                width: 100%;
                padding: 12px 16px;
                font-size: 16px;
                border: 2px solid #e1e5e9;
                border-radius: 8px;
                background: white;
                transition: border-color 0.2s;
                outline: none;
            }}
            .search-box:focus {{
                border-color: #667eea;
                box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
            }}
            .tools-grid {{
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
                gap: 14px;
                max-width: 1200px;
                margin: 0 auto;
            }}
            .tool-card {{
                background: white;
                border: 1px solid #e1e5e9;
                border-radius: 8px;
                box-shadow: 0 1px 3px rgba(0,0,0,0.12), 0 1px 2px rgba(0,0,0,0.24);
                overflow: hidden;
                transition: all 0.2s ease;
                cursor: pointer;
                position: relative;
                display: flex;
                flex-direction: column;
            }}
            .tool-card:hover {{
                transform: translateY(-2px);
                box-shadow: 0 3px 6px rgba(0,0,0,0.16), 0 3px 6px rgba(0,0,0,0.23);
                border-color: #667eea;
            }}
            .tool-card.hidden {{
                display: none;
            }}
            .tool-header {{
                padding: 12px 14px 6px 14px;
            }}
            .tool-header h3 {{
                font-size: 1.05em;
                color: #2d3748;
                margin: 0;
                font-weight: 600;
                line-height: 1.3;
            }}
            .tool-description {{
                padding: 0 14px 12px 14px;
                color: #718096;
                line-height: 1.3;
                font-size: 0.85em;
                flex-grow: 1;
            }}
            .no-results {{
                text-align: center;
                padding: 40px 20px;
                color: #718096;
                display: none;
            }}
            .no-results.visible {{
                display: block;
            }}
        </style>
    </head>
    <body>
        <div class="header">
            <h1>Helpful-Tools</h1>
            <p>Collection of useful web development and text processing tools</p>
        </div>
        <div class="search-container">
            <input type="text" class="search-box" placeholder="Search tools..." id="searchInput">
        </div>
        <div class="tools-grid" id="toolsGrid">
            {tools_html}
        </div>
        <div class="no-results" id="noResults">
            <h3>No tools found</h3>
            <p>Try adjusting your search terms</p>
        </div>
        <script>
            document.getElementById('searchInput').addEventListener('input', function(e) {{
                const searchTerm = e.target.value.toLowerCase();
                const toolCards = document.querySelectorAll('.tool-card');
                const noResults = document.getElementById('noResults');
                let visibleCount = 0;
                
                toolCards.forEach(card => {{
                    const title = card.querySelector('h3').textContent.toLowerCase();
                    const description = card.querySelector('.tool-description').textContent.toLowerCase();
                    
                    if (title.includes(searchTerm) || description.includes(searchTerm)) {{
                        card.classList.remove('hidden');
                        visibleCount++;
                    }} else {{
                        card.classList.add('hidden');
                    }}
                }});
                
                if (visibleCount === 0 && searchTerm.trim() !== '') {{
                    noResults.classList.add('visible');
                }} else {{
                    noResults.classList.remove('visible');
                }}
            }});
            
            document.querySelectorAll('.tool-card').forEach(card => {{
                card.addEventListener('click', function() {{
                    const href = this.getAttribute('data-href');
                    if (href) {{
                        window.location.href = href;
                    }}
                }});
            }});
        </script>
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

try:
    from tools.protobuf_api import router as protobuf_router
    app.include_router(protobuf_router, prefix="/api/protobuf")
except ImportError:
    pass

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)
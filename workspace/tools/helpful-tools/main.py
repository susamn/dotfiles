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
        "has_backend": False,
        "tags": ["calculator", "math"]
    },
    {
        "name": "JSON Formatter",
        "description": "Format, minify and validate JSON data",
        "path": "/tools/json-formatter",
        "file": "json_formatter.html",
        "has_backend": False,
        "tags": ["formatter", "json"]
    },
    {
        "name": "SQL Formatter",
        "description": "Format and beautify SQL queries",
        "path": "/tools/sql-formatter",
        "file": "sql_formatter.html",
        "has_backend": False,
        "tags": ["formatter", "database"]
    },
    {
        "name": "YAML Validator",
        "description": "Validate and format YAML data",
        "path": "/tools/yaml-validator",
        "file": "yaml_validator.html",
        "has_backend": False,
        "tags": ["validator", "yaml"]
    },
    {
        "name": "JSON-XML-YAML Converter",
        "description": "Convert between JSON, XML and YAML formats",
        "path": "/tools/json-yaml-xml-converter",
        "file": "json_yaml_xml_converter.html",
        "has_backend": False,
        "tags": ["converter", "json", "xml", "yaml"]
    },
    {
        "name": "CSV-JSON Converter",
        "description": "Convert between CSV and JSON formats",
        "path": "/tools/csv-json-converter",
        "file": "csv_json_converter.html",
        "has_backend": False,
        "tags": ["converter", "csv", "json"]
    },
    {
        "name": "Cron Parser",
        "description": "Parse and explain cron expressions",
        "path": "/tools/cron-parser",
        "file": "cron_parser.html",
        "has_backend": False,
        "tags": ["parser", "scheduler"]
    },
    {
        "name": "Regex Tester",
        "description": "Test and debug regular expressions",
        "path": "/tools/regex-tester",
        "file": "regex_tester.html",
        "has_backend": False,
        "tags": ["tester", "regex"]
    },
    {
        "name": "JWT Decoder",
        "description": "Decode and analyze JWT tokens",
        "path": "/tools/jwt-decoder",
        "file": "jwt_decoder.html",
        "has_backend": False,
        "tags": ["decoder", "security"]
    },
    {
        "name": "URL Encoder/Decoder",
        "description": "Encode and decode URLs",
        "path": "/tools/url-encoder",
        "file": "url_encoder.html",
        "has_backend": True,
        "tags": ["encoder", "decoder", "web"]
    },
    {
        "name": "Base64 Encoder/Decoder",
        "description": "Encode and decode Base64 strings",
        "path": "/tools/base64",
        "file": "base64_tool.html",
        "has_backend": True,
        "tags": ["encoder", "decoder", "base64"]
    },
    {
        "name": "Hash Generator",
        "description": "Generate MD5, SHA1, SHA256 hashes",
        "path": "/tools/hash-generator",
        "file": "hash_generator.html",
        "has_backend": True,
        "tags": ["generator", "security", "crypto"]
    },
    {
        "name": "QR Code Generator",
        "description": "Generate QR codes from text",
        "path": "/tools/qr-generator",
        "file": "qr_generator.html",
        "has_backend": True,
        "tags": ["generator", "qr-code", "imaging"]
    },
    {
        "name": "PlantUML Viewer",
        "description": "Create and view PlantUML diagrams",
        "path": "/tools/plantuml-viewer",
        "file": "puml_viewer.html",
        "has_backend": False,
        "tags": ["viewer", "diagrams", "uml"]
    },
    {
        "name": "Text Diff Tool",
        "description": "Compare two text blocks",
        "path": "/tools/text-diff",
        "file": "text_diff.html",
        "has_backend": True,
        "tags": ["diff", "comparison", "text"]
    },
    {
        "name": "Color Converter",
        "description": "Convert between HEX, RGB, HSL color formats",
        "path": "/tools/color-converter",
        "file": "color_converter.html",
        "has_backend": False,
        "tags": ["converter", "color", "design"]
    },
    {
        "name": "Timestamp Converter Tool",
        "description": "Convert between Unix timestamps and human dates",
        "path": "/tools/timestamp-converter",
        "file": "timestamp_converter.html",
        "has_backend": False,
        "tags": ["converter", "timestamp", "date"]
    },
    {
        "name": "HTML Entity Converter",
        "description": "Encode and decode HTML entities",
        "path": "/tools/html-entity-converter",
        "file": "html_entity_converter.html",
        "has_backend": False,
        "tags": ["converter", "html", "web"]
    },
    {
        "name": "Binary Calculator & Converter",
        "description": "Convert between number bases, storage units, and explore 32-bit systems with negative number support",
        "path": "/tools/binary-calculator",
        "file": "binary_calculator.html",
        "has_backend": False,
        "tags": ["calculator", "converter", "binary", "math"]
    },
    {
        "name": "Matrix Calculator",
        "description": "Convert matrices between different formats, perform operations like addition, subtraction, multiplication, and inversion",
        "path": "/tools/matrix-calculator",
        "file": "matrix_calculator.html",
        "has_backend": False,
        "tags": ["calculator", "matrix", "math"]
    },
    {
        "name": "Linear Algebra Solver",
        "description": "Solve systems of linear equations, calculate determinants, matrix inverses, and eigenvalues",
        "path": "/tools/linear-algebra-solver",
        "file": "linear_algebra_solver.html",
        "has_backend": False,
        "tags": ["solver", "algebra", "math"]
    },
    {
        "name": "Vector Operations Visualizer",
        "description": "Visualize vector operations, dot products, cross products, and projections in 2D/3D",
        "path": "/tools/vector-visualizer",
        "file": "vector_visualizer.html",
        "has_backend": False,
        "tags": ["visualizer", "vector", "math"]
    },
    {
        "name": "Protocol Buffers (Protobuf) Decoder",
        "description": "Decode binary Protobuf messages using a .proto schema definition",
        "path": "/tools/protobuf-decoder",
        "file": "protobuf_decoder.html",
        "has_backend": True,
        "tags": ["decoder", "protobuf", "protocol"]
    },
    {
        "name": "Network Calculator",
        "description": "CIDR, subnetting and IP address calculations",
        "path": "/tools/network-calculator",
        "file": "network_calculator.html",
        "has_backend": False,
        "tags": ["calculator", "network", "cidr"]
    }
]

@app.get("/", response_class=HTMLResponse)
async def landing_page():
    tools_html = ""
    for tool in TOOLS:
        tags_html = ""
        for tag in tool.get('tags', []):
            tags_html += f'<span class="tag tag-{tag}">{tag}</span>'
        
        tools_html += f"""
        <div class="tool-card" data-href="{tool['path']}" data-tool-id="{tool['path']}">
            <div class="tool-header">
                <h3>{tool['name']}</h3>
                <button class="star-btn" onclick="toggleStar(event, '{tool['path']}')" title="Star this tool">
                    <svg class="star-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <polygon points="12,2 15.09,8.26 22,9.27 17,14.14 18.18,21.02 12,17.77 5.82,21.02 7,14.14 2,9.27 8.91,8.26"></polygon>
                    </svg>
                </button>
            </div>
            <div class="tool-description">
                {tool['description']}
            </div>
            <div class="tool-tags">
                {tags_html}
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
                display: flex;
                justify-content: space-between;
                align-items: center;
            }}
            .tool-header h3 {{
                font-size: 1.05em;
                color: #2d3748;
                margin: 0;
                font-weight: 600;
                line-height: 1.3;
                flex: 1;
            }}
            .star-btn {{
                background: none;
                border: none;
                cursor: pointer;
                padding: 4px;
                border-radius: 50%;
                display: flex;
                align-items: center;
                justify-content: center;
                transition: all 0.2s ease;
                opacity: 0.6;
            }}
            .star-btn:hover {{
                opacity: 1;
                background: rgba(0,0,0,0.05);
            }}
            .star-icon {{
                width: 16px;
                height: 16px;
                color: #718096;
                transition: all 0.2s ease;
            }}
            .star-btn.starred .star-icon {{
                fill: #ffd700;
                color: #ffd700;
            }}
            .tool-card.starred {{
                border-color: #ffd700;
                box-shadow: 0 1px 3px rgba(255, 215, 0, 0.2), 0 1px 2px rgba(255, 215, 0, 0.1);
            }}
            .starred-section {{
                margin-bottom: 20px;
                max-width: 1200px;
                margin-left: auto;
                margin-right: auto;
            }}
            .starred-section h2 {{
                color: #2d3748;
                font-size: 1.1em;
                margin-bottom: 10px;
                padding-left: 4px;
                display: flex;
                align-items: center;
                gap: 8px;
            }}
            .starred-section .star-icon {{
                width: 18px;
                height: 18px;
                fill: #ffd700;
                color: #ffd700;
            }}
            .section-divider {{
                height: 1px;
                background: linear-gradient(to right, #e1e5e9, transparent);
                margin: 20px 0;
            }}
            #starredGrid {{
                display: grid;
                grid-template-columns: repeat(4, 1fr);
                gap: 14px;
                max-width: 1200px;
                margin: 0 auto;
            }}
            @media (max-width: 1200px) {{
                #starredGrid {{
                    grid-template-columns: repeat(3, 1fr);
                }}
            }}
            @media (max-width: 900px) {{
                #starredGrid {{
                    grid-template-columns: repeat(2, 1fr);
                }}
            }}
            @media (max-width: 600px) {{
                #starredGrid {{
                    grid-template-columns: 1fr;
                }}
            }}
            .tool-description {{
                padding: 0 14px 8px 14px;
                color: #718096;
                line-height: 1.3;
                font-size: 0.85em;
                flex-grow: 1;
            }}
            .tool-tags {{
                padding: 0 14px 12px 14px;
                display: flex;
                flex-wrap: wrap;
                gap: 4px;
            }}
            .tag {{
                padding: 2px 6px;
                border-radius: 10px;
                font-size: 0.7em;
                font-weight: 500;
                text-transform: lowercase;
                border: 1px solid transparent;
            }}
            /* Tag colors based on function type */
            .tag-calculator {{ background: #e3f2fd; color: #1565c0; border-color: #bbdefb; }}
            .tag-converter {{ background: #f3e5f5; color: #7b1fa2; border-color: #ce93d8; }}
            .tag-formatter {{ background: #e8f5e8; color: #2e7d32; border-color: #a5d6a7; }}
            .tag-validator {{ background: #fff3e0; color: #ef6c00; border-color: #ffcc95; }}
            .tag-parser {{ background: #fce4ec; color: #c2185b; border-color: #f8bbd9; }}
            .tag-tester {{ background: #e0f2f1; color: #00695c; border-color: #80cbc4; }}
            .tag-decoder {{ background: #fff8e1; color: #f57f17; border-color: #fff176; }}
            .tag-encoder {{ background: #e1f5fe; color: #0277bd; border-color: #81d4fa; }}
            .tag-generator {{ background: #f1f8e9; color: #558b2f; border-color: #c5e1a5; }}
            .tag-viewer {{ background: #fafafa; color: #424242; border-color: #e0e0e0; }}
            .tag-solver {{ background: #e8eaf6; color: #3f51b5; border-color: #c5cae9; }}
            .tag-visualizer {{ background: #f3e5f5; color: #8e24aa; border-color: #d1c4e9; }}
            .tag-diff {{ background: #ffebee; color: #d32f2f; border-color: #ffcdd2; }}
            /* Content type tags */
            .tag-json {{ background: #e3f2fd; color: #1976d2; border-color: #90caf9; }}
            .tag-xml {{ background: #e8f5e8; color: #388e3c; border-color: #a5d6a7; }}
            .tag-yaml {{ background: #fff3e0; color: #f57c00; border-color: #ffcc95; }}
            .tag-csv {{ background: #f1f8e9; color: #689f38; border-color: #c5e1a5; }}
            .tag-html {{ background: #ffebee; color: #d32f2f; border-color: #ffcdd2; }}
            .tag-sql {{ background: #f3e5f5; color: #7b1fa2; border-color: #ce93d8; }}
            .tag-regex {{ background: #e0f2f1; color: #00796b; border-color: #80cbc4; }}
            .tag-base64 {{ background: #e1f5fe; color: #0288d1; border-color: #81d4fa; }}
            /* Domain tags */
            .tag-math {{ background: #e8eaf6; color: #3f51b5; border-color: #c5cae9; }}
            .tag-security {{ background: #fff8e1; color: #f9a825; border-color: #fff59d; }}
            .tag-crypto {{ background: #fff3e0; color: #ff8f00; border-color: #ffcc95; }}
            .tag-web {{ background: #e3f2fd; color: #1565c0; border-color: #bbdefb; }}
            .tag-network {{ background: #e0f2f1; color: #00695c; border-color: #80cbc4; }}
            .tag-database {{ background: #f3e5f5; color: #7b1fa2; border-color: #ce93d8; }}
            .tag-design {{ background: #fce4ec; color: #c2185b; border-color: #f8bbd9; }}
            .tag-imaging {{ background: #f1f8e9; color: #558b2f; border-color: #c5e1a5; }}
            .tag-text {{ background: #fafafa; color: #424242; border-color: #e0e0e0; }}
            .tag-date {{ background: #fff8e1; color: #f57f17; border-color: #fff176; }}
            .tag-timestamp {{ background: #fff8e1; color: #f57f17; border-color: #fff176; }}
            .tag-scheduler {{ background: #e8f5e8; color: #2e7d32; border-color: #a5d6a7; }}
            .tag-comparison {{ background: #ffebee; color: #d32f2f; border-color: #ffcdd2; }}
            .tag-color {{ background: #fce4ec; color: #c2185b; border-color: #f8bbd9; }}
            .tag-binary {{ background: #e8eaf6; color: #3f51b5; border-color: #c5cae9; }}
            .tag-matrix {{ background: #e8eaf6; color: #3f51b5; border-color: #c5cae9; }}
            .tag-vector {{ background: #f3e5f5; color: #8e24aa; border-color: #d1c4e9; }}
            .tag-algebra {{ background: #e8eaf6; color: #3f51b5; border-color: #c5cae9; }}
            .tag-protobuf {{ background: #e0f2f1; color: #00695c; border-color: #80cbc4; }}
            .tag-protocol {{ background: #e0f2f1; color: #00695c; border-color: #80cbc4; }}
            .tag-cidr {{ background: #e0f2f1; color: #00695c; border-color: #80cbc4; }}
            .tag-diagrams {{ background: #fafafa; color: #424242; border-color: #e0e0e0; }}
            .tag-uml {{ background: #fafafa; color: #424242; border-color: #e0e0e0; }}
            .tag-qr-code {{ background: #f1f8e9; color: #558b2f; border-color: #c5e1a5; }}
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
        
        <div id="starredSection" class="starred-section" style="display: none;">
            <h2>
                <svg class="star-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <polygon points="12,2 15.09,8.26 22,9.27 17,14.14 18.18,21.02 12,17.77 5.82,21.02 7,14.14 2,9.27 8.91,8.26"></polygon>
                </svg>
                Starred Tools
            </h2>
            <div class="tools-grid" id="starredGrid"></div>
            <div class="section-divider"></div>
        </div>
        
        <div class="tools-grid" id="toolsGrid">
            {tools_html}
        </div>
        <div class="no-results" id="noResults">
            <h3>No tools found</h3>
            <p>Try adjusting your search terms</p>
        </div>
        <script>
            // localStorage functions for starring
            function getStarredTools() {{
                const starred = localStorage.getItem('starredTools');
                return starred ? JSON.parse(starred) : [];
            }}
            
            function saveStarredTools(starredTools) {{
                localStorage.setItem('starredTools', JSON.stringify(starredTools));
            }}
            
            function toggleStar(event, toolId) {{
                event.stopPropagation(); // Prevent card click
                
                const starredTools = getStarredTools();
                const isStarred = starredTools.includes(toolId);
                const starBtn = event.target.closest('.star-btn');
                const toolCard = event.target.closest('.tool-card');
                
                if (isStarred) {{
                    // Remove from starred
                    const index = starredTools.indexOf(toolId);
                    starredTools.splice(index, 1);
                    starBtn.classList.remove('starred');
                    toolCard.classList.remove('starred');
                }} else {{
                    // Add to starred
                    starredTools.push(toolId);
                    starBtn.classList.add('starred');
                    toolCard.classList.add('starred');
                }}
                
                saveStarredTools(starredTools);
                updateStarredSection();
            }}
            
            function updateStarredSection() {{
                const starredTools = getStarredTools();
                const starredSection = document.getElementById('starredSection');
                const starredGrid = document.getElementById('starredGrid');
                
                if (starredTools.length === 0) {{
                    starredSection.style.display = 'none';
                    return;
                }}
                
                // Show starred section
                starredSection.style.display = 'block';
                
                // Clear current starred grid
                starredGrid.innerHTML = '';
                
                // Clone starred tool cards
                starredTools.forEach(toolId => {{
                    const originalCard = document.querySelector(`[data-tool-id="${{toolId}}"]`);
                    if (originalCard) {{
                        const clonedCard = originalCard.cloneNode(true);
                        
                        // Update the clone's star button to work with the clone
                        const clonedStarBtn = clonedCard.querySelector('.star-btn');
                        clonedStarBtn.setAttribute('onclick', `toggleStar(event, '${{toolId}}')`);
                        
                        // Add click handler for navigation
                        clonedCard.addEventListener('click', function() {{
                            const href = this.getAttribute('data-href');
                            if (href) {{
                                window.location.href = href;
                            }}
                        }});
                        
                        starredGrid.appendChild(clonedCard);
                    }}
                }});
            }}
            
            function initializeStars() {{
                const starredTools = getStarredTools();
                
                // Mark starred tools
                starredTools.forEach(toolId => {{
                    const toolCard = document.querySelector(`[data-tool-id="${{toolId}}"]`);
                    if (toolCard) {{
                        const starBtn = toolCard.querySelector('.star-btn');
                        starBtn.classList.add('starred');
                        toolCard.classList.add('starred');
                    }}
                }});
                
                updateStarredSection();
            }}
            
            // Search functionality
            document.getElementById('searchInput').addEventListener('input', function(e) {{
                const searchTerm = e.target.value.toLowerCase();
                const toolCards = document.querySelectorAll('#toolsGrid .tool-card, #starredGrid .tool-card');
                const noResults = document.getElementById('noResults');
                let visibleCount = 0;
                
                toolCards.forEach(card => {{
                    const title = card.querySelector('h3').textContent.toLowerCase();
                    const description = card.querySelector('.tool-description').textContent.toLowerCase();
                    const tags = card.querySelector('.tool-tags').textContent.toLowerCase();
                    
                    if (title.includes(searchTerm) || description.includes(searchTerm) || tags.includes(searchTerm)) {{
                        card.classList.remove('hidden');
                        visibleCount++;
                    }} else {{
                        card.classList.add('hidden');
                    }}
                }});
                
                // Hide/show starred section based on search
                const starredSection = document.getElementById('starredSection');
                const starredCards = document.querySelectorAll('#starredGrid .tool-card:not(.hidden)');
                if (searchTerm.trim() !== '' && starredCards.length === 0) {{
                    starredSection.style.display = 'none';
                }} else if (getStarredTools().length > 0) {{
                    starredSection.style.display = 'block';
                }}
                
                if (visibleCount === 0 && searchTerm.trim() !== '') {{
                    noResults.classList.add('visible');
                }} else {{
                    noResults.classList.remove('visible');
                }}
            }});
            
            // Tool card click handlers
            document.querySelectorAll('.tool-card').forEach(card => {{
                card.addEventListener('click', function() {{
                    const href = this.getAttribute('data-href');
                    if (href) {{
                        window.location.href = href;
                    }}
                }});
            }});
            
            // Initialize starred tools on page load
            document.addEventListener('DOMContentLoaded', initializeStars);
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
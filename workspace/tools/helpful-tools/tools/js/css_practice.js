    let htmlEditor, cssEditor;
    let autoRun = false;
    let runTimeout = null;

    // CSS Tricks Data
    const cssTriicks = {
        "Layout & Positioning": [
            {
                title: "Flexbox Centering",
                description: "Perfect center alignment using flexbox",
                html: `<div class="flex-center">
    <div class="content">Centered Content</div>
</div>`,
                css: `.flex-center {
    display: flex;
    justify-content: center;
    align-items: center;
    height: 100vh;
    background: #f0f0f0;
}

.content {
    padding: 20px;
    background: white;
    border-radius: 8px;
    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
}`
            },
            {
                title: "CSS Grid Layout",
                description: "Create responsive grid layouts",
                html: `<div class="grid-container">
    <div class="grid-item">1</div>
    <div class="grid-item">2</div>
    <div class="grid-item">3</div>
    <div class="grid-item">4</div>
    <div class="grid-item">5</div>
    <div class="grid-item">6</div>
</div>`,
                css: `.grid-container {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 20px;
    padding: 20px;
}

.grid-item {
    background: linear-gradient(135deg, #667eea, #764ba2);
    padding: 20px;
    text-align: center;
    color: white;
    border-radius: 8px;
    font-size: 24px;
    font-weight: bold;
}`
            },
            {
                title: "Sticky Navigation",
                description: "Navigation that sticks to top when scrolling",
                html: `<nav class="sticky-nav">Navigation</nav>
<div class="content">
    <h1>Page Content</h1>
    <p>Scroll down to see sticky effect...</p>
    <div style="height: 2000px; background: linear-gradient(to bottom, #f0f0f0, #e0e0e0);">
        <p style="padding: 20px;">Long content to demonstrate scrolling</p>
    </div>
</div>`,
                css: `.sticky-nav {
    position: sticky;
    top: 0;
    background: #333;
    color: white;
    padding: 15px 20px;
    z-index: 100;
    box-shadow: 0 2px 5px rgba(0,0,0,0.1);
}

.content {
    padding: 20px;
}`
            }
        ],
        "Visual Effects": [
            {
                title: "CSS Animations",
                description: "Smooth animations using keyframes",
                html: `<div class="animation-container">
    <div class="bounce-ball"></div>
    <div class="pulse-circle"></div>
    <div class="rotate-square"></div>
</div>`,
                css: `.animation-container {
    display: flex;
    justify-content: space-around;
    align-items: center;
    height: 300px;
    background: #f0f0f0;
}

.bounce-ball {
    width: 50px;
    height: 50px;
    background: #ff6b6b;
    border-radius: 50%;
    animation: bounce 2s infinite;
}

.pulse-circle {
    width: 60px;
    height: 60px;
    background: #4ecdc4;
    border-radius: 50%;
    animation: pulse 2s infinite;
}

.rotate-square {
    width: 50px;
    height: 50px;
    background: #45b7d1;
    animation: rotate 3s linear infinite;
}

@keyframes bounce {
    0%, 100% { transform: translateY(0); }
    50% { transform: translateY(-50px); }
}

@keyframes pulse {
    0%, 100% { transform: scale(1); }
    50% { transform: scale(1.2); }
}

@keyframes rotate {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
}`
            },
            {
                title: "Box Shadows",
                description: "Various shadow effects",
                html: `<div class="shadow-examples">
    <div class="card shadow-soft">Soft Shadow</div>
    <div class="card shadow-hard">Hard Shadow</div>
    <div class="card shadow-inset">Inset Shadow</div>
    <div class="card shadow-colorful">Colorful Shadow</div>
</div>`,
                css: `.shadow-examples {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 30px;
    padding: 30px;
    background: #f5f5f5;
}

.card {
    padding: 20px;
    background: white;
    border-radius: 8px;
    text-align: center;
    font-weight: bold;
}

.shadow-soft {
    box-shadow: 0 4px 6px rgba(0,0,0,0.1);
}

.shadow-hard {
    box-shadow: 0 0 0 1px rgba(0,0,0,0.1), 0 4px 11px rgba(0,0,0,0.15);
}

.shadow-inset {
    box-shadow: inset 0 2px 4px rgba(0,0,0,0.1);
}

.shadow-colorful {
    box-shadow: 0 8px 16px rgba(255,107,107,0.3);
}`
            },
            {
                title: "Hover Effects",
                description: "Smooth hover transitions",
                html: `<div class="hover-gallery">
    <div class="hover-card lift">Lift Effect</div>
    <div class="hover-card glow">Glow Effect</div>
    <div class="hover-card flip">Flip Effect</div>
    <div class="hover-card slide">Slide Effect</div>
</div>`,
                css: `.hover-gallery {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 20px;
    padding: 30px;
    background: #f0f0f0;
}

.hover-card {
    padding: 40px 20px;
    background: white;
    text-align: center;
    border-radius: 8px;
    cursor: pointer;
    transition: all 0.3s ease;
    font-weight: bold;
}

.lift:hover {
    transform: translateY(-10px);
    box-shadow: 0 20px 40px rgba(0,0,0,0.15);
}

.glow:hover {
    box-shadow: 0 0 20px rgba(70,130,180,0.5);
    border: 2px solid #4682b4;
}

.flip:hover {
    transform: rotateY(180deg);
    background: #4ecdc4;
    color: white;
}

.slide {
    overflow: hidden;
    position: relative;
}

.slide::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(90deg, transparent, rgba(255,255,255,0.3), transparent);
    transition: left 0.6s;
}

.slide:hover::before {
    left: 100%;
}`
            }
        ],
        "Responsive Design": [
            {
                title: "Media Queries",
                description: "Responsive breakpoints",
                html: `<div class="responsive-demo">
    <div class="responsive-grid">
        <div class="item">1</div>
        <div class="item">2</div>
        <div class="item">3</div>
        <div class="item">4</div>
    </div>
    <p class="responsive-text">Resize browser to see responsive behavior</p>
</div>`,
                css: `.responsive-demo {
    padding: 20px;
}

.responsive-grid {
    display: grid;
    gap: 20px;
    grid-template-columns: repeat(4, 1fr);
}

.item {
    background: #667eea;
    color: white;
    padding: 40px;
    text-align: center;
    border-radius: 8px;
    font-size: 24px;
    font-weight: bold;
}

.responsive-text {
    text-align: center;
    margin-top: 20px;
    font-style: italic;
    color: #666;
}

/* Tablet */
@media (max-width: 768px) {
    .responsive-grid {
        grid-template-columns: repeat(2, 1fr);
    }
    
    .item {
        padding: 30px;
        font-size: 20px;
    }
}

/* Mobile */
@media (max-width: 480px) {
    .responsive-grid {
        grid-template-columns: 1fr;
    }
    
    .item {
        padding: 20px;
        font-size: 18px;
    }
    
    .responsive-demo {
        padding: 10px;
    }
}`
            }
        ]
    };

    // Example templates
    const examples = {
        "Common Layouts": [
            {
                title: "Card Layout",
                description: "Modern card-based layout",
                html: `<div class="card-container">
    <div class="card">
        <img src="https://via.placeholder.com/300x200" alt="Image">
        <div class="card-content">
            <h3>Card Title</h3>
            <p>Card description goes here</p>
            <button class="card-btn">Read More</button>
        </div>
    </div>
</div>`,
                css: `.card-container {
    padding: 20px;
    display: flex;
    justify-content: center;
}

.card {
    max-width: 300px;
    background: white;
    border-radius: 12px;
    overflow: hidden;
    box-shadow: 0 4px 15px rgba(0,0,0,0.1);
    transition: transform 0.3s ease;
}

.card:hover {
    transform: translateY(-5px);
}

.card img {
    width: 100%;
    height: 200px;
    object-fit: cover;
}

.card-content {
    padding: 20px;
}

.card h3 {
    margin: 0 0 10px 0;
    color: #333;
}

.card p {
    color: #666;
    line-height: 1.5;
    margin-bottom: 15px;
}

.card-btn {
    background: #667eea;
    color: white;
    border: none;
    padding: 8px 16px;
    border-radius: 4px;
    cursor: pointer;
}`
            }
        ]
    };

    function initializeEditors() {
        // Initialize HTML editor
        htmlEditor = CodeMirror.fromTextArea(document.getElementById('htmlEditor'), {
            mode: 'htmlmixed',
            theme: 'material',
            lineNumbers: true,
            autoCloseTags: true,
            autoCloseBrackets: true,
            indentUnit: 2,
            tabSize: 2,
            lineWrapping: true
        });

        // Initialize CSS editor  
        cssEditor = CodeMirror.fromTextArea(document.getElementById('cssEditor'), {
            mode: 'css',
            theme: 'material',
            lineNumbers: true,
            autoCloseBrackets: true,
            indentUnit: 2,
            tabSize: 2,
            lineWrapping: true
        });

        // Setup auto-run
        htmlEditor.on('change', () => {
            if (autoRun) {
                clearTimeout(runTimeout);
                runTimeout = setTimeout(runCode, 1000);
            }
            updateEditorInfo();
        });

        cssEditor.on('change', () => {
            if (autoRun) {
                clearTimeout(runTimeout);
                runTimeout = setTimeout(runCode, 1000);
            }
            updateEditorInfo();
        });
    }

    function toggleCategory(categoryElement) {
        const content = categoryElement.nextElementSibling;
        const icon = categoryElement.querySelector('.toggle-icon');
        
        content.classList.toggle('expanded');
        icon.classList.toggle('expanded');
    }

    function loadTrick(trick) {
        htmlEditor.setValue(createFullHTML(trick.html, trick.css));
        cssEditor.setValue(trick.css);
        
        if (autoRun) {
            runCode();
        }
    }

    function createFullHTML(bodyContent, css) {
        return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CSS Practice</title>
    <style>
        ${css}
    </style>
</head>
<body>
    ${bodyContent}
</body>
</html>`;
    }

    function populatePanel(containerId, data) {
        const container = document.getElementById(containerId);
        container.innerHTML = '';

        Object.keys(data).forEach(category => {
            const categoryDiv = document.createElement('div');
            categoryDiv.className = 'trick-category';

            const header = document.createElement('div');
            header.className = 'category-header';
            header.onclick = () => toggleCategory(header);
            header.innerHTML = `
                <span>${category}</span>
                <span class="toggle-icon">▶</span>
            `;

            const content = document.createElement('div');
            content.className = 'category-content';

            data[category].forEach(item => {
                const itemDiv = document.createElement('div');
                itemDiv.className = 'trick-item';
                itemDiv.onclick = () => loadTrick(item);
                itemDiv.innerHTML = `
                    <div class="trick-title">${item.title}</div>
                    <div class="trick-description">${item.description}</div>
                `;
                content.appendChild(itemDiv);
            });

            categoryDiv.appendChild(header);
            categoryDiv.appendChild(content);
            container.appendChild(categoryDiv);
        });
    }

    function switchLeftTab(tab) {
        document.querySelectorAll('.panel-tab').forEach(t => t.classList.remove('active'));
        document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
        
        event.target.classList.add('active');
        document.getElementById(tab + 'Tab').classList.add('active');
    }

    function runCode() {
        const html = htmlEditor.getValue();
        const css = cssEditor.getValue();
        const preview = document.getElementById('preview');
        
        const fullHTML = html.includes('<!DOCTYPE html>') ? 
            html.replace(/<style>[\s\S]*?<\/style>/, `<style>${css}</style>`) :
            createFullHTML(html, css);
        
        const blob = new Blob([fullHTML], { type: 'text/html' });
        const url = URL.createObjectURL(blob);
        preview.src = url;
        
        updateStatus('Code executed successfully');
        updateEditorInfo();
    }

    function clearCode() {
        htmlEditor.setValue('');
        cssEditor.setValue('');
        document.getElementById('preview').src = '';
        updateStatus('Editors cleared');
        updateEditorInfo();
    }

    function toggleAutoRun() {
        autoRun = !autoRun;
        const btn = document.getElementById('autoRunBtn');
        btn.textContent = `Auto Run: ${autoRun ? 'ON' : 'OFF'}`;
        btn.classList.toggle('active', autoRun);
        
        if (autoRun) {
            runCode();
        }
    }

    function loadExample(type) {
        const examples = {
            flexbox: {
                html: `<div class="flex-container">
    <div class="flex-item">Item 1</div>
    <div class="flex-item">Item 2</div>
    <div class="flex-item">Item 3</div>
</div>`,
                css: `.flex-container {
    display: flex;
    justify-content: space-around;
    align-items: center;
    height: 200px;
    background: #f0f0f0;
    gap: 20px;
    padding: 20px;
}

.flex-item {
    background: #667eea;
    color: white;
    padding: 20px;
    border-radius: 8px;
    flex: 1;
    text-align: center;
}`
            },
            grid: {
                html: `<div class="grid-container">
    <div class="grid-item header">Header</div>
    <div class="grid-item sidebar">Sidebar</div>
    <div class="grid-item main">Main Content</div>
    <div class="grid-item footer">Footer</div>
</div>`,
                css: `.grid-container {
    display: grid;
    grid-template-areas:
        "header header"
        "sidebar main"
        "footer footer";
    grid-template-rows: auto 1fr auto;
    grid-template-columns: 200px 1fr;
    gap: 10px;
    height: 400px;
    padding: 10px;
}

.grid-item {
    background: #4ecdc4;
    color: white;
    padding: 20px;
    border-radius: 8px;
    display: flex;
    align-items: center;
    justify-content: center;
}

.header { grid-area: header; background: #ff6b6b; }
.sidebar { grid-area: sidebar; background: #45b7d1; }
.main { grid-area: main; background: #96ceb4; }
.footer { grid-area: footer; background: #ffa726; }`
            },
            animation: {
                html: `<div class="animation-playground">
    <div class="animated-box fadeIn">Fade In</div>
    <div class="animated-box slideUp">Slide Up</div>
    <div class="animated-box rotateIn">Rotate In</div>
</div>`,
                css: `.animation-playground {
    display: flex;
    justify-content: space-around;
    align-items: center;
    height: 300px;
    background: #2c3e50;
    padding: 20px;
}

.animated-box {
    width: 120px;
    height: 120px;
    background: #e74c3c;
    color: white;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 8px;
    font-weight: bold;
    text-align: center;
}

.fadeIn {
    animation: fadeIn 2s ease-in-out infinite alternate;
}

.slideUp {
    animation: slideUp 2s ease-in-out infinite alternate;
}

.rotateIn {
    animation: rotateIn 2s ease-in-out infinite alternate;
}

@keyframes fadeIn {
    from { opacity: 0.3; }
    to { opacity: 1; }
}

@keyframes slideUp {
    from { transform: translateY(20px); }
    to { transform: translateY(-20px); }
}

@keyframes rotateIn {
    from { transform: rotate(-15deg) scale(0.8); }
    to { transform: rotate(15deg) scale(1.1); }
}`
            }
        };

        if (examples[type]) {
            htmlEditor.setValue(createFullHTML(examples[type].html, examples[type].css));
            cssEditor.setValue(examples[type].css);
            runCode();
        }
    }

    function updateStatus(message) {
        document.getElementById('statusText').textContent = message;
    }

    function updateEditorInfo() {
        const htmlLines = htmlEditor.getValue().split('\n').length;
        const cssLines = cssEditor.getValue().split('\n').length;
        document.getElementById('editorInfo').textContent = `HTML: ${htmlLines} lines | CSS: ${cssLines} lines`;
    }

    // Initialize
    document.addEventListener('DOMContentLoaded', function() {
        initializeEditors();
        populatePanel('tricksContainer', cssTriicks);
        populatePanel('examplesContainer', examples);
        updateEditorInfo();
        
        // Load initial example
        setTimeout(() => {
            loadExample('flexbox');
        }, 100);
    });
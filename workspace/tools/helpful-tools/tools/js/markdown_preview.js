    let syntaxPanelVisible = true;

    // Examples
    const examples = {
        simple: `# Welcome to Markdown Preview

This is a **simple example** to get you started with *markdown*.

## Features
- Live preview
- Syntax highlighting
- Easy formatting

> Start typing in the left panel to see the magic happen!`,

        full: `# Markdown Preview Tool

Welcome to the **comprehensive markdown preview tool**! This tool supports all major markdown features.

## Text Formatting

You can make text **bold**, *italic*, or ~~strikethrough~~. You can also use \`inline code\`.

## Headers

# Header 1
## Header 2  
### Header 3
#### Header 4

## Lists

### Unordered List
- Item 1
- Item 2
  - Nested item
  - Another nested item
- Item 3

### Ordered List
1. First item
2. Second item
3. Third item

### Task List
- [x] Completed task
- [ ] Pending task
- [ ] Another pending task

## Links and Images

[Visit GitHub](https://github.com)

![Sample Image](https://via.placeholder.com/300x200?text=Sample+Image)

## Code

Inline code: \`console.log('Hello World')\`

Block code:
\`\`\`javascript
function greet(name) {
    return \`Hello, \${name}!\`;
}

console.log(greet('World'));
\`\`\`

## Tables

| Feature | Supported | Notes |
|---------|-----------|-------|
| Headers | ✅ | All levels |
| Lists | ✅ | Nested support |
| Code | ✅ | Syntax highlighting |
| Tables | ✅ | This table! |

## Quotes

> "The best way to predict the future is to implement it."
> 
> — David Heinemeier Hansson

## Horizontal Rule

---

That's it! Happy writing! 🚀`
    };

    function updatePreview() {
        const input = document.getElementById('markdownInput').value;
        const preview = document.getElementById('markdownPreview');
        
        try {
            const html = marked.parse(input);
            preview.innerHTML = html;
            document.getElementById('statusText').textContent = 'Preview updated successfully';
        } catch (error) {
            preview.innerHTML = `<div style="color: #cc0000; padding: 20px;">Error parsing markdown: ${error.message}</div>`;
            document.getElementById('statusText').textContent = 'Error parsing markdown';
        }
        
        updateCharCount();
    }

    function updateCharCount() {
        const input = document.getElementById('markdownInput').value;
        document.getElementById('charCount').textContent = `Characters: ${input.length}`;
    }

    function clearAll() {
        document.getElementById('markdownInput').value = '';
        document.getElementById('markdownPreview').innerHTML = '';
        document.getElementById('statusText').textContent = 'Ready - Type markdown to see live preview';
        updateCharCount();
    }

    function copyMarkdown() {
        const input = document.getElementById('markdownInput');
        input.select();
        document.execCommand('copy');
        
        const statusText = document.getElementById('statusText');
        const originalText = statusText.textContent;
        statusText.textContent = 'Markdown copied to clipboard';
        setTimeout(() => {
            statusText.textContent = originalText;
        }, 2000);
    }

    function copyHtml() {
        const preview = document.getElementById('markdownPreview');
        const html = preview.innerHTML;
        
        navigator.clipboard.writeText(html).then(() => {
            const statusText = document.getElementById('statusText');
            const originalText = statusText.textContent;
            statusText.textContent = 'HTML copied to clipboard';
            setTimeout(() => {
                statusText.textContent = originalText;
            }, 2000);
        }).catch(() => {
            const textArea = document.createElement('textarea');
            textArea.value = html;
            document.body.appendChild(textArea);
            textArea.select();
            document.execCommand('copy');
            document.body.removeChild(textArea);
        });
    }

    function loadSimpleExample() {
        document.getElementById('markdownInput').value = examples.simple;
        updatePreview();
        document.getElementById('statusText').textContent = 'Simple example loaded';
    }

    function loadFullExample() {
        document.getElementById('markdownInput').value = examples.full;
        updatePreview();
        document.getElementById('statusText').textContent = 'Full example loaded';
    }

    function toggleSyntaxPanel() {
        const panel = document.getElementById('syntaxPanel');
        syntaxPanelVisible = !syntaxPanelVisible;
        panel.style.display = syntaxPanelVisible ? 'flex' : 'none';
        
        document.getElementById('statusText').textContent = syntaxPanelVisible ? 
            'Syntax panel shown' : 'Syntax panel hidden';
    }

    function toggleSection(sectionId) {
        const section = document.getElementById(sectionId);
        section.style.display = section.style.display === 'none' ? 'block' : 'none';
    }

    function insertSyntax(before, after = '') {
        const textarea = document.getElementById('markdownInput');
        const start = textarea.selectionStart;
        const end = textarea.selectionEnd;
        const selectedText = textarea.value.substring(start, end);
        
        const newText = before + selectedText + after;
        const beforeText = textarea.value.substring(0, start);
        const afterText = textarea.value.substring(end);
        
        textarea.value = beforeText + newText + afterText;
        
        // Set cursor position
        const newCursorPos = start + before.length + selectedText.length;
        textarea.setSelectionRange(newCursorPos, newCursorPos);
        textarea.focus();
        
        updatePreview();
    }

    function insertTable() {
        const tableMarkdown = `| Column 1 | Column 2 | Column 3 |
|----------|----------|----------|
| Cell 1   | Cell 2   | Cell 3   |
| Cell 4   | Cell 5   | Cell 6   |

`;
        const textarea = document.getElementById('markdownInput');
        const start = textarea.selectionStart;
        const beforeText = textarea.value.substring(0, start);
        const afterText = textarea.value.substring(start);
        
        textarea.value = beforeText + tableMarkdown + afterText;
        textarea.setSelectionRange(start + tableMarkdown.length, start + tableMarkdown.length);
        textarea.focus();
        
        updatePreview();
    }

    // Event listeners
    document.getElementById('markdownInput').addEventListener('input', updatePreview);
    document.getElementById('markdownInput').addEventListener('keydown', function(e) {
        if (e.key === 'Tab') {
            e.preventDefault();
            const textarea = e.target;
            const start = textarea.selectionStart;
            const end = textarea.selectionEnd;
            
            textarea.value = textarea.value.substring(0, start) + '    ' + textarea.value.substring(end);
            textarea.setSelectionRange(start + 4, start + 4);
        }
    });

    // Initialize
    document.addEventListener('DOMContentLoaded', function() {
        // Load simple example by default
        loadSimpleExample();
        
        // Initialize all syntax sections as collapsed except the first one
        const sections = ['emphasis', 'lists', 'links', 'code', 'other'];
        sections.forEach(section => {
            document.getElementById(section).style.display = 'none';
        });
    });
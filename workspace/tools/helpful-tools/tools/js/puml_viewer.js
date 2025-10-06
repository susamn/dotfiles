let currentDiagramUrl = '';
let currentZoom = 1.0;

const PLANTUML_SERVER = 'http://www.plantuml.com/plantuml';

// PlantUML examples
const examples = {
    sequence: `@startuml
title Simple Sequence Diagram

Alice -> Bob: Authentication Request
Bob --> Alice: Authentication Response

Alice -> Bob: Another authentication Request
Alice <-- Bob: Another authentication Response
@enduml`,

    usecase: `@startuml
left to right direction
actor "User" as user
actor "Admin" as admin

rectangle "System" {
  user --> (Login)
  user --> (View Profile)
  user --> (Update Profile)

  admin --> (Login)
  admin --> (Manage Users)
  admin --> (System Settings)
}
@enduml`,

    class: `@startuml
class User {
  -String name
  -String email
  +getName()
  +setName(String)
  +getEmail()
  +setEmail(String)
}

class Order {
  -Date date
  -double total
  +getDate()
  +getTotal()
  +addItem(Item)
}

class Item {
  -String name
  -double price
  +getName()
  +getPrice()
}

User ||--o{ Order
Order ||--o{ Item
@enduml`,

    activity: `@startuml
start
:User enters credentials;
if (Valid credentials?) then (yes)
  :Log user in;
  :Display dashboard;
else (no)
  :Show error message;
  :Return to login;
endif
stop
@enduml`,

    component: `@startuml
package "Web Layer" {
  [Web Controller]
  [Authentication]
}

package "Business Layer" {
  [User Service]
  [Order Service]
}

package "Data Layer" {
  [User Repository]
  [Order Repository]
  [Database]
}

[Web Controller] --> [User Service]
[Web Controller] --> [Order Service]
[User Service] --> [User Repository]
[Order Service] --> [Order Repository]
[User Repository] --> [Database]
[Order Repository] --> [Database]
@enduml`,

    state: `@startuml
[*] --> Idle
Idle --> Processing : start
Processing --> Success : complete
Processing --> Error : fail
Success --> [*]
Error --> Idle : retry
Error --> [*] : abort
@enduml`
};

function encodeForPlantUML(text) {
    // PlantUML uses a specific encoding that includes deflate compression
    // For simplicity, we'll use the ~1 prefix for text encoding
    try {
        // Use the text encoding method with ~1 prefix
        const encoded = btoa(unescape(encodeURIComponent(text)));
        return '~1' + encoded.replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
    } catch (error) {
        // Fallback to simple base64 encoding
        return btoa(text).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
    }
}

function renderDiagram() {
    const editor = document.getElementById('pumlEditor');
    const diagramContainer = document.getElementById('diagramContainer');
    const pumlStatus = document.getElementById('pumlStatus');
    const statusText = document.getElementById('statusText');
    const diagramInfo = document.getElementById('diagramInfo');
    const diagramTools = document.getElementById('diagramTools');

    const pumlCode = editor.value.trim();

    if (!pumlCode) {
        diagramContainer.innerHTML = '<div class="loading-state">Enter PlantUML code to render diagram</div>';
        pumlStatus.textContent = 'EMPTY';
        pumlStatus.className = 'puml-indicator';
        statusText.textContent = 'Enter PlantUML code';
        statusText.style.color = '#ff8800';
        diagramInfo.textContent = 'No diagram';
        diagramTools.style.display = 'none';
        return;
    }

    // Basic validation
    if (!pumlCode.includes('@startuml') || !pumlCode.includes('@enduml')) {
        diagramContainer.innerHTML = '<div class="error-state">PlantUML code must start with @startuml and end with @enduml</div>';
        pumlStatus.textContent = 'INVALID';
        pumlStatus.className = 'puml-indicator invalid';
        statusText.textContent = 'Invalid PlantUML syntax';
        statusText.style.color = '#cc0000';
        diagramInfo.textContent = 'Invalid syntax';
        diagramTools.style.display = 'none';
        return;
    }

    try {
        // Show loading state
        diagramContainer.innerHTML = '<div class="loading-state">Rendering diagram...</div>';
        pumlStatus.textContent = 'RENDERING';
        pumlStatus.className = 'puml-indicator';
        statusText.textContent = 'Rendering diagram...';
        statusText.style.color = '#666';

        // Generate PlantUML URL with proper encoding
        const encoded = encodeForPlantUML(pumlCode);
        const diagramUrl = `${PLANTUML_SERVER}/png/${encoded}`;
        currentDiagramUrl = diagramUrl;

        // Debug: log the URL being generated
        console.log('Generated PlantUML URL:', diagramUrl);

        // Create image element
        const img = new Image();
        img.onload = function() {
            diagramContainer.innerHTML = '';
            img.className = 'diagram-image';
            img.style.transform = `scale(${currentZoom})`;
            diagramContainer.appendChild(img);

            pumlStatus.textContent = 'RENDERED';
            pumlStatus.className = 'puml-indicator valid';
            statusText.textContent = 'Diagram rendered successfully';
            statusText.style.color = '#008000';
            diagramInfo.textContent = `${img.naturalWidth}x${img.naturalHeight}px`;
            diagramTools.style.display = 'flex';
        };

        img.onerror = function() {
            diagramContainer.innerHTML = '<div class="error-state">Failed to render diagram. Please check your PlantUML syntax.</div>';
            pumlStatus.textContent = 'ERROR';
            pumlStatus.className = 'puml-indicator invalid';
            statusText.textContent = 'Rendering failed';
            statusText.style.color = '#cc0000';
            diagramInfo.textContent = 'Render error';
            diagramTools.style.display = 'none';
        };

        img.src = diagramUrl;

    } catch (error) {
        diagramContainer.innerHTML = `<div class="error-state">Error: ${error.message}</div>`;
        pumlStatus.textContent = 'ERROR';
        pumlStatus.className = 'puml-indicator invalid';
        statusText.textContent = 'Rendering error';
        statusText.style.color = '#cc0000';
        diagramInfo.textContent = 'Error';
        diagramTools.style.display = 'none';
    }
}

function loadExample(type) {
    if (examples[type]) {
        document.getElementById('pumlEditor').value = examples[type];
        updateLineNumbers();
        updateEditorInfo();
        renderDiagram();
    }
}

function loadSample() {
    loadExample('sequence');
}

function clearAll() {
    document.getElementById('pumlEditor').value = '';
    document.getElementById('diagramContainer').innerHTML = '<div class="loading-state">Enter PlantUML code on the left and click "Render Diagram"</div>';
    document.getElementById('pumlStatus').textContent = 'WAITING';
    document.getElementById('pumlStatus').className = 'puml-indicator';
    document.getElementById('statusText').textContent = 'Ready - Enter PlantUML code to generate diagrams';
    document.getElementById('statusText').style.color = '#666';
    document.getElementById('diagramInfo').textContent = 'No diagram';
    document.getElementById('diagramTools').style.display = 'none';
    currentDiagramUrl = '';
    currentZoom = 1.0;
    updateLineNumbers();
    updateEditorInfo();
}

function downloadDiagram() {
    if (!currentDiagramUrl) {
        document.getElementById('statusText').textContent = 'No diagram to download';
        document.getElementById('statusText').style.color = '#ff8800';
        return;
    }

    const link = document.createElement('a');
    link.href = currentDiagramUrl;
    link.download = 'plantuml-diagram.png';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);

    showStatusMessage('Diagram download started');
}

function copyDiagramUrl() {
    if (!currentDiagramUrl) {
        document.getElementById('statusText').textContent = 'No diagram URL to copy';
        document.getElementById('statusText').style.color = '#ff8800';
        return;
    }

    navigator.clipboard.writeText(currentDiagramUrl).then(() => {
        showStatusMessage('Diagram URL copied to clipboard');
    }).catch(() => {
        const textArea = document.createElement('textarea');
        textArea.value = currentDiagramUrl;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
        showStatusMessage('Diagram URL copied to clipboard');
    });
}

function openDiagramInNewTab() {
    if (currentDiagramUrl) {
        window.open(currentDiagramUrl, '_blank');
    }
}

function zoomDiagram(factor) {
    const img = document.querySelector('.diagram-image');
    if (!img) return;

    if (factor === 1.0) {
        currentZoom = 1.0;
    } else {
        currentZoom *= factor;
        currentZoom = Math.max(0.1, Math.min(3.0, currentZoom));
    }

    img.style.transform = `scale(${currentZoom})`;
    showStatusMessage(`Zoom: ${Math.round(currentZoom * 100)}%`);
}

function updateLineNumbers() {
    const editor = document.getElementById('pumlEditor');
    const lineNumbers = document.getElementById('lineNumbers');

    const lines = editor.value.split('\n');
    const numbers = lines.map((_, index) => index + 1).join('\n');
    lineNumbers.textContent = numbers;
}

function updateEditorInfo() {
    const editor = document.getElementById('pumlEditor');
    const text = editor.value;
    const lines = text.split('\n').length;
    const chars = text.length;

    document.getElementById('editorInfo').textContent = `Lines: ${lines} | Characters: ${chars}`;
}

function showStatusMessage(message) {
    const statusText = document.getElementById('statusText');
    const originalText = statusText.textContent;
    const originalColor = statusText.style.color;

    statusText.textContent = message;
    statusText.style.color = '#008000';

    setTimeout(() => {
        statusText.textContent = originalText;
        statusText.style.color = originalColor;
    }, 2000);
}

// Auto-render on input change
document.getElementById('pumlEditor').addEventListener('input', function() {
    updateLineNumbers();
    updateEditorInfo();

    clearTimeout(this.renderTimer);
    this.renderTimer = setTimeout(renderDiagram, 1500);
});

// Handle scroll sync for line numbers
document.getElementById('pumlEditor').addEventListener('scroll', function() {
    document.getElementById('lineNumbers').scrollTop = this.scrollTop;
});

// Initialize
updateLineNumbers();
updateEditorInfo();
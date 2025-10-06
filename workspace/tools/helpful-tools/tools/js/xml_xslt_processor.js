let isThreePanel = true;

const examples = {
    bookXml: `<?xml version="1.0" encoding="UTF-8"?>
<library>
    <book id="1" year="2020">
        <title>XML Processing Guide</title>
        <author>John Smith</author>
        <author>Jane Doe</author>
        <genre>Technical</genre>
        <price currency="USD">29.99</price>
        <description>A comprehensive guide to XML processing and XSLT transformations.</description>
    </book>
    <book id="2" year="2019">
        <title>Web Development Basics</title>
        <author>Alice Johnson</author>
        <genre>Web Development</genre>
        <price currency="USD">24.99</price>
        <description>Learn the fundamentals of modern web development.</description>
    </book>
    <book id="3" year="2021">
        <title>Advanced JavaScript</title>
        <author>Bob Wilson</author>
        <author>Carol Brown</author>
        <genre>Programming</genre>
        <price currency="USD">34.99</price>
        <description>Master advanced JavaScript concepts and patterns.</description>
    </book>
</library>`,

    bookXslt: `<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output method="html" indent="yes"/>
    
    <xsl:template match="/">
        <html>
            <head>
                <title>Library Catalog</title>
                <style>
                    body { font-family: Arial, sans-serif; margin: 20px; }
                    .book { border: 1px solid #ccc; margin: 10px 0; padding: 15px; border-radius: 5px; }
                    .title { font-size: 18px; font-weight: bold; color: #2c5aa0; }
                    .authors { color: #666; margin: 5px 0; }
                    .price { color: #28a745; font-weight: bold; }
                    .genre { background: #f8f9fa; padding: 2px 8px; border-radius: 3px; font-size: 12px; }
                </style>
            </head>
            <body>
                <h1>Library Catalog</h1>
                <xsl:for-each select="library/book">
                    <xsl:sort select="@year" order="descending"/>
                    <div class="book">
                        <div class="title"><xsl:value-of select="title"/></div>
                        <div class="authors">
                            Authors: 
                            <xsl:for-each select="author">
                                <xsl:value-of select="."/>
                                <xsl:if test="position() != last()">, </xsl:if>
                            </xsl:for-each>
                        </div>
                        <div>
                            <span class="genre"><xsl:value-of select="genre"/></span>
                            | Year: <xsl:value-of select="@year"/>
                        </div>
                        <div class="price">Price: $<xsl:value-of select="price"/></div>
                        <p><xsl:value-of select="description"/></p>
                    </div>
                </xsl:for-each>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>`,

    tableXml: `<?xml version="1.0" encoding="UTF-8"?>
<employees>
    <employee id="101">
        <name>John Smith</name>
        <department>Engineering</department>
        <position>Senior Developer</position>
        <salary>75000</salary>
        <location>New York</location>
    </employee>
    <employee id="102">
        <name>Sarah Johnson</name>
        <department>Marketing</department>
        <position>Marketing Manager</position>
        <salary>65000</salary>
        <location>Los Angeles</location>
    </employee>
    <employee id="103">
        <name>Mike Wilson</name>
        <department>Engineering</department>
        <position>DevOps Engineer</position>
        <salary>70000</salary>
        <location>Seattle</location>
    </employee>
    <employee id="104">
        <name>Lisa Brown</name>
        <department>Design</department>
        <position>UX Designer</position>
        <salary>68000</salary>
        <location>San Francisco</location>
    </employee>
</employees>`,

    tableXslt: `<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output method="html" indent="yes"/>
    
    <xsl:template match="/">
        <html>
            <head>
                <title>Employee Directory</title>
                <style>
                    body { font-family: Arial, sans-serif; margin: 20px; }
                    table { width: 100%; border-collapse: collapse; margin: 20px 0; }
                    th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
                    th { background-color: #f2f2f2; font-weight: bold; }
                    tr:nth-child(even) { background-color: #f9f9f9; }
                    .salary { color: #28a745; font-weight: bold; }
                    .department { font-weight: bold; }
                    .summary { background: #e9ecef; padding: 15px; border-radius: 5px; margin: 20px 0; }
                </style>
            </head>
            <body>
                <h1>Employee Directory</h1>
                
                <div class="summary">
                    <h3>Summary</h3>
                    <p>Total Employees: <xsl:value-of select="count(employees/employee)"/></p>
                    <p>Average Salary: $<xsl:value-of select="format-number(sum(employees/employee/salary) div count(employees/employee), '#,##0')"/></p>
                </div>
                
                <table>
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Name</th>
                            <th>Department</th>
                            <th>Position</th>
                            <th>Salary</th>
                            <th>Location</th>
                        </tr>
                    </thead>
                    <tbody>
                        <xsl:for-each select="employees/employee">
                            <xsl:sort select="department"/>
                            <xsl:sort select="name"/>
                            <tr>
                                <td><xsl:value-of select="@id"/></td>
                                <td><xsl:value-of select="name"/></td>
                                <td class="department"><xsl:value-of select="department"/></td>
                                <td><xsl:value-of select="position"/></td>
                                <td class="salary">$<xsl:value-of select="format-number(salary, '#,##0')"/></td>
                                <td><xsl:value-of select="location"/></td>
                            </tr>
                        </xsl:for-each>
                    </tbody>
                </table>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>`
};

function processXslt() {
    const xmlText = document.getElementById('xmlInput').value.trim();
    const xsltText = document.getElementById('xsltInput').value.trim();
    const output = document.getElementById('outputContent');
    const statusText = document.getElementById('statusText');

    if (!xmlText || !xsltText) {
        statusText.textContent = 'Please provide both XML and XSLT content';
        statusText.style.color = '#ff8800';
        return;
    }

    try {
        // Parse XML
        const parser = new DOMParser();
        const xmlDoc = parser.parseFromString(xmlText, 'text/xml');
        
        // Check for XML parsing errors
        const xmlError = xmlDoc.querySelector('parsererror');
        if (xmlError) {
            throw new Error('XML parsing error: ' + xmlError.textContent);
        }

        // Parse XSLT
        const xsltDoc = parser.parseFromString(xsltText, 'text/xml');
        
        // Check for XSLT parsing errors
        const xsltError = xsltDoc.querySelector('parsererror');
        if (xsltError) {
            throw new Error('XSLT parsing error: ' + xsltError.textContent);
        }

        // Create XSLT processor
        const xsltProcessor = new XSLTProcessor();
        xsltProcessor.importStylesheet(xsltDoc);

        // Transform XML
        const resultDoc = xsltProcessor.transformToDocument(xmlDoc);
        
        // Serialize result
        const serializer = new XMLSerializer();
        let result = serializer.serializeToString(resultDoc);

        // Format output based on type
        if (result.includes('<html') || result.includes('<!DOCTYPE html')) {
            // HTML output - display as formatted HTML
            output.innerHTML = `<iframe srcdoc="${escapeHtml(result)}" style="width:100%;height:100%;border:none;"></iframe>`;
            document.getElementById('outputFormat').textContent = 'HTML';
        } else {
            // XML/Text output - display as formatted text
            output.innerHTML = syntaxHighlightXml(formatXmlString(result));
            document.getElementById('outputFormat').textContent = 'XML';
        }

        statusText.textContent = 'XSLT transformation completed successfully';
        statusText.style.color = '#008000';

    } catch (error) {
        output.innerHTML = `<div class="error-display">Error: ${error.message}</div>`;
        statusText.textContent = 'XSLT transformation failed';
        statusText.style.color = '#cc0000';
    }
}

function validateXml() {
    const xmlText = document.getElementById('xmlInput').value.trim();
    const statusText = document.getElementById('statusText');

    if (!xmlText) {
        statusText.textContent = 'Please provide XML content to validate';
        statusText.style.color = '#ff8800';
        return;
    }

    try {
        const parser = new DOMParser();
        const xmlDoc = parser.parseFromString(xmlText, 'text/xml');
        
        const error = xmlDoc.querySelector('parsererror');
        if (error) {
            statusText.textContent = 'XML validation failed: ' + error.textContent;
            statusText.style.color = '#cc0000';
        } else {
            statusText.textContent = 'XML is valid and well-formed';
            statusText.style.color = '#008000';
        }
    } catch (error) {
        statusText.textContent = 'XML validation error: ' + error.message;
        statusText.style.color = '#cc0000';
    }
}

function formatXml() {
    const xmlInput = document.getElementById('xmlInput');
    const xmlText = xmlInput.value.trim();

    if (!xmlText) return;

    try {
        const formatted = formatXmlString(xmlText);
        xmlInput.value = formatted;
        document.getElementById('statusText').textContent = 'XML formatted successfully';
        document.getElementById('statusText').style.color = '#008000';
    } catch (error) {
        document.getElementById('statusText').textContent = 'XML formatting error: ' + error.message;
        document.getElementById('statusText').style.color = '#cc0000';
    }
}

function formatXslt() {
    const xsltInput = document.getElementById('xsltInput');
    const xsltText = xsltInput.value.trim();

    if (!xsltText) return;

    try {
        const formatted = formatXmlString(xsltText);
        xsltInput.value = formatted;
        document.getElementById('statusText').textContent = 'XSLT formatted successfully';
        document.getElementById('statusText').style.color = '#008000';
    } catch (error) {
        document.getElementById('statusText').textContent = 'XSLT formatting error: ' + error.message;
        document.getElementById('statusText').style.color = '#cc0000';
    }
}

function formatXmlString(xmlString) {
    const parser = new DOMParser();
    const xmlDoc = parser.parseFromString(xmlString, 'text/xml');
    
    const error = xmlDoc.querySelector('parsererror');
    if (error) {
        throw new Error('Invalid XML: ' + error.textContent);
    }

    const serializer = new XMLSerializer();
    let formatted = serializer.serializeToString(xmlDoc);
    
    // Basic formatting
    formatted = formatted.replace(/></g, '>\n<');
    
    // Indent properly
    const lines = formatted.split('\n');
    let indent = 0;
    const indentString = '  ';
    
    return lines.map(line => {
        line = line.trim();
        if (line.match(/^<\/\w/)) {
            indent--;
        }
        
        const indentedLine = indentString.repeat(Math.max(0, indent)) + line;
        
        if (line.match(/^<\w[^>]*[^\/]>$/)) {
            indent++;
        }
        
        return indentedLine;
    }).join('\n');
}

function syntaxHighlightXml(xml) {
    xml = xml.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

    // Highlight XML declaration
    xml = xml.replace(/(&lt;\?xml[^&gt;]*\?&gt;)/g, '<span class="xml-declaration">$1</span>');

    // Highlight comments
    xml = xml.replace(/(&lt;!--[\s\S]*?--&gt;)/g, '<span class="xml-comment">$1</span>');

    // Highlight tags with attributes
    xml = xml.replace(/(&lt;\/?)([a-zA-Z_][\w\-:]*)((?:\s+[a-zA-Z_][\w\-:]*\s*=\s*"[^"]*")*)\s*(\/?&gt;)/g, function(match, openBracket, tagName, attributes, closeBracket) {
        let result = '<span class="xml-tag">' + openBracket + tagName;

        if (attributes) {
            result += attributes.replace(/([a-zA-Z_][\w\-:]*)\s*=\s*("[^"]*")/g, function(attrMatch, attrName, attrValue) {
                return ' <span class="xml-attribute">' + attrName + '</span>=<span class="xml-value">' + attrValue + '</span>';
            });
        }

        result += closeBracket + '</span>';
        return result;
    });

    return xml;
}

function escapeHtml(text) {
    return text.replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function clearAll() {
    document.getElementById('xmlInput').value = '';
    document.getElementById('xsltInput').value = '';
    document.getElementById('outputContent').innerHTML = '';
    document.getElementById('statusText').textContent = 'Ready - Load XML and XSLT to transform';
    document.getElementById('statusText').style.color = '#666';
    updateCharCount();
}

function copyOutput() {
    const output = document.getElementById('outputContent');
    let text = output.textContent || output.innerText || '';
    
    if (!text.trim()) {
        return;
    }

    navigator.clipboard.writeText(text).then(() => {
        const statusText = document.getElementById('statusText');
        const originalText = statusText.textContent;
        const originalColor = statusText.style.color;
        statusText.textContent = 'Output copied to clipboard';
        statusText.style.color = '#008000';
        setTimeout(() => {
            statusText.textContent = originalText;
            statusText.style.color = originalColor;
        }, 2000);
    }).catch(() => {
        const textArea = document.createElement('textarea');
        textArea.value = text;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
    });
}

function loadBookExample() {
    document.getElementById('xmlInput').value = examples.bookXml;
    document.getElementById('xsltInput').value = examples.bookXslt;
    updateCharCount();
    document.getElementById('statusText').textContent = 'Book catalog example loaded';
    document.getElementById('statusText').style.color = '#008000';
}

function loadTableExample() {
    document.getElementById('xmlInput').value = examples.tableXml;
    document.getElementById('xsltInput').value = examples.tableXslt;
    updateCharCount();
    document.getElementById('statusText').textContent = 'Employee table example loaded';
    document.getElementById('statusText').style.color = '#008000';
}

function toggleLayout() {
    const container = document.getElementById('mainContainer');
    const outputPanel = document.getElementById('outputPanel');
    
    isThreePanel = !isThreePanel;
    
    if (isThreePanel) {
        container.className = 'main-container';
        outputPanel.style.display = 'flex';
        document.querySelector('.toggle-layout').textContent = '2-Panel View';
    } else {
        container.className = 'main-container two-panel';
        outputPanel.style.display = 'none';
        document.querySelector('.toggle-layout').textContent = '3-Panel View';
    }
    
    document.getElementById('statusText').textContent = isThreePanel ? 
        'Switched to 3-panel view' : 'Switched to 2-panel view';
}

function updateCharCount() {
    const xmlLength = document.getElementById('xmlInput').value.length;
    const xsltLength = document.getElementById('xsltInput').value.length;
    document.getElementById('charCount').textContent = `XML: ${xmlLength} chars | XSLT: ${xsltLength} chars`;
}

// Event listeners
document.getElementById('xmlInput').addEventListener('input', updateCharCount);
document.getElementById('xsltInput').addEventListener('input', updateCharCount);

// Initialize
document.addEventListener('DOMContentLoaded', function() {
    updateCharCount();
});
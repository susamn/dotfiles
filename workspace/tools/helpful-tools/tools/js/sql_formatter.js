const SQL_KEYWORDS = [
    'SELECT', 'FROM', 'WHERE', 'JOIN', 'INNER', 'LEFT', 'RIGHT', 'FULL', 'OUTER',
    'ON', 'AS', 'AND', 'OR', 'NOT', 'IN', 'EXISTS', 'BETWEEN', 'LIKE', 'IS', 'NULL',
    'INSERT', 'INTO', 'VALUES', 'UPDATE', 'SET', 'DELETE', 'CREATE', 'TABLE', 'ALTER',
    'DROP', 'INDEX', 'VIEW', 'DATABASE', 'SCHEMA', 'GRANT', 'REVOKE', 'COMMIT', 'ROLLBACK',
    'UNION', 'ALL', 'DISTINCT', 'ORDER', 'BY', 'GROUP', 'HAVING', 'LIMIT', 'OFFSET',
    'CASE', 'WHEN', 'THEN', 'ELSE', 'END', 'IF', 'WITH', 'RECURSIVE', 'OVER', 'PARTITION',
    'ROW_NUMBER', 'RANK', 'DENSE_RANK', 'LEAD', 'LAG', 'FIRST_VALUE', 'LAST_VALUE'
];

const SQL_FUNCTIONS = [
    'COUNT', 'SUM', 'AVG', 'MIN', 'MAX', 'CONCAT', 'SUBSTRING', 'LENGTH', 'UPPER', 'LOWER',
    'TRIM', 'LTRIM', 'RTRIM', 'REPLACE', 'NOW', 'CURRENT_DATE', 'CURRENT_TIME', 'DATEADD',
    'DATEDIFF', 'YEAR', 'MONTH', 'DAY', 'HOUR', 'MINUTE', 'SECOND', 'CAST', 'CONVERT',
    'COALESCE', 'ISNULL', 'NULLIF', 'ABS', 'ROUND', 'FLOOR', 'CEIL', 'SQRT', 'POWER'
];

const SQL_OPERATORS = ['=', '!=', '<>', '<', '>', '<=', '>=', '+', '-', '*', '/', '%', '||'];

let lastFormattedSQL = '';

function detectQueryType(sql) {
    const trimmed = sql.trim().toUpperCase();
    if (trimmed.startsWith('SELECT')) return 'SELECT';
    if (trimmed.startsWith('INSERT')) return 'INSERT';
    if (trimmed.startsWith('UPDATE')) return 'UPDATE';
    if (trimmed.startsWith('DELETE')) return 'DELETE';
    if (trimmed.startsWith('CREATE')) return 'CREATE';
    if (trimmed.startsWith('ALTER')) return 'ALTER';
    if (trimmed.startsWith('DROP')) return 'DROP';
    if (trimmed.startsWith('WITH')) return 'CTE';
    return 'QUERY';
}

function formatSQL() {
    const input = document.getElementById('sqlInput').value.trim();
    const output = document.getElementById('sqlOutput');
    const statusText = document.getElementById('statusText');
    const sqlStatus = document.getElementById('sqlStatus');
    const queryType = document.getElementById('queryType');

    if (!input) {
        output.textContent = 'Enter SQL query on the left to see formatted output';
        statusText.textContent = 'Please enter SQL query';
        statusText.style.color = '#ff8800';
        sqlStatus.textContent = 'EMPTY';
        sqlStatus.className = 'sql-indicator';
        queryType.textContent = '';
        return;
    }

    try {
        const formatted = formatSQLQuery(input);
        const highlighted = syntaxHighlightSQL(formatted);

        output.innerHTML = highlighted;
        lastFormattedSQL = formatted;

        sqlStatus.textContent = 'FORMATTED';
        sqlStatus.className = 'sql-indicator valid';
        statusText.textContent = 'SQL formatted successfully';
        statusText.style.color = '#008000';

        const type = detectQueryType(input);
        queryType.textContent = type;
        queryType.style.background = '#388e3c';
        queryType.style.color = 'white';
        queryType.style.padding = '2px 6px';
        queryType.style.borderRadius = '3px';
        queryType.style.fontSize = '10px';

    } catch (error) {
        output.innerHTML = `<div class="error-display">Formatting Error: ${error.message}</div>`;
        statusText.textContent = 'SQL formatting error';
        statusText.style.color = '#cc0000';
        sqlStatus.textContent = 'ERROR';
        sqlStatus.className = 'sql-indicator error';
        queryType.textContent = '';
        lastFormattedSQL = '';
    }
}

function formatSQLQuery(sql) {
    const indentSize = document.getElementById('indentSize').value;
    const uppercaseKeywords = document.getElementById('uppercaseKeywords').checked;
    const newlineBeforeComma = document.getElementById('newlineBeforeComma').checked;

    const indent = indentSize === 'tab' ? '\t' : ' '.repeat(parseInt(indentSize));

    // Basic SQL formatting
    let formatted = sql
        .replace(/\s+/g, ' ') // Normalize whitespace
        .trim();

    // Handle keywords
    if (uppercaseKeywords) {
        SQL_KEYWORDS.forEach(keyword => {
            const regex = new RegExp(`\\b${keyword}\\b`, 'gi');
            formatted = formatted.replace(regex, keyword.toUpperCase());
        });

        SQL_FUNCTIONS.forEach(func => {
            const regex = new RegExp(`\\b${func}\\b(?=\\s*\\()`, 'gi');
            formatted = formatted.replace(regex, func.toUpperCase());
        });
    }

    // Add newlines for major clauses
    formatted = formatted
        .replace(/\b(SELECT|FROM|WHERE|JOIN|INNER JOIN|LEFT JOIN|RIGHT JOIN|FULL JOIN|ORDER BY|GROUP BY|HAVING|UNION|WITH)\b/gi, '\n$1')
        .replace(/\b(INSERT INTO|UPDATE|DELETE FROM|CREATE TABLE|ALTER TABLE|DROP TABLE)\b/gi, '\n$1')
        .replace(/\bAND\b/gi, '\n' + indent + 'AND')
        .replace(/\bOR\b/gi, '\n' + indent + 'OR');

    // Handle SELECT list formatting
    if (newlineBeforeComma) {
        formatted = formatted.replace(/,(\s*)/g, '\n' + indent + ',');
    } else {
        formatted = formatted.replace(/,(\s*)/g, ',\n' + indent);
    }

    // Handle subqueries and parentheses
    let indentLevel = 0;
    const lines = formatted.split('\n');
    const result = [];

    for (let line of lines) {
        const trimmedLine = line.trim();
        if (!trimmedLine) continue;

        // Decrease indent for closing parentheses
        if (trimmedLine.startsWith(')')) {
            indentLevel = Math.max(0, indentLevel - 1);
        }

        // Add current line with proper indentation
        result.push(indent.repeat(indentLevel) + trimmedLine);

        // Increase indent for opening parentheses
        if (trimmedLine.includes('(') && !trimmedLine.includes(')')) {
            indentLevel++;
        }
    }

    return result.join('\n').trim();
}

function minifySQL() {
    const input = document.getElementById('sqlInput').value.trim();
    const output = document.getElementById('sqlOutput');
    const statusText = document.getElementById('statusText');

    if (!input) {
        statusText.textContent = 'Please enter SQL query';
        statusText.style.color = '#ff8800';
        return;
    }

    try {
        const minified = input
            .replace(/\s+/g, ' ')
            .replace(/\s*([(),;])\s*/g, '$1')
            .trim();

        const highlighted = syntaxHighlightSQL(minified);
        output.innerHTML = highlighted;
        lastFormattedSQL = minified;

        statusText.textContent = 'SQL minified successfully';
        statusText.style.color = '#008000';

    } catch (error) {
        output.innerHTML = `<div class="error-display">Minification Error: ${error.message}</div>`;
        statusText.textContent = 'SQL minification error';
        statusText.style.color = '#cc0000';
    }
}

function syntaxHighlightSQL(sql) {
    let highlighted = sql
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');

    // Highlight comments first
    highlighted = highlighted.replace(/(--.*$)/gm, '<span class="sql-comment">$1</span>');
    highlighted = highlighted.replace(/(\/\*[\s\S]*?\*\/)/g, '<span class="sql-comment">$1</span>');

    // Highlight strings
    highlighted = highlighted.replace(/('(?:[^'\\]|\\.)*')/g, '<span class="sql-string">$1</span>');
    highlighted = highlighted.replace(/("(?:[^"\\]|\\.)*")/g, '<span class="sql-string">$1</span>');

    // Highlight numbers
    highlighted = highlighted.replace(/\b(\d+(?:\.\d+)?)\b/g, '<span class="sql-number">$1</span>');

    // Highlight keywords (avoid conflicts with already highlighted content)
    SQL_KEYWORDS.forEach(keyword => {
        const regex = new RegExp(`\\b(${keyword})\\b(?![^<]*>)`, 'gi');
        highlighted = highlighted.replace(regex, (match) => {
            // Don't replace if already inside a span tag
            return `<span class="sql-keyword">${match}</span>`;
        });
    });

    // Highlight functions
    SQL_FUNCTIONS.forEach(func => {
        const regex = new RegExp(`\\b(${func})(?=\\s*\\()(?![^<]*>)`, 'gi');
        highlighted = highlighted.replace(regex, (match) => {
            return `<span class="sql-function">${match}</span>`;
        });
    });

    // Highlight operators (be more careful with escaping)
    const safeOperators = ['=', '!=', '&lt;&gt;', '&lt;=', '&gt;=', '&lt;', '&gt;', '\\+', '-', '\\*', '/', '%', '\\|\\|'];
    safeOperators.forEach(op => {
        const regex = new RegExp(`(${op})(?![^<]*>)`, 'g');
        highlighted = highlighted.replace(regex, '<span class="sql-operator">$1</span>');
    });

    return highlighted;
}

function validateSQL() {
    const input = document.getElementById('sqlInput').value.trim();
    const statusText = document.getElementById('statusText');
    const sqlStatus = document.getElementById('sqlStatus');

    if (!input) {
        statusText.textContent = 'Please enter SQL query to validate';
        statusText.style.color = '#ff8800';
        return;
    }

    // Basic SQL validation
    const errors = [];

    // Check for balanced parentheses
    let parenCount = 0;
    for (let char of input) {
        if (char === '(') parenCount++;
        if (char === ')') parenCount--;
        if (parenCount < 0) {
            errors.push('Unmatched closing parenthesis');
            break;
        }
    }
    if (parenCount > 0) {
        errors.push('Unmatched opening parenthesis');
    }

    // Check for balanced quotes
    const singleQuotes = (input.match(/'/g) || []).length;
    const doubleQuotes = (input.match(/"/g) || []).length;
    if (singleQuotes % 2 !== 0) {
        errors.push('Unmatched single quote');
    }
    if (doubleQuotes % 2 !== 0) {
        errors.push('Unmatched double quote');
    }

    // Check for basic SQL structure
    const trimmed = input.trim().toUpperCase();
    const validStarters = ['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'CREATE', 'ALTER', 'DROP', 'WITH'];
    if (!validStarters.some(starter => trimmed.startsWith(starter))) {
        errors.push('Query should start with a valid SQL statement');
    }

    if (errors.length === 0) {
        sqlStatus.textContent = 'VALID';
        sqlStatus.className = 'sql-indicator valid';
        statusText.textContent = 'SQL query appears to be valid';
        statusText.style.color = '#008000';
    } else {
        sqlStatus.textContent = 'INVALID';
        sqlStatus.className = 'sql-indicator error';
        statusText.textContent = 'Validation errors: ' + errors.join(', ');
        statusText.style.color = '#cc0000';
    }
}

function loadExample(type) {
    const examples = {
        basic: `select id, name, email from users where active = 1 order by name`,

        join: `select u.name, p.title, c.name as category from users u inner join posts p on u.id = p.user_id left join categories c on p.category_id = c.id where u.active = 1`,

        subquery: `select name, email from users where id in (select distinct user_id from orders where order_date > '2023-01-01') order by name`,

        cte: `with monthly_sales as (select extract(month from order_date) as month, sum(total) as sales from orders group by extract(month from order_date)) select month, sales, lag(sales) over (order by month) as prev_month_sales from monthly_sales`,

        complex: `with ranked_products as (select p.id, p.name, p.price, c.name as category, row_number() over (partition by c.id order by p.price desc) as rank from products p join categories c on p.category_id = c.id where p.active = true) select rp.name, rp.price, rp.category from ranked_products rp where rp.rank <= 3 order by rp.category, rp.rank`
    };

    document.getElementById('sqlInput').value = examples[type] || '';
    updateSQLInfo();
    if (document.getElementById('autoFormat').checked) {
        formatSQL();
    }
}

function loadSample() {
    loadExample('join');
}

function clearAll() {
    document.getElementById('sqlInput').value = '';
    document.getElementById('sqlOutput').textContent = 'Enter SQL query on the left to see formatted output';
    document.getElementById('statusText').textContent = 'Ready - Enter SQL query to format';
    document.getElementById('statusText').style.color = '#666';
    document.getElementById('sqlStatus').textContent = 'READY';
    document.getElementById('sqlStatus').className = 'sql-indicator';
    document.getElementById('queryType').textContent = '';
    document.getElementById('queryType').style.background = '';
    lastFormattedSQL = '';
    updateSQLInfo();
}

function copyFormatted() {
    if (!lastFormattedSQL.trim()) {
        const statusText = document.getElementById('statusText');
        statusText.textContent = 'No formatted SQL to copy';
        statusText.style.color = '#ff8800';
        return;
    }

    navigator.clipboard.writeText(lastFormattedSQL).then(() => {
        const statusText = document.getElementById('statusText');
        const originalText = statusText.textContent;
        const originalColor = statusText.style.color;
        statusText.textContent = 'Formatted SQL copied to clipboard';
        statusText.style.color = '#008000';
        setTimeout(() => {
            statusText.textContent = originalText;
            statusText.style.color = originalColor;
        }, 2000);
    }).catch(() => {
        const textArea = document.createElement('textarea');
        textArea.value = lastFormattedSQL;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
    });
}

function updateFormatting() {
    const input = document.getElementById('sqlInput').value.trim();
    if (input && document.getElementById('autoFormat').checked) {
        formatSQL();
    }
}

function updateSQLInfo() {
    const input = document.getElementById('sqlInput').value;
    const lines = input.split('\n').length;
    document.getElementById('sqlInfo').textContent = `Lines: ${lines} | Characters: ${input.length}`;
}

// Auto-format on input change
document.getElementById('sqlInput').addEventListener('input', function() {
    updateSQLInfo();

    if (document.getElementById('autoFormat').checked) {
        clearTimeout(this.formatTimer);
        this.formatTimer = setTimeout(formatSQL, 500);
    }
});

// Initialize
updateSQLInfo();
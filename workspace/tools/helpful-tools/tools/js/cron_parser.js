const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

function parseCronField(field, min, max, names = null) {
    if (field === '*') {
        return { type: 'all', values: null, description: 'every' };
    }

    if (field.includes('/')) {
        const [range, step] = field.split('/');
        const stepNum = parseInt(step);
        if (range === '*') {
            return { type: 'step', values: stepNum, description: `every ${stepNum}` };
        } else {
            return { type: 'range_step', values: [range, stepNum], description: `every ${stepNum} in range ${range}` };
        }
    }

    if (field.includes('-')) {
        const [start, end] = field.split('-').map(Number);
        return { type: 'range', values: [start, end], description: `${start}-${end}` };
    }

    if (field.includes(',')) {
        const values = field.split(',').map(v => {
            const num = parseInt(v);
            return names && names[num] ? `${num} (${names[num]})` : num;
        });
        return { type: 'list', values: field.split(',').map(Number), description: values.join(', ') };
    }

    const num = parseInt(field);
    if (isNaN(num) || num < min || num > max) {
        throw new Error(`Invalid value ${field} for range ${min}-${max}`);
    }

    const displayValue = names && names[num] ? `${num} (${names[num]})` : num;
    return { type: 'specific', values: num, description: displayValue };
}

function parseCron(cronExpression) {
    const parts = cronExpression.trim().split(/\s+/);

    if (parts.length !== 5) {
        throw new Error('Cron expression must have exactly 5 fields: minute hour day month weekday');
    }

    const [minute, hour, day, month, weekday] = parts;

    return {
        minute: parseCronField(minute, 0, 59),
        hour: parseCronField(hour, 0, 23),
        day: parseCronField(day, 1, 31),
        month: parseCronField(month, 1, 12, monthNames),
        weekday: parseCronField(weekday, 0, 7, dayNames)
    };
}

function generateDescription(parsed) {
    const { minute, hour, day, month, weekday } = parsed;

    let desc = 'Runs ';

    // Handle special cases first
    if (minute.type === 'step' && minute.values === 1 && hour.type === 'all') {
        desc += 'every minute';
    } else if (minute.type === 'step' && hour.type === 'all') {
        desc += `every ${minute.values} minutes`;
    } else if (hour.type === 'step' && minute.type === 'specific' && minute.values === 0) {
        desc += `every ${hour.values} hours on the hour`;
    } else {
        // Standard time description
        if (minute.type === 'specific' && hour.type === 'specific') {
            const timeStr = `${hour.values.toString().padStart(2, '0')}:${minute.values.toString().padStart(2, '0')}`;
            desc += `at ${timeStr}`;
        } else if (minute.type === 'specific') {
            desc += `at ${minute.values} minutes past `;
            if (hour.type === 'all') {
                desc += 'every hour';
            } else {
                desc += `hour ${hour.description}`;
            }
        } else {
            desc += `at minute ${minute.description} of hour ${hour.description}`;
        }
    }

    // Add day/month/weekday constraints
    const constraints = [];

    if (weekday.type !== 'all') {
        if (weekday.type === 'specific') {
            constraints.push(`on ${dayNames[weekday.values === 7 ? 0 : weekday.values]}`);
        } else {
            constraints.push(`on weekdays ${weekday.description}`);
        }
    }

    if (day.type !== 'all') {
        if (day.type === 'specific') {
            const suffix = getDaySuffix(day.values);
            constraints.push(`on the ${day.values}${suffix} day`);
        } else {
            constraints.push(`on days ${day.description}`);
        }
    }

    if (month.type !== 'all') {
        if (month.type === 'specific') {
            constraints.push(`in ${monthNames[month.values - 1]}`);
        } else {
            constraints.push(`in months ${month.description}`);
        }
    }

    if (constraints.length > 0) {
        desc += ' ' + constraints.join(' and ');
    }

    return desc;
}

function getDaySuffix(day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
        case 1: return 'st';
        case 2: return 'nd';
        case 3: return 'rd';
        default: return 'th';
    }
}

function getNextRuns(cronExpression, count = 10) {
    const runs = [];
    const now = new Date();
    let current = new Date(now.getTime() + 60000); // Start from next minute
    current.setSeconds(0, 0);

    const parsed = parseCron(cronExpression);

    while (runs.length < count) {
        if (matchesCron(current, parsed)) {
            runs.push(new Date(current));
        }
        current.setMinutes(current.getMinutes() + 1);

        // Safety break to prevent infinite loops
        if (current.getTime() > now.getTime() + (365 * 24 * 60 * 60 * 1000)) {
            break;
        }
    }

    return runs;
}

function matchesCron(date, parsed) {
    const minute = date.getMinutes();
    const hour = date.getHours();
    const day = date.getDate();
    const month = date.getMonth() + 1;
    const weekday = date.getDay();

    return (
        matchesField(minute, parsed.minute) &&
        matchesField(hour, parsed.hour) &&
        matchesField(day, parsed.day) &&
        matchesField(month, parsed.month) &&
        matchesField(weekday === 0 ? 7 : weekday, parsed.weekday, true) // Handle Sunday as 7
    );
}

function matchesField(value, field, allowSundayAs7 = false) {
    if (field.type === 'all') return true;

    if (field.type === 'specific') {
        if (allowSundayAs7 && field.values === 7 && value === 7) return true;
        return value === field.values;
    }

    if (field.type === 'list') {
        return field.values.some(v => {
            if (allowSundayAs7 && v === 7 && value === 7) return true;
            return value === v;
        });
    }

    if (field.type === 'range') {
        return value >= field.values[0] && value <= field.values[1];
    }

    if (field.type === 'step') {
        return value % field.values === 0;
    }

    if (field.type === 'range_step') {
        const [range, step] = field.values;
        if (range === '*') {
            return value % step === 0;
        }
        // Handle range with step (more complex)
        return value % step === 0;
    }

    return false;
}

function formatRelativeTime(date) {
    const now = new Date();
    const diff = date.getTime() - now.getTime();

    if (diff < 60000) return 'in less than a minute';
    if (diff < 3600000) return `in ${Math.round(diff / 60000)} minutes`;
    if (diff < 86400000) return `in ${Math.round(diff / 3600000)} hours`;

    const days = Math.round(diff / 86400000);
    return `in ${days} day${days > 1 ? 's' : ''}`;
}

function parseCronExpression() {
    const input = document.getElementById('cronInput');
    const cronError = document.getElementById('cronError');
    const cronStatus = document.getElementById('cronStatus');
    const statusText = document.getElementById('statusText');

    const expression = input.value.trim();

    // Clear previous state
    cronError.style.display = 'none';
    input.className = 'cron-input';

    if (!expression) {
        clearResults();
        cronStatus.textContent = 'WAITING';
        cronStatus.className = 'cron-indicator';
        statusText.textContent = 'Enter a cron expression';
        return;
    }

    try {
        const parsed = parseCron(expression);

        // Update status
        input.className = 'cron-input valid';
        cronStatus.textContent = 'VALID';
        cronStatus.className = 'cron-indicator valid';
        statusText.textContent = 'Cron expression parsed successfully';
        statusText.style.color = '#008000';

        // Update field displays
        updateFieldDisplays(parsed);

        // Generate description
        const description = generateDescription(parsed);
        updateDescription(description);

        // Generate next runs
        const nextRuns = getNextRuns(expression);
        updateNextRuns(nextRuns);

        // Update info
        document.getElementById('cronInfo').textContent = `Expression: ${expression}`;

    } catch (error) {
        input.className = 'cron-input error';
        cronError.textContent = error.message;
        cronError.style.display = 'block';
        cronStatus.textContent = 'INVALID';
        cronStatus.className = 'cron-indicator invalid';
        statusText.textContent = 'Invalid cron expression';
        statusText.style.color = '#cc0000';
        clearResults();
    }
}

function updateFieldDisplays(parsed) {
    document.getElementById('minuteValue').textContent = parsed.minute.description;
    document.getElementById('hourValue').textContent = parsed.hour.description;
    document.getElementById('dayValue').textContent = parsed.day.description;
    document.getElementById('monthValue').textContent = parsed.month.description;
    document.getElementById('weekdayValue').textContent = parsed.weekday.description;

    // Update descriptions
    document.getElementById('minuteDesc').textContent = getFieldHelp('minute', parsed.minute);
    document.getElementById('hourDesc').textContent = getFieldHelp('hour', parsed.hour);
    document.getElementById('dayDesc').textContent = getFieldHelp('day', parsed.day);
    document.getElementById('monthDesc').textContent = getFieldHelp('month', parsed.month);
    document.getElementById('weekdayDesc').textContent = getFieldHelp('weekday', parsed.weekday);
}

function getFieldHelp(fieldName, field) {
    const ranges = {
        minute: '0-59',
        hour: '0-23',
        day: '1-31',
        month: '1-12',
        weekday: '0-7 (Sun=0,7)'
    };

    if (field.type === 'all') return `${ranges[fieldName]} (all)`;
    if (field.type === 'step') return `Every ${field.values}`;
    if (field.type === 'range') return `Range: ${field.values[0]}-${field.values[1]}`;
    if (field.type === 'list') return `List: ${field.values.join(',')}`;
    return ranges[fieldName];
}

function updateDescription(description) {
    document.getElementById('cronDescription').innerHTML = `
            <div class="description-box">
                ${description}
            </div>
        `;
}

function updateNextRuns(runs) {
    const list = document.getElementById('nextRunsList');

    if (runs.length === 0) {
        list.innerHTML = '<li class="empty-state">No upcoming runs found</li>';
        return;
    }

    list.innerHTML = runs.map(run => `
            <li class="next-run-item">
                <span class="run-datetime">${run.toLocaleString()}</span>
                <span class="run-relative">${formatRelativeTime(run)}</span>
            </li>
        `).join('');
}

function clearResults() {
    ['minuteValue', 'hourValue', 'dayValue', 'monthValue', 'weekdayValue'].forEach(id => {
        document.getElementById(id).textContent = '-';
    });

    ['minuteDesc', 'hourDesc', 'dayDesc', 'monthDesc', 'weekdayDesc'].forEach(id => {
        const field = id.replace('Desc', '');
        const ranges = {
            minute: '0-59',
            hour: '0-23',
            day: '1-31',
            month: '1-12',
            weekday: '0-7 (Sun=0,7)'
        };
        document.getElementById(id).textContent = ranges[field];
    });

    document.getElementById('cronDescription').innerHTML = '<div class="empty-state">Enter a cron expression above to see its human-readable description</div>';
    document.getElementById('nextRunsList').innerHTML = '<li class="empty-state">Enter a valid cron expression to see upcoming execution times</li>';
}

function loadExample(expression) {
    document.getElementById('cronInput').value = expression;
    parseCronExpression();
}

function loadSampleCron() {
    loadExample('0 9-17 * * 1-5');
}

function clearAll() {
    document.getElementById('cronInput').value = '';
    document.getElementById('cronError').style.display = 'none';
    document.getElementById('cronInput').className = 'cron-input';
    document.getElementById('cronStatus').textContent = 'WAITING';
    document.getElementById('cronStatus').className = 'cron-indicator';
    document.getElementById('statusText').textContent = 'Ready - Enter a cron expression to parse';
    document.getElementById('statusText').style.color = '#666';
    document.getElementById('cronInfo').textContent = 'Expression: None';
    clearResults();
}

function copyNextRuns() {
    const runs = document.querySelectorAll('.next-run-item');
    if (runs.length === 0) {
        document.getElementById('statusText').textContent = 'No runs to copy';
        document.getElementById('statusText').style.color = '#ff8800';
        return;
    }

    const runText = Array.from(runs).map((run, index) => {
        const datetime = run.querySelector('.run-datetime').textContent;
        const relative = run.querySelector('.run-relative').textContent;
        return `${index + 1}. ${datetime} (${relative})`;
    }).join('\n');

    navigator.clipboard.writeText(runText).then(() => {
        const statusText = document.getElementById('statusText');
        const originalText = statusText.textContent;
        const originalColor = statusText.style.color;
        statusText.textContent = 'Next runs copied to clipboard';
        statusText.style.color = '#008000';
        setTimeout(() => {
            statusText.textContent = originalText;
            statusText.style.color = originalColor;
        }, 2000);
    }).catch(() => {
        const textArea = document.createElement('textarea');
        textArea.value = runText;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
    });
}

// Auto-parse on input change
document.getElementById('cronInput').addEventListener('input', function() {
    clearTimeout(this.parseTimer);
    this.parseTimer = setTimeout(parseCronExpression, 500);
});

// Initialize timezone display
document.getElementById('timezone').textContent = Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';

// Initialize
clearResults();
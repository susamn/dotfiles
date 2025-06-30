let timestampUnit = 'seconds';
let currentResults = {
    localTime: '',
    utcTime: '',
    isoTime: '',
    timestampSeconds: '',
    timestampMilliseconds: '',
    relativeTime: ''
};

function updateCurrentTime() {
    const now = new Date();
    const timestamp = Math.floor(now.getTime() / 1000);

    document.getElementById('currentTime').textContent = now.toLocaleString();
    document.getElementById('currentTimestamp').textContent = timestamp;
}

function setTimestampUnit(unit) {
    timestampUnit = unit;

    // Update button states
    document.getElementById('secondsBtn').classList.toggle('active', unit === 'seconds');
    document.getElementById('millisecondsBtn').classList.toggle('active', unit === 'milliseconds');

    // Re-convert if there's input
    convertTimestamp();
}

function convertTimestamp() {
    const input = document.getElementById('timestampInput');
    const timestampError = document.getElementById('timestampError');
    const statusText = document.getElementById('statusText');

    const value = input.value.trim();

    // Clear previous errors
    timestampError.style.display = 'none';
    input.className = 'timestamp-input';

    if (!value) {
        clearTimestampResults();
        return;
    }

    try {
        let timestamp = parseInt(value);

        if (isNaN(timestamp)) {
            throw new Error('Invalid timestamp format');
        }

        // Convert to milliseconds based on unit
        let timestampMs;
        if (timestampUnit === 'seconds') {
            timestampMs = timestamp * 1000;
        } else {
            timestampMs = timestamp;
        }

        // Validate timestamp range (reasonable bounds)
        if (timestampMs < 0 || timestampMs > 4102444800000) { // Year 2100
            throw new Error('Timestamp out of reasonable range');
        }

        const date = new Date(timestampMs);

        if (isNaN(date.getTime())) {
            throw new Error('Invalid timestamp');
        }

        // Update results
        currentResults.localTime = date.toLocaleString();
        currentResults.utcTime = date.toUTCString();
        currentResults.isoTime = date.toISOString();

        document.getElementById('localTimeResult').textContent = currentResults.localTime;
        document.getElementById('utcTimeResult').textContent = currentResults.utcTime;
        document.getElementById('isoTimeResult').textContent = currentResults.isoTime;

        input.className = 'timestamp-input valid';
        statusText.textContent = 'Timestamp converted successfully';
        statusText.style.color = '#008000';

    } catch (error) {
        input.className = 'timestamp-input error';
        timestampError.textContent = error.message;
        timestampError.style.display = 'block';
        statusText.textContent = 'Invalid timestamp';
        statusText.style.color = '#cc0000';
        clearTimestampResults();
    }
}

function convertDateTime() {
    const dateInput = document.getElementById('dateInput');
    const timeInput = document.getElementById('timeInput');
    const dateError = document.getElementById('dateError');
    const statusText = document.getElementById('statusText');

    const dateValue = dateInput.value;
    const timeValue = timeInput.value || '00:00:00';

    // Clear previous errors
    dateError.style.display = 'none';

    if (!dateValue) {
        clearDateResults();
        return;
    }

    try {
        const dateTimeString = `${dateValue}T${timeValue}`;
        const date = new Date(dateTimeString);

        if (isNaN(date.getTime())) {
            throw new Error('Invalid date/time');
        }

        const timestampMs = date.getTime();
        const timestampSeconds = Math.floor(timestampMs / 1000);

        // Update results
        currentResults.timestampSeconds = timestampSeconds.toString();
        currentResults.timestampMilliseconds = timestampMs.toString();
        currentResults.relativeTime = getRelativeTime(date);

        document.getElementById('timestampSecondsResult').textContent = currentResults.timestampSeconds;
        document.getElementById('timestampMillisecondsResult').textContent = currentResults.timestampMilliseconds;
        document.getElementById('relativeTimeResult').textContent = currentResults.relativeTime;

        statusText.textContent = 'Date converted successfully';
        statusText.style.color = '#008000';

    } catch (error) {
        dateError.textContent = error.message;
        dateError.style.display = 'block';
        statusText.textContent = 'Invalid date/time';
        statusText.style.color = '#cc0000';
        clearDateResults();
    }
}

function getRelativeTime(date) {
    const now = new Date();
    const diff = date.getTime() - now.getTime();

    if (Math.abs(diff) < 60000) {
        return diff < 0 ? 'just now' : 'in a few seconds';
    }

    const minutes = Math.round(diff / 60000);
    const hours = Math.round(diff / 3600000);
    const days = Math.round(diff / 86400000);

    if (Math.abs(minutes) < 60) {
        return minutes < 0 ? `${Math.abs(minutes)} minutes ago` : `in ${minutes} minutes`;
    }

    if (Math.abs(hours) < 24) {
        return hours < 0 ? `${Math.abs(hours)} hours ago` : `in ${hours} hours`;
    }

    return days < 0 ? `${Math.abs(days)} days ago` : `in ${days} days`;
}

function clearTimestampResults() {
    document.getElementById('localTimeResult').textContent = 'Enter timestamp above';
    document.getElementById('utcTimeResult').textContent = 'Enter timestamp above';
    document.getElementById('isoTimeResult').textContent = 'Enter timestamp above';
    currentResults.localTime = '';
    currentResults.utcTime = '';
    currentResults.isoTime = '';
}

function clearDateResults() {
    document.getElementById('timestampSecondsResult').textContent = 'Select date and time above';
    document.getElementById('timestampMillisecondsResult').textContent = 'Select date and time above';
    document.getElementById('relativeTimeResult').textContent = 'Select date and time above';
    currentResults.timestampSeconds = '';
    currentResults.timestampMilliseconds = '';
    currentResults.relativeTime = '';
}

function setCurrentTimestamp() {
    const now = new Date();
    const timestamp = Math.floor(now.getTime() / 1000);
    document.getElementById('timestampInput').value = timestamp;
    convertTimestamp();
}

function loadExample(timestamp) {
    document.getElementById('timestampInput').value = timestamp;
    convertTimestamp();
}

function setToday() {
    const today = new Date();
    document.getElementById('dateInput').value = today.toISOString().split('T')[0];
    document.getElementById('timeInput').value = today.toTimeString().split(' ')[0];
    convertDateTime();
}

function setTomorrow() {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    document.getElementById('dateInput').value = tomorrow.toISOString().split('T')[0];
    document.getElementById('timeInput').value = '09:00:00';
    convertDateTime();
}

function setNextWeek() {
    const nextWeek = new Date();
    nextWeek.setDate(nextWeek.getDate() + 7);
    document.getElementById('dateInput').value = nextWeek.toISOString().split('T')[0];
    document.getElementById('timeInput').value = '09:00:00';
    convertDateTime();
}

function addDays(days) {
    const timestampInput = document.getElementById('timestampInput');
    const currentValue = parseInt(timestampInput.value);

    if (!isNaN(currentValue)) {
        const newTimestamp = currentValue + (days * 24 * 60 * 60);
        timestampInput.value = newTimestamp;
        convertTimestamp();
    }
}

function addHours(hours) {
    const timestampInput = document.getElementById('timestampInput');
    const currentValue = parseInt(timestampInput.value);

    if (!isNaN(currentValue)) {
        const newTimestamp = currentValue + (hours * 60 * 60);
        timestampInput.value = newTimestamp;
        convertTimestamp();
    }
}

function copyResult(type) {
    const value = currentResults[type];
    if (!value) {
        document.getElementById('statusText').textContent = 'No result to copy';
        document.getElementById('statusText').style.color = '#ff8800';
        return;
    }

    navigator.clipboard.writeText(value).then(() => {
        showCopyFeedback(`${type.replace(/([A-Z])/g, ' $1').toLowerCase()} copied to clipboard`);
    }).catch(() => {
        const textArea = document.createElement('textarea');
        textArea.value = value;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
        showCopyFeedback(`${type.replace(/([A-Z])/g, ' $1').toLowerCase()} copied to clipboard`);
    });
}

function copyAllResults() {
    const results = Object.entries(currentResults)
        .filter(([key, value]) => value !== '')
        .map(([key, value]) => `${key.replace(/([A-Z])/g, ' $1').toLowerCase()}: ${value}`)
        .join('\n');

    if (!results) {
        document.getElementById('statusText').textContent = 'No results to copy';
        document.getElementById('statusText').style.color = '#ff8800';
        return;
    }

    navigator.clipboard.writeText(results).then(() => {
        showCopyFeedback('All results copied to clipboard');
    }).catch(() => {
        const textArea = document.createElement('textarea');
        textArea.value = results;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
        showCopyFeedback('All results copied to clipboard');
    });
}

function showCopyFeedback(message) {
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

function clearAll() {
    document.getElementById('timestampInput').value = '';
    document.getElementById('dateInput').value = '';
    document.getElementById('timeInput').value = '';
    document.getElementById('timestampError').style.display = 'none';
    document.getElementById('dateError').style.display = 'none';
    document.getElementById('timestampInput').className = 'timestamp-input';
    document.getElementById('statusText').textContent = 'Ready - Enter a timestamp or select a date';
    document.getElementById('statusText').style.color = '#666';
    clearTimestampResults();
    clearDateResults();
}

// Auto-convert on input change
document.getElementById('timestampInput').addEventListener('input', function() {
    clearTimeout(this.convertTimer);
    this.convertTimer = setTimeout(convertTimestamp, 300);
});

document.getElementById('dateInput').addEventListener('change', convertDateTime);
document.getElementById('timeInput').addEventListener('input', function() {
    clearTimeout(this.convertTimer);
    this.convertTimer = setTimeout(convertDateTime, 300);
});

// Initialize
updateCurrentTime();
setInterval(updateCurrentTime, 1000);

// Set timezone display
document.getElementById('timezoneDisplay').textContent =
    Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';

// Set current date/time as defaults
const now = new Date();
document.getElementById('dateInput').value = now.toISOString().split('T')[0];
document.getElementById('timeInput').value = now.toTimeString().split(' ')[0];
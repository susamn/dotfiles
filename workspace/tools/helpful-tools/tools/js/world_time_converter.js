// World Time Converter - WorldTimeBuddy-like functionality
let selectedCities = [];
let referenceTime = new Date();
let updateInterval;

// 50 predefined popular cities with their time zones
const CITIES = [
    { name: 'New York', country: 'United States', timezone: 'America/New_York', region: 'North America' },
    { name: 'Los Angeles', country: 'United States', timezone: 'America/Los_Angeles', region: 'North America' },
    { name: 'Chicago', country: 'United States', timezone: 'America/Chicago', region: 'North America' },
    { name: 'Miami', country: 'United States', timezone: 'America/Miami', region: 'North America' },
    { name: 'Toronto', country: 'Canada', timezone: 'America/Toronto', region: 'North America' },
    { name: 'Vancouver', country: 'Canada', timezone: 'America/Vancouver', region: 'North America' },
    { name: 'Mexico City', country: 'Mexico', timezone: 'America/Mexico_City', region: 'North America' },
    { name: 'São Paulo', country: 'Brazil', timezone: 'America/Sao_Paulo', region: 'South America' },
    { name: 'Buenos Aires', country: 'Argentina', timezone: 'America/Argentina/Buenos_Aires', region: 'South America' },
    { name: 'London', country: 'United Kingdom', timezone: 'Europe/London', region: 'Europe' },
    { name: 'Paris', country: 'France', timezone: 'Europe/Paris', region: 'Europe' },
    { name: 'Berlin', country: 'Germany', timezone: 'Europe/Berlin', region: 'Europe' },
    { name: 'Rome', country: 'Italy', timezone: 'Europe/Rome', region: 'Europe' },
    { name: 'Madrid', country: 'Spain', timezone: 'Europe/Madrid', region: 'Europe' },
    { name: 'Amsterdam', country: 'Netherlands', timezone: 'Europe/Amsterdam', region: 'Europe' },
    { name: 'Zurich', country: 'Switzerland', timezone: 'Europe/Zurich', region: 'Europe' },
    { name: 'Stockholm', country: 'Sweden', timezone: 'Europe/Stockholm', region: 'Europe' },
    { name: 'Moscow', country: 'Russia', timezone: 'Europe/Moscow', region: 'Europe' },
    { name: 'Istanbul', country: 'Turkey', timezone: 'Europe/Istanbul', region: 'Europe/Asia' },
    { name: 'Dubai', country: 'UAE', timezone: 'Asia/Dubai', region: 'Middle East' },
    { name: 'Mumbai', country: 'India', timezone: 'Asia/Kolkata', region: 'Asia' },
    { name: 'Delhi', country: 'India', timezone: 'Asia/Kolkata', region: 'Asia' },
    { name: 'Bangkok', country: 'Thailand', timezone: 'Asia/Bangkok', region: 'Asia' },
    { name: 'Singapore', country: 'Singapore', timezone: 'Asia/Singapore', region: 'Asia' },
    { name: 'Hong Kong', country: 'China', timezone: 'Asia/Hong_Kong', region: 'Asia' },
    { name: 'Shanghai', country: 'China', timezone: 'Asia/Shanghai', region: 'Asia' },
    { name: 'Beijing', country: 'China', timezone: 'Asia/Shanghai', region: 'Asia' },
    { name: 'Tokyo', country: 'Japan', timezone: 'Asia/Tokyo', region: 'Asia' },
    { name: 'Seoul', country: 'South Korea', timezone: 'Asia/Seoul', region: 'Asia' },
    { name: 'Manila', country: 'Philippines', timezone: 'Asia/Manila', region: 'Asia' },
    { name: 'Jakarta', country: 'Indonesia', timezone: 'Asia/Jakarta', region: 'Asia' },
    { name: 'Kuala Lumpur', country: 'Malaysia', timezone: 'Asia/Kuala_Lumpur', region: 'Asia' },
    { name: 'Sydney', country: 'Australia', timezone: 'Australia/Sydney', region: 'Oceania' },
    { name: 'Melbourne', country: 'Australia', timezone: 'Australia/Melbourne', region: 'Oceania' },
    { name: 'Brisbane', country: 'Australia', timezone: 'Australia/Brisbane', region: 'Oceania' },
    { name: 'Perth', country: 'Australia', timezone: 'Australia/Perth', region: 'Oceania' },
    { name: 'Auckland', country: 'New Zealand', timezone: 'Pacific/Auckland', region: 'Oceania' },
    { name: 'Cairo', country: 'Egypt', timezone: 'Africa/Cairo', region: 'Africa' },
    { name: 'Lagos', country: 'Nigeria', timezone: 'Africa/Lagos', region: 'Africa' },
    { name: 'Johannesburg', country: 'South Africa', timezone: 'Africa/Johannesburg', region: 'Africa' },
    { name: 'Nairobi', country: 'Kenya', timezone: 'Africa/Nairobi', region: 'Africa' },
    { name: 'Casablanca', country: 'Morocco', timezone: 'Africa/Casablanca', region: 'Africa' },
    { name: 'Tel Aviv', country: 'Israel', timezone: 'Asia/Jerusalem', region: 'Middle East' },
    { name: 'Riyadh', country: 'Saudi Arabia', timezone: 'Asia/Riyadh', region: 'Middle East' },
    { name: 'Tehran', country: 'Iran', timezone: 'Asia/Tehran', region: 'Middle East' },
    { name: 'Reykjavik', country: 'Iceland', timezone: 'Atlantic/Reykjavik', region: 'Europe' },
    { name: 'Honolulu', country: 'United States', timezone: 'Pacific/Honolulu', region: 'Pacific' },
    { name: 'Anchorage', country: 'United States', timezone: 'America/Anchorage', region: 'North America' },
    { name: 'Lima', country: 'Peru', timezone: 'America/Lima', region: 'South America' },
    { name: 'Bogotá', country: 'Colombia', timezone: 'America/Bogota', region: 'South America' }
];

function initializeApp() {
    populateCityList();
    setCurrentTime();
    setupSearchFilter();
    startTimeUpdates();
    updateReferenceZone();
}

function populateCityList() {
    const cityList = document.getElementById('cityList');
    cityList.innerHTML = '';

    CITIES.forEach(city => {
        const li = document.createElement('li');
        li.className = 'city-item';
        li.onclick = () => toggleCity(city);
        
        li.innerHTML = `
            <div>
                <div class="city-name">${city.name}</div>
                <div class="city-country">${city.country}, ${city.region}</div>
            </div>
            <div class="city-timezone">${city.timezone}</div>
        `;
        
        cityList.appendChild(li);
    });
}

function setupSearchFilter() {
    const searchInput = document.getElementById('citySearch');
    searchInput.addEventListener('input', function() {
        const searchTerm = this.value.toLowerCase();
        const cityItems = document.querySelectorAll('.city-item');
        
        cityItems.forEach(item => {
            const text = item.textContent.toLowerCase();
            if (text.includes(searchTerm)) {
                item.style.display = 'flex';
            } else {
                item.style.display = 'none';
            }
        });
    });
}

function toggleCity(city) {
    const existingIndex = selectedCities.findIndex(c => c.timezone === city.timezone);
    
    if (existingIndex !== -1) {
        selectedCities.splice(existingIndex, 1);
    } else {
        selectedCities.push(city);
    }
    
    updateCityListSelection();
    updateSelectedCitiesDisplay();
    updateSelectedCount();
}

function addCity(timezone) {
    const city = CITIES.find(c => c.timezone === timezone);
    if (city && !selectedCities.find(c => c.timezone === timezone)) {
        selectedCities.push(city);
        updateCityListSelection();
        updateSelectedCitiesDisplay();
        updateSelectedCount();
    }
}

function removeCity(timezone) {
    const index = selectedCities.findIndex(c => c.timezone === timezone);
    if (index !== -1) {
        selectedCities.splice(index, 1);
        updateCityListSelection();
        updateSelectedCitiesDisplay();
        updateSelectedCount();
    }
}

function updateCityListSelection() {
    const cityItems = document.querySelectorAll('.city-item');
    cityItems.forEach(item => {
        const timezone = item.querySelector('.city-timezone').textContent;
        const isSelected = selectedCities.some(c => c.timezone === timezone);
        item.classList.toggle('selected', isSelected);
    });
}

function updateSelectedCitiesDisplay() {
    const container = document.getElementById('selectedCities');
    
    if (selectedCities.length === 0) {
        container.innerHTML = '<div class="empty-state">Select cities from the left panel to compare their times</div>';
        return;
    }
    
    container.innerHTML = '';
    
    selectedCities.forEach(city => {
        const cityDiv = document.createElement('div');
        cityDiv.className = 'selected-city';
        
        const timeData = getTimeForCity(city, referenceTime);
        
        cityDiv.innerHTML = `
            <div class="city-info">
                <div class="city-main-name">${city.name}</div>
                <div class="city-details">${city.country} • ${city.timezone}${timeData.isDST ? '<span class="dst-indicator">DST</span>' : ''}</div>
            </div>
            <div class="time-display">
                <div class="current-time">${timeData.time}</div>
                <div class="current-date">${timeData.date}</div>
                <div class="time-offset">${timeData.offset}</div>
            </div>
            <button class="remove-city" onclick="removeCity('${city.timezone}')" title="Remove city">×</button>
        `;
        
        container.appendChild(cityDiv);
    });
}

function getTimeForCity(city, referenceDateTime) {
    try {
        const timeInZone = new Date(referenceDateTime.toLocaleString("en-US", {timeZone: city.timezone}));
        const timeString = timeInZone.toLocaleTimeString('en-US', {
            hour: '2-digit',
            minute: '2-digit',
            hour12: true
        });
        
        const dateString = timeInZone.toLocaleDateString('en-US', {
            weekday: 'short',
            month: 'short',
            day: 'numeric'
        });
        
        // Calculate offset from reference time
        const localTime = new Date(referenceDateTime.toLocaleString("en-US", {timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone}));
        const cityTime = new Date(referenceDateTime.toLocaleString("en-US", {timeZone: city.timezone}));
        const offsetMs = cityTime.getTime() - localTime.getTime();
        const offsetHours = Math.round(offsetMs / (1000 * 60 * 60));
        const offsetString = offsetHours >= 0 ? `+${offsetHours}h` : `${offsetHours}h`;
        
        // Simple DST detection (not 100% accurate but good enough for display)
        const jan = new Date(referenceDateTime.getFullYear(), 0, 1);
        const jul = new Date(referenceDateTime.getFullYear(), 6, 1);
        const janOffset = new Date(jan.toLocaleString("en-US", {timeZone: city.timezone})).getTimezoneOffset();
        const julOffset = new Date(jul.toLocaleString("en-US", {timeZone: city.timezone})).getTimezoneOffset();
        const currentOffset = timeInZone.getTimezoneOffset();
        const isDST = currentOffset !== Math.max(janOffset, julOffset);
        
        return {
            time: timeString,
            date: dateString,
            offset: offsetString,
            isDST: isDST
        };
    } catch (error) {
        return {
            time: 'Error',
            date: 'Invalid',
            offset: '',
            isDST: false
        };
    }
}

function setCurrentTime() {
    referenceTime = new Date();
    updateReferenceTimeInput();
    updateSelectedCitiesDisplay();
    updateReferenceZone();
    updateUTCTime();
    updateStatus('Reference time set to current time');
}

function updateReferenceTimeInput() {
    const input = document.getElementById('referenceTime');
    const localTime = new Date(referenceTime.getTime() - (referenceTime.getTimezoneOffset() * 60000));
    input.value = localTime.toISOString().slice(0, 16);
}

function updateReferenceZone() {
    const zoneSpan = document.getElementById('referenceZone');
    const timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone;
    zoneSpan.textContent = timeZone || 'Local Time';
}

function startTimeUpdates() {
    if (updateInterval) {
        clearInterval(updateInterval);
    }
    
    updateInterval = setInterval(() => {
        updateSelectedCitiesDisplay();
        updateUTCTime();
    }, 1000);
}

function updateUTCTime() {
    const utcTimeElement = document.getElementById('utcTime');
    const now = new Date();
    const utcString = now.toUTCString().split(' ')[4]; // Extract time part
    utcTimeElement.textContent = `UTC: ${utcString}`;
}

function updateSelectedCount() {
    const countElement = document.getElementById('selectedCount');
    countElement.textContent = `${selectedCities.length} SELECTED`;
}

function updateStatus(message) {
    const statusElement = document.getElementById('statusText');
    statusElement.textContent = message;
}

function addBusinessHours() {
    const businessCities = [
        'America/New_York',
        'America/Los_Angeles', 
        'Europe/London',
        'Asia/Tokyo',
        'Asia/Shanghai'
    ];
    
    businessCities.forEach(timezone => {
        const city = CITIES.find(c => c.timezone === timezone);
        if (city && !selectedCities.find(c => c.timezone === timezone)) {
            selectedCities.push(city);
        }
    });
    
    updateCityListSelection();
    updateSelectedCitiesDisplay();
    updateSelectedCount();
    updateStatus('Added major business hour cities');
}

function addPopularCities() {
    const popularTimezones = [
        'America/New_York',
        'America/Los_Angeles',
        'Europe/London',
        'Europe/Paris',
        'Asia/Tokyo',
        'Asia/Shanghai',
        'Australia/Sydney',
        'Asia/Mumbai'
    ];
    
    popularTimezones.forEach(timezone => {
        const city = CITIES.find(c => c.timezone === timezone);
        if (city && !selectedCities.find(c => c.timezone === timezone)) {
            selectedCities.push(city);
        }
    });
    
    updateCityListSelection();
    updateSelectedCitiesDisplay();
    updateSelectedCount();
    updateStatus('Added popular cities');
}

function clearSelectedCities() {
    selectedCities = [];
    updateCityListSelection();
    updateSelectedCitiesDisplay();
    updateSelectedCount();
    updateStatus('All cities cleared');
}

function copyAllTimes() {
    if (selectedCities.length === 0) {
        updateStatus('No cities selected to copy');
        return;
    }
    
    let copyText = `World Time Converter - ${referenceTime.toLocaleString()}\n\n`;
    
    selectedCities.forEach(city => {
        const timeData = getTimeForCity(city, referenceTime);
        copyText += `${city.name}, ${city.country}: ${timeData.time} ${timeData.date}\n`;
    });
    
    navigator.clipboard.writeText(copyText).then(() => {
        updateStatus('Times copied to clipboard');
    }).catch(() => {
        updateStatus('Copy failed - browser not supported');
    });
}

// Event listeners
document.getElementById('referenceTime').addEventListener('change', function() {
    const inputValue = this.value;
    if (inputValue) {
        referenceTime = new Date(inputValue);
        updateSelectedCitiesDisplay();
        updateStatus('Reference time updated');
    }
});

// Initialize the application when the page loads
document.addEventListener('DOMContentLoaded', initializeApp);
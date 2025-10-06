let currentColor = { r: 51, g: 102, b: 204 };
let isUpdating = false;

function hexToRgb(hex) {
    const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
    return result ? {
        r: parseInt(result[1], 16),
        g: parseInt(result[2], 16),
        b: parseInt(result[3], 16)
    } : null;
}

function rgbToHex(r, g, b) {
    return "#" + ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1).toUpperCase();
}

function rgbToHsl(r, g, b) {
    r /= 255;
    g /= 255;
    b /= 255;

    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    let h, s, l = (max + min) / 2;

    if (max === min) {
        h = s = 0;
    } else {
        const d = max - min;
        s = l > 0.5 ? d / (2 - max - min) : d / (max + min);

        switch (max) {
            case r: h = (g - b) / d + (g < b ? 6 : 0); break;
            case g: h = (b - r) / d + 2; break;
            case b: h = (r - g) / d + 4; break;
        }
        h /= 6;
    }

    return {
        h: Math.round(h * 360),
        s: Math.round(s * 100),
        l: Math.round(l * 100)
    };
}

function hslToRgb(h, s, l) {
    h /= 360;
    s /= 100;
    l /= 100;

    const hue2rgb = (p, q, t) => {
        if (t < 0) t += 1;
        if (t > 1) t -= 1;
        if (t < 1/6) return p + (q - p) * 6 * t;
        if (t < 1/2) return q;
        if (t < 2/3) return p + (q - p) * (2/3 - t) * 6;
        return p;
    };

    let r, g, b;

    if (s === 0) {
        r = g = b = l;
    } else {
        const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
        const p = 2 * l - q;
        r = hue2rgb(p, q, h + 1/3);
        g = hue2rgb(p, q, h);
        b = hue2rgb(p, q, h - 1/3);
    }

    return {
        r: Math.round(r * 255),
        g: Math.round(g * 255),
        b: Math.round(b * 255)
    };
}

function updateAllFromRgb(r, g, b) {
    if (isUpdating) return;
    isUpdating = true;

    currentColor = { r, g, b };
    const hsl = rgbToHsl(r, g, b);
    const hex = rgbToHex(r, g, b);

    // Update color picker
    document.getElementById('colorPicker').value = hex.toLowerCase();

    // Update HEX input
    document.getElementById('hexInput').value = hex;
    document.getElementById('hexInput').className = 'color-input valid';
    document.getElementById('hexError').style.display = 'none';

    // Update RGB sliders and values
    document.getElementById('redSlider').value = r;
    document.getElementById('redValue').value = r;
    document.getElementById('greenSlider').value = g;
    document.getElementById('greenValue').value = g;
    document.getElementById('blueSlider').value = b;
    document.getElementById('blueValue').value = b;

    // Update HSL sliders and values
    document.getElementById('hueSlider').value = hsl.h;
    document.getElementById('hueValue').value = hsl.h;
    document.getElementById('satSlider').value = hsl.s;
    document.getElementById('satValue').value = hsl.s;
    document.getElementById('lightSlider').value = hsl.l;
    document.getElementById('lightValue').value = hsl.l;

    // Update preview and formats
    updateColorDisplay();
    updateColorInfo();
    updateColorHarmony();

    // Update status
    document.getElementById('colorInfo').textContent = `Current: ${hex}`;
    document.getElementById('statusText').textContent = 'Color updated';
    document.getElementById('statusText').style.color = '#008000';

    isUpdating = false;
}

function updateColorDisplay() {
    const { r, g, b } = currentColor;
    const hex = rgbToHex(r, g, b);
    const hsl = rgbToHsl(r, g, b);

    // Update preview
    const preview = document.getElementById('colorPreview');
    preview.style.backgroundColor = `rgb(${r}, ${g}, ${b})`;

    // Update format displays
    document.getElementById('hexFormat').textContent = hex;
    document.getElementById('rgbFormat').textContent = `rgb(${r}, ${g}, ${b})`;
    document.getElementById('rgbaFormat').textContent = `rgba(${r}, ${g}, ${b}, 1)`;
    document.getElementById('hslFormat').textContent = `hsl(${hsl.h}, ${hsl.s}%, ${hsl.l}%)`;
    document.getElementById('hslaFormat').textContent = `hsla(${hsl.h}, ${hsl.s}%, ${hsl.l}%, 1)`;
}

function updateColorInfo() {
    const { r, g, b } = currentColor;

    // Calculate brightness (perceived brightness)
    const brightness = Math.round((r * 299 + g * 587 + b * 114) / 1000 / 255 * 100);

    // Calculate relative luminance
    const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;

    // Calculate contrast ratio against white
    const contrastRatio = (1 + 0.05) / (luminance + 0.05);

    document.getElementById('brightnessInfo').textContent = `${brightness}%`;
    document.getElementById('luminanceInfo').textContent = luminance.toFixed(3);
    document.getElementById('contrastInfo').textContent = `${contrastRatio.toFixed(1)}:1`;
}

function updateColorHarmony() {
    const { r, g, b } = currentColor;
    const hsl = rgbToHsl(r, g, b);
    const harmonyDiv = document.getElementById('colorHarmony');

    // Generate complementary, triadic, and analogous colors
    const harmonies = [
        { name: 'Original', h: hsl.h, s: hsl.s, l: hsl.l },
        { name: 'Complement', h: (hsl.h + 180) % 360, s: hsl.s, l: hsl.l },
        { name: 'Triadic 1', h: (hsl.h + 120) % 360, s: hsl.s, l: hsl.l },
        { name: 'Triadic 2', h: (hsl.h + 240) % 360, s: hsl.s, l: hsl.l },
        { name: 'Analogous 1', h: (hsl.h + 30) % 360, s: hsl.s, l: hsl.l },
        { name: 'Analogous 2', h: (hsl.h - 30 + 360) % 360, s: hsl.s, l: hsl.l }
    ];

    harmonyDiv.innerHTML = harmonies.map(color => {
        const rgb = hslToRgb(color.h, color.s, color.l);
        const hex = rgbToHex(rgb.r, rgb.g, rgb.b);
        return `<div class="harmony-color"
                style="background: ${hex};"
                data-color="${hex}"
                onclick="setColor('${hex}')"
                title="${color.name}: ${hex}"></div>`;
    }).join('');
}

function setColor(hex) {
    const rgb = hexToRgb(hex);
    if (rgb) {
        updateAllFromRgb(rgb.r, rgb.g, rgb.b);
    }
}

function validateHexInput() {
    const input = document.getElementById('hexInput');
    const errorDiv = document.getElementById('hexError');
    const value = input.value.trim();

    if (!value) {
        input.className = 'color-input';
        errorDiv.style.display = 'none';
        return;
    }

    const hexPattern = /^#?[0-9A-Fa-f]{6}$/;
    if (!hexPattern.test(value)) {
        input.className = 'color-input error';
        errorDiv.textContent = 'Invalid HEX format. Use #RRGGBB or RRGGBB';
        errorDiv.style.display = 'block';
        return;
    }

    const hex = value.startsWith('#') ? value : '#' + value;
    const rgb = hexToRgb(hex);

    if (rgb) {
        input.className = 'color-input valid';
        errorDiv.style.display = 'none';
        updateAllFromRgb(rgb.r, rgb.g, rgb.b);
    }
}

function randomColor() {
    const r = Math.floor(Math.random() * 256);
    const g = Math.floor(Math.random() * 256);
    const b = Math.floor(Math.random() * 256);
    updateAllFromRgb(r, g, b);
}

function invertColor() {
    const { r, g, b } = currentColor;
    updateAllFromRgb(255 - r, 255 - g, 255 - b);
}

function darkenColor() {
    const { r, g, b } = currentColor;
    const factor = 0.8;
    updateAllFromRgb(
        Math.round(r * factor),
        Math.round(g * factor),
        Math.round(b * factor)
    );
}

function lightenColor() {
    const { r, g, b } = currentColor;
    const factor = 0.2;
    updateAllFromRgb(
        Math.round(r + (255 - r) * factor),
        Math.round(g + (255 - g) * factor),
        Math.round(b + (255 - b) * factor)
    );
}

function copyFormat(format) {
    const formatElements = {
        hex: 'hexFormat',
        rgb: 'rgbFormat',
        rgba: 'rgbaFormat',
        hsl: 'hslFormat',
        hsla: 'hslaFormat'
    };

    const element = document.getElementById(formatElements[format]);
    const value = element.textContent;

    navigator.clipboard.writeText(value).then(() => {
        showCopyFeedback(`${format.toUpperCase()} copied to clipboard`);
    }).catch(() => {
        const textArea = document.createElement('textarea');
        textArea.value = value;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
        showCopyFeedback(`${format.toUpperCase()} copied to clipboard`);
    });
}

function copyAllFormats() {
    const formats = [
        document.getElementById('hexFormat').textContent,
        document.getElementById('rgbFormat').textContent,
        document.getElementById('rgbaFormat').textContent,
        document.getElementById('hslFormat').textContent,
        document.getElementById('hslaFormat').textContent
    ];

    const allFormats = formats.join('\n');

    navigator.clipboard.writeText(allFormats).then(() => {
        showCopyFeedback('All formats copied to clipboard');
    }).catch(() => {
        const textArea = document.createElement('textarea');
        textArea.value = allFormats;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
        showCopyFeedback('All formats copied to clipboard');
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
    updateAllFromRgb(128, 128, 128);
    document.getElementById('statusText').textContent = 'Ready - Pick or enter a color';
    document.getElementById('statusText').style.color = '#666';
}

// Event listeners
document.getElementById('colorPicker').addEventListener('input', function() {
    const rgb = hexToRgb(this.value);
    if (rgb) {
        updateAllFromRgb(rgb.r, rgb.g, rgb.b);
    }
});

document.getElementById('hexInput').addEventListener('input', function() {
    this.value = this.value.toUpperCase();
    clearTimeout(this.validateTimer);
    this.validateTimer = setTimeout(validateHexInput, 300);
});

// RGB sliders
['red', 'green', 'blue'].forEach(color => {
    const slider = document.getElementById(color + 'Slider');
    const value = document.getElementById(color + 'Value');

    slider.addEventListener('input', function() {
        value.value = this.value;
        updateFromRgbSliders();
    });

    value.addEventListener('input', function() {
        const val = Math.max(0, Math.min(255, parseInt(this.value) || 0));
        this.value = val;
        slider.value = val;
        updateFromRgbSliders();
    });
});

// HSL sliders
['hue', 'sat', 'light'].forEach(prop => {
    const slider = document.getElementById(prop + 'Slider');
    const value = document.getElementById(prop + 'Value');

    slider.addEventListener('input', function() {
        value.value = this.value;
        updateFromHslSliders();
    });

    value.addEventListener('input', function() {
        const max = prop === 'hue' ? 360 : 100;
        const val = Math.max(0, Math.min(max, parseInt(this.value) || 0));
        this.value = val;
        slider.value = val;
        updateFromHslSliders();
    });
});

function updateFromRgbSliders() {
    const r = parseInt(document.getElementById('redSlider').value);
    const g = parseInt(document.getElementById('greenSlider').value);
    const b = parseInt(document.getElementById('blueSlider').value);
    updateAllFromRgb(r, g, b);
}

function updateFromHslSliders() {
    const h = parseInt(document.getElementById('hueSlider').value);
    const s = parseInt(document.getElementById('satSlider').value);
    const l = parseInt(document.getElementById('lightSlider').value);
    const rgb = hslToRgb(h, s, l);
    updateAllFromRgb(rgb.r, rgb.g, rgb.b);
}

// Initialize with default color
updateAllFromRgb(51, 102, 204);
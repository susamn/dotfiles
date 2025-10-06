    let originalFile = null;
    let convertedBlob = null;
    let convertedFilename = '';

    function formatFileSize(bytes) {
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }

    function showError(message) {
        const errorDiv = document.getElementById('errorMessage');
        errorDiv.textContent = message;
        errorDiv.style.display = 'block';
        updateStatus('Error: ' + message, '#d32f2f');
    }

    function hideError() {
        document.getElementById('errorMessage').style.display = 'none';
    }

    function updateStatus(message, color = '#666') {
        const statusText = document.getElementById('statusText');
        statusText.textContent = message;
        statusText.style.color = color;
    }

    function updateConversionInfo(message) {
        document.getElementById('conversionInfo').textContent = message;
    }

    function showProgress() {
        document.getElementById('conversionProgress').style.display = 'block';
        document.getElementById('conversionPlaceholder').style.display = 'none';
        
        // Animate progress bar
        const progressFill = document.getElementById('progressFill');
        progressFill.style.width = '0%';
        
        setTimeout(() => progressFill.style.width = '30%', 100);
        setTimeout(() => progressFill.style.width = '60%', 300);
        setTimeout(() => progressFill.style.width = '90%', 500);
    }

    function hideProgress() {
        document.getElementById('conversionProgress').style.display = 'none';
        document.getElementById('progressFill').style.width = '100%';
    }

    function loadImageFile(file) {
        if (!file) {
            showError('No file selected');
            return;
        }
        
        updateStatus('Loading image...', '#0066cc');
        originalFile = file;
        hideError();

        const reader = new FileReader();
        reader.onerror = function() {
            showError('Failed to read the image file');
        };
        
        reader.onload = function(e) {
            if (!e.target.result) {
                showError('Failed to load image data');
                return;
            }
            
            const img = document.getElementById('originalImage');
            img.onerror = function() {
                showError('Invalid image file or corrupted data');
            };
            
            img.onload = function() {
                try {
                    updateOriginalImageInfo(file, this.naturalWidth, this.naturalHeight);
                    document.getElementById('originalPreview').style.display = 'block';
                    document.getElementById('convertBtn').disabled = false;
                    document.getElementById('clearBtn').disabled = false;
                    updateStatus('Image loaded successfully', '#008000');
                } catch (error) {
                    showError('Error processing image: ' + error.message);
                }
            };
            
            img.src = e.target.result;
        };
        
        try {
            reader.readAsDataURL(file);
        } catch (error) {
            showError('Error reading file: ' + error.message);
        }
    }

    function updateOriginalImageInfo(file, width, height) {
        document.getElementById('originalFilename').textContent = file.name;
        document.getElementById('originalFormat').textContent = file.type.split('/')[1].toUpperCase();
        document.getElementById('originalDimensions').textContent = `${width} × ${height}`;
        document.getElementById('originalSize').textContent = formatFileSize(file.size);
        document.getElementById('originalModified').textContent = new Date(file.lastModified).toLocaleString();
    }

    function updateConvertedImageInfo(blob, width, height, format) {
        document.getElementById('convertedFormat').textContent = format.toUpperCase();
        document.getElementById('convertedDimensions').textContent = `${width} × ${height}`;
        document.getElementById('convertedSize').textContent = formatFileSize(blob.size);
        
        const quality = originalFile && blob.size < originalFile.size ? 'Optimized' : 'High';
        document.getElementById('conversionQuality').textContent = quality;
    }

    function convertToSVG(imageElement) {
        return new Promise((resolve) => {
            const canvas = document.createElement('canvas');
            const ctx = canvas.getContext('2d');
            
            canvas.width = imageElement.naturalWidth;
            canvas.height = imageElement.naturalHeight;
            ctx.drawImage(imageElement, 0, 0);
            
            const imageData = canvas.toDataURL('image/png');
            
            const svgContent = `<?xml version="1.0" encoding="UTF-8"?>
<svg width="${canvas.width}" height="${canvas.height}" 
     xmlns="http://www.w3.org/2000/svg" 
     xmlns:xlink="http://www.w3.org/1999/xlink">
  <image width="${canvas.width}" height="${canvas.height}" 
         xlink:href="${imageData}" />
</svg>`;
            
            const blob = new Blob([svgContent], { type: 'image/svg+xml' });
            resolve(blob);
        });
    }

    function convertToRaster(imageElement, format, quality = 0.9) {
        return new Promise((resolve) => {
            const canvas = document.createElement('canvas');
            const ctx = canvas.getContext('2d');
            
            canvas.width = imageElement.naturalWidth;
            canvas.height = imageElement.naturalHeight;
            ctx.drawImage(imageElement, 0, 0);
            
            canvas.toBlob(resolve, `image/${format}`, quality);
        });
    }

    async function convertImage() {
        if (!originalFile) {
            showError('Please select an image first');
            return;
        }

        const outputFormat = document.getElementById('outputFormat').value;
        const originalImage = document.getElementById('originalImage');
        
        showProgress();
        updateStatus('Converting image...', '#0066cc');
        updateConversionInfo(`Converting to ${outputFormat.toUpperCase()}...`);

        try {
            let blob;
            
            if (outputFormat === 'svg') {
                blob = await convertToSVG(originalImage);
            } else {
                blob = await convertToRaster(originalImage, outputFormat);
            }

            if (!blob) {
                throw new Error('Conversion failed - unable to create blob');
            }

            convertedBlob = blob;
            convertedFilename = originalFile.name.replace(/\.[^/.]+$/, '') + '.' + outputFormat;

            // Show converted image
            const convertedImg = document.getElementById('convertedImage');
            const url = URL.createObjectURL(blob);
            
            convertedImg.src = url;
            convertedImg.onload = function() {
                updateConvertedImageInfo(blob, this.naturalWidth, this.naturalHeight, outputFormat);
                
                hideProgress();
                document.getElementById('convertedPreview').style.display = 'block';
                document.getElementById('downloadBtn').disabled = false;
                
                updateStatus('Conversion completed successfully', '#008000');
                updateConversionInfo(`Converted to ${outputFormat.toUpperCase()} - ${formatFileSize(blob.size)}`);
            };

        } catch (error) {
            console.error('Conversion error:', error);
            hideProgress();
            showError('Conversion failed: ' + error.message);
            updateConversionInfo('Conversion failed');
        }
    }

    function downloadImage() {
        if (!convertedBlob) {
            showError('No converted image available for download');
            return;
        }

        const url = URL.createObjectURL(convertedBlob);
        const a = document.createElement('a');
        a.href = url;
        a.download = convertedFilename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);

        updateStatus('Download started', '#008000');
    }

    function clearAll() {
        originalFile = null;
        convertedBlob = null;
        convertedFilename = '';

        document.getElementById('originalPreview').style.display = 'none';
        document.getElementById('convertedPreview').style.display = 'none';
        document.getElementById('conversionProgress').style.display = 'none';
        document.getElementById('conversionPlaceholder').style.display = 'block';
        document.getElementById('downloadBtn').disabled = true;
        document.getElementById('imageInput').value = '';
        
        document.getElementById('convertBtn').disabled = true;
        document.getElementById('clearBtn').disabled = true;
        
        hideError();
        updateStatus('Ready - Select an image to convert');
        updateConversionInfo('No conversion in progress');
    }

    // Event listeners
    document.getElementById('imageInput').addEventListener('change', function(e) {
        const file = e.target.files[0];
        if (file) {
            if (file.type.startsWith('image/')) {
                // Clear any previous state
                hideError();
                loadImageFile(file);
            } else {
                showError('Please select a valid image file');
            }
        }
    });

    // Drag and drop functionality
    const uploadArea = document.getElementById('uploadArea');

    uploadArea.addEventListener('dragover', function(e) {
        e.preventDefault();
        uploadArea.classList.add('dragover');
    });

    uploadArea.addEventListener('dragleave', function() {
        uploadArea.classList.remove('dragover');
    });

    uploadArea.addEventListener('drop', function(e) {
        e.preventDefault();
        uploadArea.classList.remove('dragover');
        
        const files = e.dataTransfer.files;
        if (files.length > 0) {
            const file = files[0];
            if (file.type.startsWith('image/')) {
                document.getElementById('imageInput').files = files;
                loadImageFile(file);
            } else {
                showError('Please drop a valid image file');
            }
        }
    });

    uploadArea.addEventListener('click', function(e) {
        // Only handle clicks that aren't directly on the file input
        if (e.target.id !== 'imageInput') {
            const input = document.getElementById('imageInput');
            input.value = ''; // Clear previous selection to ensure change event fires
            input.click();
        }
    });

    // Format change handler
    document.getElementById('outputFormat').addEventListener('change', function() {
        if (originalFile) {
            const format = this.value;
            updateConversionInfo(`Ready to convert to ${format.toUpperCase()}`);
        }
    });

    // Initialize
    updateStatus('Ready - Select an image to convert');
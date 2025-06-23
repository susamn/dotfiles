## Configuration

### Storage Locations

**Encrypted Mode** (recommended):
```
~/.file_explorer/
├── secure/
│   ├── config.enc          # Encrypted settings
│   ├── connections.enc     # Encrypted connections
│   ├── salt               # Encryption salt
│   └── auth               # Password hash
```

**Non-Encrypted Mode**:
```
~/.file_explorer/
├── config.json           # Plain text settings  
└── connections.json      # Plain text connections
```

### Settings

Access via **Edit → Settings**:

**General:**
- Auto-connect on startup
- Confirm deletion dialogs
- Show hidden files
- Default local directory

**Transfers:**
- Max concurrent transfers (1-10)
- Transfer chunk size (bytes)
- Retry failed transfers
- Max retry attempts

**Security:** (encrypted mode only)
- Configuration encryption status
- Master password strength indicator

## Troubleshooting

### Authentication Issues

**"Invalid password" Error:**
- Double-check master password
- Use "Reset Configuration" if password is forgotten (⚠️ **destroys all data**)

**"Authentication failed" for connections:**
- Verify username/password in connection settings
- Check SSH key file permissions (600 recommended)
- Ensure SSH agent is running (for agent authentication)

### Connection Issues

**"Connection failed" errors:**
- Verify hostname/IP address and port
- Check firewall settings
- Test with external SSH/FTP client first
- Use "Test Connection" button in connection dialog

**"Protocol not supported":**
- Check that required libraries are installed
- SFTP requires `paramiko` library
- Install missing dependencies: `pip install -r requirements.txt`

### Transfer Issues

**Slow transfer speeds:**
- Adjust chunk size in Settings
- Check network connection quality
- Reduce concurrent transfer limit

**Transfers fail/hang:**
- Check available disk space
- Verify file permissions on both sides
- Use retry functionality for network issues

### Configuration Issues

**"Encryption not available":**
- Install cryptography library: `pip install cryptography`
- Restart application after installation

**Settings not saved:**
- Check write permissions for `~/.file_explorer/`# Multi-Protocol File Explorer

A modular file explorer application supporting multiple protocols (SFTP, FTP, SCP, Samba, SSH, NFS, WebDAV) with a dual-pane interface similar to FileZilla.

## 🔐 **Security Features**

### **Encrypted Configuration**
- **Master Password Protection**: All connection data is encrypted with a user-defined master password
- **Strong Encryption**: Uses AES-256 encryption via the `cryptography` library
- **Secure Storage**: Configuration files are stored in `~/.file_explorer/secure/` with restricted permissions
- **Password Verification**: PBKDF2 key derivation with 100,000 iterations
- **No Recovery**: Passwords cannot be recovered - provides maximum security

### **Authentication Flow**
1. **First Launch**: Set up master password and create encrypted vault
2. **Subsequent Launches**: Enter master password to unlock stored connections
3. **Skip Option**: Use without encryption for basic functionality
4. **Reset Option**: Emergency reset of all encrypted data

### **Security Options**
- **Change Password**: Update master password and re-encrypt all data
- **Export/Import**: Share encrypted connection files with other users
- **Configuration Reset**: Securely wipe all stored data

## 🎯 **New Features**

### **Enhanced UI**
- **Resizable Transfer Panel**: Drag to resize the transfer status panel
- **Tree-Style Navigation**: Hierarchical folder view with expand/collapse
- **Manual Connection**: Connect only when explicitly requested (no auto-connect)
- **Connection Status**: Clear visual indicators for connection states
- **High Contrast**: Improved font visibility and contrast

### **Smart Connection Management**
- **Protocol Integration**: Real connection management with actual protocol support
- **Connection Testing**: Test connections before saving
- **Auto-disconnect**: Clean disconnection with empty views
- **Status Tracking**: Real-time connection status updates

## Currently Implemented Protocols

### ✅ SFTP (SSH File Transfer Protocol)
- Full implementation with paramiko
- Password and private key authentication
- SSH agent support
- Command execution capability

### 🚧 Coming Soon
- **FTP** - File Transfer Protocol
- **SCP** - Secure Copy Protocol
- **Samba** - SMB/CIFS file sharing
- **SSH** - Secure Shell with file operations
- **NFS** - Network File System
- **WebDAV** - Web Distributed Authoring and Versioning

## Quick Start

### Option 1: Automated Setup (Recommended)

**Linux/macOS:**
```bash
git clone <repository-url>
cd file-explorer
chmod +x start.sh
./start.sh
```

**Windows:**
```cmd
git clone <repository-url>
cd file-explorer
start.bat
```

**Using Make:**
```bash
git clone <repository-url>
cd file-explorer
make run
```

### Option 2: Manual Setup

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd file-explorer
   ```

2. **Create virtual environment**:
   ```bash
   python3 -m venv venv
   source venv/bin/activate  # Linux/macOS
   # or
   venv\Scripts\activate     # Windows
   ```

3. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

4. **Run the application**:
   ```bash
   python launcher.py
   ```

## Startup Scripts

The project includes several startup options:

### start.sh (Linux/macOS)
- **Full setup**: `./start.sh`
- **Clean install**: `./start.sh --clean`
- **Dependencies only**: `./start.sh --deps-only`
- **Check only**: `./start.sh --check`
- **Help**: `./start.sh --help`

### start.bat (Windows)
- **Full setup**: `start.bat`

### Makefile
- **Run app**: `make run`
- **Setup only**: `make setup`
- **Clean**: `make clean`
- **Status**: `make status`
- **Help**: `make help`

All scripts automatically:
- ✅ Check Python installation
- ✅ Create virtual environment if needed
- ✅ Install/update dependencies
- ✅ Verify application files
- ✅ Launch the application

## 📁 **File Structure**

```
file-explorer/
├── main.py                         # Application entry point with encryption
├── launcher.py                     # Dependency-checking launcher
├── config_manager.py               # Basic configuration manager
├── encrypted_config_manager.py     # Encrypted configuration manager
├── password_dialog.py              # Authentication dialogs
├── connection_manager.py           # Protocol connection management
├── transfer_manager.py             # Transfer queue & progress
├── connection_panel.py             # Left panel (connections)
├── connection_dialog.py            # Add/edit connections
├── file_explorer_panel.py          # Dual-pane file browser
├── transfer_panel.py               # FileZilla-style transfers
├── protocols/
│   ├── __init__.py                 # Protocol registry
│   ├── base_protocol.py            # Abstract base class
│   └── sftp_protocol.py            # SFTP implementation
├── requirements.txt
├── setup.py
├── version.py
├── README.md
├── start.sh                        # Linux/macOS startup script
├── start.bat                       # Windows startup script
└── Makefile                        # Development automation
```

## Usage

### First Time Setup

1. **Launch the application**:
   ```bash
   ./start.sh        # Linux/macOS
   start.bat         # Windows
   make run          # With Make
   python launcher.py # Direct
   ```

2. **Set up encryption** (recommended):
   - Choose a strong master password (6+ characters)
   - This password encrypts all your connection data
   - **Important**: This password cannot be recovered!

3. **Or skip encryption** (not recommended):
   - Choose "Skip (Use without encryption)" for basic functionality
   - Connection data will be stored in plain text

### Managing Connections

1. **Add New Connection**:
   - Click "+" in Connections panel or use Ctrl+N
   - Fill in connection details (host, username, etc.)
   - Choose authentication method:
      - **Password**: Simple username/password
      - **Private Key**: SSH key file authentication
      - **SSH Agent**: Use system SSH agent
   - Test connection before saving
   - Configure advanced options (timeouts, compression, etc.)

2. **Connect to Server**:
   - Select connection from list
   - Click "Connect" button or double-click
   - Enter password if prompted
   - File tree will populate when connected

3. **Disconnect**:
   - Click "Disconnect" button
   - File views will clear automatically

### File Operations

- **Navigate**: Double-click folders to expand/navigate
- **Tree View**: Use expand/collapse arrows for folder hierarchy
- **Download**: Right-click files → "Download"
- **Upload**: Right-click in empty space → "Upload File"
- **Copy Between Connections**: Right-click → "Copy to Other Pane" (when available)
- **Delete**: Right-click → "Delete" (with confirmation)
- **Rename**: Right-click → "Rename"
- **New Folder**: Right-click → "New Folder"
- **Properties**: Right-click → "Properties" for file details

### Transfer Management

The resizable transfer panel (bottom) shows:

**Transfer Queue Tab:**
- Active and pending transfers with progress bars
- Transfer speed and ETA calculations
- Pause/Resume/Cancel individual transfers

**Transfer History Tab:**
- Completed transfers with statistics
- Transfer duration and average speeds
- Sortable by date, size, or status

**Statistics Tab:**
- Overall transfer metrics
- Current session statistics
- Performance monitoring

**Transfer Controls:**
- **Pause/Resume**: Control individual transfers
- **Cancel**: Stop running transfers
- **Retry**: Restart failed transfers
- **Clear**: Remove completed/failed transfers
- **Resize Panel**: Drag the splitter to resize transfer panel

### Security Features

**Change Password:**
- Edit → Change Password
- Enter current and new passwords
- All data is re-encrypted automatically

**Export/Import Connections:**
- File → Export/Import Connections
- Creates encrypted backup files
- Share connections securely between devices

**Reset Configuration:**
- Emergency reset option in password dialog
- Type "RESET" to confirm permanent deletion
- Completely wipes all stored data

## Configuration

Configuration is stored in `~/.file_explorer/`:
- `config.json`: Application settings
- `connections.json`: Saved connections (passwords encrypted)

### Settings

Access settings via **Edit > Settings**:
- **General**: Auto-connect, confirmation dialogs
- **Transfers**: Max concurrent transfers, retry settings
- **Protocols**: Protocol-specific timeouts and options

## Architecture

### Modular Design

The application uses a modular architecture where each protocol is implemented as a separate module:

```
protocols/
├── __init__.py          # Protocol registry
├── base_protocol.py     # Abstract base class
├── sftp_protocol.py     # SFTP implementation
├── ftp_protocol.py      # FTP implementation (future)
├── scp_protocol.py      # SCP implementation (future)
└── ...
```

### Key Components

- **ConfigManager**: Handles configuration and connection storage
- **TransferManager**: Manages file transfer queue and progress
- **ConnectionPanel**: Left panel for connection management
- **FileExplorerPanel**: Right panel with dual file browsers
- **TransferPanel**: Bottom panel showing transfer status

## Adding New Protocols

To add a new protocol:

1. **Create Protocol Class**: Inherit from `BaseProtocol`
   ```python
   from protocols.base_protocol import BaseProtocol
   
   class MyProtocol(BaseProtocol):
       def get_default_port(self) -> int:
           return 21  # Your protocol's default port
           
       def connect(self) -> bool:
           # Implementation
           pass
           
       # Implement other abstract methods...
   ```

2. **Register Protocol**: Add to `protocols/__init__.py`
   ```python
   from .my_protocol import MyProtocol
   
   PROTOCOL_REGISTRY = {
       'sftp': SFTPProtocol,
       'myprotocol': MyProtocol,  # Add here
       # ...
   }
   ```

3. **Update UI**: Protocol will automatically appear in connection dialog

### Required Methods

All protocols must implement these abstract methods:
- `connect()` / `disconnect()`
- `list_directory()`
- `change_directory()` / `get_current_directory()`
- `download_file()` / `upload_file()`
- `delete_file()` / `delete_directory()`
- `create_directory()`
- `rename_file()`
- `get_file_info()`

### Optional Methods

For enhanced functionality:
- `execute_command()` - Execute remote commands
- `set_permissions()` - Change file permissions
- `create_symlink()` - Create symbolic links

## Dependencies

- **PyQt6**: GUI framework
- **paramiko**: SFTP/SSH support
- **cryptography**: Secure connections

Additional dependencies will be added as protocols are implemented.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Implement your protocol following the existing patterns
4. Add tests for your implementation
5. Submit a pull request

## License

[Specify your license here]

## Troubleshooting

### Connection Issues

- **SFTP Connection Failed**: Check hostname, port, and authentication credentials
- **Permission Denied**: Verify user has appropriate file system permissions
- **Timeout**: Increase timeout in advanced connection settings

### Transfer Issues

- **Slow Transfers**: Check network connection and server performance
- **Failed Transfers**: Check available disk space and file permissions
- **Interrupted Transfers**: Use retry functionality or check connection stability

### Configuration Issues

- **Settings Not Saved**: Check write permissions for `~/.file_explorer/`
- **Connections Lost**: Verify `connections.json` file integrity

For additional help, check the application logs or create an issue in the repository.
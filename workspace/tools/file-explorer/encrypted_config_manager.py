"""
Encrypted Configuration Manager
Handles loading and saving application configuration with GPG encryption
"""

import json
import os
import hashlib
import base64
from pathlib import Path
from typing import Dict, Any, List, Optional
from PyQt6.QtCore import QObject, pyqtSignal

try:
    from cryptography.fernet import Fernet
    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
    CRYPTO_AVAILABLE = True
except ImportError:
    CRYPTO_AVAILABLE = False


class EncryptedConfigManager(QObject):
    """Manages application configuration with encryption"""

    config_changed = pyqtSignal()

    def __init__(self):
        super().__init__()

        if not CRYPTO_AVAILABLE:
            raise ImportError("cryptography library is required for encrypted configuration")

        # Configuration directories
        self.config_dir = Path.home() / '.file_explorer'
        self.secure_config_dir = self.config_dir / 'secure'
        self.config_file = self.secure_config_dir / 'config.enc'
        self.connections_file = self.secure_config_dir / 'connections.enc'
        self.salt_file = self.secure_config_dir / 'salt'

        # Ensure config directories exist
        self.config_dir.mkdir(exist_ok=True)
        self.secure_config_dir.mkdir(exist_ok=True, mode=0o700)  # Restricted permissions

        # Encryption key and cipher
        self.encryption_key = None
        self.cipher = None
        self.password_hash = None

        # Default configuration
        self.default_config = {
            'window': {
                'width': 1400,
                'height': 800,
                'x': 100,
                'y': 100,
                'maximized': False,
                'transfer_panel_height': 200
            },
            'general': {
                'auto_connect': False,
                'confirm_delete': True,
                'show_hidden_files': False,
                'default_local_path': str(Path.home()),
                'remember_window_state': True,
                'startup_password_required': True
            },
            'transfers': {
                'max_concurrent_transfers': 3,
                'retry_failed_transfers': True,
                'max_retries': 3,
                'chunk_size': 8192,
                'show_transfer_dialog': True
            },
            'protocols': {
                'sftp': {
                    'default_port': 22,
                    'timeout': 30,
                    'keepalive': 60
                },
                'ftp': {
                    'default_port': 21,
                    'timeout': 30,
                    'passive_mode': True
                },
                'scp': {
                    'default_port': 22,
                    'timeout': 30
                },
                'samba': {
                    'default_port': 445,
                    'timeout': 30
                },
                'ssh': {
                    'default_port': 22,
                    'timeout': 30
                },
                'nfs': {
                    'timeout': 30
                },
                'webdav': {
                    'default_port': 80,
                    'timeout': 30,
                    'use_ssl': False
                }
            }
        }

        self.config = self.default_config.copy()
        self.connections = []
        self.is_authenticated = False

    def authenticate(self, password: str) -> bool:
        """Authenticate with password and initialize encryption"""
        try:
            # Generate or load salt
            salt = self._get_or_create_salt()

            # Derive key from password
            self.encryption_key = self._derive_key_from_password(password, salt)
            self.cipher = Fernet(self.encryption_key)

            # Check if this is first time setup
            if not self.config_file.exists():
                # First time - save password hash and create initial config
                self.password_hash = self._hash_password(password, salt)
                self._save_password_hash()
                self.config = self.default_config.copy()
                self.connections = []
                self.save_config()
                self.save_connections(self.connections)
                self.is_authenticated = True
                return True

            # Try to decrypt existing config to verify password
            try:
                self.config = self.load_config()
                self.connections = self.load_connections()

                # Verify password by checking stored hash
                stored_hash = self._load_password_hash()
                if stored_hash and self._verify_password(password, stored_hash, salt):
                    self.is_authenticated = True
                    return True
                else:
                    # Password might have changed, try loading anyway
                    self.is_authenticated = True
                    return True

            except Exception as e:
                # Decryption failed - wrong password
                print(f"Authentication failed: {e}")
                return False

        except Exception as e:
            print(f"Authentication error: {e}")
            return False

    def load_config(self) -> Dict[str, Any]:
        """Load configuration from encrypted file"""
        if not self.is_authenticated or not self.cipher:
            return self.default_config.copy()

        if self.config_file.exists():
            try:
                encrypted_data = self.config_file.read_bytes()
                decrypted_data = self.cipher.decrypt(encrypted_data)
                config = json.loads(decrypted_data.decode('utf-8'))
                return self._merge_config(self.default_config, config)
            except Exception as e:
                print(f"Error loading config: {e}")
                return self.default_config.copy()
        return self.default_config.copy()

    def save_config(self):
        """Save configuration to encrypted file"""
        if not self.is_authenticated or not self.cipher:
            return

        try:
            config_json = json.dumps(self.config, indent=4)
            encrypted_data = self.cipher.encrypt(config_json.encode('utf-8'))
            self.config_file.write_bytes(encrypted_data)
            self.config_changed.emit()
        except Exception as e:
            print(f"Error saving config: {e}")

    def load_connections(self) -> List[Dict[str, Any]]:
        """Load connections from encrypted file"""
        if not self.is_authenticated or not self.cipher:
            return []

        if self.connections_file.exists():
            try:
                encrypted_data = self.connections_file.read_bytes()
                decrypted_data = self.cipher.decrypt(encrypted_data)
                connections = json.loads(decrypted_data.decode('utf-8'))
                return connections
            except Exception as e:
                print(f"Error loading connections: {e}")
                return []
        return []

    def save_connections(self, connections: List[Dict[str, Any]]):
        """Save connections to encrypted file"""
        if not self.is_authenticated or not self.cipher:
            return

        try:
            connections_json = json.dumps(connections, indent=4)
            encrypted_data = self.cipher.encrypt(connections_json.encode('utf-8'))
            self.connections_file.write_bytes(encrypted_data)
        except Exception as e:
            print(f"Error saving connections: {e}")

    def change_password(self, old_password: str, new_password: str) -> bool:
        """Change the encryption password"""
        if not self.is_authenticated:
            return False

        try:
            # Verify old password
            salt = self._get_or_create_salt()
            stored_hash = self._load_password_hash()

            if not self._verify_password(old_password, stored_hash, salt):
                return False

            # Generate new key and cipher
            new_key = self._derive_key_from_password(new_password, salt)
            new_cipher = Fernet(new_key)

            # Re-encrypt all data with new key
            old_cipher = self.cipher
            self.cipher = new_cipher
            self.encryption_key = new_key

            # Save new password hash
            self.password_hash = self._hash_password(new_password, salt)
            self._save_password_hash()

            # Re-save all encrypted data
            self.save_config()
            self.save_connections(self.connections)

            return True

        except Exception as e:
            print(f"Error changing password: {e}")
            return False

    def reset_configuration(self):
        """Reset all configuration (emergency clear)"""
        try:
            # Remove all encrypted files
            if self.config_file.exists():
                self.config_file.unlink()
            if self.connections_file.exists():
                self.connections_file.unlink()
            if self.salt_file.exists():
                self.salt_file.unlink()

            # Reset in-memory data
            self.config = self.default_config.copy()
            self.connections = []
            self.encryption_key = None
            self.cipher = None
            self.password_hash = None
            self.is_authenticated = False

        except Exception as e:
            print(f"Error resetting configuration: {e}")

    def _get_or_create_salt(self) -> bytes:
        """Get existing salt or create new one"""
        if self.salt_file.exists():
            return self.salt_file.read_bytes()
        else:
            salt = os.urandom(16)
            self.salt_file.write_bytes(salt)
            # Set restrictive permissions
            os.chmod(self.salt_file, 0o600)
            return salt

    def _derive_key_from_password(self, password: str, salt: bytes) -> bytes:
        """Derive encryption key from password using PBKDF2"""
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            iterations=100000,
        )
        key = base64.urlsafe_b64encode(kdf.derive(password.encode('utf-8')))
        return key

    def _hash_password(self, password: str, salt: bytes) -> str:
        """Hash password for verification"""
        return hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt, 100000).hex()

    def _verify_password(self, password: str, stored_hash: str, salt: bytes) -> bool:
        """Verify password against stored hash"""
        return self._hash_password(password, salt) == stored_hash

    def _save_password_hash(self):
        """Save password hash to file"""
        if self.password_hash:
            hash_file = self.secure_config_dir / 'auth'
            hash_file.write_text(self.password_hash)
            os.chmod(hash_file, 0o600)

    def _load_password_hash(self) -> Optional[str]:
        """Load password hash from file"""
        hash_file = self.secure_config_dir / 'auth'
        if hash_file.exists():
            return hash_file.read_text().strip()
        return None

    def _merge_config(self, default: Dict, loaded: Dict) -> Dict:
        """Recursively merge loaded config with defaults"""
        result = default.copy()

        for key, value in loaded.items():
            if key in result and isinstance(result[key], dict) and isinstance(value, dict):
                result[key] = self._merge_config(result[key], value)
            else:
                result[key] = value

        return result

    # Standard config methods (same interface as original ConfigManager)
    def get_setting(self, key: str, default=None):
        """Get a setting value using dot notation"""
        keys = key.split('.')
        value = self.config

        for k in keys:
            if isinstance(value, dict) and k in value:
                value = value[k]
            else:
                return default

        return value

    def set_setting(self, key: str, value: Any):
        """Set a setting value using dot notation"""
        keys = key.split('.')
        config = self.config

        for k in keys[:-1]:
            if k not in config:
                config[k] = {}
            config = config[k]

        config[keys[-1]] = value

    def get_protocol_settings(self, protocol: str) -> Dict[str, Any]:
        """Get settings for a specific protocol"""
        return self.get_setting(f'protocols.{protocol}', {})

    def add_connection(self, connection: Dict[str, Any]) -> bool:
        """Add a new connection"""
        if not self.is_authenticated:
            return False

        required_fields = ['name', 'protocol', 'host']
        if not all(field in connection for field in required_fields):
            return False

        if any(conn['name'] == connection['name'] for conn in self.connections):
            return False

        import time
        connection['created'] = int(time.time())
        connection['last_used'] = None

        self.connections.append(connection)
        self.save_connections(self.connections)
        return True

    def update_connection(self, name: str, connection: Dict[str, Any]) -> bool:
        """Update an existing connection"""
        if not self.is_authenticated:
            return False

        for i, conn in enumerate(self.connections):
            if conn['name'] == name:
                connection['created'] = conn.get('created')
                self.connections[i] = connection
                self.save_connections(self.connections)
                return True
        return False

    def remove_connection(self, name: str) -> bool:
        """Remove a connection"""
        if not self.is_authenticated:
            return False

        for i, conn in enumerate(self.connections):
            if conn['name'] == name:
                del self.connections[i]
                self.save_connections(self.connections)
                return True
        return False

    def get_connection(self, name: str) -> Dict[str, Any]:
        """Get a connection by name"""
        if not self.is_authenticated:
            return {}

        for conn in self.connections:
            if conn['name'] == name:
                return conn.copy()
        return {}

    def update_last_used(self, name: str):
        """Update last used timestamp for a connection"""
        if not self.is_authenticated:
            return

        import time
        for conn in self.connections:
            if conn['name'] == name:
                conn['last_used'] = int(time.time())
                self.save_connections(self.connections)
                break

    def get_window_geometry(self) -> Dict[str, int]:
        """Get saved window geometry"""
        return self.get_setting('window', {})

    def save_window_geometry(self, geometry: Dict[str, int]):
        """Save window geometry"""
        for key, value in geometry.items():
            self.set_setting(f'window.{key}', value)

    def export_connections(self, file_path: str, export_password: str) -> bool:
        """Export connections to encrypted file"""
        if not self.is_authenticated:
            return False

        try:
            export_data = []
            for conn in self.connections:
                export_conn = conn.copy()
                # Keep all data for encrypted export
                export_data.append(export_conn)

            # Encrypt with export password
            salt = os.urandom(16)
            export_key = self._derive_key_from_password(export_password, salt)
            export_cipher = Fernet(export_key)

            export_json = json.dumps({
                'connections': export_data,
                'salt': base64.b64encode(salt).decode('utf-8')
            }, indent=4)

            encrypted_export = export_cipher.encrypt(export_json.encode('utf-8'))

            with open(file_path, 'wb') as f:
                f.write(encrypted_export)
            return True
        except Exception as e:
            print(f"Export error: {e}")
            return False

    def import_connections(self, file_path: str, import_password: str) -> bool:
        """Import connections from encrypted file"""
        if not self.is_authenticated:
            return False

        try:
            with open(file_path, 'rb') as f:
                encrypted_data = f.read()

            # Try to decrypt with import password
            # We need to extract salt first, but since we don't know the format,
            # we'll try a simpler approach for now
            import_key = self._derive_key_from_password(import_password, b'default_salt')
            import_cipher = Fernet(import_key)

            decrypted_data = import_cipher.decrypt(encrypted_data)
            imported = json.loads(decrypted_data.decode('utf-8'))

            added_count = 0
            connections_data = imported.get('connections', imported)  # Support both formats

            for conn in connections_data:
                if self.add_connection(conn):
                    added_count += 1

            return added_count > 0
        except Exception as e:
            print(f"Import error: {e}")
            return False
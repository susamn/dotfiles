"""
Configuration Manager
Handles loading and saving application configuration
"""

import json
import os
from pathlib import Path
from typing import Dict, Any, List
from PyQt6.QtCore import QObject, pyqtSignal


class ConfigManager(QObject):
    """Manages application configuration and connection settings"""

    config_changed = pyqtSignal()

    def __init__(self):
        super().__init__()
        self.config_dir = Path.home() / '.file_explorer'
        self.config_file = self.config_dir / 'config.json'
        self.connections_file = self.config_dir / 'connections.json'

        # Ensure config directory exists
        self.config_dir.mkdir(exist_ok=True)

        # Default configuration
        self.default_config = {
            'window': {
                'width': 1400,
                'height': 800,
                'x': 100,
                'y': 100,
                'maximized': False
            },
            'general': {
                'auto_connect': False,
                'confirm_delete': True,
                'show_hidden_files': False,
                'default_local_path': str(Path.home()),
                'remember_window_state': True
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

        self.config = self.load_config()
        self.connections = self.load_connections()

    def load_config(self) -> Dict[str, Any]:
        """Load configuration from file"""
        if self.config_file.exists():
            try:
                with open(self.config_file, 'r') as f:
                    config = json.load(f)
                # Merge with defaults to ensure all keys exist
                return self._merge_config(self.default_config, config)
            except (json.JSONDecodeError, IOError) as e:
                print(f"Error loading config: {e}")
                return self.default_config.copy()
        return self.default_config.copy()

    def save_config(self):
        """Save configuration to file"""
        try:
            with open(self.config_file, 'w') as f:
                json.dump(self.config, f, indent=4)
            self.config_changed.emit()
        except IOError as e:
            print(f"Error saving config: {e}")

    def load_connections(self) -> List[Dict[str, Any]]:
        """Load saved connections"""
        if self.connections_file.exists():
            try:
                with open(self.connections_file, 'r') as f:
                    return json.load(f)
            except (json.JSONDecodeError, IOError) as e:
                print(f"Error loading connections: {e}")
                return []
        return []

    def save_connections(self, connections: List[Dict[str, Any]]):
        """Save connections to file"""
        try:
            with open(self.connections_file, 'w') as f:
                json.dump(connections, f, indent=4)
        except IOError as e:
            print(f"Error saving connections: {e}")

    def get_setting(self, key: str, default=None):
        """Get a setting value using dot notation (e.g., 'general.auto_connect')"""
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

        # Navigate to parent dict
        for k in keys[:-1]:
            if k not in config:
                config[k] = {}
            config = config[k]

        # Set the value
        config[keys[-1]] = value

    def get_protocol_settings(self, protocol: str) -> Dict[str, Any]:
        """Get settings for a specific protocol"""
        return self.get_setting(f'protocols.{protocol}', {})

    def add_connection(self, connection: Dict[str, Any]) -> bool:
        """Add a new connection"""
        # Validate required fields
        required_fields = ['name', 'protocol', 'host']
        if not all(field in connection for field in required_fields):
            return False

        # Check if name already exists
        if any(conn['name'] == connection['name'] for conn in self.connections):
            return False

        # Add timestamp
        import time
        connection['created'] = int(time.time())
        connection['last_used'] = None

        self.connections.append(connection)
        self.save_connections(self.connections)
        return True

    def update_connection(self, name: str, connection: Dict[str, Any]) -> bool:
        """Update an existing connection"""
        for i, conn in enumerate(self.connections):
            if conn['name'] == name:
                # Preserve timestamps
                connection['created'] = conn.get('created')
                self.connections[i] = connection
                self.save_connections(self.connections)
                return True
        return False

    def remove_connection(self, name: str) -> bool:
        """Remove a connection"""
        for i, conn in enumerate(self.connections):
            if conn['name'] == name:
                del self.connections[i]
                self.save_connections(self.connections)
                return True
        return False

    def get_connection(self, name: str) -> Dict[str, Any]:
        """Get a connection by name"""
        for conn in self.connections:
            if conn['name'] == name:
                return conn.copy()
        return {}

    def update_last_used(self, name: str):
        """Update last used timestamp for a connection"""
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

    def _merge_config(self, default: Dict, loaded: Dict) -> Dict:
        """Recursively merge loaded config with defaults"""
        result = default.copy()

        for key, value in loaded.items():
            if key in result and isinstance(result[key], dict) and isinstance(value, dict):
                result[key] = self._merge_config(result[key], value)
            else:
                result[key] = value

        return result

    def export_connections(self, file_path: str) -> bool:
        """Export connections to a file"""
        try:
            # Remove sensitive data for export
            export_data = []
            for conn in self.connections:
                export_conn = conn.copy()
                # Remove password and private key data
                export_conn.pop('password', None)
                export_conn.pop('private_key', None)
                export_conn.pop('private_key_password', None)
                export_data.append(export_conn)

            with open(file_path, 'w') as f:
                json.dump(export_data, f, indent=4)
            return True
        except IOError:
            return False

    def import_connections(self, file_path: str) -> bool:
        """Import connections from a file"""
        try:
            with open(file_path, 'r') as f:
                imported = json.load(f)

            # Validate and add connections
            added_count = 0
            for conn in imported:
                if self.add_connection(conn):
                    added_count += 1

            return added_count > 0
        except (IOError, json.JSONDecodeError):
            return False
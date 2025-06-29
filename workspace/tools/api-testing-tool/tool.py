import sys
import json
import time
import os
import uuid
import base64
import urllib.parse
from typing import Dict, Any, Optional, List
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, 
    QSplitter, QComboBox, QLineEdit, QPushButton, QTextEdit, QTabWidget,
    QTableWidget, QTableWidgetItem, QLabel, QFrame,
    QHeaderView, QMessageBox, QProgressBar, QTreeWidget, QTreeWidgetItem,
    QMenu, QFileDialog, QInputDialog, QDialog, QDialogButtonBox,
    QFormLayout, QCheckBox, QGroupBox, QListWidget, QListWidgetItem,
    QPlainTextEdit, QTextBrowser
)
from PyQt6.QtCore import Qt, QThread, pyqtSignal, QTimer, QDateTime, QUrl
from PyQt6.QtGui import QFont, QSyntaxHighlighter, QTextCharFormat, QColor, QAction, QIcon, QDesktopServices
import httpx
import re
import websocket
from datetime import datetime
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC


class JsonHighlighter(QSyntaxHighlighter):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.highlighting_rules = []
        
        # JSON syntax highlighting
        json_format = QTextCharFormat()
        json_format.setForeground(QColor(0, 128, 0))
        self.highlighting_rules.append((r'"[^"]*":', json_format))  # Keys
        
        string_format = QTextCharFormat()
        string_format.setForeground(QColor(200, 100, 0))
        self.highlighting_rules.append((r'"[^"]*"', string_format))  # Strings
        
        number_format = QTextCharFormat()
        number_format.setForeground(QColor(0, 0, 255))
        self.highlighting_rules.append((r'\b\d+\.?\d*\b', number_format))  # Numbers
        
        keyword_format = QTextCharFormat()
        keyword_format.setForeground(QColor(128, 0, 128))
        keyword_format.setFontWeight(QFont.Weight.Bold)
        self.highlighting_rules.append((r'\b(true|false|null)\b', keyword_format))

    def highlightBlock(self, text):
        for pattern, format in self.highlighting_rules:
            expression = re.compile(pattern)
            for match in expression.finditer(text):
                self.setFormat(match.start(), match.end() - match.start(), format)


class GraphQLHighlighter(QSyntaxHighlighter):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.highlighting_rules = []
        
        # GraphQL keywords
        keyword_format = QTextCharFormat()
        keyword_format.setForeground(QColor(0, 0, 255))
        keyword_format.setFontWeight(QFont.Weight.Bold)
        keywords = ['query', 'mutation', 'subscription', 'fragment', 'type', 'interface', 'union', 'enum', 'input']
        for keyword in keywords:
            self.highlighting_rules.append((rf'\b{keyword}\b', keyword_format))
        
        # Field names
        field_format = QTextCharFormat()
        field_format.setForeground(QColor(0, 128, 0))
        self.highlighting_rules.append((r'\b\w+(?=\s*:)', field_format))
        
        # String literals
        string_format = QTextCharFormat()
        string_format.setForeground(QColor(200, 100, 0))
        self.highlighting_rules.append((r'"[^"]*"', string_format))
        
        # Comments
        comment_format = QTextCharFormat()
        comment_format.setForeground(QColor(128, 128, 128))
        self.highlighting_rules.append((r'#.*', comment_format))

    def highlightBlock(self, text):
        for pattern, format in self.highlighting_rules:
            expression = re.compile(pattern)
            for match in expression.finditer(text):
                self.setFormat(match.start(), match.end() - match.start(), format)


class PythonHighlighter(QSyntaxHighlighter):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.highlighting_rules = []
        
        # Python keywords
        keyword_format = QTextCharFormat()
        keyword_format.setForeground(QColor(0, 0, 255))
        keyword_format.setFontWeight(QFont.Weight.Bold)
        keywords = ['def', 'class', 'if', 'else', 'elif', 'for', 'while', 'try', 'except', 
                   'import', 'from', 'return', 'and', 'or', 'not', 'in', 'is', 'True', 'False', 'None']
        for keyword in keywords:
            self.highlighting_rules.append((rf'\b{keyword}\b', keyword_format))
        
        # Strings
        string_format = QTextCharFormat()
        string_format.setForeground(QColor(0, 128, 0))
        self.highlighting_rules.append((r'"[^"]*"', string_format))
        self.highlighting_rules.append((r"'[^']*'", string_format))
        
        # Comments
        comment_format = QTextCharFormat()
        comment_format.setForeground(QColor(128, 128, 128))
        self.highlighting_rules.append((r'#.*', comment_format))

    def highlightBlock(self, text):
        for pattern, format in self.highlighting_rules:
            expression = re.compile(pattern)
            for match in expression.finditer(text):
                self.setFormat(match.start(), match.end() - match.start(), format)


class DataEncryption:
    def __init__(self):
        self.key = None
        self.fernet = None
        self.salt = None
        self.password = None
    
    def derive_key(self, password: str, salt: bytes = None) -> tuple:
        if salt is None:
            salt = os.urandom(16)
        
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            iterations=100000,
        )
        key = base64.urlsafe_b64encode(kdf.derive(password.encode()))
        return key, salt
    
    def set_password(self, password: str, salt: bytes = None):
        self.password = password
        self.key, self.salt = self.derive_key(password, salt)
        self.fernet = Fernet(self.key)
        return self.salt
    
    def encrypt_data(self, data: dict) -> bytes:
        if not self.fernet:
            raise ValueError("Encryption not initialized. Set password first.")
        json_data = json.dumps(data, indent=2)
        return self.fernet.encrypt(json_data.encode())
    
    def decrypt_data(self, encrypted_data: bytes) -> dict:
        if not self.fernet:
            raise ValueError("Encryption not initialized. Set password first.")
        decrypted_bytes = self.fernet.decrypt(encrypted_data)
        return json.loads(decrypted_bytes.decode())
    
    def save_encrypted_file(self, data: dict, filepath: str, salt: bytes = None):
        # Use stored salt if available, otherwise generate new one
        if salt is None:
            salt = self.salt if self.salt else os.urandom(16)
        encrypted_data = self.encrypt_data(data)
        with open(filepath, 'wb') as f:
            f.write(salt + encrypted_data)
    
    def load_encrypted_file(self, filepath: str, password: str) -> dict:
        try:
            with open(filepath, 'rb') as f:
                file_data = f.read()
            
            if len(file_data) < 16:
                return {}
            
            salt = file_data[:16]
            encrypted_data = file_data[16:]
            
            self.set_password(password, salt)
            return self.decrypt_data(encrypted_data)
        except FileNotFoundError:
            return {}
        except Exception:
            raise ValueError("Invalid password or corrupted data")


class DataManager:
    """Central data manager for handling encrypted storage"""
    def __init__(self, encryption: DataEncryption, file_path: str = None):
        self.encryption = encryption
        # Default to data/data.enc if no file path specified
        if file_path is None:
            data_dir = 'data'
            if not os.path.exists(data_dir):
                os.makedirs(data_dir)
            file_path = os.path.join(data_dir, 'data.enc')
        self.encrypted_file = file_path
    
    def set_file_path(self, file_path: str):
        """Change the data file path"""
        self.encrypted_file = file_path
    
    def load_all_data(self, password: str) -> dict:
        """Load all encrypted data"""
        if os.path.exists(self.encrypted_file):
            return self.encryption.load_encrypted_file(self.encrypted_file, password)
        return {}
    
    def save_all_data(self, data: dict):
        """Save all data to encrypted file"""
        if self.encryption.key:
            self.encryption.save_encrypted_file(data, self.encrypted_file)


class AuthConfig:
    def __init__(self):
        self.auth_type = 'None'
        self.username = ''
        self.password = ''
        self.token = ''
        self.api_key = ''
        self.api_key_header = 'X-API-Key'
        self.oauth2_client_id = ''
        self.oauth2_client_secret = ''
        self.oauth2_auth_url = ''
        self.oauth2_token_url = ''
        self.oauth2_scope = ''
        self.oauth2_access_token = ''
        self.bearer_token = ''
    
    def to_dict(self):
        return {
            'auth_type': self.auth_type,
            'username': self.username,
            'password': self.password,
            'token': self.token,
            'api_key': self.api_key,
            'api_key_header': self.api_key_header,
            'oauth2_client_id': self.oauth2_client_id,
            'oauth2_client_secret': self.oauth2_client_secret,
            'oauth2_auth_url': self.oauth2_auth_url,
            'oauth2_token_url': self.oauth2_token_url,
            'oauth2_scope': self.oauth2_scope,
            'oauth2_access_token': self.oauth2_access_token,
            'bearer_token': self.bearer_token
        }
    
    @classmethod
    def from_dict(cls, data):
        auth = cls()
        for key, value in data.items():
            if hasattr(auth, key):
                setattr(auth, key, value)
        return auth
    
    def apply_to_headers(self, headers):
        """Apply authentication to request headers"""
        if self.auth_type == 'Basic Auth':
            credentials = base64.b64encode(f"{self.username}:{self.password}".encode()).decode()
            headers['Authorization'] = f'Basic {credentials}'
        elif self.auth_type == 'Bearer Token':
            headers['Authorization'] = f'Bearer {self.bearer_token}'
        elif self.auth_type == 'API Key':
            headers[self.api_key_header] = self.api_key
        elif self.auth_type == 'OAuth 2.0' and self.oauth2_access_token:
            headers['Authorization'] = f'Bearer {self.oauth2_access_token}'


class WebSocketTester:
    def __init__(self):
        self.socket = None
        self.connected = False
        self.messages = []
    
    def connect(self, url, headers=None):
        try:
            self.socket = websocket.WebSocket()
            if headers:
                self.socket.connect(url, header=headers)
            else:
                self.socket.connect(url)
            self.connected = True
            return True, "Connected successfully"
        except Exception as e:
            self.connected = False
            return False, str(e)
    
    def send_message(self, message):
        if not self.connected or not self.socket:
            return False, "Not connected"
        
        try:
            self.socket.send(message)
            return True, "Message sent"
        except Exception as e:
            return False, str(e)
    
    def receive_message(self, timeout=5):
        if not self.connected or not self.socket:
            return None, "Not connected"
        
        try:
            self.socket.settimeout(timeout)
            message = self.socket.recv()
            self.messages.append({
                'timestamp': datetime.now().isoformat(),
                'type': 'received',
                'message': message
            })
            return message, None
        except Exception as e:
            return None, str(e)
    
    def disconnect(self):
        if self.socket:
            self.socket.close()
            self.connected = False


class SSLManager:
    @staticmethod
    def verify_certificate(url):
        """Verify SSL certificate for a URL"""
        try:
            import ssl
            import socket
            from urllib.parse import urlparse
            
            parsed = urlparse(url)
            hostname = parsed.hostname
            port = parsed.port or (443 if parsed.scheme == 'https' else 80)
            
            context = ssl.create_default_context()
            
            with socket.create_connection((hostname, port), timeout=10) as sock:
                with context.wrap_socket(sock, server_hostname=hostname) as ssock:
                    cert = ssock.getpeercert()
                    return True, cert
                    
        except Exception as e:
            return False, str(e)
    
    @staticmethod
    def get_ssl_info(url):
        """Get SSL certificate information"""
        success, result = SSLManager.verify_certificate(url)
        
        if success:
            cert = result
            info = {
                'subject': dict(x[0] for x in cert['subject']),
                'issuer': dict(x[0] for x in cert['issuer']),
                'version': cert['version'],
                'serialNumber': cert['serialNumber'],
                'notBefore': cert['notBefore'],
                'notAfter': cert['notAfter'],
                'subjectAltName': cert.get('subjectAltName', [])
            }
            return info
        else:
            return {'error': result}


class PluginManager:
    def __init__(self):
        self.plugins = {}
        self.plugin_dir = 'plugins'
        self.load_plugins()
    
    def load_plugins(self):
        """Load plugins from the plugins directory"""
        if not os.path.exists(self.plugin_dir):
            os.makedirs(self.plugin_dir)
            return
        
        for filename in os.listdir(self.plugin_dir):
            if filename.endswith('.py') and not filename.startswith('_'):
                try:
                    plugin_name = filename[:-3]
                    # Simple plugin loading - in real implementation, use proper module loading
                    self.plugins[plugin_name] = {
                        'name': plugin_name,
                        'path': os.path.join(self.plugin_dir, filename),
                        'loaded': False
                    }
                except Exception as e:
                    print(f"Error loading plugin {filename}: {e}")
    
    def get_available_plugins(self):
        return list(self.plugins.keys())
    
    def execute_plugin(self, plugin_name, request_data, response_data):
        """Execute a plugin with request/response data"""
        if plugin_name not in self.plugins:
            return None, "Plugin not found"
        
        try:
            # Simple plugin execution - in real implementation, use proper sandboxing
            plugin_path = self.plugins[plugin_name]['path']
            with open(plugin_path, 'r') as f:
                plugin_code = f.read()
            
            # Create execution context
            context = {
                'request_data': request_data,
                'response_data': response_data,
                'result': None
            }
            
            exec(plugin_code, context)
            return context.get('result'), None
            
        except Exception as e:
            return None, str(e)


class RequestHistory:
    def __init__(self, data_manager=None):
        self.history = []
        self.data_manager = data_manager
        self.legacy_file = 'request_history.json'
    
    def load_history(self, all_data=None):
        try:
            if all_data and 'history' in all_data:
                self.history = all_data['history']
                return True
            
            # Fallback to legacy file
            if os.path.exists(self.legacy_file):
                with open(self.legacy_file, 'r') as f:
                    self.history = json.load(f)
                    return True
                    
        except Exception as e:
            print(f"Error loading history: {e}")
            
        return True  # Return True even if no data found (empty start)
    
    def get_data(self):
        """Get history data for saving"""
        return self.history
    
    def add_request(self, method, url, headers, params, body, response_data):
        entry = {
            'id': str(uuid.uuid4()),
            'timestamp': datetime.now().isoformat(),
            'method': method,
            'url': url,
            'headers': headers,
            'params': params,
            'body': body,
            'status_code': response_data.get('status_code'),
            'response_time': response_data.get('response_time'),
            'response_size': response_data.get('size')
        }
        
        self.history.insert(0, entry)  # Add to beginning
        
        # Keep only last 100 requests
        if len(self.history) > 100:
            self.history = self.history[:100]
        
        # Note: History will be saved through main app's save_all_data
    
    def clear_history(self):
        self.history = []
        # Note: History will be saved through main app's save_all_data


class CodeGenerator:
    @staticmethod
    def generate_curl(method, url, headers, params, body, auth_config=None):
        cmd = ['curl', '-X', method]
        
        # Add headers
        for key, value in headers.items():
            cmd.extend(['-H', f'{key}: {value}'])
        
        # Add authentication
        if auth_config:
            if auth_config.auth_type == 'Basic Auth':
                cmd.extend(['-u', f'{auth_config.username}:{auth_config.password}'])
            elif auth_config.auth_type == 'Bearer Token':
                cmd.extend(['-H', f'Authorization: Bearer {auth_config.bearer_token}'])
            elif auth_config.auth_type == 'API Key':
                cmd.extend(['-H', f'{auth_config.api_key_header}: {auth_config.api_key}'])
        
        # Add URL with params
        if params:
            param_str = '&'.join([f'{k}={v}' for k, v in params.items()])
            url = f'{url}?{param_str}'
        cmd.append(f"'{url}'")
        
        # Add body
        if body and method.upper() in ['POST', 'PUT', 'PATCH']:
            cmd.extend(['-d', f"'{body}'"])
        
        return ' '.join(cmd)
    
    @staticmethod
    def generate_python_requests(method, url, headers, params, body, auth_config=None):
        code = "import requests\n\n"
        
        # URL
        code += f'url = "{url}"\n\n'
        
        # Headers
        if headers:
            code += "headers = {\n"
            for key, value in headers.items():
                code += f'    "{key}": "{value}",\n'
            code += "}\n\n"
        else:
            code += "headers = {}\n\n"
        
        # Authentication
        auth_code = ""
        if auth_config:
            if auth_config.auth_type == 'Basic Auth':
                code += f'auth = ("{auth_config.username}", "{auth_config.password}")\n\n'
                auth_code = ", auth=auth"
            elif auth_config.auth_type == 'Bearer Token':
                code += f'headers["Authorization"] = "Bearer {auth_config.bearer_token}"\n\n'
            elif auth_config.auth_type == 'API Key':
                code += f'headers["{auth_config.api_key_header}"] = "{auth_config.api_key}"\n\n'
        
        # Params
        if params:
            code += "params = {\n"
            for key, value in params.items():
                code += f'    "{key}": "{value}",\n'
            code += "}\n\n"
        else:
            code += "params = {}\n\n"
        
        # Body
        if body and method.upper() in ['POST', 'PUT', 'PATCH']:
            try:
                # Try to parse as JSON
                json.loads(body)
                code += f'data = {body}\n\n'
                code += f'response = requests.{method.lower()}(url, headers=headers, params=params, json=data{auth_code})\n'
            except json.JSONDecodeError:
                code += f'data = """{body}"""\n\n'
                code += f'response = requests.{method.lower()}(url, headers=headers, params=params, data=data{auth_code})\n'
        else:
            code += f'response = requests.{method.lower()}(url, headers=headers, params=params{auth_code})\n'
        
        code += '\nprint(f"Status Code: {response.status_code}")\n'
        code += 'print(f"Response: {response.text}")\n'
        
        return code
    
    @staticmethod
    def generate_javascript_fetch(method, url, headers, params, body, auth_config=None):
        code = "// JavaScript Fetch\n\n"
        
        # URL with params
        if params:
            param_str = '&'.join([f'{k}={v}' for k, v in params.items()])
            url = f'{url}?{param_str}'
        
        code += f'const url = "{url}";\n\n'
        
        # Options
        code += "const options = {\n"
        code += f'    method: "{method}",\n'
        
        # Headers with auth
        if headers or auth_config:
            code += "    headers: {\n"
            for key, value in headers.items():
                code += f'        "{key}": "{value}",\n'
            
            if auth_config:
                if auth_config.auth_type == 'Bearer Token':
                    code += f'        "Authorization": "Bearer {auth_config.bearer_token}",\n'
                elif auth_config.auth_type == 'API Key':
                    code += f'        "{auth_config.api_key_header}": "{auth_config.api_key}",\n'
                elif auth_config.auth_type == 'Basic Auth':
                    credentials = base64.b64encode(f"{auth_config.username}:{auth_config.password}".encode()).decode()
                    code += f'        "Authorization": "Basic {credentials}",\n'
            
            code += "    },\n"
        
        if body and method.upper() in ['POST', 'PUT', 'PATCH']:
            try:
                json.loads(body)
                code += f'    body: JSON.stringify({body})\n'
            except json.JSONDecodeError:
                code += f'    body: `{body}`\n'
        
        code += "};\n\n"
        code += "fetch(url, options)\n"
        code += "    .then(response => response.json())\n"
        code += "    .then(data => console.log(data))\n"
        code += "    .catch(error => console.error('Error:', error));"
        
        return code


class TestAssertion:
    def __init__(self, name: str, script: str, enabled: bool = True):
        self.name = name
        self.script = script
        self.enabled = enabled
        self.result = None
        self.error = None
    
    def run(self, response_data):
        if not self.enabled:
            return True
        
        try:
            # Create a safe execution environment
            context = {
                'response': response_data,
                'status_code': response_data.get('status_code'),
                'headers': response_data.get('headers', {}),
                'body': response_data.get('body', ''),
                'response_time': response_data.get('response_time', 0),
                'size': response_data.get('size', 0)
            }
            
            # Try to parse body as JSON
            try:
                context['json'] = json.loads(response_data.get('body', '{}'))
            except:
                context['json'] = {}
            
            # Execute the test script
            exec(self.script, {"__builtins__": {}}, context)
            
            self.result = True
            self.error = None
            return True
            
        except Exception as e:
            self.result = False
            self.error = str(e)
            return False


class EnvironmentManager:
    def __init__(self, data_manager=None):
        self.environments = {}
        self.current_environment = None
        self.global_variables = {}
        self.data_manager = data_manager
        self.legacy_file = 'environments.json'
    
    def load_environments(self, all_data=None):
        try:
            if all_data and 'environments' in all_data:
                env_data = all_data['environments']
                self.environments = env_data.get('environments', {})
                self.global_variables = env_data.get('global_variables', {})
                self.current_environment = env_data.get('current_environment', None)
                return True
            
            # Fallback to legacy file
            if os.path.exists(self.legacy_file):
                with open(self.legacy_file, 'r') as f:
                    data = json.load(f)
                    self.environments = data.get('environments', {})
                    self.global_variables = data.get('global_variables', {})
                    self.current_environment = data.get('current_environment', None)
                    return True
                    
        except Exception as e:
            print(f"Error loading environments: {e}")
            
        return True  # Return True even if no data found (empty start)
    
    def get_data(self):
        """Get environment data for saving"""
        return {
            'environments': self.environments,
            'global_variables': self.global_variables,
            'current_environment': self.current_environment
        }
    
    def create_environment(self, name: str):
        self.environments[name] = {}
        # Note: Data will be saved through main app's save_all_data
    
    def delete_environment(self, name: str):
        if name in self.environments:
            del self.environments[name]
            if self.current_environment == name:
                self.current_environment = None
            # Note: Data will be saved through main app's save_all_data
    
    def set_current_environment(self, name: str):
        if name in self.environments or name is None:
            self.current_environment = name
            # Note: Data will be saved through main app's save_all_data
    
    def get_variable(self, key: str) -> Optional[str]:
        # Check current environment first, then global
        if self.current_environment and key in self.environments.get(self.current_environment, {}):
            return self.environments[self.current_environment][key]
        return self.global_variables.get(key)
    
    def set_variable(self, key: str, value: str, is_global: bool = False):
        if is_global:
            self.global_variables[key] = value
        elif self.current_environment:
            self.environments[self.current_environment][key] = value
        # Note: Data will be saved through main app's save_all_data
    
    def substitute_variables(self, text: str) -> str:
        """Replace {{variable}} patterns with actual values"""
        pattern = r'\{\{([^}]+)\}\}'
        
        def replace_var(match):
            var_name = match.group(1).strip()
            value = self.get_variable(var_name)
            return value if value is not None else match.group(0)
        
        return re.sub(pattern, replace_var, text)


class Collection:
    def __init__(self, name: str):
        self.id = str(uuid.uuid4())
        self.name = name
        self.requests = []
        self.folders = []
        self.auth = AuthConfig()
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'requests': [req.to_dict() for req in self.requests],
            'folders': [folder.to_dict() for folder in self.folders],
            'auth': self.auth.to_dict()
        }
    
    @classmethod
    def from_dict(cls, data):
        collection = cls(data['name'])
        collection.id = data.get('id', str(uuid.uuid4()))
        collection.requests = [RequestItem.from_dict(req) for req in data.get('requests', [])]
        collection.folders = [Folder.from_dict(folder) for folder in data.get('folders', [])]
        if 'auth' in data:
            collection.auth = AuthConfig.from_dict(data['auth'])
        return collection


class Folder:
    def __init__(self, name: str):
        self.id = str(uuid.uuid4())
        self.name = name
        self.requests = []
        self.auth = AuthConfig()
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'requests': [req.to_dict() for req in self.requests],
            'auth': self.auth.to_dict()
        }
    
    @classmethod
    def from_dict(cls, data):
        folder = cls(data['name'])
        folder.id = data.get('id', str(uuid.uuid4()))
        folder.requests = [RequestItem.from_dict(req) for req in data.get('requests', [])]
        if 'auth' in data:
            folder.auth = AuthConfig.from_dict(data['auth'])
        return folder


class RequestItem:
    def __init__(self, name: str, method: str = 'GET', url: str = ''):
        self.id = str(uuid.uuid4())
        self.name = name
        self.method = method
        self.url = url
        self.headers = {}
        self.params = {}
        self.body = ''
        self.body_type = 'None'
        self.pre_request_script = ''
        self.tests = []
        self.auth = AuthConfig()
        self.request_type = 'HTTP'  # HTTP, GraphQL, WebSocket
        self.graphql_query = ''
        self.graphql_variables = '{}'
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'method': self.method,
            'url': self.url,
            'headers': self.headers,
            'params': self.params,
            'body': self.body,
            'body_type': self.body_type,
            'pre_request_script': self.pre_request_script,
            'tests': [{'name': t.name, 'script': t.script, 'enabled': t.enabled} for t in self.tests],
            'auth': self.auth.to_dict(),
            'request_type': self.request_type,
            'graphql_query': self.graphql_query,
            'graphql_variables': self.graphql_variables
        }
    
    @classmethod
    def from_dict(cls, data):
        request = cls(data['name'], data.get('method', 'GET'), data.get('url', ''))
        request.id = data.get('id', str(uuid.uuid4()))
        request.headers = data.get('headers', {})
        request.params = data.get('params', {})
        request.body = data.get('body', '')
        request.body_type = data.get('body_type', 'None')
        request.pre_request_script = data.get('pre_request_script', '')
        request.request_type = data.get('request_type', 'HTTP')
        request.graphql_query = data.get('graphql_query', '')
        request.graphql_variables = data.get('graphql_variables', '{}')
        
        # Load tests
        request.tests = []
        for test_data in data.get('tests', []):
            test = TestAssertion(test_data['name'], test_data['script'], test_data.get('enabled', True))
            request.tests.append(test)
        
        # Load auth
        if 'auth' in data:
            request.auth = AuthConfig.from_dict(data['auth'])
        
        return request


class CollectionManager:
    def __init__(self, data_manager=None):
        self.collections = []
        self.data_manager = data_manager
        self.legacy_file = 'collections.json'
    
    def load_collections(self, all_data=None):
        try:
            if all_data and 'collections' in all_data:
                collections_data = all_data['collections']
                self.collections = [Collection.from_dict(col) for col in collections_data.get('collections', [])]
                return True
            
            # Fallback to legacy file
            if os.path.exists(self.legacy_file):
                with open(self.legacy_file, 'r') as f:
                    data = json.load(f)
                    self.collections = [Collection.from_dict(col) for col in data.get('collections', [])]
                    return True
                    
        except Exception as e:
            print(f"Error loading collections: {e}")
            
        return True  # Return True even if no data found (empty start)
    
    def get_data(self):
        """Get collections data for saving"""
        return {
            'collections': [col.to_dict() for col in self.collections]
        }
    
    def export_collections(self):
        """Export collections to plain JSON format"""
        return {
            'collections': [col.to_dict() for col in self.collections]
        }
    
    def create_collection(self, name: str) -> Collection:
        collection = Collection(name)
        self.collections.append(collection)
        # Note: Data will be saved through main app's save_all_data
        return collection
    
    def delete_collection(self, collection_id: str):
        self.collections = [col for col in self.collections if col.id != collection_id]
        # Note: Data will be saved through main app's save_all_data
    
    def export_collection(self, collection_id: str, file_path: str):
        collection = next((col for col in self.collections if col.id == collection_id), None)
        if collection:
            with open(file_path, 'w') as f:
                json.dump(collection.to_dict(), f, indent=2)


class AuthWidget(QWidget):
    def __init__(self):
        super().__init__()
        self.auth_config = AuthConfig()
        self.init_ui()
    
    def init_ui(self):
        layout = QVBoxLayout()
        
        # Auth type selector
        auth_type_layout = QHBoxLayout()
        auth_type_layout.addWidget(QLabel('Authentication Type:'))
        
        self.auth_type_combo = QComboBox()
        self.auth_type_combo.addItems(['None', 'Basic Auth', 'Bearer Token', 'API Key', 'OAuth 2.0'])
        self.auth_type_combo.currentTextChanged.connect(self.on_auth_type_changed)
        auth_type_layout.addWidget(self.auth_type_combo)
        auth_type_layout.addStretch()
        
        layout.addLayout(auth_type_layout)
        
        # Auth configuration stack
        self.auth_stack = QTabWidget()
        self.auth_stack.setTabPosition(QTabWidget.TabPosition.West)
        
        # Basic Auth
        basic_widget = QWidget()
        basic_layout = QFormLayout()
        self.username_input = QLineEdit()
        self.username_input.setPlaceholderText('Enter username')
        self.password_input = QLineEdit()
        self.password_input.setEchoMode(QLineEdit.EchoMode.Password)
        self.password_input.setPlaceholderText('Enter password')
        basic_layout.addRow('Username:', self.username_input)
        basic_layout.addRow('Password:', self.password_input)
        basic_widget.setLayout(basic_layout)
        self.auth_stack.addTab(basic_widget, 'Basic')
        
        # Bearer Token
        bearer_widget = QWidget()
        bearer_layout = QFormLayout()
        self.bearer_token_input = QLineEdit()
        self.bearer_token_input.setPlaceholderText('Enter bearer token (e.g., your-jwt-token)')
        bearer_layout.addRow('Token:', self.bearer_token_input)
        bearer_widget.setLayout(bearer_layout)
        self.auth_stack.addTab(bearer_widget, 'Bearer')
        
        # API Key
        api_key_widget = QWidget()
        api_key_layout = QFormLayout()
        self.api_key_input = QLineEdit()
        self.api_key_input.setPlaceholderText('Enter your API key')
        self.api_key_header_input = QLineEdit()
        self.api_key_header_input.setText('X-API-Key')
        self.api_key_header_input.setPlaceholderText('Header name (e.g., X-API-Key)')
        api_key_layout.addRow('Key:', self.api_key_input)
        api_key_layout.addRow('Header:', self.api_key_header_input)
        api_key_widget.setLayout(api_key_layout)
        self.auth_stack.addTab(api_key_widget, 'API Key')
        
        # OAuth 2.0
        oauth_widget = QWidget()
        oauth_layout = QFormLayout()
        self.oauth_client_id_input = QLineEdit()
        self.oauth_client_id_input.setPlaceholderText('Your OAuth client ID')
        self.oauth_client_secret_input = QLineEdit()
        self.oauth_client_secret_input.setEchoMode(QLineEdit.EchoMode.Password)
        self.oauth_client_secret_input.setPlaceholderText('Your OAuth client secret')
        self.oauth_auth_url_input = QLineEdit()
        self.oauth_auth_url_input.setPlaceholderText('https://example.com/oauth/authorize')
        self.oauth_token_url_input = QLineEdit()
        self.oauth_token_url_input.setPlaceholderText('https://example.com/oauth/token')
        self.oauth_scope_input = QLineEdit()
        self.oauth_scope_input.setPlaceholderText('read write (space-separated)')
        self.oauth_access_token_input = QLineEdit()
        self.oauth_access_token_input.setPlaceholderText('Access token will appear here')
        self.oauth_access_token_input.setReadOnly(True)
        
        oauth_layout.addRow('Client ID:', self.oauth_client_id_input)
        oauth_layout.addRow('Client Secret:', self.oauth_client_secret_input)
        oauth_layout.addRow('Auth URL:', self.oauth_auth_url_input)
        oauth_layout.addRow('Token URL:', self.oauth_token_url_input)
        oauth_layout.addRow('Scope:', self.oauth_scope_input)
        oauth_layout.addRow('Access Token:', self.oauth_access_token_input)
        
        oauth_btn_layout = QHBoxLayout()
        get_token_btn = QPushButton('Get Access Token')
        get_token_btn.clicked.connect(self.get_oauth_token)
        oauth_btn_layout.addWidget(get_token_btn)
        oauth_btn_layout.addStretch()
        
        oauth_layout.addRow('', oauth_btn_layout)
        oauth_widget.setLayout(oauth_layout)
        self.auth_stack.addTab(oauth_widget, 'OAuth 2.0')
        
        layout.addWidget(self.auth_stack)
        
        # Inherit from parent checkbox
        self.inherit_checkbox = QCheckBox('Inherit authentication from parent')
        layout.addWidget(self.inherit_checkbox)
        
        # Add a help text widget for when no auth is selected
        self.no_auth_widget = QWidget()
        no_auth_layout = QVBoxLayout()
        
        help_label = QLabel("🔒 No Authentication Selected")
        help_label.setStyleSheet("font-size: 16px; font-weight: bold; color: #666; margin: 20px;")
        help_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        no_auth_layout.addWidget(help_label)
        
        help_text = QLabel(
            "Select an authentication type above to configure credentials.\n\n"
            "Available options:\n"
            "• Basic Auth - Username and password\n"
            "• Bearer Token - Authorization header token\n"
            "• API Key - Custom header with key\n"
            "• OAuth 2.0 - OAuth flow with client credentials"
        )
        help_text.setStyleSheet("color: #888; line-height: 1.4;")
        help_text.setAlignment(Qt.AlignmentFlag.AlignCenter)
        help_text.setWordWrap(True)
        no_auth_layout.addWidget(help_text)
        
        no_auth_layout.addStretch()
        self.no_auth_widget.setLayout(no_auth_layout)
        
        # Add the no-auth widget as the first tab
        self.auth_stack.insertTab(0, self.no_auth_widget, 'None')
        
        self.setLayout(layout)
        # Always show the auth stack, but default to "None" tab
        self.auth_stack.setVisible(True)
        self.auth_stack.setCurrentIndex(0)
    
    def on_auth_type_changed(self, auth_type):
        self.auth_config.auth_type = auth_type
        
        # Map auth types to tab indices (now with None as tab 0)
        if auth_type == 'None':
            self.auth_stack.setCurrentIndex(0)
        elif auth_type == 'Basic Auth':
            self.auth_stack.setCurrentIndex(1)
        elif auth_type == 'Bearer Token':
            self.auth_stack.setCurrentIndex(2)
        elif auth_type == 'API Key':
            self.auth_stack.setCurrentIndex(3)
        elif auth_type == 'OAuth 2.0':
            self.auth_stack.setCurrentIndex(4)
    
    def get_oauth_token(self):
        """Open browser for OAuth 2.0 authorization"""
        client_id = self.oauth_client_id_input.text().strip()
        auth_url = self.oauth_auth_url_input.text().strip()
        scope = self.oauth_scope_input.text().strip()
        
        if not client_id or not auth_url:
            QMessageBox.warning(self, 'Warning', 'Client ID and Auth URL are required')
            return
        
        # Construct authorization URL
        params = {
            'client_id': client_id,
            'response_type': 'code',
            'redirect_uri': 'http://localhost:8080/callback',
            'scope': scope
        }
        
        auth_url_with_params = f"{auth_url}?{urllib.parse.urlencode(params)}"
        
        # Open in browser
        QDesktopServices.openUrl(QUrl(auth_url_with_params))
        
        # Show instructions
        QMessageBox.information(self, 'OAuth 2.0', 
                              'Browser opened for authorization. Copy the authorization code and exchange it for an access token.')
    
    def get_auth_config(self) -> AuthConfig:
        # Update config from UI
        self.auth_config.username = self.username_input.text()
        self.auth_config.password = self.password_input.text()
        self.auth_config.bearer_token = self.bearer_token_input.text()
        self.auth_config.api_key = self.api_key_input.text()
        self.auth_config.api_key_header = self.api_key_header_input.text()
        self.auth_config.oauth2_client_id = self.oauth_client_id_input.text()
        self.auth_config.oauth2_client_secret = self.oauth_client_secret_input.text()
        self.auth_config.oauth2_auth_url = self.oauth_auth_url_input.text()
        self.auth_config.oauth2_token_url = self.oauth_token_url_input.text()
        self.auth_config.oauth2_scope = self.oauth_scope_input.text()
        self.auth_config.oauth2_access_token = self.oauth_access_token_input.text()
        
        return self.auth_config
    
    def set_auth_config(self, auth_config: AuthConfig):
        self.auth_config = auth_config
        
        # Update UI
        self.auth_type_combo.setCurrentText(auth_config.auth_type)
        self.username_input.setText(auth_config.username)
        self.password_input.setText(auth_config.password)
        self.bearer_token_input.setText(auth_config.bearer_token)
        self.api_key_input.setText(auth_config.api_key)
        self.api_key_header_input.setText(auth_config.api_key_header)
        self.oauth_client_id_input.setText(auth_config.oauth2_client_id)
        self.oauth_client_secret_input.setText(auth_config.oauth2_client_secret)
        self.oauth_auth_url_input.setText(auth_config.oauth2_auth_url)
        self.oauth_token_url_input.setText(auth_config.oauth2_token_url)
        self.oauth_scope_input.setText(auth_config.oauth2_scope)
        self.oauth_access_token_input.setText(auth_config.oauth2_access_token)


class GraphQLWidget(QWidget):
    def __init__(self):
        super().__init__()
        self.init_ui()
    
    def init_ui(self):
        layout = QVBoxLayout()
        
        # Query editor
        query_label = QLabel('GraphQL Query:')
        layout.addWidget(query_label)
        
        self.query_editor = QPlainTextEdit()
        self.query_editor.setFont(QFont('Consolas', 10))
        self.query_highlighter = GraphQLHighlighter(self.query_editor.document())
        
        # Default query
        default_query = """query GetUser($id: ID!) {
  user(id: $id) {
    id
    name
    email
    posts {
      id
      title
      content
    }
  }
}"""
        self.query_editor.setPlainText(default_query)
        layout.addWidget(self.query_editor)
        
        # Variables editor
        variables_label = QLabel('Variables (JSON):')
        layout.addWidget(variables_label)
        
        self.variables_editor = QTextEdit()
        self.variables_editor.setFont(QFont('Consolas', 10))
        self.variables_editor.setMaximumHeight(150)
        self.variables_editor.setPlainText('{\n  "id": "1"\n}')
        layout.addWidget(self.variables_editor)
        
        self.setLayout(layout)
    
    def get_query(self) -> str:
        return self.query_editor.toPlainText()
    
    def set_query(self, query: str):
        self.query_editor.setPlainText(query)
    
    def get_variables(self) -> str:
        return self.variables_editor.toPlainText()
    
    def set_variables(self, variables: str):
        self.variables_editor.setPlainText(variables)


class WebSocketWidget(QWidget):
    def __init__(self):
        super().__init__()
        self.ws_tester = WebSocketTester()
        self.init_ui()
    
    def init_ui(self):
        layout = QVBoxLayout()
        
        # Connection controls
        conn_layout = QHBoxLayout()
        
        self.ws_url_input = QLineEdit()
        self.ws_url_input.setPlaceholderText('wss://echo.websocket.org')
        conn_layout.addWidget(QLabel('URL:'))
        conn_layout.addWidget(self.ws_url_input)
        
        self.connect_btn = QPushButton('Connect')
        self.connect_btn.clicked.connect(self.toggle_connection)
        conn_layout.addWidget(self.connect_btn)
        
        self.status_label = QLabel('Disconnected')
        conn_layout.addWidget(self.status_label)
        
        layout.addLayout(conn_layout)
        
        # Message input
        msg_layout = QHBoxLayout()
        
        self.message_input = QLineEdit()
        self.message_input.setPlaceholderText('Enter message to send...')
        msg_layout.addWidget(self.message_input)
        
        self.send_btn = QPushButton('Send')
        self.send_btn.clicked.connect(self.send_message)
        self.send_btn.setEnabled(False)
        msg_layout.addWidget(self.send_btn)
        
        layout.addLayout(msg_layout)
        
        # Messages log
        layout.addWidget(QLabel('Messages:'))
        self.messages_log = QTextBrowser()
        self.messages_log.setFont(QFont('Consolas', 9))
        layout.addWidget(self.messages_log)
        
        # Controls
        controls_layout = QHBoxLayout()
        
        clear_btn = QPushButton('Clear Log')
        clear_btn.clicked.connect(self.clear_log)
        controls_layout.addWidget(clear_btn)
        
        listen_btn = QPushButton('Listen for Messages')
        listen_btn.clicked.connect(self.listen_for_messages)
        controls_layout.addWidget(listen_btn)
        
        controls_layout.addStretch()
        layout.addLayout(controls_layout)
        
        self.setLayout(layout)
    
    def toggle_connection(self):
        if self.ws_tester.connected:
            self.disconnect_websocket()
        else:
            self.connect_websocket()
    
    def connect_websocket(self):
        url = self.ws_url_input.text().strip()
        if not url:
            QMessageBox.warning(self, 'Warning', 'Please enter a WebSocket URL')
            return
        
        success, message = self.ws_tester.connect(url)
        
        if success:
            self.status_label.setText('Connected')
            self.status_label.setStyleSheet('color: green')
            self.connect_btn.setText('Disconnect')
            self.send_btn.setEnabled(True)
            self.log_message('system', f'Connected to {url}')
        else:
            self.status_label.setText('Connection Failed')
            self.status_label.setStyleSheet('color: red')
            self.log_message('error', f'Connection failed: {message}')
    
    def disconnect_websocket(self):
        self.ws_tester.disconnect()
        self.status_label.setText('Disconnected')
        self.status_label.setStyleSheet('color: gray')
        self.connect_btn.setText('Connect')
        self.send_btn.setEnabled(False)
        self.log_message('system', 'Disconnected')
    
    def send_message(self):
        message = self.message_input.text().strip()
        if not message:
            return
        
        success, result = self.ws_tester.send_message(message)
        
        if success:
            self.log_message('sent', message)
            self.message_input.clear()
        else:
            self.log_message('error', f'Send failed: {result}')
    
    def listen_for_messages(self):
        if not self.ws_tester.connected:
            return
        
        message, error = self.ws_tester.receive_message()
        
        if message:
            self.log_message('received', message)
        elif error:
            self.log_message('error', f'Receive error: {error}')
    
    def log_message(self, msg_type, message):
        timestamp = datetime.now().strftime('%H:%M:%S')
        
        if msg_type == 'sent':
            color = 'blue'
            prefix = '→'
        elif msg_type == 'received':
            color = 'green'
            prefix = '←'
        elif msg_type == 'system':
            color = 'gray'
            prefix = '•'
        else:  # error
            color = 'red'
            prefix = '✗'
        
        formatted_message = f'<span style="color: {color};">[{timestamp}] {prefix} {message}</span><br>'
        self.messages_log.append(formatted_message)
    
    def clear_log(self):
        self.messages_log.clear()


class HistoryWidget(QWidget):
    history_selected = pyqtSignal(dict)
    
    def __init__(self, history: RequestHistory):
        super().__init__()
        self.history = history
        self.init_ui()
        self.refresh_history()
    
    def init_ui(self):
        layout = QVBoxLayout()
        layout.setContentsMargins(5, 5, 5, 5)
        
        # Header
        header_layout = QHBoxLayout()
        header_label = QLabel('History')
        header_label.setStyleSheet("font-weight: bold; font-size: 11px;")
        header_layout.addWidget(header_label)
        
        clear_btn = QPushButton('×')
        clear_btn.setFixedSize(20, 20)
        clear_btn.clicked.connect(self.clear_history)
        header_layout.addWidget(clear_btn)
        
        layout.addLayout(header_layout)
        
        # History list
        self.history_list = QListWidget()
        self.history_list.itemDoubleClicked.connect(self.on_item_selected)
        layout.addWidget(self.history_list)
        
        self.setLayout(layout)
    
    def refresh_history(self):
        self.history_list.clear()
        for entry in self.history.history[:20]:  # Show only last 20
            timestamp = datetime.fromisoformat(entry['timestamp']).strftime('%H:%M')
            status = entry.get('status_code', '?')
            method = entry['method']
            
            # Truncate URL
            url = entry['url']
            if len(url) > 25:
                url = url[:25] + '...'
            
            item_text = f"{timestamp} {method} ({status})"
            
            item = QListWidgetItem(item_text)
            item.setData(Qt.ItemDataRole.UserRole, entry)
            item.setToolTip(entry['url'])
            self.history_list.addItem(item)
    
    def on_item_selected(self, item):
        entry = item.data(Qt.ItemDataRole.UserRole)
        self.history_selected.emit(entry)
    
    def clear_history(self):
        reply = QMessageBox.question(self, 'Clear History', 'Clear all request history?')
        if reply == QMessageBox.StandardButton.Yes:
            self.history.clear_history()
            self.refresh_history()


class CodeGeneratorWidget(QWidget):
    def __init__(self):
        super().__init__()
        self.auth_config = None
        self.init_ui()
    
    def init_ui(self):
        layout = QVBoxLayout()
        
        # Language selector
        lang_layout = QHBoxLayout()
        lang_layout.addWidget(QLabel('Language:'))
        
        self.lang_combo = QComboBox()
        self.lang_combo.addItems(['cURL', 'Python Requests', 'JavaScript Fetch'])
        self.lang_combo.currentTextChanged.connect(self.generate_code)
        lang_layout.addWidget(self.lang_combo)
        
        copy_btn = QPushButton('Copy')
        copy_btn.clicked.connect(self.copy_code)
        lang_layout.addWidget(copy_btn)
        
        layout.addLayout(lang_layout)
        
        # Code display
        self.code_display = QTextEdit()
        self.code_display.setFont(QFont('Consolas', 10))
        self.code_display.setReadOnly(True)
        layout.addWidget(self.code_display)
        
        self.setLayout(layout)
        
        # Store request data
        self.method = 'GET'
        self.url = ''
        self.headers = {}
        self.params = {}
        self.body = ''
    
    def update_request_data(self, method, url, headers, params, body, auth_config=None):
        self.method = method
        self.url = url
        self.headers = headers
        self.params = params
        self.body = body
        self.auth_config = auth_config
        self.generate_code()
    
    def generate_code(self):
        if not self.url:
            self.code_display.setPlainText('No request data available')
            return
        
        lang = self.lang_combo.currentText()
        
        if lang == 'cURL':
            code = CodeGenerator.generate_curl(self.method, self.url, self.headers, self.params, self.body, self.auth_config)
        elif lang == 'Python Requests':
            code = CodeGenerator.generate_python_requests(self.method, self.url, self.headers, self.params, self.body, self.auth_config)
        elif lang == 'JavaScript Fetch':
            code = CodeGenerator.generate_javascript_fetch(self.method, self.url, self.headers, self.params, self.body, self.auth_config)
        else:
            code = 'Unsupported language'
        
        self.code_display.setPlainText(code)
    
    def copy_code(self):
        code = self.code_display.toPlainText()
        if code:
            QApplication.clipboard().setText(code)


class PreRequestScriptWidget(QWidget):
    def __init__(self, env_manager: EnvironmentManager):
        super().__init__()
        self.env_manager = env_manager
        self.init_ui()
    
    def init_ui(self):
        layout = QVBoxLayout()
        
        # Header
        header_layout = QHBoxLayout()
        header_layout.addWidget(QLabel('Pre-request Script (Python)'))
        
        test_btn = QPushButton('Test Script')
        test_btn.clicked.connect(self.test_script)
        header_layout.addWidget(test_btn)
        
        layout.addLayout(header_layout)
        
        # Script editor
        self.script_editor = QPlainTextEdit()
        self.script_editor.setFont(QFont('Consolas', 10))
        self.script_highlighter = PythonHighlighter(self.script_editor.document())
        
        # Default script template
        default_script = """# Pre-request script
# Available functions:
# - set_variable(key, value, is_global=False)
# - get_variable(key)
# - print(message) - for debugging

# Example:
# import time
# timestamp = str(int(time.time()))
# set_variable('timestamp', timestamp)
"""
        self.script_editor.setPlainText(default_script)
        layout.addWidget(self.script_editor)
        
        # Output area
        self.output_area = QTextEdit()
        self.output_area.setFont(QFont('Consolas', 9))
        self.output_area.setMaximumHeight(100)
        self.output_area.setReadOnly(True)
        layout.addWidget(QLabel('Output:'))
        layout.addWidget(self.output_area)
        
        self.setLayout(layout)
    
    def get_script(self) -> str:
        return self.script_editor.toPlainText()
    
    def set_script(self, script: str):
        self.script_editor.setPlainText(script)
    
    def test_script(self):
        self.execute_script(test_mode=True)
    
    def execute_script(self, test_mode=False):
        script = self.script_editor.toPlainText().strip()
        if not script:
            return
        
        try:
            # Create execution context
            output = []
            
            def print_func(*args):
                output.append(' '.join(str(arg) for arg in args))
            
            def set_variable(key, value, is_global=False):
                if not test_mode:
                    self.env_manager.set_variable(key, str(value), is_global)
                output.append(f"Set variable: {key} = {value}")
            
            def get_variable(key):
                value = self.env_manager.get_variable(key)
                output.append(f"Get variable: {key} = {value}")
                return value
            
            context = {
                'print': print_func,
                'set_variable': set_variable,
                'get_variable': get_variable,
                '__builtins__': {
                    'int': int,
                    'str': str,
                    'float': float,
                    'bool': bool,
                    'len': len,
                    'range': range,
                    'enumerate': enumerate,
                    'zip': zip,
                    'min': min,
                    'max': max,
                    'abs': abs,
                    'round': round,
                    'sum': sum,
                    'any': any,
                    'all': all
                }
            }
            
            # Execute script
            exec(script, context)
            
            # Display output
            if output:
                self.output_area.setPlainText('\n'.join(output))
            else:
                self.output_area.setPlainText('Script executed successfully (no output)')
            
        except Exception as e:
            self.output_area.setPlainText(f'Error: {str(e)}')


class TestsWidget(QWidget):
    def __init__(self):
        super().__init__()
        self.tests = []
        self.init_ui()
    
    def init_ui(self):
        layout = QVBoxLayout()
        
        # Header
        header_layout = QHBoxLayout()
        header_layout.addWidget(QLabel('Tests & Assertions'))
        
        add_test_btn = QPushButton('Add Test')
        add_test_btn.clicked.connect(self.add_test)
        header_layout.addWidget(add_test_btn)
        
        run_tests_btn = QPushButton('Run Tests')
        run_tests_btn.clicked.connect(self.run_tests)
        header_layout.addWidget(run_tests_btn)
        
        layout.addLayout(header_layout)
        
        # Tests table
        self.tests_table = QTableWidget(0, 4)
        self.tests_table.setHorizontalHeaderLabels(['Enable', 'Name', 'Script', 'Result'])
        self.tests_table.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeMode.ResizeToContents)
        self.tests_table.horizontalHeader().setSectionResizeMode(2, QHeaderView.ResizeMode.Stretch)
        self.tests_table.horizontalHeader().setSectionResizeMode(3, QHeaderView.ResizeMode.ResizeToContents)
        layout.addWidget(self.tests_table)
        
        # Test template
        layout.addWidget(QLabel('Test Template:'))
        template_text = """# Test assertion script
# Available variables: response, status_code, headers, body, json, response_time, size

# Examples:
# assert status_code == 200, f"Expected 200, got {status_code}"
# assert 'error' not in json, "Response contains error"
# assert response_time < 1000, f"Response too slow: {response_time}ms"
# assert len(json.get('data', [])) > 0, "No data returned"
"""
        template_display = QTextEdit()
        template_display.setPlainText(template_text)
        template_display.setMaximumHeight(120)
        template_display.setReadOnly(True)
        template_display.setFont(QFont('Consolas', 9))
        layout.addWidget(template_display)
        
        self.setLayout(layout)
        
        # Store response data for testing
        self.response_data = {}
    
    def add_test(self):
        name, ok = QInputDialog.getText(self, 'Add Test', 'Test name:')
        if ok and name.strip():
            test = TestAssertion(name.strip(), 'assert status_code == 200')
            self.tests.append(test)
            self.refresh_tests_table()
    
    def refresh_tests_table(self):
        self.tests_table.setRowCount(len(self.tests))
        
        for i, test in enumerate(self.tests):
            # Enable checkbox
            enable_item = QTableWidgetItem()
            enable_item.setFlags(Qt.ItemFlag.ItemIsUserCheckable | Qt.ItemFlag.ItemIsEnabled)
            enable_item.setCheckState(Qt.CheckState.Checked if test.enabled else Qt.CheckState.Unchecked)
            self.tests_table.setItem(i, 0, enable_item)
            
            # Name
            name_item = QTableWidgetItem(test.name)
            self.tests_table.setItem(i, 1, name_item)
            
            # Script
            script_item = QTableWidgetItem(test.script)
            self.tests_table.setItem(i, 2, script_item)
            
            # Result
            if test.result is None:
                result_text = '-'
                result_color = None
            elif test.result:
                result_text = 'PASS'
                result_color = QColor(0, 128, 0)
            else:
                result_text = f'FAIL: {test.error}'
                result_color = QColor(128, 0, 0)
            
            result_item = QTableWidgetItem(result_text)
            if result_color:
                result_item.setForeground(result_color)
            self.tests_table.setItem(i, 3, result_item)
    
    def get_tests(self) -> List[TestAssertion]:
        # Update tests from table
        for i, test in enumerate(self.tests):
            if i < self.tests_table.rowCount():
                enable_item = self.tests_table.item(i, 0)
                name_item = self.tests_table.item(i, 1)
                script_item = self.tests_table.item(i, 2)
                
                if enable_item:
                    test.enabled = enable_item.checkState() == Qt.CheckState.Checked
                if name_item:
                    test.name = name_item.text()
                if script_item:
                    test.script = script_item.text()
        
        return self.tests
    
    def set_tests(self, tests: List[TestAssertion]):
        self.tests = tests
        self.refresh_tests_table()
    
    def set_response_data(self, response_data):
        self.response_data = response_data
    
    def run_tests(self):
        if not self.response_data:
            QMessageBox.warning(self, 'Warning', 'No response data available for testing')
            return
        
        # Update tests from table first
        self.get_tests()
        
        passed = 0
        failed = 0
        
        for test in self.tests:
            if test.enabled:
                if test.run(self.response_data):
                    passed += 1
                else:
                    failed += 1
        
        self.refresh_tests_table()
        
        # Show results
        if failed == 0:
            QMessageBox.information(self, 'Tests Complete', f'All {passed} tests passed!')
        else:
            QMessageBox.warning(self, 'Tests Complete', 
                              f'{passed} tests passed, {failed} tests failed')


class PasswordDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.password = None
        self.init_ui()
    
    def init_ui(self):
        self.setWindowTitle('API Testing Tool - Authentication')
        self.setModal(True)
        self.setFixedSize(400, 200)
        self.setWindowFlags(Qt.WindowType.Dialog | Qt.WindowType.WindowCloseButtonHint)
        
        layout = QVBoxLayout()
        
        # Logo/Title
        title = QLabel('API Testing Tool')
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        title.setStyleSheet("font-size: 18px; font-weight: bold; margin: 10px;")
        layout.addWidget(title)
        
        # Info text
        import os
        has_encrypted_data = os.path.exists('data.enc')
        if has_encrypted_data:
            info_text = 'Enter your master password to decrypt and load your data:'
        else:
            info_text = 'First time setup: Create a master password to encrypt your data:'
        
        info = QLabel(info_text)
        info.setAlignment(Qt.AlignmentFlag.AlignCenter)
        info.setWordWrap(True)
        layout.addWidget(info)
        
        # Password input
        form_layout = QFormLayout()
        self.password_input = QLineEdit()
        self.password_input.setEchoMode(QLineEdit.EchoMode.Password)
        self.password_input.returnPressed.connect(self.accept)
        form_layout.addRow('Password:', self.password_input)
        layout.addLayout(form_layout)
        
        # Buttons
        button_layout = QHBoxLayout()
        
        skip_btn = QPushButton('Skip (Start Empty)')
        skip_btn.clicked.connect(self.skip_password)
        button_layout.addWidget(skip_btn)
        
        button_layout.addStretch()
        
        if has_encrypted_data:
            ok_btn = QPushButton('Load Data')
        else:
            ok_btn = QPushButton('Create & Continue')
        ok_btn.setDefault(True)
        ok_btn.clicked.connect(self.accept)
        button_layout.addWidget(ok_btn)
        
        cancel_btn = QPushButton('Exit')
        cancel_btn.clicked.connect(self.reject)
        button_layout.addWidget(cancel_btn)
        
        layout.addLayout(button_layout)
        self.setLayout(layout)
        
        # Focus on password input
        self.password_input.setFocus()
    
    def skip_password(self):
        self.password = None
        self.done(2)  # Custom return code for skip
    
    def accept(self):
        self.password = self.password_input.text()
        if not self.password:
            QMessageBox.warning(self, 'Warning', 'Please enter a password or click Skip.')
            return
        super().accept()
    
    def get_password(self):
        return self.password


class DataFileDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.selected_file = None
        self.selected_action = None  # 'select', 'create', 'empty'
        self.init_ui()
    
    def init_ui(self):
        self.setWindowTitle('API Testing Tool - Choose Data')
        self.setModal(True)
        self.setFixedSize(450, 400)
        self.setWindowFlags(Qt.WindowType.Dialog | Qt.WindowType.WindowCloseButtonHint)
        
        layout = QVBoxLayout()
        
        # Title
        title = QLabel('API Testing Tool')
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        title.setStyleSheet("font-size: 20px; font-weight: bold; margin: 15px;")
        layout.addWidget(title)
        
        # Description
        desc = QLabel('Choose how you want to start:')
        desc.setAlignment(Qt.AlignmentFlag.AlignCenter)
        desc.setStyleSheet("margin-bottom: 25px; color: #666; font-size: 14px;")
        layout.addWidget(desc)
        
        # Option 1: Select existing data file
        btn1 = QPushButton('1. Select a Data File')
        btn1.setStyleSheet("QPushButton { text-align: left; padding: 15px; font-size: 14px; }")
        btn1.clicked.connect(self.select_data_file)
        layout.addWidget(btn1)
        
        desc1 = QLabel('   Choose from existing encrypted data files in ./data/')
        desc1.setStyleSheet("color: #888; margin-bottom: 10px; font-size: 12px;")
        layout.addWidget(desc1)
        
        # Option 2: Create new data file
        btn2 = QPushButton('2. Create New Data File')
        btn2.setStyleSheet("QPushButton { text-align: left; padding: 15px; font-size: 14px; }")
        btn2.clicked.connect(self.create_data_file)
        layout.addWidget(btn2)
        
        desc2 = QLabel('   Create a new encrypted data file in ./data/ directory')
        desc2.setStyleSheet("color: #888; margin-bottom: 10px; font-size: 12px;")
        layout.addWidget(desc2)
        
        # Option 3: Start empty
        btn3 = QPushButton('3. Start Empty')
        btn3.setStyleSheet("QPushButton { text-align: left; padding: 15px; font-size: 14px; }")
        btn3.clicked.connect(self.start_empty)
        layout.addWidget(btn3)
        
        desc3 = QLabel('   Start with no data (nothing will be saved)')
        desc3.setStyleSheet("color: #888; margin-bottom: 20px; font-size: 12px;")
        layout.addWidget(desc3)
        
        layout.addStretch()
        
        # Exit button
        button_layout = QHBoxLayout()
        button_layout.addStretch()
        
        exit_btn = QPushButton('Exit')
        exit_btn.clicked.connect(self.reject)
        button_layout.addWidget(exit_btn)
        
        layout.addLayout(button_layout)
        self.setLayout(layout)
    
    def select_data_file(self):
        # Create data directory if it doesn't exist
        data_dir = 'data'
        if not os.path.exists(data_dir):
            os.makedirs(data_dir)
        
        # Find all .enc files in data directory
        try:
            enc_files = [f for f in os.listdir(data_dir) if f.endswith('.enc')]
        except:
            enc_files = []
        
        if not enc_files:
            QMessageBox.information(self, 'No Data Files', 
                                  'No encrypted data files found in ./data/ directory.\n'
                                  'Use "Create New Data File" to create one.')
            return
        
        # Show file selection dialog
        file_path, ok = QInputDialog.getItem(
            self, 'Select Data File', 
            'Choose a data file:', 
            enc_files, 0, False
        )
        
        if ok and file_path:
            self.selected_file = os.path.join(data_dir, file_path)
            self.selected_action = 'select'
            self.accept()
    
    def create_data_file(self):
        # Create data directory if it doesn't exist
        data_dir = 'data'
        if not os.path.exists(data_dir):
            os.makedirs(data_dir)
        
        # Ask for filename
        filename, ok = QInputDialog.getText(
            self, 'Create New Data File', 
            'Enter filename for new data file:', 
            text='my-project.enc'
        )
        
        if ok and filename.strip():
            if not filename.endswith('.enc'):
                filename += '.enc'
            
            # Create full path in data directory
            full_path = os.path.join(data_dir, filename)
            
            # Check if file already exists
            if os.path.exists(full_path):
                reply = QMessageBox.question(
                    self, 'File Exists', 
                    f'File "{filename}" already exists in data directory.\n'
                    'Do you want to overwrite it?',
                    QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                    QMessageBox.StandardButton.No
                )
                if reply != QMessageBox.StandardButton.Yes:
                    return
            
            self.selected_file = full_path
            self.selected_action = 'create'
            self.accept()
    
    def start_empty(self):
        self.selected_file = None
        self.selected_action = 'empty'
        self.accept()


class EnvironmentDialog(QDialog):
    def __init__(self, env_manager: EnvironmentManager, parent=None):
        super().__init__(parent)
        self.env_manager = env_manager
        self.init_ui()
        self.refresh_environments()
    
    def init_ui(self):
        self.setWindowTitle('Environment Manager')
        self.setModal(True)
        self.resize(600, 400)
        
        layout = QVBoxLayout()
        
        # Environment selector
        env_layout = QHBoxLayout()
        env_layout.addWidget(QLabel('Current Environment:'))
        
        self.env_combo = QComboBox()
        self.env_combo.currentTextChanged.connect(self.on_environment_changed)
        env_layout.addWidget(self.env_combo)
        
        new_env_btn = QPushButton('New')
        new_env_btn.clicked.connect(self.create_environment)
        env_layout.addWidget(new_env_btn)
        
        delete_env_btn = QPushButton('Delete')
        delete_env_btn.clicked.connect(self.delete_environment)
        env_layout.addWidget(delete_env_btn)
        
        layout.addLayout(env_layout)
        
        # Variables tables
        splitter = QSplitter(Qt.Orientation.Horizontal)
        
        # Environment variables
        env_group = QGroupBox('Environment Variables')
        env_layout_inner = QVBoxLayout()
        
        self.env_vars_table = QTableWidget(0, 2)
        self.env_vars_table.setHorizontalHeaderLabels(['Key', 'Value'])
        self.env_vars_table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        
        add_env_var_btn = QPushButton('Add Variable')
        add_env_var_btn.clicked.connect(lambda: self.add_variable_row(self.env_vars_table))
        
        env_layout_inner.addWidget(self.env_vars_table)
        env_layout_inner.addWidget(add_env_var_btn)
        env_group.setLayout(env_layout_inner)
        
        # Global variables
        global_group = QGroupBox('Global Variables')
        global_layout = QVBoxLayout()
        
        self.global_vars_table = QTableWidget(0, 2)
        self.global_vars_table.setHorizontalHeaderLabels(['Key', 'Value'])
        self.global_vars_table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        
        add_global_var_btn = QPushButton('Add Variable')
        add_global_var_btn.clicked.connect(lambda: self.add_variable_row(self.global_vars_table))
        
        global_layout.addWidget(self.global_vars_table)
        global_layout.addWidget(add_global_var_btn)
        global_group.setLayout(global_layout)
        
        splitter.addWidget(env_group)
        splitter.addWidget(global_group)
        layout.addWidget(splitter)
        
        # Buttons
        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel)
        buttons.accepted.connect(self.save_and_accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)
        
        self.setLayout(layout)
    
    def refresh_environments(self):
        self.env_combo.clear()
        self.env_combo.addItem('None')
        for env_name in self.env_manager.environments.keys():
            self.env_combo.addItem(env_name)
        
        if self.env_manager.current_environment:
            self.env_combo.setCurrentText(self.env_manager.current_environment)
        else:
            self.env_combo.setCurrentText('None')
        
        self.refresh_variables()
    
    def refresh_variables(self):
        # Clear tables
        self.env_vars_table.setRowCount(0)
        self.global_vars_table.setRowCount(0)
        
        # Load environment variables
        current_env = self.env_combo.currentText()
        if current_env != 'None' and current_env in self.env_manager.environments:
            env_vars = self.env_manager.environments[current_env]
            for key, value in env_vars.items():
                self.add_variable_row(self.env_vars_table, key, value)
        
        # Load global variables
        for key, value in self.env_manager.global_variables.items():
            self.add_variable_row(self.global_vars_table, key, value)
    
    def add_variable_row(self, table: QTableWidget, key: str = '', value: str = ''):
        row = table.rowCount()
        table.insertRow(row)
        table.setItem(row, 0, QTableWidgetItem(key))
        table.setItem(row, 1, QTableWidgetItem(value))
    
    def create_environment(self):
        name, ok = QInputDialog.getText(self, 'New Environment', 'Environment name:')
        if ok and name.strip():
            self.env_manager.create_environment(name.strip())
            self.refresh_environments()
            self.env_combo.setCurrentText(name.strip())
    
    def delete_environment(self):
        current_env = self.env_combo.currentText()
        if current_env != 'None':
            reply = QMessageBox.question(self, 'Delete Environment', 
                                       f'Delete environment "{current_env}"?')
            if reply == QMessageBox.StandardButton.Yes:
                self.env_manager.delete_environment(current_env)
                self.refresh_environments()
    
    def on_environment_changed(self, env_name):
        if env_name == 'None':
            self.env_manager.set_current_environment(None)
        else:
            self.env_manager.set_current_environment(env_name)
        self.refresh_variables()
    
    def save_and_accept(self):
        # Save environment variables
        current_env = self.env_combo.currentText()
        if current_env != 'None' and current_env in self.env_manager.environments:
            env_vars = {}
            for row in range(self.env_vars_table.rowCount()):
                key_item = self.env_vars_table.item(row, 0)
                value_item = self.env_vars_table.item(row, 1)
                if key_item and value_item and key_item.text().strip():
                    env_vars[key_item.text().strip()] = value_item.text()
            self.env_manager.environments[current_env] = env_vars
        
        # Save global variables
        global_vars = {}
        for row in range(self.global_vars_table.rowCount()):
            key_item = self.global_vars_table.item(row, 0)
            value_item = self.global_vars_table.item(row, 1)
            if key_item and value_item and key_item.text().strip():
                global_vars[key_item.text().strip()] = value_item.text()
        self.env_manager.global_variables = global_vars
        
        # Trigger save from parent window
        if hasattr(self.parent(), 'save_all_data'):
            self.parent().save_all_data()
        self.accept()


class HttpWorker(QThread):
    finished = pyqtSignal(dict)
    error = pyqtSignal(str)
    
    def __init__(self, method, url, headers, params, body, request_type='HTTP', graphql_query='', graphql_variables='{}', timeout=30):
        super().__init__()
        self.method = method
        self.url = url
        self.headers = headers
        self.params = params
        self.body = body
        self.request_type = request_type
        self.graphql_query = graphql_query
        self.graphql_variables = graphql_variables
        self.timeout = timeout
    
    def run(self):
        try:
            start_time = time.time()
            
            # Handle GraphQL requests
            if self.request_type == 'GraphQL':
                self.method = 'POST'
                self.headers['Content-Type'] = 'application/json'
                
                try:
                    variables = json.loads(self.graphql_variables) if self.graphql_variables else {}
                except json.JSONDecodeError:
                    variables = {}
                
                graphql_body = {
                    'query': self.graphql_query,
                    'variables': variables
                }
                self.body = json.dumps(graphql_body)
            
            with httpx.Client(timeout=self.timeout, verify=False) as client:  # Disable SSL verification for testing
                if self.method.upper() == 'GET':
                    response = client.get(self.url, headers=self.headers, params=self.params)
                elif self.method.upper() == 'POST':
                    response = client.post(self.url, headers=self.headers, params=self.params, content=self.body)
                elif self.method.upper() == 'PUT':
                    response = client.put(self.url, headers=self.headers, params=self.params, content=self.body)
                elif self.method.upper() == 'DELETE':
                    response = client.delete(self.url, headers=self.headers, params=self.params)
                elif self.method.upper() == 'PATCH':
                    response = client.patch(self.url, headers=self.headers, params=self.params, content=self.body)
                elif self.method.upper() == 'HEAD':
                    response = client.head(self.url, headers=self.headers, params=self.params)
                elif self.method.upper() == 'OPTIONS':
                    response = client.options(self.url, headers=self.headers, params=self.params)
                else:
                    raise ValueError(f"Unsupported HTTP method: {self.method}")
            
            end_time = time.time()
            response_time = (end_time - start_time) * 1000  # Convert to milliseconds
            
            result = {
                'status_code': response.status_code,
                'headers': dict(response.headers),
                'body': response.text,
                'response_time': response_time,
                'size': len(response.content),
                'url': str(response.url),
                'request_headers': self.headers,
                'request_params': self.params,
                'request_body': self.body,
                'request_type': self.request_type
            }
            
            self.finished.emit(result)
            
        except Exception as e:
            self.error.emit(str(e))


class HeadersWidget(QWidget):
    def __init__(self):
        super().__init__()
        self.init_ui()
    
    def init_ui(self):
        layout = QVBoxLayout()
        
        # Headers table
        self.headers_table = QTableWidget(0, 3)
        self.headers_table.setHorizontalHeaderLabels(['Enable', 'Key', 'Value'])
        self.headers_table.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)
        self.headers_table.horizontalHeader().setSectionResizeMode(2, QHeaderView.ResizeMode.Stretch)
        
        # Add header button
        add_btn = QPushButton('Add Header')
        add_btn.clicked.connect(self.add_header_row)
        
        layout.addWidget(self.headers_table)
        layout.addWidget(add_btn)
        self.setLayout(layout)
        
        # Add initial row
        self.add_header_row()
    
    def add_header_row(self):
        row = self.headers_table.rowCount()
        self.headers_table.insertRow(row)
        
        # Enable checkbox
        enable_item = QTableWidgetItem()
        enable_item.setFlags(Qt.ItemFlag.ItemIsUserCheckable | Qt.ItemFlag.ItemIsEnabled)
        enable_item.setCheckState(Qt.CheckState.Checked)
        self.headers_table.setItem(row, 0, enable_item)
        
        # Key and Value
        self.headers_table.setItem(row, 1, QTableWidgetItem(''))
        self.headers_table.setItem(row, 2, QTableWidgetItem(''))
    
    def get_headers(self) -> Dict[str, str]:
        headers = {}
        for row in range(self.headers_table.rowCount()):
            enable_item = self.headers_table.item(row, 0)
            key_item = self.headers_table.item(row, 1)
            value_item = self.headers_table.item(row, 2)
            
            if (enable_item and enable_item.checkState() == Qt.CheckState.Checked and
                key_item and value_item and key_item.text().strip() and value_item.text().strip()):
                headers[key_item.text().strip()] = value_item.text().strip()
        
        return headers
    
    def set_headers(self, headers: Dict[str, str]):
        self.headers_table.setRowCount(0)
        for key, value in headers.items():
            row = self.headers_table.rowCount()
            self.headers_table.insertRow(row)
            
            enable_item = QTableWidgetItem()
            enable_item.setFlags(Qt.ItemFlag.ItemIsUserCheckable | Qt.ItemFlag.ItemIsEnabled)
            enable_item.setCheckState(Qt.CheckState.Checked)
            self.headers_table.setItem(row, 0, enable_item)
            
            self.headers_table.setItem(row, 1, QTableWidgetItem(key))
            self.headers_table.setItem(row, 2, QTableWidgetItem(value))
        
        # Add empty row
        self.add_header_row()


class ParamsWidget(QWidget):
    def __init__(self):
        super().__init__()
        self.init_ui()
    
    def init_ui(self):
        layout = QVBoxLayout()
        
        # Params table
        self.params_table = QTableWidget(0, 3)
        self.params_table.setHorizontalHeaderLabels(['Enable', 'Key', 'Value'])
        self.params_table.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)
        self.params_table.horizontalHeader().setSectionResizeMode(2, QHeaderView.ResizeMode.Stretch)
        
        # Add param button
        add_btn = QPushButton('Add Parameter')
        add_btn.clicked.connect(self.add_param_row)
        
        layout.addWidget(self.params_table)
        layout.addWidget(add_btn)
        self.setLayout(layout)
        
        # Add initial row
        self.add_param_row()
    
    def add_param_row(self):
        row = self.params_table.rowCount()
        self.params_table.insertRow(row)
        
        # Enable checkbox
        enable_item = QTableWidgetItem()
        enable_item.setFlags(Qt.ItemFlag.ItemIsUserCheckable | Qt.ItemFlag.ItemIsEnabled)
        enable_item.setCheckState(Qt.CheckState.Checked)
        self.params_table.setItem(row, 0, enable_item)
        
        # Key and Value
        self.params_table.setItem(row, 1, QTableWidgetItem(''))
        self.params_table.setItem(row, 2, QTableWidgetItem(''))
    
    def get_params(self) -> Dict[str, str]:
        params = {}
        for row in range(self.params_table.rowCount()):
            enable_item = self.params_table.item(row, 0)
            key_item = self.params_table.item(row, 1)
            value_item = self.params_table.item(row, 2)
            
            if (enable_item and enable_item.checkState() == Qt.CheckState.Checked and
                key_item and value_item and key_item.text().strip() and value_item.text().strip()):
                params[key_item.text().strip()] = value_item.text().strip()
        
        return params
    
    def set_params(self, params: Dict[str, str]):
        self.params_table.setRowCount(0)
        for key, value in params.items():
            row = self.params_table.rowCount()
            self.params_table.insertRow(row)
            
            enable_item = QTableWidgetItem()
            enable_item.setFlags(Qt.ItemFlag.ItemIsUserCheckable | Qt.ItemFlag.ItemIsEnabled)
            enable_item.setCheckState(Qt.CheckState.Checked)
            self.params_table.setItem(row, 0, enable_item)
            
            self.params_table.setItem(row, 1, QTableWidgetItem(key))
            self.params_table.setItem(row, 2, QTableWidgetItem(value))
        
        # Add empty row
        self.add_param_row()


class BodyWidget(QWidget):
    def __init__(self):
        super().__init__()
        self.init_ui()
    
    def init_ui(self):
        layout = QVBoxLayout()
        
        # Body type and request type selector
        type_layout = QHBoxLayout()
        
        # Request type
        type_layout.addWidget(QLabel('Type:'))
        self.request_type_combo = QComboBox()
        self.request_type_combo.addItems(['HTTP', 'GraphQL', 'WebSocket'])
        self.request_type_combo.currentTextChanged.connect(self.on_request_type_changed)
        type_layout.addWidget(self.request_type_combo)
        
        # Body type
        type_layout.addWidget(QLabel('Body:'))
        self.body_type = QComboBox()
        self.body_type.addItems(['None', 'JSON', 'Form Data', 'Raw Text', 'XML', 'Binary'])
        self.body_type.currentTextChanged.connect(self.on_body_type_changed)
        type_layout.addWidget(self.body_type)
        
        type_layout.addStretch()
        layout.addLayout(type_layout)
        
        # Content stack
        self.content_stack = QTabWidget()
        
        # HTTP Body
        self.body_editor = QTextEdit()
        self.body_editor.setFont(QFont('Consolas', 10))
        self.content_stack.addTab(self.body_editor, 'Body')
        
        # GraphQL
        self.graphql_widget = GraphQLWidget()
        self.content_stack.addTab(self.graphql_widget, 'GraphQL')
        
        # WebSocket
        self.websocket_widget = WebSocketWidget()
        self.content_stack.addTab(self.websocket_widget, 'WebSocket')
        
        layout.addWidget(self.content_stack)
        self.setLayout(layout)
        
        # Initially show HTTP
        self.content_stack.setCurrentIndex(0)
    
    def on_request_type_changed(self, request_type):
        if request_type == 'HTTP':
            self.content_stack.setCurrentIndex(0)
        elif request_type == 'GraphQL':
            self.content_stack.setCurrentIndex(1)
        elif request_type == 'WebSocket':
            self.content_stack.setCurrentIndex(2)
    
    def on_body_type_changed(self, body_type):
        if body_type == 'JSON':
            self.body_editor.setPlainText('{\n    \n}')
        elif body_type == 'XML':
            self.body_editor.setPlainText('<?xml version="1.0" encoding="UTF-8"?>\n<root>\n    \n</root>')
        elif body_type == 'None':
            self.body_editor.setPlainText('')
    
    def get_request_type(self) -> str:
        return self.request_type_combo.currentText()
    
    def get_body(self) -> str:
        if self.body_type.currentText() == 'None':
            return ''
        return self.body_editor.toPlainText()
    
    def get_graphql_query(self) -> str:
        return self.graphql_widget.get_query()
    
    def get_graphql_variables(self) -> str:
        return self.graphql_widget.get_variables()
    
    def set_body(self, body: str, body_type: str = 'None', request_type: str = 'HTTP'):
        self.request_type_combo.setCurrentText(request_type)
        self.body_type.setCurrentText(body_type)
        self.body_editor.setPlainText(body)
    
    def set_graphql_data(self, query: str, variables: str):
        self.graphql_widget.set_query(query)
        self.graphql_widget.set_variables(variables)


class ResponseWidget(QWidget):
    def __init__(self):
        super().__init__()
        self.init_ui()
    
    def init_ui(self):
        layout = QVBoxLayout()
        
        # Response status bar
        self.status_bar = QHBoxLayout()
        self.status_label = QLabel('Status: Ready')
        self.time_label = QLabel('Time: -')
        self.size_label = QLabel('Size: -')
        
        # SSL info button
        self.ssl_btn = QPushButton('SSL Info')
        self.ssl_btn.clicked.connect(self.show_ssl_info)
        self.ssl_btn.setVisible(False)
        
        self.status_bar.addWidget(self.status_label)
        self.status_bar.addStretch()
        self.status_bar.addWidget(self.ssl_btn)
        self.status_bar.addWidget(self.time_label)
        self.status_bar.addWidget(self.size_label)
        
        layout.addLayout(self.status_bar)
        
        # Response tabs
        self.response_tabs = QTabWidget()
        
        # Body tab
        self.body_text = QTextEdit()
        self.body_text.setFont(QFont('Consolas', 10))
        self.body_text.setReadOnly(True)
        self.highlighter = JsonHighlighter(self.body_text.document())
        self.response_tabs.addTab(self.body_text, 'Body')
        
        # Headers tab
        self.headers_table = QTableWidget(0, 2)
        self.headers_table.setHorizontalHeaderLabels(['Header', 'Value'])
        self.headers_table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        self.response_tabs.addTab(self.headers_table, 'Headers')
        
        layout.addWidget(self.response_tabs)
        self.setLayout(layout)
        
        self.current_url = None
    
    def display_response(self, response_data: Dict[str, Any]):
        # Update status bar
        status_code = response_data['status_code']
        status_text = f"Status: {status_code}"
        if 200 <= status_code < 300:
            status_color = "color: green"
        elif 300 <= status_code < 400:
            status_color = "color: orange"
        else:
            status_color = "color: red"
        
        self.status_label.setText(status_text)
        self.status_label.setStyleSheet(status_color)
        
        self.time_label.setText(f"Time: {response_data['response_time']:.2f}ms")
        self.size_label.setText(f"Size: {self.format_size(response_data['size'])}")
        
        # Show SSL button for HTTPS URLs
        self.current_url = response_data.get('url', '')
        if self.current_url and self.current_url.startswith('https://'):
            self.ssl_btn.setVisible(True)
        else:
            self.ssl_btn.setVisible(False)
        
        # Display body
        body = response_data['body']
        try:
            # Try to format as JSON
            formatted_body = json.dumps(json.loads(body), indent=2)
            self.body_text.setPlainText(formatted_body)
        except (json.JSONDecodeError, TypeError):
            # Display as plain text
            self.body_text.setPlainText(body)
        
        # Display headers
        headers = response_data['headers']
        self.headers_table.setRowCount(len(headers))
        for i, (key, value) in enumerate(headers.items()):
            self.headers_table.setItem(i, 0, QTableWidgetItem(key))
            self.headers_table.setItem(i, 1, QTableWidgetItem(value))
    
    def show_ssl_info(self):
        if not self.current_url:
            return
        
        ssl_info = SSLManager.get_ssl_info(self.current_url)
        
        if 'error' in ssl_info:
            QMessageBox.warning(self, 'SSL Error', f"SSL verification failed: {ssl_info['error']}")
        else:
            info_text = f"""SSL Certificate Information:

Subject: {ssl_info.get('subject', {}).get('commonName', 'Unknown')}
Issuer: {ssl_info.get('issuer', {}).get('organizationName', 'Unknown')}
Valid From: {ssl_info.get('notBefore', 'Unknown')}
Valid To: {ssl_info.get('notAfter', 'Unknown')}
Serial Number: {ssl_info.get('serialNumber', 'Unknown')}
Version: {ssl_info.get('version', 'Unknown')}
"""
            
            if ssl_info.get('subjectAltName'):
                alt_names = [name[1] for name in ssl_info['subjectAltName']]
                info_text += f"\nSubject Alternative Names:\n{', '.join(alt_names)}"
            
            msg = QMessageBox(self)
            msg.setWindowTitle('SSL Certificate Info')
            msg.setText(info_text)
            msg.setIcon(QMessageBox.Icon.Information)
            msg.exec()
    
    def format_size(self, size_bytes: int) -> str:
        if size_bytes == 0:
            return "0 B"
        size_names = ["B", "KB", "MB", "GB"]
        i = 0
        while size_bytes >= 1024 and i < len(size_names) - 1:
            size_bytes /= 1024.0
            i += 1
        return f"{size_bytes:.1f} {size_names[i]}"
    
    def clear_response(self):
        self.status_label.setText('Status: Ready')
        self.status_label.setStyleSheet('')
        self.time_label.setText('Time: -')
        self.size_label.setText('Size: -')
        self.ssl_btn.setVisible(False)
        self.body_text.setPlainText('')
        self.headers_table.setRowCount(0)
        self.current_url = None


class CollectionTreeWidget(QTreeWidget):
    request_selected = pyqtSignal(object)  # RequestItem
    
    def __init__(self, collection_manager: CollectionManager, parent_app=None):
        super().__init__()
        self.collection_manager = collection_manager
        self.parent_app = parent_app
        self.init_ui()
        self.refresh_collections()
    
    def init_ui(self):
        self.setHeaderLabel('Collections')
        self.itemDoubleClicked.connect(self.on_item_double_clicked)
        
        # Context menu
        self.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.customContextMenuRequested.connect(self.show_context_menu)
    
    def refresh_collections(self):
        self.clear()
        for collection in self.collection_manager.collections:
            col_item = QTreeWidgetItem([collection.name])
            col_item.setData(0, Qt.ItemDataRole.UserRole, ('collection', collection))
            
            # Add requests
            for request in collection.requests:
                req_item = QTreeWidgetItem([f"{request.method} {request.name}"])
                req_item.setData(0, Qt.ItemDataRole.UserRole, ('request', request))
                col_item.addChild(req_item)
            
            # Add folders
            for folder in collection.folders:
                folder_item = QTreeWidgetItem([folder.name])
                folder_item.setData(0, Qt.ItemDataRole.UserRole, ('folder', folder))
                
                for request in folder.requests:
                    req_item = QTreeWidgetItem([f"{request.method} {request.name}"])
                    req_item.setData(0, Qt.ItemDataRole.UserRole, ('request', request))
                    folder_item.addChild(req_item)
                
                col_item.addChild(folder_item)
            
            self.addTopLevelItem(col_item)
            col_item.setExpanded(True)
    
    def on_item_double_clicked(self, item, column):
        data = item.data(0, Qt.ItemDataRole.UserRole)
        if data and data[0] == 'request':
            self.request_selected.emit(data[1])
    
    def show_context_menu(self, position):
        item = self.itemAt(position)
        if not item:
            return
        
        menu = QMenu(self)
        data = item.data(0, Qt.ItemDataRole.UserRole)
        
        if data:
            if data[0] == 'collection':
                menu.addAction('New Request', lambda: self.add_request(data[1]))
                menu.addAction('New Folder', lambda: self.add_folder(data[1]))
                menu.addAction('Export Collection', lambda: self.export_collection(data[1]))
                menu.addAction('Delete Collection', lambda: self.delete_collection(data[1]))
            elif data[0] == 'folder':
                menu.addAction('New Request', lambda: self.add_request_to_folder(data[1]))
                menu.addAction('Delete Folder', lambda: self.delete_folder(data[1]))
            elif data[0] == 'request':
                menu.addAction('Duplicate Request', lambda: self.duplicate_request(data[1]))
                menu.addAction('Delete Request', lambda: self.delete_request(data[1]))
        
        menu.exec(self.mapToGlobal(position))
    
    def add_request(self, collection: Collection):
        name, ok = QInputDialog.getText(self, 'New Request', 'Request name:')
        if ok and name.strip():
            request = RequestItem(name.strip())
            collection.requests.append(request)
            if self.parent_app:
                self.parent_app.save_all_data()
            self.refresh_collections()
    
    def add_folder(self, collection: Collection):
        name, ok = QInputDialog.getText(self, 'New Folder', 'Folder name:')
        if ok and name.strip():
            folder = Folder(name.strip())
            collection.folders.append(folder)
            if self.parent_app:
                self.parent_app.save_all_data()
            self.refresh_collections()
    
    def add_request_to_folder(self, folder: Folder):
        name, ok = QInputDialog.getText(self, 'New Request', 'Request name:')
        if ok and name.strip():
            request = RequestItem(name.strip())
            folder.requests.append(request)
            if self.parent_app:
                self.parent_app.save_all_data()
            self.refresh_collections()
    
    def export_collection(self, collection: Collection):
        file_path, _ = QFileDialog.getSaveFileName(self, 'Export Collection', 
                                                 f'{collection.name}.json', 
                                                 'JSON Files (*.json)')
        if file_path:
            self.collection_manager.export_collection(collection.id, file_path)
    
    def delete_collection(self, collection: Collection):
        reply = QMessageBox.question(self, 'Delete Collection', 
                                   f'Delete collection "{collection.name}"?')
        if reply == QMessageBox.StandardButton.Yes:
            self.collection_manager.delete_collection(collection.id)
            self.refresh_collections()
    
    def delete_folder(self, folder: Folder):
        # Find and remove folder from its collection
        for collection in self.collection_manager.collections:
            if folder in collection.folders:
                collection.folders.remove(folder)
                break
        if self.parent_app:
            self.parent_app.save_all_data()
        self.refresh_collections()
    
    def delete_request(self, request: RequestItem):
        # Find and remove request from its parent
        for collection in self.collection_manager.collections:
            if request in collection.requests:
                collection.requests.remove(request)
                break
            for folder in collection.folders:
                if request in folder.requests:
                    folder.requests.remove(request)
                    break
        if self.parent_app:
            self.parent_app.save_all_data()
        self.refresh_collections()
    
    def duplicate_request(self, request: RequestItem):
        # Create a copy of the request
        new_request = RequestItem(f"{request.name} Copy", request.method, request.url)
        new_request.headers = request.headers.copy()
        new_request.params = request.params.copy()
        new_request.body = request.body
        new_request.body_type = request.body_type
        new_request.pre_request_script = request.pre_request_script
        new_request.tests = [TestAssertion(t.name, t.script, t.enabled) for t in request.tests]
        new_request.auth = AuthConfig.from_dict(request.auth.to_dict())
        new_request.request_type = request.request_type
        new_request.graphql_query = request.graphql_query
        new_request.graphql_variables = request.graphql_variables
        
        # Find parent and add the duplicate
        for collection in self.collection_manager.collections:
            if request in collection.requests:
                collection.requests.append(new_request)
                break
            for folder in collection.folders:
                if request in folder.requests:
                    folder.requests.append(new_request)
                    break
        
        if self.parent_app:
            self.parent_app.save_all_data()
        self.refresh_collections()


class ApiTestingTool(QMainWindow):
    def __init__(self):
        super().__init__()
        self.http_worker = None
        self.data_encryption = DataEncryption()
        self.data_manager = DataManager(self.data_encryption)
        self.master_password = None
        self.data_loaded = False
        self.parent_app = self  # Reference to self for consistent API
        
        # Initialize managers
        self.env_manager = EnvironmentManager(self.data_manager)
        self.collection_manager = CollectionManager(self.data_manager)
        self.request_history = RequestHistory(self.data_manager)
        self.plugin_manager = PluginManager()
        self.current_request = None
        
        self.init_ui()
        self.init_menu()
        
        # Show data file selection and authentication dialogs after UI is initialized
        self.select_data_file_and_authenticate()
        
        # Setup auto-save timer (save every 30 seconds if data has changed)
        self.setup_auto_save()
    
    def select_data_file_and_authenticate(self):
        """Show data file selection dialog, then password dialog if needed"""
        # First, show data file selection dialog
        data_dialog = DataFileDialog(self)
        result = data_dialog.exec()
        
        if result != QDialog.DialogCode.Accepted:
            sys.exit(0)  # User clicked Exit
        
        action = data_dialog.selected_action
        selected_file = data_dialog.selected_file
        
        if action == 'empty':
            # Start empty - no encryption, no data saving
            self.master_password = None
            self.data_loaded = False
            # Load empty data
            self.env_manager.load_environments()
            self.request_history.load_history()
            self.collection_manager.load_collections()
            
        elif action == 'create':
            # Create new data file - ask for password
            password_dialog = PasswordDialog(self)
            # Update dialog text for new file creation
            password_dialog.setWindowTitle('Create New Data File')
            for label in password_dialog.findChildren(QLabel):
                if 'Enter your master password' in label.text():
                    label.setText('Create a master password for this data file:')
                elif 'First time setup' in label.text():
                    label.setText('Create a master password for this data file:')
            
            result = password_dialog.exec()
            if result != QDialog.DialogCode.Accepted:
                sys.exit(0)
            
            password = password_dialog.get_password()
            if password:
                self.master_password = password
                self.data_encryption.set_password(password)
                self.data_manager.set_file_path(selected_file)
                
                # Start with empty data and save immediately
                self.env_manager.load_environments()
                self.request_history.load_history()
                self.collection_manager.load_collections()
                self.data_loaded = True
                if self.parent_app:
                    self.parent_app.save_all_data()
                
        elif action == 'select':
            # Load existing data file - ask for password
            max_attempts = 3
            attempts = 0
            
            while attempts < max_attempts:
                password_dialog = PasswordDialog(self)
                # Update dialog for existing file
                password_dialog.setWindowTitle(f'Open Data File - {selected_file}')
                for label in password_dialog.findChildren(QLabel):
                    if 'master password' in label.text():
                        label.setText(f'Enter password for {selected_file}:')
                
                result = password_dialog.exec()
                if result != QDialog.DialogCode.Accepted:
                    sys.exit(0)
                
                password = password_dialog.get_password()
                if password:
                    try:
                        self.master_password = password
                        self.data_encryption.set_password(password)
                        self.data_manager.set_file_path(selected_file)
                        
                        # Try to load the encrypted data
                        all_data = self.data_manager.load_all_data(password)
                        
                        env_loaded = self.env_manager.load_environments(all_data)
                        history_loaded = self.request_history.load_history(all_data)
                        collections_loaded = self.collection_manager.load_collections(all_data)
                        
                        if env_loaded and history_loaded and collections_loaded:
                            self.data_loaded = True
                            break  # Success!
                        else:
                            raise ValueError("Failed to load data")
                            
                    except Exception as e:
                        attempts += 1
                        if attempts < max_attempts:
                            QMessageBox.warning(self, 'Wrong Password', 
                                              f'Invalid password for {selected_file}.\n'
                                              f'Attempts remaining: {max_attempts - attempts}')
                        else:
                            QMessageBox.critical(self, 'Authentication Failed', 
                                               f'Failed to open {selected_file} after {max_attempts} attempts.\n'
                                               'Application will exit.')
                            sys.exit(0)
                else:
                    sys.exit(0)
        
        # Refresh UI after loading data
        self.refresh_environment_combo()
        self.collections_tree.refresh_collections()
        self.history_widget.refresh_history()
        
        # Update menu items based on encryption status
        self.update_menu_states()
    
    def update_menu_states(self):
        """Update menu item states based on encryption status"""
        if hasattr(self, 'save_action') and hasattr(self, 'change_password_action'):
            if self.master_password:
                # Encryption is active - enable menu items
                self.save_action.setEnabled(True)
                self.save_action.setText('Save Data')
                
                self.change_password_action.setEnabled(True)
                self.change_password_action.setText('Change Password')
            else:
                # No encryption - disable menu items
                self.save_action.setEnabled(False)
                self.save_action.setText('Save Data (No encryption active)')
                
                self.change_password_action.setEnabled(False)
                self.change_password_action.setText('Change Password (No encryption active)')
    
    def setup_auto_save(self):
        """Setup automatic data saving every 30 seconds"""
        from PyQt6.QtCore import QTimer
        self.auto_save_timer = QTimer()
        self.auto_save_timer.timeout.connect(self.auto_save_data)
        self.auto_save_timer.start(30000)  # 30 seconds
        self.last_save_hash = None
    
    def auto_save_data(self):
        """Automatically save data if it has changed"""
        try:
            if not self.master_password:
                return  # No encryption setup, skip auto-save
            
            # Create a hash of current data to check if it changed
            current_data = {
                'environments': self.env_manager.get_data(),
                'collections': self.collection_manager.get_data(),
                'history': self.request_history.get_data()
            }
            
            import hashlib
            data_str = json.dumps(current_data, sort_keys=True)
            current_hash = hashlib.md5(data_str.encode()).hexdigest()
            
            # Only save if data has changed
            if current_hash != self.last_save_hash:
                if self.parent_app:
                    self.parent_app.save_all_data()
                self.last_save_hash = current_hash
                print("Auto-saved data")  # Debug message
                
        except Exception as e:
            print(f"Auto-save failed: {e}")
    
    def save_all_data(self):
        """Save all data to encrypted file"""
        if self.master_password and self.data_encryption.key:
            try:
                all_data = {
                    'environments': self.env_manager.get_data(),
                    'collections': self.collection_manager.get_data(),
                    'history': self.request_history.get_data()
                }
                self.data_manager.save_all_data(all_data)
            except Exception as e:
                print(f"Error saving data: {e}")
    
    def init_ui(self):
        self.setWindowTitle('API Testing Tool - Advanced')
        self.setGeometry(100, 100, 1600, 900)
        
        # Central widget
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        # Main layout with sidebar
        main_layout = QHBoxLayout()
        
        # Left sidebar - much smaller
        sidebar_splitter = QSplitter(Qt.Orientation.Vertical)
        
        # Collections tree
        collections_frame = QFrame()
        collections_layout = QVBoxLayout()
        collections_layout.setContentsMargins(5, 5, 5, 5)
        
        collections_header = QHBoxLayout()
        collections_label = QLabel('Collections')
        collections_label.setStyleSheet("font-weight: bold; font-size: 11px;")
        collections_header.addWidget(collections_label)
        
        new_collection_btn = QPushButton('+')
        new_collection_btn.setFixedSize(20, 20)
        new_collection_btn.clicked.connect(self.create_collection)
        collections_header.addWidget(new_collection_btn)
        
        collections_layout.addLayout(collections_header)
        
        self.collections_tree = CollectionTreeWidget(self.collection_manager, self)
        self.collections_tree.request_selected.connect(self.load_request)
        self.collections_tree.setHeaderHidden(True)
        collections_layout.addWidget(self.collections_tree)
        
        collections_frame.setLayout(collections_layout)
        
        # History widget - compact
        self.history_widget = HistoryWidget(self.request_history)
        self.history_widget.history_selected.connect(self.load_from_history)
        
        # Environment selector - compact
        env_frame = QFrame()
        env_layout = QVBoxLayout()
        env_layout.setContentsMargins(5, 5, 5, 5)
        
        env_header = QLabel('Environment')
        env_header.setStyleSheet("font-weight: bold; font-size: 11px;")
        env_layout.addWidget(env_header)
        
        self.env_combo = QComboBox()
        self.env_combo.currentTextChanged.connect(self.on_environment_changed)
        self.env_combo.setMaximumHeight(25)
        env_layout.addWidget(self.env_combo)
        
        env_frame.setLayout(env_layout)
        env_frame.setMaximumHeight(80)
        
        sidebar_splitter.addWidget(collections_frame)
        sidebar_splitter.addWidget(self.history_widget)
        sidebar_splitter.addWidget(env_frame)
        sidebar_splitter.setSizes([300, 150, 80])
        sidebar_splitter.setMaximumWidth(250)  # Much smaller sidebar
        
        main_layout.addWidget(sidebar_splitter)
        
        # Main content area - horizontal split for request/response side by side
        content_splitter = QSplitter(Qt.Orientation.Horizontal)
        
        # Request section
        request_frame = QFrame()
        request_layout = QVBoxLayout()
        request_layout.setContentsMargins(10, 5, 10, 5)
        
        # URL bar
        url_layout = QHBoxLayout()
        
        self.method_combo = QComboBox()
        self.method_combo.addItems(['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS'])
        self.method_combo.setFixedWidth(80)
        
        self.url_input = QLineEdit()
        self.url_input.setPlaceholderText('Enter request URL...')
        
        self.send_button = QPushButton('Send')
        self.send_button.clicked.connect(self.send_request)
        self.send_button.setFixedWidth(70)
        
        save_btn = QPushButton('Save')
        save_btn.clicked.connect(self.save_current_request)
        save_btn.setFixedWidth(50)
        
        url_layout.addWidget(self.method_combo)
        url_layout.addWidget(self.url_input)
        url_layout.addWidget(save_btn)
        url_layout.addWidget(self.send_button)
        
        request_layout.addLayout(url_layout)
        
        # Request tabs
        self.request_tabs = QTabWidget()
        
        # Add request configuration tabs
        self.params_widget = ParamsWidget()
        self.headers_widget = HeadersWidget()
        self.body_widget = BodyWidget()
        self.auth_widget = AuthWidget()
        self.pre_request_widget = PreRequestScriptWidget(self.env_manager)
        self.tests_widget = TestsWidget()
        
        self.request_tabs.addTab(self.params_widget, 'Params')
        self.request_tabs.addTab(self.headers_widget, 'Headers')
        self.request_tabs.addTab(self.body_widget, 'Body')
        self.request_tabs.addTab(self.auth_widget, 'Auth')
        self.request_tabs.addTab(self.pre_request_widget, 'Scripts')
        self.request_tabs.addTab(self.tests_widget, 'Tests')
        
        request_layout.addWidget(self.request_tabs)
        
        # Progress bar
        self.progress_bar = QProgressBar()
        self.progress_bar.setVisible(False)
        self.progress_bar.setMaximumHeight(4)
        request_layout.addWidget(self.progress_bar)
        
        request_frame.setLayout(request_layout)
        
        # Response section
        response_frame = QFrame()
        response_layout = QVBoxLayout()
        response_layout.setContentsMargins(10, 5, 10, 5)
        
        # Response tabs
        response_tabs = QTabWidget()
        
        # Response widget
        self.response_widget = ResponseWidget()
        
        # Code generator widget
        self.code_generator = CodeGeneratorWidget()
        
        response_tabs.addTab(self.response_widget, 'Response')
        response_tabs.addTab(self.code_generator, 'Code')
        
        response_layout.addWidget(response_tabs)
        response_frame.setLayout(response_layout)
        
        # Add request and response side by side
        content_splitter.addWidget(request_frame)
        content_splitter.addWidget(response_frame)
        content_splitter.setSizes([600, 600])  # Equal split for request/response
        
        main_layout.addWidget(content_splitter)
        central_widget.setLayout(main_layout)
        
        # Set default headers
        self.set_default_headers()
        self.refresh_environment_combo()
    
    def init_menu(self):
        menubar = self.menuBar()
        
        # File menu
        file_menu = menubar.addMenu('File')
        
        new_collection_action = QAction('New Collection', self)
        new_collection_action.triggered.connect(self.create_collection)
        file_menu.addAction(new_collection_action)
        
        file_menu.addSeparator()
        
        # Save option (will be updated after authentication)
        self.save_action = QAction('Save Data', self)
        self.save_action.setShortcut('Ctrl+S')
        self.save_action.triggered.connect(self.manual_save_data)
        self.save_action.setEnabled(False)
        self.save_action.setText('Save Data (No encryption active)')
        file_menu.addAction(self.save_action)
        
        # Change password option (will be updated after authentication)
        self.change_password_action = QAction('Change Password', self)
        self.change_password_action.triggered.connect(self.change_password)
        self.change_password_action.setEnabled(False)
        self.change_password_action.setText('Change Password (No encryption active)')
        file_menu.addAction(self.change_password_action)
        
        file_menu.addSeparator()
        
        import_action = QAction('Import Collection', self)
        import_action.triggered.connect(self.import_collection)
        file_menu.addAction(import_action)
        
        export_action = QAction('Export Collections', self)
        export_action.triggered.connect(self.export_collections)
        file_menu.addAction(export_action)
        
        file_menu.addSeparator()
        
        exit_action = QAction('Exit', self)
        exit_action.setShortcut('Ctrl+Q')
        exit_action.triggered.connect(self.close)
        file_menu.addAction(exit_action)
        
        # Environment menu
        env_menu = menubar.addMenu('Environment')
        
        manage_env_action = QAction('Manage Environments', self)
        manage_env_action.triggered.connect(self.manage_environments)
        env_menu.addAction(manage_env_action)
        
        # Tools menu
        tools_menu = menubar.addMenu('Tools')
        
        clear_history_action = QAction('Clear History', self)
        clear_history_action.triggered.connect(self.clear_history)
        tools_menu.addAction(clear_history_action)
        
        ssl_info_action = QAction('Check SSL Certificate', self)
        ssl_info_action.triggered.connect(self.check_ssl_certificate)
        tools_menu.addAction(ssl_info_action)
        
        # Plugins menu
        plugins_menu = menubar.addMenu('Plugins')
        
        refresh_plugins_action = QAction('Refresh Plugins', self)
        refresh_plugins_action.triggered.connect(self.refresh_plugins)
        plugins_menu.addAction(refresh_plugins_action)
        
        # Add available plugins
        for plugin_name in self.plugin_manager.get_available_plugins():
            plugin_action = QAction(f'Run {plugin_name}', self)
            plugin_action.triggered.connect(lambda checked, name=plugin_name: self.run_plugin(name))
            plugins_menu.addAction(plugin_action)
    
    def refresh_environment_combo(self):
        current = self.env_combo.currentText()
        self.env_combo.clear()
        self.env_combo.addItem('None')
        
        for env_name in self.env_manager.environments.keys():
            self.env_combo.addItem(env_name)
        
        if self.env_manager.current_environment:
            self.env_combo.setCurrentText(self.env_manager.current_environment)
        elif current:
            self.env_combo.setCurrentText(current)
    
    def on_environment_changed(self, env_name):
        if env_name == 'None':
            self.env_manager.set_current_environment(None)
        else:
            self.env_manager.set_current_environment(env_name)
        if self.parent_app:
            self.parent_app.save_all_data()
    
    def create_collection(self):
        name, ok = QInputDialog.getText(self, 'New Collection', 'Collection name:')
        if ok and name.strip():
            self.collection_manager.create_collection(name.strip())
            if self.parent_app:
                self.parent_app.save_all_data()
            self.collections_tree.refresh_collections()
    
    def import_collection(self):
        file_path, _ = QFileDialog.getOpenFileName(self, 'Import Collection', 
                                                 '', 'JSON Files (*.json)')
        if file_path:
            try:
                with open(file_path, 'r') as f:
                    data = json.load(f)
                    collection = Collection.from_dict(data)
                    self.collection_manager.collections.append(collection)
                    if self.parent_app:
                        self.parent_app.save_all_data()
                    self.collections_tree.refresh_collections()
                    QMessageBox.information(self, 'Success', 'Collection imported successfully')
            except Exception as e:
                QMessageBox.critical(self, 'Error', f'Failed to import collection: {e}')
    
    def export_collections(self):
        """Export all collections to plain JSON files"""
        if not self.collection_manager.collections:
            QMessageBox.information(self, 'Info', 'No collections to export.')
            return
        
        # Choose directory to save files
        directory = QFileDialog.getExistingDirectory(self, 'Choose Export Directory')
        if not directory:
            return
        
        try:
            # Export collections
            collections_data = self.collection_manager.export_collections()
            collections_file = os.path.join(directory, 'collections.json')
            with open(collections_file, 'w') as f:
                json.dump(collections_data, f, indent=2)
            
            # Export environments
            env_data = {
                'environments': self.env_manager.environments,
                'global_variables': self.env_manager.global_variables,
                'current_environment': self.env_manager.current_environment
            }
            env_file = os.path.join(directory, 'environments.json')
            with open(env_file, 'w') as f:
                json.dump(env_data, f, indent=2)
            
            # Export history
            history_file = os.path.join(directory, 'request_history.json')
            with open(history_file, 'w') as f:
                json.dump(self.request_history.history, f, indent=2)
            
            QMessageBox.information(self, 'Success', 
                                  f'Data exported successfully to:\n'
                                  f'• {collections_file}\n'
                                  f'• {env_file}\n'
                                  f'• {history_file}')
            
        except Exception as e:
            QMessageBox.critical(self, 'Error', f'Failed to export data: {e}')
    
    def manual_save_data(self):
        """Manual save triggered by user (File -> Save Data or Ctrl+S)"""
        if not self.master_password:
            QMessageBox.information(self, 'Save Data', 
                                  'No encryption is active. Data cannot be saved.\n'
                                  'Restart the application and choose a data file to enable saving.')
            return
        
        try:
            # Show saving indicator
            self.statusBar().showMessage("Saving encrypted data...", 3000)
            
            # Force save all data
            if self.parent_app:
                self.parent_app.save_all_data()
            
            # Show success message
            QMessageBox.information(self, 'Save Successful', 
                                  f'All data has been saved successfully to:\n{self.data_manager.encrypted_file}')
            
            self.statusBar().showMessage("Data saved successfully", 2000)
            
        except Exception as e:
            QMessageBox.critical(self, 'Save Error', 
                               f'Failed to save data:\n{str(e)}\n\n'
                               'Please check file permissions and disk space.')
            self.statusBar().showMessage("Save failed", 2000)
    
    def change_password(self):
        """Change the encryption password for the current data file"""
        if not self.master_password:
            QMessageBox.information(self, 'Change Password', 
                                  'No encryption is active. Cannot change password.\n'
                                  'Restart the application and choose a data file to enable encryption.')
            return
        
        # Create password change dialog
        dialog = QDialog(self)
        dialog.setWindowTitle('Change Password')
        dialog.setModal(True)
        dialog.setFixedSize(400, 250)
        
        layout = QVBoxLayout()
        
        # Title
        title = QLabel('Change Master Password')
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        title.setStyleSheet("font-size: 16px; font-weight: bold; margin: 10px;")
        layout.addWidget(title)
        
        # Info
        info = QLabel(f'Changing password for: {os.path.basename(self.data_manager.encrypted_file)}')
        info.setAlignment(Qt.AlignmentFlag.AlignCenter)
        info.setStyleSheet("color: #666; margin-bottom: 15px;")
        layout.addWidget(info)
        
        # Form
        form_layout = QFormLayout()
        
        current_password = QLineEdit()
        current_password.setEchoMode(QLineEdit.EchoMode.Password)
        current_password.setPlaceholderText('Enter current password')
        form_layout.addRow('Current Password:', current_password)
        
        new_password = QLineEdit()
        new_password.setEchoMode(QLineEdit.EchoMode.Password)
        new_password.setPlaceholderText('Enter new password')
        form_layout.addRow('New Password:', new_password)
        
        confirm_password = QLineEdit()
        confirm_password.setEchoMode(QLineEdit.EchoMode.Password)
        confirm_password.setPlaceholderText('Confirm new password')
        form_layout.addRow('Confirm Password:', confirm_password)
        
        layout.addLayout(form_layout)
        
        # Buttons
        button_layout = QHBoxLayout()
        button_layout.addStretch()
        
        cancel_btn = QPushButton('Cancel')
        cancel_btn.clicked.connect(dialog.reject)
        button_layout.addWidget(cancel_btn)
        
        change_btn = QPushButton('Change Password')
        change_btn.setDefault(True)
        change_btn.clicked.connect(dialog.accept)
        button_layout.addWidget(change_btn)
        
        layout.addLayout(button_layout)
        dialog.setLayout(layout)
        
        # Focus on current password
        current_password.setFocus()
        
        # Show dialog
        if dialog.exec() == QDialog.DialogCode.Accepted:
            current_pwd = current_password.text()
            new_pwd = new_password.text()
            confirm_pwd = confirm_password.text()
            
            # Validation
            if not current_pwd:
                QMessageBox.warning(self, 'Validation Error', 'Please enter your current password.')
                return
            
            if not new_pwd:
                QMessageBox.warning(self, 'Validation Error', 'Please enter a new password.')
                return
            
            if new_pwd != confirm_pwd:
                QMessageBox.warning(self, 'Validation Error', 'New passwords do not match.')
                return
            
            if len(new_pwd) < 4:
                QMessageBox.warning(self, 'Validation Error', 'Password must be at least 4 characters long.')
                return
            
            # Verify current password
            if current_pwd != self.master_password:
                QMessageBox.critical(self, 'Authentication Failed', 'Current password is incorrect.')
                return
            
            try:
                # Show progress
                self.statusBar().showMessage("Changing password and re-encrypting data...", 5000)
                QApplication.processEvents()
                
                # Get current data
                current_data = {
                    'environments': self.env_manager.get_data(),
                    'collections': self.collection_manager.get_data(),
                    'history': self.request_history.get_data()
                }
                
                # Update encryption with new password
                self.master_password = new_pwd
                self.data_encryption.set_password(new_pwd)
                
                # Save data with new encryption
                self.data_manager.save_all_data(current_data)
                
                # Success message
                QMessageBox.information(self, 'Password Changed', 
                                      'Password has been changed successfully!\n'
                                      'All data has been re-encrypted with the new password.')
                
                self.statusBar().showMessage("Password changed successfully", 3000)
                
            except Exception as e:
                QMessageBox.critical(self, 'Password Change Failed', 
                                   f'Failed to change password:\n{str(e)}\n\n'
                                   'Your data is still protected with the old password.')
                self.statusBar().showMessage("Password change failed", 2000)
    
    def manage_environments(self):
        dialog = EnvironmentDialog(self.env_manager, self)
        if dialog.exec() == QDialog.DialogCode.Accepted:
            self.refresh_environment_combo()
    
    def clear_history(self):
        reply = QMessageBox.question(self, 'Clear History', 'Clear all request history?')
        if reply == QMessageBox.StandardButton.Yes:
            self.request_history.clear_history()
            self.history_widget.refresh_history()
    
    def check_ssl_certificate(self):
        url = self.url_input.text().strip()
        if not url:
            QMessageBox.warning(self, 'Warning', 'Please enter a URL')
            return
        
        if not url.startswith('https://'):
            QMessageBox.warning(self, 'Warning', 'SSL check requires HTTPS URL')
            return
        
        ssl_info = SSLManager.get_ssl_info(url)
        
        if 'error' in ssl_info:
            QMessageBox.warning(self, 'SSL Error', f"SSL verification failed: {ssl_info['error']}")
        else:
            info_text = f"""SSL Certificate Information for {url}:

Subject: {ssl_info.get('subject', {}).get('commonName', 'Unknown')}
Issuer: {ssl_info.get('issuer', {}).get('organizationName', 'Unknown')}
Valid From: {ssl_info.get('notBefore', 'Unknown')}
Valid To: {ssl_info.get('notAfter', 'Unknown')}
Serial Number: {ssl_info.get('serialNumber', 'Unknown')}
Version: {ssl_info.get('version', 'Unknown')}
"""
            
            if ssl_info.get('subjectAltName'):
                alt_names = [name[1] for name in ssl_info['subjectAltName']]
                info_text += f"\nSubject Alternative Names:\n{', '.join(alt_names)}"
            
            msg = QMessageBox(self)
            msg.setWindowTitle('SSL Certificate Info')
            msg.setText(info_text)
            msg.setIcon(QMessageBox.Icon.Information)
            msg.exec()
    
    def refresh_plugins(self):
        self.plugin_manager.load_plugins()
        QMessageBox.information(self, 'Plugins', f'Loaded {len(self.plugin_manager.plugins)} plugins')
    
    def run_plugin(self, plugin_name):
        if not hasattr(self, 'last_response_data'):
            QMessageBox.warning(self, 'Warning', 'No response data available for plugin')
            return
        
        request_data = {
            'method': self.method_combo.currentText(),
            'url': self.url_input.text(),
            'headers': self.headers_widget.get_headers(),
            'params': self.params_widget.get_params(),
            'body': self.body_widget.get_body()
        }
        
        result, error = self.plugin_manager.execute_plugin(plugin_name, request_data, self.last_response_data)
        
        if error:
            QMessageBox.critical(self, 'Plugin Error', f'Plugin execution failed: {error}')
        else:
            QMessageBox.information(self, 'Plugin Result', f'Plugin executed successfully: {result}')
    
    def load_request(self, request: RequestItem):
        self.current_request = request
        
        # Load request data into UI
        self.method_combo.setCurrentText(request.method)
        self.url_input.setText(request.url)
        self.headers_widget.set_headers(request.headers)
        self.params_widget.set_params(request.params)
        
        # Set body and request type
        self.body_widget.set_body(request.body, request.body_type, request.request_type)
        if request.request_type == 'GraphQL':
            self.body_widget.set_graphql_data(request.graphql_query, request.graphql_variables)
        
        self.auth_widget.set_auth_config(request.auth)
        self.pre_request_widget.set_script(request.pre_request_script)
        self.tests_widget.set_tests(request.tests)
        
        # Update code generator
        self.update_code_generator()
    
    def load_from_history(self, entry):
        # Load request data from history
        self.method_combo.setCurrentText(entry['method'])
        self.url_input.setText(entry['url'])
        self.headers_widget.set_headers(entry.get('headers', {}))
        self.params_widget.set_params(entry.get('params', {}))
        self.body_widget.set_body(entry.get('body', ''))
        
        # Update code generator
        self.update_code_generator()
    
    def save_current_request(self):
        current_url = self.url_input.text().strip()
        current_method = self.method_combo.currentText()
        
        if not self.current_request:
            # Create new request in first collection
            if not self.collection_manager.collections:
                self.create_collection()
            
            name, ok = QInputDialog.getText(self, 'Save Request', 'Request name:')
            if not ok or not name.strip():
                return
            
            request = RequestItem(name.strip())
            self.collection_manager.collections[0].requests.append(request)
            self.current_request = request
        else:
            # Check if URL or method has changed significantly
            url_changed = (self.current_request.url != current_url and 
                          current_url and 
                          self.current_request.url != '')
            method_changed = self.current_request.method != current_method
            
            if url_changed or method_changed:
                # Ask if user wants to save as new request
                reply = QMessageBox.question(
                    self, 'Request Changed', 
                    f'The {"URL" if url_changed else "method"} has changed.\n\n'
                    f'Current request: {self.current_request.name}\n'
                    f'Old: {self.current_request.method} {self.current_request.url}\n'
                    f'New: {current_method} {current_url}\n\n'
                    'Do you want to save this as a new request?',
                    QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No | QMessageBox.StandardButton.Cancel,
                    QMessageBox.StandardButton.Yes
                )
                
                if reply == QMessageBox.StandardButton.Cancel:
                    return
                elif reply == QMessageBox.StandardButton.Yes:
                    # Create new request
                    name, ok = QInputDialog.getText(self, 'Save New Request', 'Request name:',
                                                  text=f"{self.current_request.name} - Modified")
                    if not ok or not name.strip():
                        return
                    
                    # Find the collection containing the current request
                    parent_collection = None
                    for collection in self.collection_manager.collections:
                        if self.current_request in collection.requests:
                            parent_collection = collection
                            break
                        for folder in collection.folders:
                            if self.current_request in folder.requests:
                                parent_collection = collection
                                break
                    
                    if not parent_collection:
                        parent_collection = self.collection_manager.collections[0]
                    
                    # Create new request
                    new_request = RequestItem(name.strip())
                    parent_collection.requests.append(new_request)
                    self.current_request = new_request
                # If No, continue with updating existing request
        
        # Update request data
        self.current_request.method = current_method
        self.current_request.url = current_url
        self.current_request.headers = self.headers_widget.get_headers()
        self.current_request.params = self.params_widget.get_params()
        self.current_request.body = self.body_widget.get_body()
        self.current_request.body_type = self.body_widget.body_type.currentText()
        self.current_request.request_type = self.body_widget.get_request_type()
        self.current_request.graphql_query = self.body_widget.get_graphql_query()
        self.current_request.graphql_variables = self.body_widget.get_graphql_variables()
        self.current_request.auth = self.auth_widget.get_auth_config()
        self.current_request.pre_request_script = self.pre_request_widget.get_script()
        self.current_request.tests = self.tests_widget.get_tests()
        
        if self.parent_app:
            self.parent_app.save_all_data()
        self.collections_tree.refresh_collections()
        
        QMessageBox.information(self, 'Success', 'Request saved successfully')
    
    def closeEvent(self, event):
        """Handle application close event - ensure data is saved"""
        try:
            # Stop auto-save timer
            if hasattr(self, 'auto_save_timer'):
                self.auto_save_timer.stop()
            
            # Perform final save if we have encryption set up
            if self.master_password:
                # Save without asking - auto-save should handle this gracefully
                if self.parent_app:
                    self.parent_app.save_all_data()
                
                # Brief visual feedback
                self.statusBar().showMessage("Saving encrypted data...", 1000)
                QApplication.processEvents()
                
                # Small delay to ensure save completes
                import time
                time.sleep(0.2)
                
                self.statusBar().showMessage("Data saved successfully", 500)
                QApplication.processEvents()
            
            # Accept the close event
            event.accept()
            
        except Exception as e:
            # If save fails, warn user but allow exit
            reply = QMessageBox.warning(
                self, 'Save Error',
                f'Failed to save data: {str(e)}\n\nExit anyway?',
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                QMessageBox.StandardButton.No
            )
            
            if reply == QMessageBox.StandardButton.Yes:
                event.accept()
            else:
                event.ignore()
    
    def set_default_headers(self):
        # Add common headers by default
        headers_table = self.headers_widget.headers_table
        
        # Add Content-Type header
        if headers_table.rowCount() > 0:
            headers_table.setItem(0, 1, QTableWidgetItem('Content-Type'))
            headers_table.setItem(0, 2, QTableWidgetItem('application/json'))
    
    def update_code_generator(self):
        method = self.method_combo.currentText()
        url = self.url_input.text().strip()
        headers = self.headers_widget.get_headers()
        params = self.params_widget.get_params()
        body = self.body_widget.get_body()
        auth_config = self.auth_widget.get_auth_config()
        
        self.code_generator.update_request_data(method, url, headers, params, body, auth_config)
    
    def send_request(self):
        if self.http_worker and self.http_worker.isRunning():
            return
        
        # Execute pre-request script
        self.pre_request_widget.execute_script()
        
        method = self.method_combo.currentText()
        url = self.url_input.text().strip()
        request_type = self.body_widget.get_request_type()
        
        if not url:
            QMessageBox.warning(self, 'Warning', 'Please enter a URL')
            return
        
        if not url.startswith(('http://', 'https://', 'ws://', 'wss://')):
            if request_type == 'WebSocket':
                url = 'wss://' + url
            else:
                url = 'https://' + url
        
        # Handle WebSocket connections
        if request_type == 'WebSocket':
            self.body_widget.websocket_widget.ws_url_input.setText(url)
            self.body_widget.websocket_widget.connect_websocket()
            return
        
        # Apply environment variable substitution
        url = self.env_manager.substitute_variables(url)
        
        headers = self.headers_widget.get_headers()
        # Substitute variables in headers
        for key, value in headers.items():
            headers[key] = self.env_manager.substitute_variables(value)
        
        # Apply authentication
        auth_config = self.auth_widget.get_auth_config()
        auth_config.apply_to_headers(headers)
        
        params = self.params_widget.get_params()
        # Substitute variables in params
        for key, value in params.items():
            params[key] = self.env_manager.substitute_variables(value)
        
        body = self.body_widget.get_body()
        body = self.env_manager.substitute_variables(body)
        
        # GraphQL data
        graphql_query = self.body_widget.get_graphql_query()
        graphql_variables = self.body_widget.get_graphql_variables()
        
        # Update code generator
        self.code_generator.update_request_data(method, url, headers, params, body, auth_config)
        
        # Show progress
        self.progress_bar.setVisible(True)
        self.progress_bar.setRange(0, 0)  # Indeterminate progress
        self.send_button.setEnabled(False)
        
        # Clear previous response
        self.response_widget.clear_response()
        
        # Start HTTP request in worker thread
        self.http_worker = HttpWorker(method, url, headers, params, body, request_type, graphql_query, graphql_variables)
        self.http_worker.finished.connect(self.on_request_finished)
        self.http_worker.error.connect(self.on_request_error)
        self.http_worker.start()
    
    def on_request_finished(self, response_data):
        self.progress_bar.setVisible(False)
        self.send_button.setEnabled(True)
        self.response_widget.display_response(response_data)
        
        # Store for plugins
        self.last_response_data = response_data
        
        # Add to history
        method = self.method_combo.currentText()
        url = self.url_input.text().strip()
        headers = self.headers_widget.get_headers()
        params = self.params_widget.get_params()
        body = self.body_widget.get_body()
        
        self.request_history.add_request(method, url, headers, params, body, response_data)
        if self.parent_app:
            self.parent_app.save_all_data()
        self.history_widget.refresh_history()
        
        # Run tests
        self.tests_widget.set_response_data(response_data)
        if self.tests_widget.tests:
            self.tests_widget.run_tests()
    
    def on_request_error(self, error_message):
        self.progress_bar.setVisible(False)
        self.send_button.setEnabled(True)
        QMessageBox.critical(self, 'Request Error', f'Error: {error_message}')


def main():
    app = QApplication(sys.argv)
    
    # Create plugins directory if it doesn't exist
    if not os.path.exists('plugins'):
        os.makedirs('plugins')
        
        # Create a sample plugin
        sample_plugin = '''# Sample Plugin - Response Time Checker
# This plugin checks if response time is acceptable

if response_data:
    response_time = response_data.get('response_time', 0)
    if response_time > 2000:  # 2 seconds
        result = f"WARNING: Slow response time: {response_time:.2f}ms"
    else:
        result = f"OK: Response time: {response_time:.2f}ms"
else:
    result = "No response data available"
'''
        with open('plugins/response_time_checker.py', 'w') as f:
            f.write(sample_plugin)
    
    window = ApiTestingTool()
    window.show()
    sys.exit(app.exec())


if __name__ == '__main__':
    main()

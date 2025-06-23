"""
Connection Dialog
Dialog for adding/editing connections
"""

import os
from typing import Dict, Optional
from PyQt6.QtWidgets import *
from PyQt6.QtCore import *
from PyQt6.QtGui import *

from config_manager import ConfigManager


class ConnectionDialog(QDialog):
    """Dialog for creating/editing connections"""

    def __init__(self, config_manager: ConfigManager, parent=None, connection_data: Optional[Dict] = None):
        super().__init__(parent)
        self.config_manager = config_manager
        self.connection_data = connection_data or {}
        self.is_editing = connection_data is not None

        self.setWindowTitle("Edit Connection" if self.is_editing else "New Connection")
        self.setModal(True)
        self.resize(450, 400)

        self.setup_ui()
        self.populate_fields()
        self.apply_styling()

    def setup_ui(self):
        """Setup the dialog UI"""
        layout = QVBoxLayout(self)

        # Create tab widget for different sections
        tab_widget = QTabWidget()

        # General tab
        general_tab = self.create_general_tab()
        tab_widget.addTab(general_tab, "General")

        # Authentication tab
        auth_tab = self.create_authentication_tab()
        tab_widget.addTab(auth_tab, "Authentication")

        # Advanced tab
        advanced_tab = self.create_advanced_tab()
        tab_widget.addTab(advanced_tab, "Advanced")

        layout.addWidget(tab_widget)

        # Buttons
        button_layout = self.create_buttons()
        layout.addLayout(button_layout)

    def create_general_tab(self):
        """Create the general settings tab"""
        tab = QWidget()
        layout = QFormLayout(tab)

        # Connection name
        self.name_edit = QLineEdit()
        self.name_edit.setPlaceholderText("Enter connection name")
        layout.addRow("Name:", self.name_edit)

        # Protocol selection
        self.protocol_combo = QComboBox()
        self.protocol_combo.addItems(["SFTP", "FTP", "SCP", "Samba", "SSH", "NFS", "WebDAV"])
        self.protocol_combo.currentTextChanged.connect(self.on_protocol_changed)
        layout.addRow("Protocol:", self.protocol_combo)

        # Host
        self.host_edit = QLineEdit()
        self.host_edit.setPlaceholderText("hostname or IP address")
        layout.addRow("Host:", self.host_edit)

        # Port
        self.port_spin = QSpinBox()
        self.port_spin.setRange(1, 65535)
        self.port_spin.setValue(22)  # Default SSH/SFTP port
        layout.addRow("Port:", self.port_spin)

        # Username
        self.username_edit = QLineEdit()
        self.username_edit.setPlaceholderText("username")
        layout.addRow("Username:", self.username_edit)

        # Initial directory
        self.initial_dir_edit = QLineEdit()
        self.initial_dir_edit.setPlaceholderText("/home/user (optional)")
        layout.addRow("Initial Directory:", self.initial_dir_edit)

        return tab

    def create_authentication_tab(self):
        """Create the authentication settings tab"""
        tab = QWidget()
        layout = QVBoxLayout(tab)

        # Authentication method
        auth_group = QGroupBox("Authentication Method")
        auth_layout = QVBoxLayout(auth_group)

        self.auth_password_radio = QRadioButton("Password")
        self.auth_password_radio.setChecked(True)
        self.auth_password_radio.toggled.connect(self.on_auth_method_changed)
        auth_layout.addWidget(self.auth_password_radio)

        self.auth_key_radio = QRadioButton("Private Key")
        self.auth_key_radio.toggled.connect(self.on_auth_method_changed)
        auth_layout.addWidget(self.auth_key_radio)

        self.auth_agent_radio = QRadioButton("SSH Agent")
        auth_layout.addWidget(self.auth_agent_radio)

        layout.addWidget(auth_group)

        # Password section
        self.password_group = QGroupBox("Password")
        password_layout = QFormLayout(self.password_group)

        self.password_edit = QLineEdit()
        self.password_edit.setEchoMode(QLineEdit.EchoMode.Password)
        password_layout.addRow("Password:", self.password_edit)

        self.save_password_check = QCheckBox("Save password (stored encrypted)")
        password_layout.addRow("", self.save_password_check)

        layout.addWidget(self.password_group)

        # Private key section
        self.key_group = QGroupBox("Private Key")
        key_layout = QFormLayout(self.key_group)

        key_file_layout = QHBoxLayout()
        self.key_file_edit = QLineEdit()
        self.key_file_edit.setPlaceholderText("Path to private key file")
        key_file_layout.addWidget(self.key_file_edit)

        browse_key_button = QPushButton("Browse...")
        browse_key_button.clicked.connect(self.browse_key_file)
        key_file_layout.addWidget(browse_key_button)

        key_layout.addRow("Key File:", key_file_layout)

        self.key_passphrase_edit = QLineEdit()
        self.key_passphrase_edit.setEchoMode(QLineEdit.EchoMode.Password)
        self.key_passphrase_edit.setPlaceholderText("Passphrase (if required)")
        key_layout.addRow("Passphrase:", self.key_passphrase_edit)

        layout.addWidget(self.key_group)

        layout.addStretch()

        # Initially show password method
        self.on_auth_method_changed()

        return tab

    def create_advanced_tab(self):
        """Create the advanced settings tab"""
        tab = QWidget()
        layout = QFormLayout(tab)

        # Connection timeout
        self.timeout_spin = QSpinBox()
        self.timeout_spin.setRange(5, 300)
        self.timeout_spin.setValue(30)
        self.timeout_spin.setSuffix(" seconds")
        layout.addRow("Connection Timeout:", self.timeout_spin)

        # Keep alive
        self.keepalive_spin = QSpinBox()
        self.keepalive_spin.setRange(0, 300)
        self.keepalive_spin.setValue(60)
        self.keepalive_spin.setSuffix(" seconds")
        layout.addRow("Keep Alive:", self.keepalive_spin)

        # Transfer mode (for FTP)
        self.transfer_mode_combo = QComboBox()
        self.transfer_mode_combo.addItems(["Passive", "Active"])
        layout.addRow("Transfer Mode:", self.transfer_mode_combo)

        # Encoding
        self.encoding_combo = QComboBox()
        self.encoding_combo.addItems(["UTF-8", "ISO-8859-1", "Windows-1252"])
        layout.addRow("Character Encoding:", self.encoding_combo)

        # Use compression
        self.compression_check = QCheckBox("Enable compression")
        layout.addRow("", self.compression_check)

        # Auto connect
        self.auto_connect_check = QCheckBox("Connect automatically on startup")
        layout.addRow("", self.auto_connect_check)

        return tab

    def create_buttons(self):
        """Create dialog buttons"""
        button_layout = QHBoxLayout()
        button_layout.addStretch()

        # Test connection button
        test_button = QPushButton("Test Connection")
        test_button.clicked.connect(self.test_connection)
        button_layout.addWidget(test_button)

        # OK/Cancel buttons
        ok_button = QPushButton("OK")
        ok_button.clicked.connect(self.accept)
        ok_button.setDefault(True)
        button_layout.addWidget(ok_button)

        cancel_button = QPushButton("Cancel")
        cancel_button.clicked.connect(self.reject)
        button_layout.addWidget(cancel_button)

        return button_layout

    def on_protocol_changed(self, protocol):
        """Handle protocol change"""
        protocol = protocol.lower()

        # Set default port based on protocol
        default_ports = {
            'sftp': 22,
            'ssh': 22,
            'scp': 22,
            'ftp': 21,
            'samba': 445,
            'nfs': 2049,
            'webdav': 80
        }

        if protocol in default_ports:
            self.port_spin.setValue(default_ports[protocol])

        # Show/hide relevant options
        self.transfer_mode_combo.setVisible(protocol == 'ftp')

    def on_auth_method_changed(self):
        """Handle authentication method change"""
        if self.auth_password_radio.isChecked():
            self.password_group.setVisible(True)
            self.key_group.setVisible(False)
        elif self.auth_key_radio.isChecked():
            self.password_group.setVisible(False)
            self.key_group.setVisible(True)
        else:  # SSH Agent
            self.password_group.setVisible(False)
            self.key_group.setVisible(False)

    def browse_key_file(self):
        """Browse for private key file"""
        file_path, _ = QFileDialog.getOpenFileName(
            self, "Select Private Key File",
            os.path.expanduser("~/.ssh"),
            "All Files (*)"
        )
        if file_path:
            self.key_file_edit.setText(file_path)

    def populate_fields(self):
        """Populate fields with existing connection data"""
        if not self.connection_data:
            return

        # General tab
        self.name_edit.setText(self.connection_data.get('name', ''))

        protocol = self.connection_data.get('protocol', 'sftp').upper()
        index = self.protocol_combo.findText(protocol)
        if index >= 0:
            self.protocol_combo.setCurrentIndex(index)

        self.host_edit.setText(self.connection_data.get('host', ''))
        self.port_spin.setValue(self.connection_data.get('port', 22))
        self.username_edit.setText(self.connection_data.get('username', ''))
        self.initial_dir_edit.setText(self.connection_data.get('initial_directory', ''))

        # Authentication tab
        auth_method = self.connection_data.get('auth_method', 'password')
        if auth_method == 'password':
            self.auth_password_radio.setChecked(True)
            self.password_edit.setText(self.connection_data.get('password', ''))
            self.save_password_check.setChecked(self.connection_data.get('save_password', False))
        elif auth_method == 'private_key':
            self.auth_key_radio.setChecked(True)
            self.key_file_edit.setText(self.connection_data.get('private_key_file', ''))
            self.key_passphrase_edit.setText(self.connection_data.get('private_key_passphrase', ''))
        else:
            self.auth_agent_radio.setChecked(True)

        # Advanced tab
        self.timeout_spin.setValue(self.connection_data.get('timeout', 30))
        self.keepalive_spin.setValue(self.connection_data.get('keepalive', 60))

        transfer_mode = self.connection_data.get('transfer_mode', 'Passive')
        index = self.transfer_mode_combo.findText(transfer_mode)
        if index >= 0:
            self.transfer_mode_combo.setCurrentIndex(index)

        encoding = self.connection_data.get('encoding', 'UTF-8')
        index = self.encoding_combo.findText(encoding)
        if index >= 0:
            self.encoding_combo.setCurrentIndex(index)

        self.compression_check.setChecked(self.connection_data.get('use_compression', False))
        self.auto_connect_check.setChecked(self.connection_data.get('auto_connect', False))

        self.on_auth_method_changed()

    def get_connection_data(self) -> Dict:
        """Get connection data from form"""
        # Determine authentication method
        if self.auth_password_radio.isChecked():
            auth_method = 'password'
        elif self.auth_key_radio.isChecked():
            auth_method = 'private_key'
        else:
            auth_method = 'ssh_agent'

        data = {
            'name': self.name_edit.text().strip(),
            'protocol': self.protocol_combo.currentText().lower(),
            'host': self.host_edit.text().strip(),
            'port': self.port_spin.value(),
            'username': self.username_edit.text().strip(),
            'initial_directory': self.initial_dir_edit.text().strip(),
            'auth_method': auth_method,
            'timeout': self.timeout_spin.value(),
            'keepalive': self.keepalive_spin.value(),
            'transfer_mode': self.transfer_mode_combo.currentText(),
            'encoding': self.encoding_combo.currentText(),
            'use_compression': self.compression_check.isChecked(),
            'auto_connect': self.auto_connect_check.isChecked()
        }

        # Add authentication-specific fields
        if auth_method == 'password':
            if self.save_password_check.isChecked():
                data['password'] = self.password_edit.text()
            data['save_password'] = self.save_password_check.isChecked()
        elif auth_method == 'private_key':
            data['private_key_file'] = self.key_file_edit.text().strip()
            data['private_key_passphrase'] = self.key_passphrase_edit.text()

        return data

    def validate_form(self) -> bool:
        """Validate form data"""
        if not self.name_edit.text().strip():
            QMessageBox.warning(self, "Validation Error", "Connection name is required.")
            return False

        if not self.host_edit.text().strip():
            QMessageBox.warning(self, "Validation Error", "Host is required.")
            return False

        if not self.username_edit.text().strip():
            protocols_needing_username = ['sftp', 'scp', 'ssh', 'ftp', 'samba']
            if self.protocol_combo.currentText().lower() in protocols_needing_username:
                QMessageBox.warning(self, "Validation Error", "Username is required for this protocol.")
                return False

        if self.auth_key_radio.isChecked():
            if not self.key_file_edit.text().strip():
                QMessageBox.warning(self, "Validation Error", "Private key file is required.")
                return False
            if not os.path.exists(self.key_file_edit.text().strip()):
                QMessageBox.warning(self, "Validation Error", "Private key file does not exist.")
                return False

        return True

    def test_connection(self):
        """Test the connection"""
        if not self.validate_form():
            return

        connection_data = self.get_connection_data()

        # Show progress dialog
        progress = QProgressDialog("Testing connection...", "Cancel", 0, 0, self)
        progress.setWindowModality(Qt.WindowModality.WindowModal)
        progress.setAutoClose(True)
        progress.setAutoReset(True)
        progress.show()

        # Import connection manager for testing
        try:
            from connection_manager import ConnectionManager
            test_manager = ConnectionManager()

            # Test connection in background
            def test_result():
                try:
                    success = test_manager.test_connection(connection_data)
                    progress.close()

                    if success:
                        QMessageBox.information(self, "Test Connection",
                                                "✅ Connection test successful!")
                    else:
                        QMessageBox.warning(self, "Test Connection",
                                            "❌ Connection test failed. Please check your settings.")
                except Exception as e:
                    progress.close()
                    QMessageBox.critical(self, "Test Connection",
                                         f"❌ Connection test error:\n{str(e)}")

            # Run test after a short delay to show progress dialog
            QTimer.singleShot(500, test_result)

        except ImportError:
            progress.close()
            QMessageBox.information(self, "Test Connection",
                                    "Connection testing is not available. Please check if all "
                                    "required protocol libraries are installed.")
        except Exception as e:
            progress.close()
            QMessageBox.critical(self, "Test Connection",
                                 f"Test connection error: {str(e)}")

    def accept(self):
        """Accept dialog if form is valid"""
        if self.validate_form():
            super().accept()

    def apply_styling(self):
        """Apply styling to the dialog with high contrast"""
        self.setStyleSheet("""
            QDialog {
                background-color: #f0f0f0;
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                color: #000000;
                font-size: 9pt;
            }
            
            QTabWidget::pane {
                border: 1px solid #c0c0c0;
                background: #ffffff;
            }
            
            QTabBar::tab {
                background: qlineargradient(y1: 0, y2: 1, stop: 0 #f8f8f8, stop: 1 #e0e0e0);
                border: 1px solid #a0a0a0;
                padding: 4px 12px;
                margin-right: 2px;
                color: #000000;
            }
            
            QTabBar::tab:selected {
                background: #ffffff;
                border-bottom: 1px solid #ffffff;
                color: #000000;
            }
            
            QGroupBox {
                font-weight: bold;
                border: 1px solid #c0c0c0;
                border-radius: 4px;
                margin-top: 8px;
                padding-top: 4px;
                color: #000000;
                background: #ffffff;
            }
            
            QGroupBox::title {
                subcontrol-origin: margin;
                left: 10px;
                padding: 0 4px 0 4px;
                color: #000000;
                background: #f0f0f0;
            }
            
            QLineEdit, QSpinBox, QComboBox {
                padding: 4px;
                border: 1px solid #a0a0a0;
                border-radius: 2px;
                background: #ffffff;
                color: #000000;
                font-size: 9pt;
            }
            
            QLineEdit:focus, QSpinBox:focus, QComboBox:focus {
                border-color: #0066cc;
                color: #000000;
            }
            
            QComboBox::drop-down {
                border: none;
                background: #f0f0f0;
            }
            
            QComboBox::down-arrow {
                width: 10px;
                height: 10px;
            }
            
            QComboBox QAbstractItemView {
                background: #ffffff;
                color: #000000;
                border: 1px solid #a0a0a0;
                selection-background-color: #e3f2fd;
            }
            
            QPushButton {
                background: qlineargradient(y1: 0, y2: 1, stop: 0 #f8f8f8, stop: 1 #e0e0e0);
                border: 1px solid #a0a0a0;
                padding: 4px 12px;
                border-radius: 2px;
                min-width: 70px;
                color: #000000;
                font-size: 9pt;
            }
            
            QPushButton:hover {
                background: qlineargradient(y1: 0, y2: 1, stop: 0 #ffffff, stop: 1 #e8e8e8);
                color: #000000;
            }
            
            QPushButton:pressed {
                background: qlineargradient(y1: 0, y2: 1, stop: 0 #e0e0e0, stop: 1 #f0f0f0);
                color: #000000;
            }
            
            QPushButton:default {
                border: 2px solid #0066cc;
                color: #000000;
            }
            
            QRadioButton {
                color: #000000;
                font-size: 9pt;
            }
            
            QRadioButton::indicator {
                width: 13px;
                height: 13px;
            }
            
            QCheckBox {
                color: #000000;
                font-size: 9pt;
            }
            
            QCheckBox::indicator {
                width: 13px;
                height: 13px;
            }
            
            QLabel {
                color: #000000;
                background: transparent;
                font-size: 9pt;
            }
            
            QFormLayout QLabel {
                color: #000000;
            }
        """)
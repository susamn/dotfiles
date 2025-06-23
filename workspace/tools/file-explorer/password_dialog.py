"""
Password Dialog
Authentication dialog for encrypted configuration
"""

from PyQt6.QtWidgets import *
from PyQt6.QtCore import *
from PyQt6.QtGui import *


class PasswordDialog(QDialog):
    """Dialog for password authentication"""

    def __init__(self, is_first_time=False, parent=None):
        super().__init__(parent)
        self.is_first_time = is_first_time
        self.password = ""

        self.setWindowTitle("File Explorer - Authentication")
        self.setModal(True)
        self.setFixedSize(400, 280)
        self.setWindowFlags(Qt.WindowType.Dialog | Qt.WindowType.WindowTitleHint)

        self.setup_ui()
        self.apply_styling()

    def setup_ui(self):
        """Setup the password dialog UI"""
        layout = QVBoxLayout(self)
        layout.setSpacing(15)
        layout.setContentsMargins(20, 20, 20, 20)

        # Header
        header_layout = QHBoxLayout()

        # Icon
        icon_label = QLabel()
        icon_pixmap = self.style().standardIcon(QStyle.StandardPixmap.SP_DriveNetIcon).pixmap(48, 48)
        icon_label.setPixmap(icon_pixmap)
        header_layout.addWidget(icon_label)

        # Title and description
        title_layout = QVBoxLayout()

        title_label = QLabel("Multi-Protocol File Explorer")
        title_label.setStyleSheet("font-weight: bold; font-size: 14pt; color: #000000;")
        title_layout.addWidget(title_label)

        if self.is_first_time:
            desc_label = QLabel("Set up a master password to encrypt your connection data")
        else:
            desc_label = QLabel("Enter your master password to unlock stored connections")
        desc_label.setStyleSheet("color: #666666; font-size: 10pt;")
        desc_label.setWordWrap(True)
        title_layout.addWidget(desc_label)

        header_layout.addLayout(title_layout)
        header_layout.addStretch()

        layout.addLayout(header_layout)

        # Separator
        separator = QFrame()
        separator.setFrameShape(QFrame.Shape.HLine)
        separator.setFrameShadow(QFrame.Shadow.Sunken)
        layout.addWidget(separator)

        # Password input
        password_group = QGroupBox("Authentication")
        password_layout = QFormLayout(password_group)

        self.password_edit = QLineEdit()
        self.password_edit.setEchoMode(QLineEdit.EchoMode.Password)
        self.password_edit.setPlaceholderText("Enter master password...")
        self.password_edit.returnPressed.connect(self.authenticate)
        password_layout.addRow("Password:", self.password_edit)

        if self.is_first_time:
            self.confirm_password_edit = QLineEdit()
            self.confirm_password_edit.setEchoMode(QLineEdit.EchoMode.Password)
            self.confirm_password_edit.setPlaceholderText("Confirm password...")
            self.confirm_password_edit.returnPressed.connect(self.authenticate)
            password_layout.addRow("Confirm:", self.confirm_password_edit)

        # Show/hide password checkbox
        self.show_password_check = QCheckBox("Show password")
        self.show_password_check.toggled.connect(self.toggle_password_visibility)
        password_layout.addRow("", self.show_password_check)

        layout.addWidget(password_group)

        # Security notice
        if self.is_first_time:
            notice_label = QLabel("⚠️ Important: This password cannot be recovered if lost. "
                                  "All connection data will be permanently encrypted.")
            notice_label.setStyleSheet("color: #d32f2f; font-size: 9pt; background: #fff5f5; "
                                       "padding: 8px; border: 1px solid #d32f2f; border-radius: 4px;")
            notice_label.setWordWrap(True)
            layout.addWidget(notice_label)

        layout.addStretch()

        # Buttons
        button_layout = QHBoxLayout()

        if not self.is_first_time:
            self.skip_button = QPushButton("Skip (Use without encryption)")
            self.skip_button.clicked.connect(self.skip_authentication)
            button_layout.addWidget(self.skip_button)

        button_layout.addStretch()

        self.ok_button = QPushButton("Continue" if self.is_first_time else "Unlock")
        self.ok_button.clicked.connect(self.authenticate)
        self.ok_button.setDefault(True)
        button_layout.addWidget(self.ok_button)

        if not self.is_first_time:
            self.reset_button = QPushButton("Reset Configuration")
            self.reset_button.clicked.connect(self.reset_configuration)
            self.reset_button.setStyleSheet("QPushButton { color: #d32f2f; }")
            button_layout.addWidget(self.reset_button)

        layout.addLayout(button_layout)

        # Set focus
        self.password_edit.setFocus()

    def toggle_password_visibility(self, show):
        """Toggle password visibility"""
        echo_mode = QLineEdit.EchoMode.Normal if show else QLineEdit.EchoMode.Password
        self.password_edit.setEchoMode(echo_mode)
        if hasattr(self, 'confirm_password_edit'):
            self.confirm_password_edit.setEchoMode(echo_mode)

    def authenticate(self):
        """Handle authentication"""
        password = self.password_edit.text()

        if not password:
            QMessageBox.warning(self, "Warning", "Please enter a password.")
            return

        if self.is_first_time:
            # First time setup - verify password confirmation
            confirm_password = self.confirm_password_edit.text()

            if password != confirm_password:
                QMessageBox.warning(self, "Warning", "Passwords do not match.")
                return

            if len(password) < 6:
                QMessageBox.warning(self, "Warning",
                                    "Password must be at least 6 characters long.")
                return

        self.password = password
        self.accept()

    def skip_authentication(self):
        """Skip authentication and use without encryption"""
        reply = QMessageBox.question(
            self, "Skip Authentication",
            "Are you sure you want to continue without encryption?\n\n"
            "Your connection data will not be encrypted and any existing "
            "encrypted data will not be accessible.",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No
        )

        if reply == QMessageBox.StandardButton.Yes:
            self.password = None  # Signal to use non-encrypted mode
            self.accept()

    def reset_configuration(self):
        """Reset all configuration"""
        reply = QMessageBox.warning(
            self, "Reset Configuration",
            "⚠️ WARNING: This will permanently delete ALL encrypted configuration data!\n\n"
            "This includes:\n"
            "• All saved connections\n"
            "• Application settings\n"
            "• Transfer history\n\n"
            "This action CANNOT be undone!\n\n"
            "Are you absolutely sure you want to continue?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No
        )

        if reply == QMessageBox.StandardButton.Yes:
            # Second confirmation
            text, ok = QInputDialog.getText(
                self, "Confirm Reset",
                "Type 'RESET' to confirm permanent deletion of all data:",
                QLineEdit.EchoMode.Normal
            )

            if ok and text == "RESET":
                self.password = "RESET_CONFIG"  # Special signal
                self.accept()
            else:
                QMessageBox.information(self, "Reset Cancelled", "Configuration reset cancelled.")

    def get_password(self):
        """Get the entered password"""
        return self.password

    def apply_styling(self):
        """Apply styling to the dialog"""
        self.setStyleSheet("""
            QDialog {
                background-color: #f5f5f5;
                color: #000000;
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                font-size: 9pt;
            }
            
            QGroupBox {
                font-weight: bold;
                border: 2px solid #c0c0c0;
                border-radius: 6px;
                margin-top: 12px;
                padding-top: 8px;
                color: #000000;
                background: #ffffff;
            }
            
            QGroupBox::title {
                subcontrol-origin: margin;
                left: 15px;
                padding: 0 8px 0 8px;
                color: #000000;
                background: #f5f5f5;
                font-size: 10pt;
            }
            
            QLineEdit {
                padding: 8px 12px;
                border: 2px solid #c0c0c0;
                border-radius: 4px;
                background: #ffffff;
                color: #000000;
                font-size: 10pt;
                min-height: 20px;
            }
            
            QLineEdit:focus {
                border-color: #0066cc;
                background: #ffffff;
            }
            
            QPushButton {
                background: qlineargradient(y1: 0, y2: 1, stop: 0 #ffffff, stop: 1 #e8e8e8);
                border: 2px solid #a0a0a0;
                padding: 8px 16px;
                border-radius: 4px;
                min-width: 80px;
                color: #000000;
                font-size: 9pt;
                font-weight: bold;
            }
            
            QPushButton:hover {
                background: qlineargradient(y1: 0, y2: 1, stop: 0 #ffffff, stop: 1 #f0f0f0);
                border-color: #0066cc;
            }
            
            QPushButton:pressed {
                background: qlineargradient(y1: 0, y2: 1, stop: 0 #e8e8e8, stop: 1 #f0f0f0);
            }
            
            QPushButton:default {
                border: 2px solid #0066cc;
                background: qlineargradient(y1: 0, y2: 1, stop: 0 #e3f2fd, stop: 1 #bbdefb);
            }
            
            QCheckBox {
                color: #000000;
                font-size: 9pt;
            }
            
            QCheckBox::indicator {
                width: 16px;
                height: 16px;
                border: 1px solid #a0a0a0;
                background: #ffffff;
            }
            
            QCheckBox::indicator:checked {
                background: #0066cc;
                border-color: #0066cc;
            }
            
            QLabel {
                color: #000000;
                background: transparent;
            }
            
            QFormLayout QLabel {
                color: #000000;
                font-weight: bold;
            }
            
            QFrame {
                color: #c0c0c0;
            }
        """)


class ChangePasswordDialog(QDialog):
    """Dialog for changing master password"""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.old_password = ""
        self.new_password = ""

        self.setWindowTitle("Change Master Password")
        self.setModal(True)
        self.setFixedSize(400, 250)

        self.setup_ui()
        self.apply_styling()

    def setup_ui(self):
        """Setup the change password dialog"""
        layout = QVBoxLayout(self)
        layout.setSpacing(15)
        layout.setContentsMargins(20, 20, 20, 20)

        # Description
        desc_label = QLabel("Change your master password. All encrypted data will be "
                            "re-encrypted with the new password.")
        desc_label.setWordWrap(True)
        desc_label.setStyleSheet("color: #666666; font-size: 10pt;")
        layout.addWidget(desc_label)

        # Password inputs
        password_group = QGroupBox("Password Change")
        password_layout = QFormLayout(password_group)

        self.old_password_edit = QLineEdit()
        self.old_password_edit.setEchoMode(QLineEdit.EchoMode.Password)
        self.old_password_edit.setPlaceholderText("Current password...")
        password_layout.addRow("Current Password:", self.old_password_edit)

        self.new_password_edit = QLineEdit()
        self.new_password_edit.setEchoMode(QLineEdit.EchoMode.Password)
        self.new_password_edit.setPlaceholderText("New password...")
        password_layout.addRow("New Password:", self.new_password_edit)

        self.confirm_password_edit = QLineEdit()
        self.confirm_password_edit.setEchoMode(QLineEdit.EchoMode.Password)
        self.confirm_password_edit.setPlaceholderText("Confirm new password...")
        password_layout.addRow("Confirm New:", self.confirm_password_edit)

        layout.addWidget(password_group)

        layout.addStretch()

        # Buttons
        button_layout = QHBoxLayout()
        button_layout.addStretch()

        ok_button = QPushButton("Change Password")
        ok_button.clicked.connect(self.change_password)
        ok_button.setDefault(True)
        button_layout.addWidget(ok_button)

        cancel_button = QPushButton("Cancel")
        cancel_button.clicked.connect(self.reject)
        button_layout.addWidget(cancel_button)

        layout.addLayout(button_layout)

        self.old_password_edit.setFocus()

    def change_password(self):
        """Handle password change"""
        old_password = self.old_password_edit.text()
        new_password = self.new_password_edit.text()
        confirm_password = self.confirm_password_edit.text()

        if not old_password:
            QMessageBox.warning(self, "Warning", "Please enter your current password.")
            return

        if not new_password:
            QMessageBox.warning(self, "Warning", "Please enter a new password.")
            return

        if new_password != confirm_password:
            QMessageBox.warning(self, "Warning", "New passwords do not match.")
            return

        if len(new_password) < 6:
            QMessageBox.warning(self, "Warning",
                                "New password must be at least 6 characters long.")
            return

        self.old_password = old_password
        self.new_password = new_password
        self.accept()

    def get_passwords(self):
        """Get the old and new passwords"""
        return self.old_password, self.new_password

    def apply_styling(self):
        """Apply styling"""
        self.setStyleSheet("""
            QDialog {
                background-color: #f5f5f5;
                color: #000000;
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                font-size: 9pt;
            }
            
            QGroupBox {
                font-weight: bold;
                border: 2px solid #c0c0c0;
                border-radius: 6px;
                margin-top: 12px;
                padding-top: 8px;
                color: #000000;
                background: #ffffff;
            }
            
            QGroupBox::title {
                subcontrol-origin: margin;
                left: 15px;
                padding: 0 8px 0 8px;
                color: #000000;
                background: #f5f5f5;
            }
            
            QLineEdit {
                padding: 8px 12px;
                border: 2px solid #c0c0c0;
                border-radius: 4px;
                background: #ffffff;
                color: #000000;
                font-size: 10pt;
            }
            
            QLineEdit:focus {
                border-color: #0066cc;
            }
            
            QPushButton {
                background: qlineargradient(y1: 0, y2: 1, stop: 0 #ffffff, stop: 1 #e8e8e8);
                border: 2px solid #a0a0a0;
                padding: 8px 16px;
                border-radius: 4px;
                min-width: 80px;
                color: #000000;
                font-weight: bold;
            }
            
            QPushButton:hover {
                background: qlineargradient(y1: 0, y2: 1, stop: 0 #ffffff, stop: 1 #f0f0f0);
                border-color: #0066cc;
            }
            
            QPushButton:default {
                border: 2px solid #0066cc;
                background: qlineargradient(y1: 0, y2: 1, stop: 0 #e3f2fd, stop: 1 #bbdefb);
            }
            
            QLabel {
                color: #000000;
                background: transparent;
            }
        """)
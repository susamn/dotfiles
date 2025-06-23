"""
Connection Panel
Left panel for managing connections
"""

from typing import Dict, List, Optional
from PyQt6.QtWidgets import *
from PyQt6.QtCore import *
from PyQt6.QtGui import *

from config_manager import ConfigManager
from transfer_manager import TransferManager
from connection_dialog import ConnectionDialog


class ConnectionPanel(QWidget):
    """Left panel for managing connections"""

    connection_selected = pyqtSignal(str)  # connection_name
    connection_status_changed = pyqtSignal(str, bool)  # connection_name, connected

    def __init__(self, config_manager: ConfigManager, transfer_manager: TransferManager):
        super().__init__()
        self.config_manager = config_manager
        self.transfer_manager = transfer_manager
        self.connections = {}  # name -> connection_object

        self.setup_ui()
        self.setup_context_menu()

    def setup_ui(self):
        """Setup the connection panel UI"""
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        # Header
        header = self.create_header()
        layout.addWidget(header)

        # Connection list
        self.connection_list = QListWidget()
        self.connection_list.setAlternatingRowColors(True)
        self.connection_list.itemClicked.connect(self.on_connection_clicked)
        self.connection_list.itemDoubleClicked.connect(self.connect_selected)
        layout.addWidget(self.connection_list)

        # Apply styling
        self.apply_styling()

    def create_header(self):
        """Create the header with title and buttons"""
        header = QWidget()
        header_layout = QVBoxLayout(header)
        header_layout.setContentsMargins(8, 8, 8, 8)

        # Title and buttons row
        title_row = QHBoxLayout()

        title_label = QLabel("Connections")
        title_label.setStyleSheet("font-weight: bold; font-size: 12px;")
        title_row.addWidget(title_label)

        title_row.addStretch()

        # Add connection button
        add_button = QPushButton("+")
        add_button.setFixedSize(24, 24)
        add_button.setToolTip("Add new connection")
        add_button.clicked.connect(self.add_connection)
        title_row.addWidget(add_button)

        header_layout.addLayout(title_row)

        # Connection actions row
        actions_row = QHBoxLayout()

        self.connect_button = QPushButton("Connect")
        self.connect_button.setEnabled(False)
        self.connect_button.clicked.connect(self.connect_selected)
        actions_row.addWidget(self.connect_button)

        self.disconnect_button = QPushButton("Disconnect")
        self.disconnect_button.setEnabled(False)
        self.disconnect_button.clicked.connect(self.disconnect_selected)
        actions_row.addWidget(self.disconnect_button)

        header_layout.addLayout(actions_row)

        return header

    def setup_context_menu(self):
        """Setup context menu for connection list"""
        self.connection_list.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.connection_list.customContextMenuRequested.connect(self.show_context_menu)

    def show_context_menu(self, position):
        """Show context menu for connections"""
        item = self.connection_list.itemAt(position)
        if not item:
            return

        menu = QMenu(self)

        # Connect/Disconnect
        connection_name = item.text().split(" [")[0]  # Remove status part
        if self.is_connected(connection_name):
            menu.addAction("Disconnect", lambda: self.disconnect_connection(connection_name))
        else:
            menu.addAction("Connect", lambda: self.connect_connection(connection_name))

        menu.addSeparator()

        # Edit/Delete
        menu.addAction("Edit...", lambda: self.edit_connection(connection_name))
        menu.addAction("Duplicate", lambda: self.duplicate_connection(connection_name))
        menu.addSeparator()
        menu.addAction("Delete", lambda: self.delete_connection(connection_name))

        menu.exec(self.connection_list.mapToGlobal(position))

    def load_connections(self):
        """Load connections from config"""
        self.connection_list.clear()

        for conn_data in self.config_manager.connections:
            self.add_connection_item(conn_data)

    def add_connection_item(self, conn_data: Dict):
        """Add a connection item to the list"""
        name = conn_data['name']
        protocol = conn_data['protocol'].upper()
        host = conn_data['host']

        # Create list item
        item_text = f"{name} [{protocol}]"
        item = QListWidgetItem(item_text)

        # Set icon based on protocol
        icon = self.get_protocol_icon(conn_data['protocol'])
        item.setIcon(icon)

        # Set tooltip
        tooltip = f"Name: {name}\nProtocol: {protocol}\nHost: {host}"
        if 'port' in conn_data:
            tooltip += f"\nPort: {conn_data['port']}"
        if 'username' in conn_data:
            tooltip += f"\nUsername: {conn_data['username']}"
        item.setToolTip(tooltip)

        # Store connection data
        item.setData(Qt.ItemDataRole.UserRole, conn_data)

        self.connection_list.addItem(item)

    def get_protocol_icon(self, protocol: str) -> QIcon:
        """Get icon for protocol"""
        # Use standard icons for now
        icon_map = {
            'sftp': QStyle.StandardPixmap.SP_DriveNetIcon,
            'ftp': QStyle.StandardPixmap.SP_DriveNetIcon,
            'scp': QStyle.StandardPixmap.SP_ComputerIcon,
            'samba': QStyle.StandardPixmap.SP_DirIcon,
            'ssh': QStyle.StandardPixmap.SP_ComputerIcon,
            'nfs': QStyle.StandardPixmap.SP_DriveNetIcon,
            'webdav': QStyle.StandardPixmap.SP_DriveNetIcon,
        }

        standard_pixmap = icon_map.get(protocol, QStyle.StandardPixmap.SP_ComputerIcon)
        return self.style().standardIcon(standard_pixmap)

    def on_connection_clicked(self, item):
        """Handle connection selection"""
        conn_data = item.data(Qt.ItemDataRole.UserRole)
        if conn_data:
            connection_name = conn_data['name']
            self.connection_selected.emit(connection_name)

            # Update button states
            is_connected = self.is_connected(connection_name)
            self.connect_button.setEnabled(not is_connected)
            self.disconnect_button.setEnabled(is_connected)

    def add_connection(self):
        """Show dialog to add new connection"""
        dialog = ConnectionDialog(self.config_manager, self)
        if dialog.exec() == QDialog.DialogCode.Accepted:
            conn_data = dialog.get_connection_data()
            if self.config_manager.add_connection(conn_data):
                self.add_connection_item(conn_data)
            else:
                QMessageBox.warning(self, "Error", "Failed to add connection. Name may already exist.")

    def edit_connection(self, connection_name: str):
        """Edit an existing connection"""
        conn_data = self.config_manager.get_connection(connection_name)
        if not conn_data:
            return

        dialog = ConnectionDialog(self.config_manager, self, conn_data)
        if dialog.exec() == QDialog.DialogCode.Accepted:
            updated_data = dialog.get_connection_data()
            if self.config_manager.update_connection(connection_name, updated_data):
                self.load_connections()  # Refresh the list

    def duplicate_connection(self, connection_name: str):
        """Duplicate an existing connection"""
        conn_data = self.config_manager.get_connection(connection_name)
        if not conn_data:
            return

        # Create copy with new name
        conn_data['name'] = f"{conn_data['name']} (Copy)"

        dialog = ConnectionDialog(self.config_manager, self, conn_data)
        if dialog.exec() == QDialog.DialogCode.Accepted:
            new_data = dialog.get_connection_data()
            if self.config_manager.add_connection(new_data):
                self.add_connection_item(new_data)

    def delete_connection(self, connection_name: str):
        """Delete a connection"""
        reply = QMessageBox.question(
            self, "Confirm Delete",
            f"Are you sure you want to delete connection '{connection_name}'?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        )

        if reply == QMessageBox.StandardButton.Yes:
            if self.config_manager.remove_connection(connection_name):
                self.load_connections()  # Refresh the list

    def connect_selected(self):
        """Connect to selected connection"""
        current_item = self.connection_list.currentItem()
        if current_item:
            conn_data = current_item.data(Qt.ItemDataRole.UserRole)
            if conn_data:
                self.connect_connection(conn_data['name'])

    def disconnect_selected(self):
        """Disconnect selected connection"""
        current_item = self.connection_list.currentItem()
        if current_item:
            conn_data = current_item.data(Qt.ItemDataRole.UserRole)
            if conn_data:
                self.disconnect_connection(conn_data['name'])

    def connect_connection(self, connection_name: str):
        """Connect to a specific connection"""
        conn_data = self.config_manager.get_connection(connection_name)
        if not conn_data:
            return

        try:
            # Import the appropriate protocol module
            protocol = conn_data['protocol']
            module_name = f"protocols.{protocol}_protocol"

            # For now, just simulate connection
            # TODO: Implement actual protocol connections
            self.connections[connection_name] = {"connected": True, "data": conn_data}

            # Update UI
            self.update_connection_status(connection_name, True)
            self.config_manager.update_last_used(connection_name)

            # Emit signal
            self.connection_status_changed.emit(connection_name, True)

        except Exception as e:
            QMessageBox.critical(self, "Connection Error", f"Failed to connect: {str(e)}")

    def disconnect_connection(self, connection_name: str):
        """Disconnect from a specific connection"""
        if connection_name in self.connections:
            # TODO: Properly close connection
            del self.connections[connection_name]

            # Update UI
            self.update_connection_status(connection_name, False)

            # Emit signal
            self.connection_status_changed.emit(connection_name, False)

    def update_connection_status(self, connection_name: str, connected: bool):
        """Update visual status of connection"""
        for i in range(self.connection_list.count()):
            item = self.connection_list.item(i)
            conn_data = item.data(Qt.ItemDataRole.UserRole)

            if conn_data and conn_data['name'] == connection_name:
                # Update item text
                name = conn_data['name']
                protocol = conn_data['protocol'].upper()
                status = " [Connected]" if connected else ""
                item.setText(f"{name} [{protocol}]{status}")

                # Update item color - use proper QBrush
                if connected:
                    item.setForeground(QBrush(QColor(0, 128, 0)))  # Green for connected
                else:
                    item.setForeground(QBrush(QColor(0, 0, 0)))    # Black for disconnected

                # Update buttons if this is the selected item
                if item == self.connection_list.currentItem():
                    self.connect_button.setEnabled(not connected)
                    self.disconnect_button.setEnabled(connected)

                break

    def is_connected(self, connection_name: str) -> bool:
        """Check if connection is active"""
        return connection_name in self.connections

    def disconnect_all(self):
        """Disconnect all active connections"""
        for connection_name in list(self.connections.keys()):
            self.disconnect_connection(connection_name)

    def apply_styling(self):
        """Apply Windows-style theme with high contrast"""
        self.setStyleSheet("""
            QWidget {
                background-color: #f8f8f8;
                border: none;
                color: #000000;
                font-size: 9pt;
            }
            
            QListWidget {
                background: #ffffff;
                border: 1px solid #c0c0c0;
                alternate-background-color: #f5f5f5;
                selection-background-color: #e3f2fd;
                outline: none;
                color: #000000;
            }
            
            QListWidget::item {
                padding: 4px 8px;
                border-bottom: 1px solid #e0e0e0;
                color: #000000;
            }
            
            QListWidget::item:selected {
                background: #e3f2fd;
                color: #000000;
            }
            
            QListWidget::item:hover {
                background: #f0f8ff;
                color: #000000;
            }
            
            QPushButton {
                background: qlineargradient(y1: 0, y2: 1, stop: 0 #f8f8f8, stop: 1 #e0e0e0);
                border: 1px solid #a0a0a0;
                padding: 4px 12px;
                border-radius: 2px;
                font-size: 9pt;
                color: #000000;
            }
            
            QPushButton:hover {
                background: qlineargradient(y1: 0, y2: 1, stop: 0 #ffffff, stop: 1 #e8e8e8);
                color: #000000;
            }
            
            QPushButton:pressed {
                background: qlineargradient(y1: 0, y2: 1, stop: 0 #e0e0e0, stop: 1 #f0f0f0);
                color: #000000;
            }
            
            QPushButton:disabled {
                background: #f0f0f0;
                color: #a0a0a0;
                border-color: #d0d0d0;
            }
            
            QLabel {
                color: #000000;
                background: transparent;
            }
        """)
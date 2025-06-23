"""
File Explorer Panel
Right panel for browsing files
"""

import os
from typing import Optional, List, Dict
from PyQt6.QtWidgets import *
from PyQt6.QtCore import *
from PyQt6.QtGui import *

from transfer_manager import TransferManager, TransferType


class FileItem:
    """Represents a file or directory"""
    def __init__(self, name: str, path: str, is_dir: bool, size: int = 0,
                 modified: Optional[str] = None, permissions: str = ""):
        self.name = name
        self.path = path
        self.is_dir = is_dir
        self.size = size
        self.modified = modified
        self.permissions = permissions


class FileExplorerPanel(QWidget):
    """Main file explorer panel with dual panes"""

    def __init__(self, transfer_manager: TransferManager):
        super().__init__()
        self.transfer_manager = transfer_manager
        self.left_connection = None
        self.right_connection = None
        self.current_left_path = "/"
        self.current_right_path = "/"

        self.setup_ui()
        self.apply_styling()

    def setup_ui(self):
        """Setup the file explorer UI"""
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        # Create splitter for dual panes
        splitter = QSplitter(Qt.Orientation.Horizontal)

        # Left pane
        left_pane = self.create_file_pane("left")
        splitter.addWidget(left_pane)

        # Right pane
        right_pane = self.create_file_pane("right")
        splitter.addWidget(right_pane)

        # Equal split
        splitter.setSizes([700, 700])

        layout.addWidget(splitter)

    def create_file_pane(self, side: str):
        """Create a file pane (left or right)"""
        pane = QWidget()
        layout = QVBoxLayout(pane)
        layout.setContentsMargins(4, 4, 4, 4)
        layout.setSpacing(2)

        # Header with path and controls
        header = self.create_pane_header(side)
        layout.addWidget(header)

        # File list
        file_list = self.create_file_list(side)
        layout.addWidget(file_list)

        # Store references
        if side == "left":
            self.left_pane = pane
            self.left_file_list = file_list
        else:
            self.right_pane = pane
            self.right_file_list = file_list

        return pane

    def create_pane_header(self, side: str):
        """Create pane header with path and navigation"""
        header = QWidget()
        layout = QHBoxLayout(header)
        layout.setContentsMargins(0, 0, 0, 0)

        # Navigation buttons
        back_button = QPushButton("←")
        back_button.setFixedSize(24, 24)
        back_button.setToolTip("Back")
        layout.addWidget(back_button)

        forward_button = QPushButton("→")
        forward_button.setFixedSize(24, 24)
        forward_button.setToolTip("Forward")
        layout.addWidget(forward_button)

        up_button = QPushButton("↑")
        up_button.setFixedSize(24, 24)
        up_button.setToolTip("Up")
        up_button.clicked.connect(lambda: self.navigate_up(side))
        layout.addWidget(up_button)

        # Path bar
        path_edit = QLineEdit()
        path_edit.setText("/")
        path_edit.returnPressed.connect(lambda: self.navigate_to_path(side, path_edit.text()))
        layout.addWidget(path_edit)

        # Refresh button
        refresh_button = QPushButton("⟳")
        refresh_button.setFixedSize(24, 24)
        refresh_button.setToolTip("Refresh")
        refresh_button.clicked.connect(lambda: self.refresh_pane(side))
        layout.addWidget(refresh_button)

        # Store references
        if side == "left":
            self.left_path_edit = path_edit
        else:
            self.right_path_edit = path_edit

        return header

    def create_file_list(self, side: str):
        """Create file list widget"""
        file_list = QTreeWidget()

        # Setup columns
        file_list.setHeaderLabels(["Name", "Size", "Modified", "Permissions"])
        file_list.setRootIsDecorated(False)
        file_list.setAlternatingRowColors(True)
        file_list.setSortingEnabled(True)
        file_list.sortByColumn(0, Qt.SortOrder.AscendingOrder)

        # Set column widths
        header = file_list.header()
        header.resizeSection(0, 200)  # Name
        header.resizeSection(1, 80)   # Size
        header.resizeSection(2, 120)  # Modified
        header.resizeSection(3, 80)   # Permissions

        # Enable drag and drop
        file_list.setDragDropMode(QAbstractItemView.DragDropMode.DragDrop)
        file_list.setDefaultDropAction(Qt.DropAction.CopyAction)

        # Connect signals
        file_list.itemDoubleClicked.connect(lambda item: self.on_item_double_clicked(side, item))
        file_list.itemSelectionChanged.connect(lambda: self.on_selection_changed(side))

        # Setup context menu
        file_list.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        file_list.customContextMenuRequested.connect(lambda pos: self.show_context_menu(side, pos))

        return file_list

    def set_connection(self, connection_name: str):
        """Set the active connection"""
        # For now, set both panes to the same connection
        # TODO: Allow different connections per pane
        self.left_connection = connection_name
        self.right_connection = connection_name

        # Load initial directory
        self.refresh_pane("left")
        self.refresh_pane("right")

    def refresh_pane(self, side: str):
        """Refresh a file pane"""
        if side == "left":
            file_list = self.left_file_list
            connection = self.left_connection
            current_path = self.current_left_path
        else:
            file_list = self.right_file_list
            connection = self.right_connection
            current_path = self.current_right_path

        if not connection:
            file_list.clear()
            return

        # Clear current items
        file_list.clear()

        # Load files for current path
        files = self.get_files_for_path(connection, current_path)

        # Add files to list
        for file_item in files:
            tree_item = QTreeWidgetItem()

            # Set icon based on type
            if file_item.is_dir:
                icon = self.style().standardIcon(QStyle.StandardPixmap.SP_DirIcon)
            else:
                icon = self.style().standardIcon(QStyle.StandardPixmap.SP_FileIcon)
            tree_item.setIcon(0, icon)

            # Set data
            tree_item.setText(0, file_item.name)
            tree_item.setText(1, self.format_file_size(file_item.size) if not file_item.is_dir else "")
            tree_item.setText(2, file_item.modified or "")
            tree_item.setText(3, file_item.permissions)

            # Store file data
            tree_item.setData(0, Qt.ItemDataRole.UserRole, file_item)

            file_list.addTopLevelItem(tree_item)

        # Update path display
        if side == "left":
            self.left_path_edit.setText(current_path)
        else:
            self.right_path_edit.setText(current_path)

    def get_files_for_path(self, connection: str, path: str) -> List[FileItem]:
        """Get files for a given path using the protocol implementation"""
        files = []

        # Check if we have an active connection
        # This would normally come from the connection manager
        # For now, we'll return mock data, but this is where protocol integration happens

        try:
            # TODO: Get the actual protocol instance from connection manager
            # protocol = self.connection_manager.get_protocol(connection)
            # if protocol and protocol.is_connected():
            #     file_infos = protocol.list_directory(path)
            #     for file_info in file_infos:
            #         files.append(FileItem(
            #             file_info.name,
            #             file_info.path,
            #             file_info.is_directory,
            #             file_info.size,
            #             file_info.modified_time.strftime("%Y-%m-%d %H:%M") if file_info.modified_time else "",
            #             file_info.permissions
            #         ))
            #     return files

            # Mock data for demonstration
            # Add parent directory entry (except for root)
            if path != "/" and path != "":
                parent_path = os.path.dirname(path) or "/"
                files.append(FileItem("..", parent_path, True))

            # Add some mock files and directories
            mock_items = [
                FileItem("Documents", f"{path.rstrip('/')}/Documents", True, 0, "2024-01-15 10:30", "drwxr-xr-x"),
                FileItem("Downloads", f"{path.rstrip('/')}/Downloads", True, 0, "2024-01-16 14:20", "drwxr-xr-x"),
                FileItem("file1.txt", f"{path.rstrip('/')}/file1.txt", False, 1024, "2024-01-15 09:15", "-rw-r--r--"),
                FileItem("image.jpg", f"{path.rstrip('/')}/image.jpg", False, 2048576, "2024-01-14 16:45", "-rw-r--r--"),
                FileItem("script.py", f"{path.rstrip('/')}/script.py", False, 4096, "2024-01-16 11:30", "-rwxr-xr-x"),
            ]

            files.extend(mock_items)

        except Exception as e:
            # Handle protocol errors
            print(f"Error listing directory {path}: {e}")

        return files

    def format_file_size(self, size: int) -> str:
        """Format file size in human readable format"""
        if size < 1024:
            return f"{size} B"
        elif size < 1024 * 1024:
            return f"{size / 1024:.1f} KB"
        elif size < 1024 * 1024 * 1024:
            return f"{size / (1024 * 1024):.1f} MB"
        else:
            return f"{size / (1024 * 1024 * 1024):.1f} GB"

    def on_item_double_clicked(self, side: str, item: QTreeWidgetItem):
        """Handle item double click"""
        file_item = item.data(0, Qt.ItemDataRole.UserRole)
        if file_item and file_item.is_dir:
            # Navigate to directory
            if file_item.name == "..":
                self.navigate_up(side)
            else:
                self.navigate_to_path(side, file_item.path)

    def on_selection_changed(self, side: str):
        """Handle selection change"""
        # Update status or enable/disable actions based on selection
        pass

    def navigate_up(self, side: str):
        """Navigate up one directory"""
        if side == "left":
            current_path = self.current_left_path
        else:
            current_path = self.current_right_path

        if current_path != "/":
            parent_path = os.path.dirname(current_path)
            if not parent_path:
                parent_path = "/"
            self.navigate_to_path(side, parent_path)

    def navigate_to_path(self, side: str, path: str):
        """Navigate to a specific path"""
        if side == "left":
            self.current_left_path = path
        else:
            self.current_right_path = path

        self.refresh_pane(side)

    def show_context_menu(self, side: str, position: QPoint):
        """Show context menu for file operations"""
        if side == "left":
            file_list = self.left_file_list
        else:
            file_list = self.right_file_list

        item = file_list.itemAt(position)

        menu = QMenu(self)

        if item:
            file_item = item.data(0, Qt.ItemDataRole.UserRole)

            if not file_item.is_dir:
                # File actions
                menu.addAction("Download", lambda: self.download_file(side, file_item))
                menu.addAction("Copy to Other Pane", lambda: self.copy_to_other_pane(side, file_item))
                menu.addSeparator()

            menu.addAction("Rename", lambda: self.rename_item(side, file_item))
            menu.addAction("Delete", lambda: self.delete_item(side, file_item))
            menu.addSeparator()
            menu.addAction("Properties", lambda: self.show_properties(side, file_item))
        else:
            # Empty space actions
            menu.addAction("Upload File...", lambda: self.upload_file(side))
            menu.addAction("New Folder", lambda: self.create_folder(side))
            menu.addSeparator()
            menu.addAction("Refresh", lambda: self.refresh_pane(side))

        menu.exec(file_list.mapToGlobal(position))

    def download_file(self, side: str, file_item: FileItem):
        """Download a file to local system"""
        local_path, _ = QFileDialog.getSaveFileName(
            self, "Download File", file_item.name
        )

        if local_path:
            connection = self.left_connection if side == "left" else self.right_connection

            # Add transfer
            self.transfer_manager.add_transfer(
                TransferType.DOWNLOAD,
                file_item.path,
                local_path,
                connection,
                "local",
                file_item.size
            )

    def upload_file(self, side: str):
        """Upload a file from local system"""
        local_path, _ = QFileDialog.getOpenFileName(
            self, "Upload File"
        )

        if local_path:
            filename = os.path.basename(local_path)
            current_path = self.current_left_path if side == "left" else self.current_right_path
            remote_path = f"{current_path.rstrip('/')}/{filename}"
            connection = self.left_connection if side == "left" else self.right_connection

            # Get file size
            file_size = os.path.getsize(local_path)

            # Add transfer
            self.transfer_manager.add_transfer(
                TransferType.UPLOAD,
                local_path,
                remote_path,
                "local",
                connection,
                file_size
            )

    def copy_to_other_pane(self, side: str, file_item: FileItem):
        """Copy file to the other pane"""
        source_connection = self.left_connection if side == "left" else self.right_connection
        dest_connection = self.right_connection if side == "left" else self.left_connection
        dest_path = self.current_right_path if side == "left" else self.current_left_path

        if not dest_connection:
            QMessageBox.warning(self, "Error", "No destination connection available.")
            return

        dest_file_path = f"{dest_path.rstrip('/')}/{file_item.name}"

        # Add transfer
        self.transfer_manager.add_transfer(
            TransferType.COPY,
            file_item.path,
            dest_file_path,
            source_connection,
            dest_connection,
            file_item.size
        )

    def rename_item(self, side: str, file_item: FileItem):
        """Rename a file or directory"""
        new_name, ok = QInputDialog.getText(
            self, "Rename", "New name:", text=file_item.name
        )

        if ok and new_name and new_name != file_item.name:
            # TODO: Implement actual rename operation
            QMessageBox.information(self, "Rename", f"Rename '{file_item.name}' to '{new_name}'")
            self.refresh_pane(side)

    def delete_item(self, side: str, file_item: FileItem):
        """Delete a file or directory"""
        reply = QMessageBox.question(
            self, "Confirm Delete",
            f"Are you sure you want to delete '{file_item.name}'?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        )

        if reply == QMessageBox.StandardButton.Yes:
            # TODO: Implement actual delete operation
            QMessageBox.information(self, "Delete", f"Delete '{file_item.name}'")
            self.refresh_pane(side)

    def create_folder(self, side: str):
        """Create a new folder"""
        folder_name, ok = QInputDialog.getText(
            self, "New Folder", "Folder name:"
        )

        if ok and folder_name:
            # TODO: Implement actual folder creation
            QMessageBox.information(self, "New Folder", f"Create folder '{folder_name}'")
            self.refresh_pane(side)

    def show_properties(self, side: str, file_item: FileItem):
        """Show file properties"""
        dialog = FilePropertiesDialog(file_item, self)
        dialog.exec()

    def refresh(self):
        """Refresh both panes"""
        self.refresh_pane("left")
        self.refresh_pane("right")

    def apply_styling(self):
        """Apply Windows-style theme with high contrast"""
        self.setStyleSheet("""
            QWidget {
                background-color: #ffffff;
                border: none;
                color: #000000;
                font-size: 9pt;
            }
            
            QTreeWidget {
                background: #ffffff;
                border: 1px solid #c0c0c0;
                alternate-background-color: #f5f5f5;
                selection-background-color: #e3f2fd;
                outline: none;
                color: #000000;
            }
            
            QTreeWidget::item {
                height: 20px;
                border-bottom: 1px solid #e0e0e0;
                color: #000000;
            }
            
            QTreeWidget::item:selected {
                background: #e3f2fd;
                color: #000000;
            }
            
            QTreeWidget::item:hover {
                background: #f0f8ff;
                color: #000000;
            }
            
            QHeaderView::section {
                background: qlineargradient(y1: 0, y2: 1, stop: 0 #f8f8f8, stop: 1 #e0e0e0);
                border: 1px solid #a0a0a0;
                padding: 2px 4px;
                font-weight: bold;
                color: #000000;
                font-size: 9pt;
            }
            
            QLineEdit {
                padding: 2px 4px;
                border: 1px solid #a0a0a0;
                border-radius: 2px;
                background: #ffffff;
                color: #000000;
            }
            
            QLineEdit:focus {
                border-color: #0066cc;
                color: #000000;
            }
            
            QPushButton {
                background: qlineargradient(y1: 0, y2: 1, stop: 0 #f8f8f8, stop: 1 #e0e0e0);
                border: 1px solid #a0a0a0;
                border-radius: 2px;
                font-weight: bold;
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
            
            QSplitter::handle {
                background: #c0c0c0;
                width: 2px;
            }
            
            QSplitter::handle:hover {
                background: #a0a0a0;
            }
            
            QLabel {
                color: #000000;
                background: transparent;
            }
        """)


class FilePropertiesDialog(QDialog):
    """Dialog to show file properties"""

    def __init__(self, file_item: FileItem, parent=None):
        super().__init__(parent)
        self.file_item = file_item

        self.setWindowTitle(f"Properties - {file_item.name}")
        self.setModal(True)
        self.resize(350, 250)

        self.setup_ui()

        # Apply styling
        self.setStyleSheet("""
            QDialog {
                background-color: #f0f0f0;
                color: #000000;
                font-size: 9pt;
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
            
            QLabel {
                color: #000000;
                background: transparent;
            }
            
            QPushButton {
                background: qlineargradient(y1: 0, y2: 1, stop: 0 #f8f8f8, stop: 1 #e0e0e0);
                border: 1px solid #a0a0a0;
                padding: 4px 12px;
                border-radius: 2px;
                min-width: 70px;
                color: #000000;
            }
            
            QPushButton:hover {
                background: qlineargradient(y1: 0, y2: 1, stop: 0 #ffffff, stop: 1 #e8e8e8);
                color: #000000;
            }
        """)

    def setup_ui(self):
        """Setup the properties dialog"""
        layout = QVBoxLayout(self)

        # File info
        info_group = QGroupBox("File Information")
        info_layout = QFormLayout(info_group)

        info_layout.addRow("Name:", QLabel(self.file_item.name))
        info_layout.addRow("Path:", QLabel(self.file_item.path))
        info_layout.addRow("Type:", QLabel("Directory" if self.file_item.is_dir else "File"))

        if not self.file_item.is_dir:
            size_label = QLabel(self.format_file_size(self.file_item.size))
            info_layout.addRow("Size:", size_label)

        if self.file_item.modified:
            info_layout.addRow("Modified:", QLabel(self.file_item.modified))

        if self.file_item.permissions:
            info_layout.addRow("Permissions:", QLabel(self.file_item.permissions))

        layout.addWidget(info_group)

        # Buttons
        button_layout = QHBoxLayout()
        button_layout.addStretch()

        close_button = QPushButton("Close")
        close_button.clicked.connect(self.accept)
        button_layout.addWidget(close_button)

        layout.addLayout(button_layout)

    def format_file_size(self, size: int) -> str:
        """Format file size in human readable format"""
        if size < 1024:
            return f"{size} bytes"
        elif size < 1024 * 1024:
            return f"{size / 1024:.1f} KB ({size:,} bytes)"
        elif size < 1024 * 1024 * 1024:
            return f"{size / (1024 * 1024):.1f} MB ({size:,} bytes)"
        else:
            return f"{size / (1024 * 1024 * 1024):.1f} GB ({size:,} bytes)"
#!/usr/bin/env python3
"""
Multi-Protocol File Explorer
Main application entry point
"""

import sys
import json
import os
from pathlib import Path
from PyQt6.QtWidgets import *
from PyQt6.QtCore import *
from PyQt6.QtGui import *

from config_manager import ConfigManager
from transfer_manager import TransferManager
from connection_panel import ConnectionPanel
from file_explorer_panel import FileExplorerPanel
from transfer_panel import TransferPanel


class FileExplorer(QMainWindow):
    def __init__(self):
        super().__init__()
        self.config_manager = ConfigManager()
        self.transfer_manager = TransferManager()

        self.setWindowTitle("Multi-Protocol File Explorer")
        self.setGeometry(100, 100, 1400, 800)

        self.setup_ui()
        self.setup_menus()
        self.setup_toolbar()
        self.setup_status_bar()
        self.apply_styling()

        # Load saved connections
        self.connection_panel.load_connections()

    def setup_ui(self):
        """Setup the main UI layout"""
        central_widget = QWidget()
        self.setCentralWidget(central_widget)

        # Create main layout
        main_layout = QVBoxLayout(central_widget)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)

        # Create splitter for main panels
        main_splitter = QSplitter(Qt.Orientation.Horizontal)
        main_layout.addWidget(main_splitter)

        # Left panel - Connections
        self.connection_panel = ConnectionPanel(self.config_manager, self.transfer_manager)
        self.connection_panel.setMaximumWidth(350)
        self.connection_panel.setMinimumWidth(250)
        main_splitter.addWidget(self.connection_panel)

        # Right panel - File explorer and transfers
        right_widget = QWidget()
        right_layout = QVBoxLayout(right_widget)
        right_layout.setContentsMargins(0, 0, 0, 0)
        right_layout.setSpacing(0)

        # File explorer panel
        self.file_explorer_panel = FileExplorerPanel(self.transfer_manager)
        right_layout.addWidget(self.file_explorer_panel)

        # Transfer panel (bottom)
        self.transfer_panel = TransferPanel(self.transfer_manager)
        self.transfer_panel.setMaximumHeight(200)
        self.transfer_panel.setMinimumHeight(100)
        right_layout.addWidget(self.transfer_panel)

        main_splitter.addWidget(right_widget)

        # Set splitter proportions
        main_splitter.setSizes([300, 1100])

        # Connect signals
        self.connection_panel.connection_selected.connect(
            self.file_explorer_panel.set_connection
        )

    def setup_menus(self):
        """Setup application menus"""
        menubar = self.menuBar()

        # File menu
        file_menu = menubar.addMenu('&File')

        new_connection_action = QAction('&New Connection...', self)
        new_connection_action.setShortcut('Ctrl+N')
        new_connection_action.triggered.connect(self.connection_panel.add_connection)
        file_menu.addAction(new_connection_action)

        file_menu.addSeparator()

        exit_action = QAction('E&xit', self)
        exit_action.setShortcut('Ctrl+Q')
        exit_action.triggered.connect(self.close)
        file_menu.addAction(exit_action)

        # Edit menu
        edit_menu = menubar.addMenu('&Edit')

        settings_action = QAction('&Settings...', self)
        settings_action.triggered.connect(self.show_settings)
        edit_menu.addAction(settings_action)

        # View menu
        view_menu = menubar.addMenu('&View')

        show_transfers_action = QAction('Show &Transfers', self)
        show_transfers_action.setCheckable(True)
        show_transfers_action.setChecked(True)
        show_transfers_action.triggered.connect(self.toggle_transfers_panel)
        view_menu.addAction(show_transfers_action)

        # Help menu
        help_menu = menubar.addMenu('&Help')

        about_action = QAction('&About', self)
        about_action.triggered.connect(self.show_about)
        help_menu.addAction(about_action)

    def setup_toolbar(self):
        """Setup application toolbar"""
        toolbar = self.addToolBar('Main')
        toolbar.setMovable(False)

        # Connection actions
        connect_action = QAction('Connect', self)
        connect_action.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_ComputerIcon))
        connect_action.triggered.connect(self.connection_panel.connect_selected)
        toolbar.addAction(connect_action)

        disconnect_action = QAction('Disconnect', self)
        disconnect_action.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_DialogCancelButton))
        disconnect_action.triggered.connect(self.connection_panel.disconnect_selected)
        toolbar.addAction(disconnect_action)

        toolbar.addSeparator()

        # File operations
        refresh_action = QAction('Refresh', self)
        refresh_action.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_BrowserReload))
        refresh_action.setShortcut('F5')
        refresh_action.triggered.connect(self.file_explorer_panel.refresh)
        toolbar.addAction(refresh_action)

        toolbar.addSeparator()

        # Transfer actions
        clear_transfers_action = QAction('Clear Completed', self)
        clear_transfers_action.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_TrashIcon))
        clear_transfers_action.triggered.connect(self.transfer_panel.clear_completed)
        toolbar.addAction(clear_transfers_action)

    def setup_status_bar(self):
        """Setup status bar"""
        self.status_bar = self.statusBar()
        self.status_label = QLabel("Ready")
        self.status_bar.addWidget(self.status_label)

        # Connection status
        self.connection_status = QLabel("Not connected")
        self.status_bar.addPermanentWidget(self.connection_status)

    def apply_styling(self):
        """Apply Windows-style theme with high contrast"""
        self.setStyleSheet("""
            QMainWindow {
                background-color: #f0f0f0;
                color: #000000;
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                font-size: 9pt;
            }
            
            QMenuBar {
                background: qlineargradient(y1: 0, y2: 1, stop: 0 #ffffff, stop: 1 #e8e8e8);
                border-bottom: 1px solid #c0c0c0;
                padding: 2px;
                color: #000000;
            }
            
            QMenuBar::item {
                background: transparent;
                padding: 4px 8px;
                color: #000000;
            }
            
            QMenuBar::item:selected {
                background: qlineargradient(y1: 0, y2: 1, stop: 0 #ffffff, stop: 1 #e8e8e8);
                border: 1px solid #a0a0a0;
                color: #000000;
            }
            
            QMenu {
                background: #ffffff;
                border: 1px solid #a0a0a0;
                padding: 2px;
                color: #000000;
            }
            
            QMenu::item {
                padding: 4px 20px;
                color: #000000;
            }
            
            QMenu::item:selected {
                background: #e3f2fd;
                color: #000000;
            }
            
            QToolBar {
                background: qlineargradient(y1: 0, y2: 1, stop: 0 #ffffff, stop: 1 #e8e8e8);
                border-bottom: 1px solid #c0c0c0;
                padding: 2px;
                spacing: 2px;
            }
            
            QToolButton {
                background: qlineargradient(y1: 0, y2: 1, stop: 0 #f8f8f8, stop: 1 #e0e0e0);
                border: 1px solid #a0a0a0;
                padding: 4px 8px;
                border-radius: 2px;
                margin: 1px;
                color: #000000;
            }
            
            QToolButton:hover {
                background: qlineargradient(y1: 0, y2: 1, stop: 0 #ffffff, stop: 1 #e8e8e8);
                color: #000000;
            }
            
            QToolButton:pressed {
                background: qlineargradient(y1: 0, y2: 1, stop: 0 #e0e0e0, stop: 1 #f0f0f0);
                color: #000000;
            }
            
            QStatusBar {
                background: qlineargradient(y1: 0, y2: 1, stop: 0 #e8e8e8, stop: 1 #d0d0d0);
                border-top: 1px solid #c0c0c0;
                padding: 2px;
                color: #000000;
            }
            
            QLabel {
                color: #000000;
            }
            
            QSplitter::handle {
                background: #c0c0c0;
                width: 2px;
            }
            
            QSplitter::handle:hover {
                background: #a0a0a0;
            }
        """)

    def toggle_transfers_panel(self, checked):
        """Toggle transfer panel visibility"""
        self.transfer_panel.setVisible(checked)

    def show_settings(self):
        """Show settings dialog"""
        dialog = SettingsDialog(self.config_manager, self)
        dialog.exec()

    def show_about(self):
        """Show about dialog"""
        try:
            from version import get_about_text
            about_text = get_about_text()
        except ImportError:
            about_text = ("Multi-Protocol File Explorer\n\n"
                          "Supports SFTP, SCP, FTP, Samba, SSH, NFS, WebDAV\n\n"
                          "Built with PyQt6")

        QMessageBox.about(self, "About File Explorer", about_text)

    def closeEvent(self, event):
        """Handle application close"""
        # Save configuration
        self.config_manager.save_config()

        # Disconnect all connections
        self.connection_panel.disconnect_all()

        # Stop all transfers
        self.transfer_manager.stop_all_transfers()

        event.accept()


class SettingsDialog(QDialog):
    def __init__(self, config_manager, parent=None):
        super().__init__(parent)
        self.config_manager = config_manager
        self.setWindowTitle("Settings")
        self.setModal(True)
        self.resize(400, 300)

        layout = QVBoxLayout(self)

        # General settings
        general_group = QGroupBox("General")
        general_layout = QFormLayout(general_group)

        self.auto_connect_check = QCheckBox()
        self.auto_connect_check.setChecked(self.config_manager.get_setting('auto_connect', False))
        general_layout.addRow("Auto-connect on startup:", self.auto_connect_check)

        self.confirm_delete_check = QCheckBox()
        self.confirm_delete_check.setChecked(self.config_manager.get_setting('confirm_delete', True))
        general_layout.addRow("Confirm deletions:", self.confirm_delete_check)

        layout.addWidget(general_group)

        # Transfer settings
        transfer_group = QGroupBox("Transfers")
        transfer_layout = QFormLayout(transfer_group)

        self.max_transfers_spin = QSpinBox()
        self.max_transfers_spin.setRange(1, 10)
        self.max_transfers_spin.setValue(self.config_manager.get_setting('max_concurrent_transfers', 3))
        transfer_layout.addRow("Max concurrent transfers:", self.max_transfers_spin)

        layout.addWidget(transfer_group)

        # Buttons
        button_layout = QHBoxLayout()
        button_layout.addStretch()

        ok_button = QPushButton("OK")
        ok_button.clicked.connect(self.accept)
        button_layout.addWidget(ok_button)

        cancel_button = QPushButton("Cancel")
        cancel_button.clicked.connect(self.reject)
        button_layout.addWidget(cancel_button)

        layout.addLayout(button_layout)

    def accept(self):
        """Save settings"""
        self.config_manager.set_setting('auto_connect', self.auto_connect_check.isChecked())
        self.config_manager.set_setting('confirm_delete', self.confirm_delete_check.isChecked())
        self.config_manager.set_setting('max_concurrent_transfers', self.max_transfers_spin.value())
        super().accept()


def main():
    app = QApplication(sys.argv)

    # Set application properties
    app.setApplicationName("File Explorer")
    app.setApplicationVersion("1.0")
    app.setOrganizationName("FileExplorer")

    # Create and show main window
    window = FileExplorer()
    window.show()

    sys.exit(app.exec())


if __name__ == '__main__':
    main()
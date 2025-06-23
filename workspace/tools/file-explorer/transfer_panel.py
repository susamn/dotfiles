"""
Transfer Panel
Bottom panel for showing file transfers (like FileZilla)
"""

import time
from typing import Dict, Optional
from PyQt6.QtWidgets import *
from PyQt6.QtCore import *
from PyQt6.QtGui import *

from transfer_manager import TransferManager, TransferItem, TransferStatus, TransferType


class TransferPanel(QWidget):
    """Bottom panel showing transfer queue and history"""

    def __init__(self, transfer_manager: TransferManager):
        super().__init__()
        self.transfer_manager = transfer_manager
        self.transfer_items = {}  # transfer_id -> QTreeWidgetItem

        self.setup_ui()
        self.connect_signals()
        self.apply_styling()

    def setup_ui(self):
        """Setup the transfer panel UI"""
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        # Create tab widget for different views
        self.tab_widget = QTabWidget()

        # Transfer queue tab
        queue_tab = self.create_queue_tab()
        self.tab_widget.addTab(queue_tab, "Transfer Queue")

        # Transfer history tab
        history_tab = self.create_history_tab()
        self.tab_widget.addTab(history_tab, "Transfer History")

        # Transfer statistics tab
        stats_tab = self.create_stats_tab()
        self.tab_widget.addTab(stats_tab, "Statistics")

        layout.addWidget(self.tab_widget)

        # Control buttons
        controls = self.create_controls()
        layout.addWidget(controls)

    def create_queue_tab(self):
        """Create the transfer queue tab"""
        tab = QWidget()
        layout = QVBoxLayout(tab)
        layout.setContentsMargins(4, 4, 4, 4)

        # Transfer list
        self.queue_list = QTreeWidget()
        self.queue_list.setHeaderLabels([
            "Status", "Source", "Destination", "Size", "Progress",
            "Speed", "ETA", "Type"
        ])

        # Set column widths
        header = self.queue_list.header()
        header.resizeSection(0, 80)   # Status
        header.resizeSection(1, 200)  # Source
        header.resizeSection(2, 200)  # Destination
        header.resizeSection(3, 80)   # Size
        header.resizeSection(4, 100)  # Progress
        header.resizeSection(5, 80)   # Speed
        header.resizeSection(6, 60)   # ETA
        header.resizeSection(7, 60)   # Type

        self.queue_list.setAlternatingRowColors(True)
        self.queue_list.setRootIsDecorated(False)
        self.queue_list.setSelectionMode(QAbstractItemView.SelectionMode.ExtendedSelection)

        # Context menu
        self.queue_list.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.queue_list.customContextMenuRequested.connect(self.show_queue_context_menu)

        layout.addWidget(self.queue_list)

        return tab

    def create_history_tab(self):
        """Create the transfer history tab"""
        tab = QWidget()
        layout = QVBoxLayout(tab)
        layout.setContentsMargins(4, 4, 4, 4)

        # History list
        self.history_list = QTreeWidget()
        self.history_list.setHeaderLabels([
            "Status", "Source", "Destination", "Size", "Duration",
            "Speed", "Started", "Type"
        ])

        # Set column widths
        header = self.history_list.header()
        header.resizeSection(0, 80)   # Status
        header.resizeSection(1, 200)  # Source
        header.resizeSection(2, 200)  # Destination
        header.resizeSection(3, 80)   # Size
        header.resizeSection(4, 80)   # Duration
        header.resizeSection(5, 80)   # Speed
        header.resizeSection(6, 120)  # Started
        header.resizeSection(7, 60)   # Type

        self.history_list.setAlternatingRowColors(True)
        self.history_list.setRootIsDecorated(False)
        self.history_list.setSortingEnabled(True)

        # Context menu
        self.history_list.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.history_list.customContextMenuRequested.connect(self.show_history_context_menu)

        layout.addWidget(self.history_list)

        return tab

    def create_stats_tab(self):
        """Create the statistics tab"""
        tab = QWidget()
        layout = QVBoxLayout(tab)
        layout.setContentsMargins(8, 8, 8, 8)

        # Overall statistics
        stats_group = QGroupBox("Transfer Statistics")
        stats_layout = QGridLayout(stats_group)

        # Labels for statistics
        self.total_transfers_label = QLabel("0")
        self.completed_transfers_label = QLabel("0")
        self.failed_transfers_label = QLabel("0")
        self.total_data_label = QLabel("0 MB")
        self.avg_speed_label = QLabel("0 KB/s")
        self.total_time_label = QLabel("0:00:00")

        stats_layout.addWidget(QLabel("Total Transfers:"), 0, 0)
        stats_layout.addWidget(self.total_transfers_label, 0, 1)
        stats_layout.addWidget(QLabel("Completed:"), 0, 2)
        stats_layout.addWidget(self.completed_transfers_label, 0, 3)

        stats_layout.addWidget(QLabel("Failed:"), 1, 0)
        stats_layout.addWidget(self.failed_transfers_label, 1, 1)
        stats_layout.addWidget(QLabel("Total Data:"), 1, 2)
        stats_layout.addWidget(self.total_data_label, 1, 3)

        stats_layout.addWidget(QLabel("Average Speed:"), 2, 0)
        stats_layout.addWidget(self.avg_speed_label, 2, 1)
        stats_layout.addWidget(QLabel("Total Time:"), 2, 2)
        stats_layout.addWidget(self.total_time_label, 2, 3)

        layout.addWidget(stats_group)

        # Real-time statistics
        realtime_group = QGroupBox("Current Session")
        realtime_layout = QGridLayout(realtime_group)

        self.active_transfers_label = QLabel("0")
        self.queued_transfers_label = QLabel("0")
        self.current_speed_label = QLabel("0 KB/s")
        self.session_data_label = QLabel("0 MB")

        realtime_layout.addWidget(QLabel("Active Transfers:"), 0, 0)
        realtime_layout.addWidget(self.active_transfers_label, 0, 1)
        realtime_layout.addWidget(QLabel("Queued:"), 0, 2)
        realtime_layout.addWidget(self.queued_transfers_label, 0, 3)

        realtime_layout.addWidget(QLabel("Current Speed:"), 1, 0)
        realtime_layout.addWidget(self.current_speed_label, 1, 1)
        realtime_layout.addWidget(QLabel("Session Data:"), 1, 2)
        realtime_layout.addWidget(self.session_data_label, 1, 3)

        layout.addWidget(realtime_group)

        layout.addStretch()

        return tab

    def create_controls(self):
        """Create transfer control buttons"""
        controls = QWidget()
        layout = QHBoxLayout(controls)
        layout.setContentsMargins(4, 2, 4, 2)

        # Transfer control buttons
        self.pause_button = QPushButton("Pause")
        self.pause_button.setEnabled(False)
        self.pause_button.clicked.connect(self.pause_selected_transfers)
        layout.addWidget(self.pause_button)

        self.resume_button = QPushButton("Resume")
        self.resume_button.setEnabled(False)
        self.resume_button.clicked.connect(self.resume_selected_transfers)
        layout.addWidget(self.resume_button)

        self.cancel_button = QPushButton("Cancel")
        self.cancel_button.setEnabled(False)
        self.cancel_button.clicked.connect(self.cancel_selected_transfers)
        layout.addWidget(self.cancel_button)

        layout.addWidget(QFrame())  # Separator

        # Queue management
        self.clear_completed_button = QPushButton("Clear Completed")
        self.clear_completed_button.clicked.connect(self.clear_completed)
        layout.addWidget(self.clear_completed_button)

        self.clear_all_button = QPushButton("Clear All")
        self.clear_all_button.clicked.connect(self.clear_all)
        layout.addWidget(self.clear_all_button)

        layout.addStretch()

        # Status indicator
        self.status_indicator = QLabel("Ready")
        layout.addWidget(self.status_indicator)

        return controls

    def connect_signals(self):
        """Connect transfer manager signals"""
        self.transfer_manager.transfer_added.connect(self.on_transfer_added)
        self.transfer_manager.transfer_updated.connect(self.on_transfer_updated)
        self.transfer_manager.transfer_completed.connect(self.on_transfer_completed)
        self.transfer_manager.transfer_failed.connect(self.on_transfer_failed)

        # Connect selection changed
        self.queue_list.itemSelectionChanged.connect(self.on_selection_changed)

        # Update statistics periodically
        self.stats_timer = QTimer()
        self.stats_timer.timeout.connect(self.update_statistics)
        self.stats_timer.start(1000)  # Update every second

    def on_transfer_added(self, transfer_id: str):
        """Handle new transfer added"""
        transfer = self.transfer_manager.get_transfer(transfer_id)
        if not transfer:
            return

        # Create tree item
        item = QTreeWidgetItem()
        item.setData(0, Qt.ItemDataRole.UserRole, transfer_id)

        # Add to queue list
        self.queue_list.addTopLevelItem(item)
        self.transfer_items[transfer_id] = item

        # Update item
        self.update_transfer_item(transfer)

    def on_transfer_updated(self, transfer_id: str):
        """Handle transfer update"""
        transfer = self.transfer_manager.get_transfer(transfer_id)
        if transfer:
            self.update_transfer_item(transfer)

    def on_transfer_completed(self, transfer_id: str):
        """Handle transfer completion"""
        transfer = self.transfer_manager.get_transfer(transfer_id)
        if transfer:
            self.update_transfer_item(transfer)
            self.move_to_history(transfer)

    def on_transfer_failed(self, transfer_id: str, error: str):
        """Handle transfer failure"""
        transfer = self.transfer_manager.get_transfer(transfer_id)
        if transfer:
            self.update_transfer_item(transfer)

    def update_transfer_item(self, transfer: TransferItem):
        """Update a transfer item in the UI"""
        if transfer.id not in self.transfer_items:
            return

        item = self.transfer_items[transfer.id]

        # Status with icon
        status_text = transfer.status.value.title()
        item.setText(0, status_text)
        item.setIcon(0, self.get_status_icon(transfer.status))

        # Source and destination
        item.setText(1, transfer.source_path)
        item.setText(2, transfer.destination_path)

        # Size
        if transfer.file_size > 0:
            item.setText(3, self.format_file_size(transfer.file_size))
        else:
            item.setText(3, "Unknown")

        # Progress
        if transfer.status == TransferStatus.RUNNING:
            progress_text = f"{transfer.progress_percent:.1f}%"
            item.setText(4, progress_text)

            # Set progress bar
            if not item.data(4, Qt.ItemDataRole.UserRole):
                progress_bar = QProgressBar()
                progress_bar.setMaximum(100)
                progress_bar.setTextVisible(False)
                self.queue_list.setItemWidget(item, 4, progress_bar)
                item.setData(4, Qt.ItemDataRole.UserRole, progress_bar)

            progress_bar = item.data(4, Qt.ItemDataRole.UserRole)
            if progress_bar:
                progress_bar.setValue(int(transfer.progress_percent))
        else:
            item.setText(4, "")
            # Remove progress bar if exists
            progress_bar = item.data(4, Qt.ItemDataRole.UserRole)
            if progress_bar:
                self.queue_list.removeItemWidget(item, 4)
                item.setData(4, Qt.ItemDataRole.UserRole, None)

        # Speed
        if transfer.status == TransferStatus.RUNNING and transfer.speed_bps > 0:
            item.setText(5, self.format_speed(transfer.speed_bps))
        else:
            item.setText(5, "")

        # ETA
        if transfer.status == TransferStatus.RUNNING and transfer.eta_seconds:
            item.setText(6, self.format_time(transfer.eta_seconds))
        else:
            item.setText(6, "")

        # Type
        item.setText(7, transfer.transfer_type.value.upper())

        # Set row color based on status
        self.set_item_color(item, transfer.status)

    def move_to_history(self, transfer: TransferItem):
        """Move completed transfer to history"""
        # Create history item
        item = QTreeWidgetItem()

        # Status
        item.setText(0, transfer.status.value.title())
        item.setIcon(0, self.get_status_icon(transfer.status))

        # Source and destination
        item.setText(1, transfer.source_path)
        item.setText(2, transfer.destination_path)

        # Size
        if transfer.file_size > 0:
            item.setText(3, self.format_file_size(transfer.file_size))

        # Duration
        if transfer.duration > 0:
            item.setText(4, self.format_time(int(transfer.duration)))

        # Average speed
        if transfer.duration > 0 and transfer.file_size > 0:
            avg_speed = transfer.file_size / transfer.duration
            item.setText(5, self.format_speed(avg_speed))

        # Start time
        if transfer.start_time:
            start_time = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(transfer.start_time))
            item.setText(6, start_time)

        # Type
        item.setText(7, transfer.transfer_type.value.upper())

        # Set color
        self.set_item_color(item, transfer.status)

        # Add to history
        self.history_list.addTopLevelItem(item)

    def get_status_icon(self, status: TransferStatus) -> QIcon:
        """Get icon for transfer status"""
        icon_map = {
            TransferStatus.PENDING: QStyle.StandardPixmap.SP_MessageBoxInformation,
            TransferStatus.RUNNING: QStyle.StandardPixmap.SP_MediaPlay,
            TransferStatus.COMPLETED: QStyle.StandardPixmap.SP_DialogApplyButton,
            TransferStatus.FAILED: QStyle.StandardPixmap.SP_MessageBoxCritical,
            TransferStatus.CANCELLED: QStyle.StandardPixmap.SP_DialogCancelButton,
            TransferStatus.PAUSED: QStyle.StandardPixmap.SP_MediaPause,
        }

        pixmap = icon_map.get(status, QStyle.StandardPixmap.SP_MessageBoxInformation)
        return self.style().standardIcon(pixmap)

    def set_item_color(self, item: QTreeWidgetItem, status: TransferStatus):
        """Set item color based on status"""
        color_map = {
            TransferStatus.PENDING: QColor(0, 0, 0),        # Black
            TransferStatus.RUNNING: QColor(0, 0, 255),      # Blue
            TransferStatus.COMPLETED: QColor(0, 128, 0),    # Green
            TransferStatus.FAILED: QColor(255, 0, 0),       # Red
            TransferStatus.CANCELLED: QColor(128, 128, 128), # Gray
            TransferStatus.PAUSED: QColor(255, 165, 0),     # Orange
        }

        color = color_map.get(status, QColor(0, 0, 0))
        brush = QBrush(color)
        for i in range(item.columnCount()):
            item.setForeground(i, brush)

    def format_file_size(self, size: int) -> str:
        """Format file size"""
        if size < 1024:
            return f"{size} B"
        elif size < 1024 * 1024:
            return f"{size / 1024:.1f} KB"
        elif size < 1024 * 1024 * 1024:
            return f"{size / (1024 * 1024):.1f} MB"
        else:
            return f"{size / (1024 * 1024 * 1024):.1f} GB"

    def format_speed(self, speed_bps: float) -> str:
        """Format transfer speed"""
        if speed_bps < 1024:
            return f"{speed_bps:.0f} B/s"
        elif speed_bps < 1024 * 1024:
            return f"{speed_bps / 1024:.1f} KB/s"
        else:
            return f"{speed_bps / (1024 * 1024):.1f} MB/s"

    def format_time(self, seconds: int) -> str:
        """Format time duration"""
        if seconds < 60:
            return f"{seconds}s"
        elif seconds < 3600:
            return f"{seconds // 60}m {seconds % 60}s"
        else:
            hours = seconds // 3600
            minutes = (seconds % 3600) // 60
            return f"{hours}h {minutes}m"

    def on_selection_changed(self):
        """Handle selection change in transfer list"""
        selected_items = self.queue_list.selectedItems()

        # Update button states
        has_selection = len(selected_items) > 0
        has_running = False
        has_paused = False

        for item in selected_items:
            transfer_id = item.data(0, Qt.ItemDataRole.UserRole)
            transfer = self.transfer_manager.get_transfer(transfer_id)
            if transfer:
                if transfer.status == TransferStatus.RUNNING:
                    has_running = True
                elif transfer.status == TransferStatus.PAUSED:
                    has_paused = True

        self.pause_button.setEnabled(has_selection and has_running)
        self.resume_button.setEnabled(has_selection and has_paused)
        self.cancel_button.setEnabled(has_selection)

    def pause_selected_transfers(self):
        """Pause selected transfers"""
        for item in self.queue_list.selectedItems():
            transfer_id = item.data(0, Qt.ItemDataRole.UserRole)
            self.transfer_manager.pause_transfer(transfer_id)

    def resume_selected_transfers(self):
        """Resume selected transfers"""
        for item in self.queue_list.selectedItems():
            transfer_id = item.data(0, Qt.ItemDataRole.UserRole)
            self.transfer_manager.resume_transfer(transfer_id)

    def cancel_selected_transfers(self):
        """Cancel selected transfers"""
        for item in self.queue_list.selectedItems():
            transfer_id = item.data(0, Qt.ItemDataRole.UserRole)
            self.transfer_manager.cancel_transfer(transfer_id)

    def clear_completed(self):
        """Clear completed transfers"""
        self.transfer_manager.clear_completed()

        # Remove from UI
        items_to_remove = []
        for i in range(self.queue_list.topLevelItemCount()):
            item = self.queue_list.topLevelItem(i)
            transfer_id = item.data(0, Qt.ItemDataRole.UserRole)
            transfer = self.transfer_manager.get_transfer(transfer_id)
            if not transfer:  # Transfer was removed
                items_to_remove.append(item)

        for item in items_to_remove:
            index = self.queue_list.indexOfTopLevelItem(item)
            self.queue_list.takeTopLevelItem(index)

            # Remove from tracking
            transfer_id = item.data(0, Qt.ItemDataRole.UserRole)
            if transfer_id in self.transfer_items:
                del self.transfer_items[transfer_id]

    def clear_all(self):
        """Clear all transfers"""
        reply = QMessageBox.question(
            self, "Clear All",
            "This will cancel all running transfers and clear the queue. Continue?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        )

        if reply == QMessageBox.StandardButton.Yes:
            self.transfer_manager.stop_all_transfers()
            self.queue_list.clear()
            self.history_list.clear()
            self.transfer_items.clear()

    def show_queue_context_menu(self, position: QPoint):
        """Show context menu for queue"""
        item = self.queue_list.itemAt(position)
        if not item:
            return

        transfer_id = item.data(0, Qt.ItemDataRole.UserRole)
        transfer = self.transfer_manager.get_transfer(transfer_id)
        if not transfer:
            return

        menu = QMenu(self)

        if transfer.status == TransferStatus.RUNNING:
            menu.addAction("Pause", lambda: self.transfer_manager.pause_transfer(transfer_id))
        elif transfer.status == TransferStatus.PAUSED:
            menu.addAction("Resume", lambda: self.transfer_manager.resume_transfer(transfer_id))
        elif transfer.status == TransferStatus.FAILED:
            menu.addAction("Retry", lambda: self.transfer_manager.retry_transfer(transfer_id))

        menu.addSeparator()
        menu.addAction("Cancel", lambda: self.transfer_manager.cancel_transfer(transfer_id))
        menu.addAction("Remove", lambda: self.remove_transfer(transfer_id))

        menu.exec(self.queue_list.mapToGlobal(position))

    def show_history_context_menu(self, position: QPoint):
        """Show context menu for history"""
        item = self.history_list.itemAt(position)
        if not item:
            return

        menu = QMenu(self)
        menu.addAction("Remove from History", lambda: self.remove_history_item(item))
        menu.addAction("Clear History", lambda: self.history_list.clear())

        menu.exec(self.history_list.mapToGlobal(position))

    def remove_transfer(self, transfer_id: str):
        """Remove transfer from queue"""
        if self.transfer_manager.remove_transfer(transfer_id):
            if transfer_id in self.transfer_items:
                item = self.transfer_items[transfer_id]
                index = self.queue_list.indexOfTopLevelItem(item)
                self.queue_list.takeTopLevelItem(index)
                del self.transfer_items[transfer_id]

    def remove_history_item(self, item: QTreeWidgetItem):
        """Remove item from history"""
        index = self.history_list.indexOfTopLevelItem(item)
        self.history_list.takeTopLevelItem(index)

    def update_statistics(self):
        """Update transfer statistics"""
        stats = self.transfer_manager.get_transfer_stats()

        # Update labels
        self.total_transfers_label.setText(str(stats['total']))
        self.completed_transfers_label.setText(str(stats['completed']))
        self.failed_transfers_label.setText(str(stats['failed']))
        self.active_transfers_label.setText(str(stats['running']))
        self.queued_transfers_label.setText(str(stats['pending']))

        # Calculate current speed
        running_transfers = self.transfer_manager.get_running_transfers()
        total_speed = sum(t.speed_bps for t in running_transfers)
        self.current_speed_label.setText(self.format_speed(total_speed))

        # Update status
        if stats['running'] > 0:
            self.status_indicator.setText(f"Transferring ({stats['running']} active)")
        elif stats['pending'] > 0:
            self.status_indicator.setText(f"Queue ({stats['pending']} pending)")
        else:
            self.status_indicator.setText("Ready")

    def apply_styling(self):
        """Apply Windows-style theme with high contrast"""
        self.setStyleSheet("""
            QWidget {
                background-color: #f8f8f8;
                border: none;
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
                font-size: 9pt;
            }
            
            QTabBar::tab:selected {
                background: #ffffff;
                border-bottom: 1px solid #ffffff;
                color: #000000;
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
                height: 22px;
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
                font-size: 9pt;
                color: #000000;
            }
            
            QPushButton {
                background: qlineargradient(y1: 0, y2: 1, stop: 0 #f8f8f8, stop: 1 #e0e0e0);
                border: 1px solid #a0a0a0;
                padding: 4px 12px;
                border-radius: 2px;
                font-size: 9pt;
                min-width: 60px;
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
            
            QGroupBox {
                font-weight: bold;
                border: 1px solid #c0c0c0;
                border-radius: 4px;
                margin-top: 8px;
                padding-top: 4px;
                color: #000000;
            }
            
            QGroupBox::title {
                subcontrol-origin: margin;
                left: 10px;
                padding: 0 4px 0 4px;
                color: #000000;
            }
            
            QLabel {
                color: #000000;
                background: transparent;
            }
            
            QProgressBar {
                border: 1px solid #c0c0c0;
                border-radius: 2px;
                background: #f0f0f0;
                height: 16px;
                color: #000000;
            }
            
            QProgressBar::chunk {
                background: qlineargradient(y1: 0, y2: 1, stop: 0 #4a90e2, stop: 1 #2e5bb8);
                border-radius: 1px;
            }
        """)
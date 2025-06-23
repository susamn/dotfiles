"""
Transfer Manager
Handles file transfers between connections
"""

import time
import threading
from enum import Enum
from typing import Dict, List, Optional, Callable
from dataclasses import dataclass, field
from PyQt6.QtCore import QObject, pyqtSignal, QTimer


class TransferStatus(Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"
    PAUSED = "paused"


class TransferType(Enum):
    UPLOAD = "upload"
    DOWNLOAD = "download"
    COPY = "copy"
    MOVE = "move"


@dataclass
class TransferItem:
    """Represents a single file transfer"""
    id: str
    transfer_type: TransferType
    source_path: str
    destination_path: str
    source_connection: str
    destination_connection: str
    file_size: int = 0
    transferred_bytes: int = 0
    status: TransferStatus = TransferStatus.PENDING
    start_time: Optional[float] = None
    end_time: Optional[float] = None
    error_message: str = ""
    retry_count: int = 0
    progress_callback: Optional[Callable] = None
    speed_bps: float = 0.0
    eta_seconds: Optional[int] = None

    # Internal fields
    _last_update_time: float = field(default_factory=time.time)
    _last_transferred_bytes: int = 0
    _speed_samples: List[float] = field(default_factory=list)

    @property
    def progress_percent(self) -> float:
        """Calculate transfer progress percentage"""
        if self.file_size == 0:
            return 0.0
        return min(100.0, (self.transferred_bytes / self.file_size) * 100.0)

    @property
    def duration(self) -> float:
        """Get transfer duration in seconds"""
        if self.start_time is None:
            return 0.0
        end = self.end_time or time.time()
        return end - self.start_time

    def update_progress(self, bytes_transferred: int):
        """Update transfer progress and calculate speed"""
        self.transferred_bytes = bytes_transferred
        current_time = time.time()

        # Calculate speed (bytes per second)
        time_diff = current_time - self._last_update_time
        if time_diff >= 1.0:  # Update speed every second
            bytes_diff = bytes_transferred - self._last_transferred_bytes
            current_speed = bytes_diff / time_diff

            # Keep rolling average of last 5 speed samples
            self._speed_samples.append(current_speed)
            if len(self._speed_samples) > 5:
                self._speed_samples.pop(0)

            self.speed_bps = sum(self._speed_samples) / len(self._speed_samples)

            # Calculate ETA
            if self.speed_bps > 0:
                remaining_bytes = self.file_size - bytes_transferred
                self.eta_seconds = int(remaining_bytes / self.speed_bps)
            else:
                self.eta_seconds = None

            self._last_update_time = current_time
            self._last_transferred_bytes = bytes_transferred

        if self.progress_callback:
            self.progress_callback(self)


class TransferManager(QObject):
    """Manages file transfers with progress tracking"""

    transfer_added = pyqtSignal(str)  # transfer_id
    transfer_updated = pyqtSignal(str)  # transfer_id
    transfer_completed = pyqtSignal(str)  # transfer_id
    transfer_failed = pyqtSignal(str, str)  # transfer_id, error

    def __init__(self, max_concurrent=3):
        super().__init__()
        self.max_concurrent = max_concurrent
        self.transfers: Dict[str, TransferItem] = {}
        self.active_transfers: List[str] = []
        self.transfer_queue: List[str] = []

        # Timer for updating UI
        self.update_timer = QTimer()
        self.update_timer.timeout.connect(self._emit_updates)
        self.update_timer.start(1000)  # Update every second

        self._next_transfer_id = 1

    def add_transfer(self,
                     transfer_type: TransferType,
                     source_path: str,
                     destination_path: str,
                     source_connection: str,
                     destination_connection: str,
                     file_size: int = 0) -> str:
        """Add a new transfer to the queue"""

        transfer_id = f"transfer_{self._next_transfer_id}"
        self._next_transfer_id += 1

        transfer = TransferItem(
            id=transfer_id,
            transfer_type=transfer_type,
            source_path=source_path,
            destination_path=destination_path,
            source_connection=source_connection,
            destination_connection=destination_connection,
            file_size=file_size
        )

        self.transfers[transfer_id] = transfer
        self.transfer_queue.append(transfer_id)

        self.transfer_added.emit(transfer_id)
        self._process_queue()

        return transfer_id

    def start_transfer(self, transfer_id: str) -> bool:
        """Start a specific transfer"""
        if transfer_id not in self.transfers:
            return False

        transfer = self.transfers[transfer_id]
        if transfer.status != TransferStatus.PENDING:
            return False

        if len(self.active_transfers) >= self.max_concurrent:
            if transfer_id not in self.transfer_queue:
                self.transfer_queue.append(transfer_id)
            return False

        # Remove from queue if present
        if transfer_id in self.transfer_queue:
            self.transfer_queue.remove(transfer_id)

        # Start the transfer
        transfer.status = TransferStatus.RUNNING
        transfer.start_time = time.time()
        self.active_transfers.append(transfer_id)

        # Start transfer in separate thread
        threading.Thread(target=self._execute_transfer, args=(transfer_id,), daemon=True).start()

        self.transfer_updated.emit(transfer_id)
        return True

    def pause_transfer(self, transfer_id: str) -> bool:
        """Pause a running transfer"""
        if transfer_id not in self.transfers:
            return False

        transfer = self.transfers[transfer_id]
        if transfer.status == TransferStatus.RUNNING:
            transfer.status = TransferStatus.PAUSED
            self.transfer_updated.emit(transfer_id)
            return True
        return False

    def resume_transfer(self, transfer_id: str) -> bool:
        """Resume a paused transfer"""
        if transfer_id not in self.transfers:
            return False

        transfer = self.transfers[transfer_id]
        if transfer.status == TransferStatus.PAUSED:
            transfer.status = TransferStatus.RUNNING
            self.transfer_updated.emit(transfer_id)
            return True
        return False

    def cancel_transfer(self, transfer_id: str) -> bool:
        """Cancel a transfer"""
        if transfer_id not in self.transfers:
            return False

        transfer = self.transfers[transfer_id]
        transfer.status = TransferStatus.CANCELLED
        transfer.end_time = time.time()

        # Remove from active list
        if transfer_id in self.active_transfers:
            self.active_transfers.remove(transfer_id)

        # Remove from queue
        if transfer_id in self.transfer_queue:
            self.transfer_queue.remove(transfer_id)

        self.transfer_updated.emit(transfer_id)
        self._process_queue()
        return True

    def retry_transfer(self, transfer_id: str) -> bool:
        """Retry a failed transfer"""
        if transfer_id not in self.transfers:
            return False

        transfer = self.transfers[transfer_id]
        if transfer.status == TransferStatus.FAILED:
            transfer.status = TransferStatus.PENDING
            transfer.transferred_bytes = 0
            transfer.error_message = ""
            transfer.retry_count += 1
            transfer.start_time = None
            transfer.end_time = None

            if transfer_id not in self.transfer_queue:
                self.transfer_queue.append(transfer_id)

            self.transfer_updated.emit(transfer_id)
            self._process_queue()
            return True
        return False

    def remove_transfer(self, transfer_id: str) -> bool:
        """Remove a transfer (only if not running)"""
        if transfer_id not in self.transfers:
            return False

        transfer = self.transfers[transfer_id]
        if transfer.status == TransferStatus.RUNNING:
            return False

        # Remove from all lists
        if transfer_id in self.active_transfers:
            self.active_transfers.remove(transfer_id)
        if transfer_id in self.transfer_queue:
            self.transfer_queue.remove(transfer_id)

        del self.transfers[transfer_id]
        return True

    def clear_completed(self):
        """Remove all completed/failed/cancelled transfers"""
        to_remove = []
        for transfer_id, transfer in self.transfers.items():
            if transfer.status in [TransferStatus.COMPLETED, TransferStatus.FAILED, TransferStatus.CANCELLED]:
                to_remove.append(transfer_id)

        for transfer_id in to_remove:
            self.remove_transfer(transfer_id)

    def get_transfer(self, transfer_id: str) -> Optional[TransferItem]:
        """Get transfer by ID"""
        return self.transfers.get(transfer_id)

    def get_all_transfers(self) -> List[TransferItem]:
        """Get all transfers"""
        return list(self.transfers.values())

    def get_running_transfers(self) -> List[TransferItem]:
        """Get currently running transfers"""
        return [self.transfers[tid] for tid in self.active_transfers if tid in self.transfers]

    def get_transfer_stats(self) -> Dict[str, int]:
        """Get transfer statistics"""
        stats = {
            'total': len(self.transfers),
            'pending': 0,
            'running': 0,
            'completed': 0,
            'failed': 0,
            'cancelled': 0,
            'paused': 0
        }

        for transfer in self.transfers.values():
            stats[transfer.status.value] += 1

        return stats

    def stop_all_transfers(self):
        """Stop all active transfers"""
        for transfer_id in self.active_transfers.copy():
            self.cancel_transfer(transfer_id)

    def _process_queue(self):
        """Process the transfer queue"""
        while (len(self.active_transfers) < self.max_concurrent and
               self.transfer_queue):
            transfer_id = self.transfer_queue.pop(0)
            if transfer_id in self.transfers:
                self.start_transfer(transfer_id)

    def _execute_transfer(self, transfer_id: str):
        """Execute a transfer in a separate thread"""
        if transfer_id not in self.transfers:
            return

        transfer = self.transfers[transfer_id]

        try:
            # This is where the actual transfer logic would go
            # For now, simulate a transfer
            self._simulate_transfer(transfer)

            if transfer.status == TransferStatus.RUNNING:
                transfer.status = TransferStatus.COMPLETED
                transfer.end_time = time.time()
                self.transfer_completed.emit(transfer_id)

        except Exception as e:
            transfer.status = TransferStatus.FAILED
            transfer.end_time = time.time()
            transfer.error_message = str(e)
            self.transfer_failed.emit(transfer_id, str(e))

        finally:
            # Remove from active transfers
            if transfer_id in self.active_transfers:
                self.active_transfers.remove(transfer_id)

            self.transfer_updated.emit(transfer_id)
            self._process_queue()

    def _simulate_transfer(self, transfer: TransferItem):
        """Simulate a file transfer for testing"""
        if transfer.file_size == 0:
            transfer.file_size = 1024 * 1024  # 1MB default

        chunk_size = 8192  # 8KB chunks
        total_chunks = transfer.file_size // chunk_size

        for i in range(total_chunks + 1):
            if transfer.status != TransferStatus.RUNNING:
                break

            bytes_to_transfer = min(chunk_size, transfer.file_size - transfer.transferred_bytes)
            if bytes_to_transfer <= 0:
                break

            # Simulate network delay
            time.sleep(0.1)

            transfer.update_progress(transfer.transferred_bytes + bytes_to_transfer)

    def _emit_updates(self):
        """Emit updates for all running transfers"""
        for transfer_id in self.active_transfers:
            if transfer_id in self.transfers:
                self.transfer_updated.emit(transfer_id)
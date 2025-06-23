"""
Base Protocol
Abstract base class for all file transfer protocols
"""

import os
import stat
from abc import ABC, abstractmethod
from typing import List, Dict, Any, Optional, Callable
from dataclasses import dataclass
from datetime import datetime
from enum import Enum


class FileType(Enum):
    """File type enumeration"""
    FILE = "file"
    DIRECTORY = "directory"
    SYMLINK = "symlink"
    SPECIAL = "special"


@dataclass
class FileInfo:
    """Information about a file or directory"""
    name: str
    path: str
    file_type: FileType
    size: int = 0
    modified_time: Optional[datetime] = None
    permissions: str = ""
    owner: str = ""
    group: str = ""
    is_hidden: bool = False

    @property
    def is_directory(self) -> bool:
        return self.file_type == FileType.DIRECTORY

    @property
    def is_file(self) -> bool:
        return self.file_type == FileType.FILE

    @property
    def is_symlink(self) -> bool:
        return self.file_type == FileType.SYMLINK


class ProtocolError(Exception):
    """Base exception for protocol errors"""
    pass


class ConnectionError(ProtocolError):
    """Error during connection establishment"""
    pass


class AuthenticationError(ProtocolError):
    """Authentication failed"""
    pass


class PermissionError(ProtocolError):
    """Permission denied"""
    pass


class FileNotFoundError(ProtocolError):
    """File or directory not found"""
    pass


class TransferError(ProtocolError):
    """Error during file transfer"""
    pass


class BaseProtocol(ABC):
    """Abstract base class for all file transfer protocols"""

    def __init__(self, connection_config: Dict[str, Any]):
        """
        Initialize protocol with connection configuration

        Args:
            connection_config: Dictionary containing connection parameters
        """
        self.config = connection_config
        self.connected = False
        self.current_directory = "/"

        # Extract common configuration
        self.host = connection_config.get('host', '')
        self.port = connection_config.get('port', self.get_default_port())
        self.username = connection_config.get('username', '')
        self.timeout = connection_config.get('timeout', 30)

    @abstractmethod
    def get_default_port(self) -> int:
        """Get the default port for this protocol"""
        pass

    @abstractmethod
    def connect(self) -> bool:
        """
        Establish connection to the remote server

        Returns:
            True if connection successful, False otherwise

        Raises:
            ConnectionError: If connection fails
            AuthenticationError: If authentication fails
        """
        pass

    @abstractmethod
    def disconnect(self):
        """Close the connection to the remote server"""
        pass

    @abstractmethod
    def list_directory(self, path: str = None) -> List[FileInfo]:
        """
        List contents of a directory

        Args:
            path: Directory path (None for current directory)

        Returns:
            List of FileInfo objects

        Raises:
            FileNotFoundError: If directory doesn't exist
            PermissionError: If access denied
        """
        pass

    @abstractmethod
    def change_directory(self, path: str) -> bool:
        """
        Change current directory

        Args:
            path: Target directory path

        Returns:
            True if successful

        Raises:
            FileNotFoundError: If directory doesn't exist
            PermissionError: If access denied
        """
        pass

    @abstractmethod
    def get_current_directory(self) -> str:
        """
        Get current directory path

        Returns:
            Current directory path
        """
        pass

    @abstractmethod
    def download_file(self, remote_path: str, local_path: str,
                      progress_callback: Optional[Callable[[int, int], None]] = None) -> bool:
        """
        Download a file from remote to local

        Args:
            remote_path: Remote file path
            local_path: Local file path
            progress_callback: Optional callback for progress updates (bytes_transferred, total_bytes)

        Returns:
            True if successful

        Raises:
            FileNotFoundError: If remote file doesn't exist
            PermissionError: If access denied
            TransferError: If transfer fails
        """
        pass

    @abstractmethod
    def upload_file(self, local_path: str, remote_path: str,
                    progress_callback: Optional[Callable[[int, int], None]] = None) -> bool:
        """
        Upload a file from local to remote

        Args:
            local_path: Local file path
            remote_path: Remote file path
            progress_callback: Optional callback for progress updates (bytes_transferred, total_bytes)

        Returns:
            True if successful

        Raises:
            FileNotFoundError: If local file doesn't exist
            PermissionError: If access denied
            TransferError: If transfer fails
        """
        pass

    @abstractmethod
    def delete_file(self, path: str) -> bool:
        """
        Delete a file

        Args:
            path: File path to delete

        Returns:
            True if successful

        Raises:
            FileNotFoundError: If file doesn't exist
            PermissionError: If access denied
        """
        pass

    @abstractmethod
    def delete_directory(self, path: str, recursive: bool = False) -> bool:
        """
        Delete a directory

        Args:
            path: Directory path to delete
            recursive: Whether to delete recursively

        Returns:
            True if successful

        Raises:
            FileNotFoundError: If directory doesn't exist
            PermissionError: If access denied
        """
        pass

    @abstractmethod
    def create_directory(self, path: str) -> bool:
        """
        Create a directory

        Args:
            path: Directory path to create

        Returns:
            True if successful

        Raises:
            PermissionError: If access denied
        """
        pass

    @abstractmethod
    def rename_file(self, old_path: str, new_path: str) -> bool:
        """
        Rename/move a file or directory

        Args:
            old_path: Current path
            new_path: New path

        Returns:
            True if successful

        Raises:
            FileNotFoundError: If source doesn't exist
            PermissionError: If access denied
        """
        pass

    @abstractmethod
    def get_file_info(self, path: str) -> Optional[FileInfo]:
        """
        Get information about a file or directory

        Args:
            path: File or directory path

        Returns:
            FileInfo object or None if not found
        """
        pass

    def file_exists(self, path: str) -> bool:
        """
        Check if a file or directory exists

        Args:
            path: Path to check

        Returns:
            True if exists, False otherwise
        """
        return self.get_file_info(path) is not None

    def is_connected(self) -> bool:
        """Check if connection is active"""
        return self.connected

    def get_protocol_name(self) -> str:
        """Get the protocol name"""
        return self.__class__.__name__.replace('Protocol', '').upper()

    def test_connection(self) -> bool:
        """
        Test the connection without storing state

        Returns:
            True if connection test successful
        """
        try:
            if self.connect():
                self.disconnect()
                return True
        except Exception:
            pass
        return False

    def get_capabilities(self) -> List[str]:
        """
        Get list of protocol capabilities

        Returns:
            List of capability strings
        """
        capabilities = ['list', 'download', 'upload', 'delete', 'mkdir', 'rename']

        # Check for additional capabilities
        if hasattr(self, 'set_permissions'):
            capabilities.append('chmod')
        if hasattr(self, 'create_symlink'):
            capabilities.append('symlink')
        if hasattr(self, 'execute_command'):
            capabilities.append('execute')

        return capabilities

    @staticmethod
    def format_permissions(mode: int) -> str:
        """
        Format file permissions in rwx format

        Args:
            mode: File mode from stat

        Returns:
            Permission string like 'rwxr-xr-x'
        """
        permissions = ""

        # Owner permissions
        permissions += 'r' if mode & stat.S_IRUSR else '-'
        permissions += 'w' if mode & stat.S_IWUSR else '-'
        permissions += 'x' if mode & stat.S_IXUSR else '-'

        # Group permissions
        permissions += 'r' if mode & stat.S_IRGRP else '-'
        permissions += 'w' if mode & stat.S_IWGRP else '-'
        permissions += 'x' if mode & stat.S_IXGRP else '-'

        # Other permissions
        permissions += 'r' if mode & stat.S_IROTH else '-'
        permissions += 'w' if mode & stat.S_IWOTH else '-'
        permissions += 'x' if mode & stat.S_IXOTH else '-'

        return permissions

    @staticmethod
    def get_file_type_from_mode(mode: int) -> FileType:
        """
        Get file type from stat mode

        Args:
            mode: File mode from stat

        Returns:
            FileType enum value
        """
        if stat.S_ISDIR(mode):
            return FileType.DIRECTORY
        elif stat.S_ISREG(mode):
            return FileType.FILE
        elif stat.S_ISLNK(mode):
            return FileType.SYMLINK
        else:
            return FileType.SPECIAL

    def __enter__(self):
        """Context manager entry"""
        self.connect()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.disconnect()
"""
SFTP Protocol Implementation
Implements SFTP file transfer using paramiko
"""

import os
import stat
import socket
from typing import List, Optional, Callable
from datetime import datetime

try:
    import paramiko
    from paramiko import SSHClient, SFTPClient, AutoAddPolicy
    PARAMIKO_AVAILABLE = True
except ImportError:
    paramiko = None
    SSHClient = None
    SFTPClient = None
    AutoAddPolicy = None
    PARAMIKO_AVAILABLE = False

from .base_protocol import (
    BaseProtocol, FileInfo, FileType, ProtocolError,
    ConnectionError, AuthenticationError, PermissionError,
    FileNotFoundError, TransferError
)


class SFTPProtocol(BaseProtocol):
    """SFTP protocol implementation using paramiko"""

    def __init__(self, connection_config):
        """Initialize SFTP protocol"""
        if not PARAMIKO_AVAILABLE:
            raise ProtocolError("paramiko library is required for SFTP support")

        super().__init__(connection_config)

        self.ssh_client: Optional[SSHClient] = None
        self.sftp_client: Optional[SFTPClient] = None

        # SFTP-specific configuration
        self.auth_method = connection_config.get('auth_method', 'password')
        self.password = connection_config.get('password', '')
        self.private_key_file = connection_config.get('private_key_file', '')
        self.private_key_passphrase = connection_config.get('private_key_passphrase', '')
        self.use_compression = connection_config.get('use_compression', False)
        self.keepalive = connection_config.get('keepalive', 60)

    def get_default_port(self) -> int:
        """Get default SFTP port"""
        return 22

    def connect(self) -> bool:
        """Establish SFTP connection"""
        try:
            # Create SSH client
            self.ssh_client = SSHClient()
            self.ssh_client.set_missing_host_key_policy(AutoAddPolicy())

            # Prepare connection parameters
            connect_kwargs = {
                'hostname': self.host,
                'port': self.port,
                'username': self.username,
                'timeout': self.timeout,
                'compress': self.use_compression,
            }

            # Handle authentication
            if self.auth_method == 'password':
                connect_kwargs['password'] = self.password
            elif self.auth_method == 'private_key':
                if self.private_key_file:
                    # Load private key
                    try:
                        if self.private_key_file.endswith('.rsa') or 'rsa' in self.private_key_file.lower():
                            key = paramiko.RSAKey.from_private_key_file(
                                self.private_key_file,
                                password=self.private_key_passphrase or None
                            )
                        elif self.private_key_file.endswith('.dsa') or 'dsa' in self.private_key_file.lower():
                            key = paramiko.DSSKey.from_private_key_file(
                                self.private_key_file,
                                password=self.private_key_passphrase or None
                            )
                        elif self.private_key_file.endswith('.ecdsa') or 'ecdsa' in self.private_key_file.lower():
                            key = paramiko.ECDSAKey.from_private_key_file(
                                self.private_key_file,
                                password=self.private_key_passphrase or None
                            )
                        else:
                            # Try to auto-detect key type
                            key = paramiko.RSAKey.from_private_key_file(
                                self.private_key_file,
                                password=self.private_key_passphrase or None
                            )
                        connect_kwargs['pkey'] = key
                    except Exception as e:
                        raise AuthenticationError(f"Failed to load private key: {e}")

            # Connect
            self.ssh_client.connect(**connect_kwargs)

            # Create SFTP client
            self.sftp_client = self.ssh_client.open_sftp()

            # Set keepalive
            if self.keepalive > 0:
                transport = self.ssh_client.get_transport()
                if transport:
                    transport.set_keepalive(self.keepalive)

            # Get initial directory
            try:
                self.current_directory = self.sftp_client.getcwd() or '/'
            except:
                self.current_directory = '/'

            # Navigate to initial directory if specified
            initial_dir = self.config.get('initial_directory')
            if initial_dir:
                try:
                    self.change_directory(initial_dir)
                except:
                    pass  # Ignore if initial directory doesn't exist

            self.connected = True
            return True

        except socket.timeout:
            raise ConnectionError(f"Connection to {self.host}:{self.port} timed out")
        except socket.gaierror as e:
            raise ConnectionError(f"Failed to resolve hostname {self.host}: {e}")
        except paramiko.AuthenticationException as e:
            raise AuthenticationError(f"Authentication failed: {e}")
        except paramiko.SSHException as e:
            raise ConnectionError(f"SSH connection failed: {e}")
        except Exception as e:
            raise ConnectionError(f"Connection failed: {e}")

    def disconnect(self):
        """Close SFTP connection"""
        if self.sftp_client:
            try:
                self.sftp_client.close()
            except:
                pass
            self.sftp_client = None

        if self.ssh_client:
            try:
                self.ssh_client.close()
            except:
                pass
            self.ssh_client = None

        self.connected = False

    def list_directory(self, path: str = None) -> List[FileInfo]:
        """List directory contents"""
        if not self.connected or not self.sftp_client:
            raise ConnectionError("Not connected")

        target_path = path or self.current_directory

        try:
            files = []
            for item in self.sftp_client.listdir_attr(target_path):
                file_info = self._stat_to_fileinfo(item, target_path)
                files.append(file_info)

            # Sort: directories first, then files, both alphabetically
            files.sort(key=lambda x: (not x.is_directory, x.name.lower()))

            return files

        except FileNotFoundError:
            raise FileNotFoundError(f"Directory not found: {target_path}")
        except PermissionError:
            raise PermissionError(f"Permission denied: {target_path}")
        except Exception as e:
            raise ProtocolError(f"Failed to list directory: {e}")

    def change_directory(self, path: str) -> bool:
        """Change current directory"""
        if not self.connected or not self.sftp_client:
            raise ConnectionError("Not connected")

        try:
            # Normalize path
            if not path.startswith('/'):
                # Relative path
                path = os.path.join(self.current_directory, path).replace('\\', '/')

            # Test if directory exists and is accessible
            stat_info = self.sftp_client.stat(path)
            if not stat.S_ISDIR(stat_info.st_mode):
                raise FileNotFoundError(f"Not a directory: {path}")

            # Change directory
            self.sftp_client.chdir(path)
            self.current_directory = self.sftp_client.getcwd() or path
            return True

        except FileNotFoundError:
            raise FileNotFoundError(f"Directory not found: {path}")
        except PermissionError:
            raise PermissionError(f"Permission denied: {path}")
        except Exception as e:
            raise ProtocolError(f"Failed to change directory: {e}")

    def get_current_directory(self) -> str:
        """Get current directory"""
        if not self.connected or not self.sftp_client:
            raise ConnectionError("Not connected")

        try:
            return self.sftp_client.getcwd() or self.current_directory
        except:
            return self.current_directory

    def download_file(self, remote_path: str, local_path: str,
                      progress_callback: Optional[Callable[[int, int], None]] = None) -> bool:
        """Download file from remote to local"""
        if not self.connected or not self.sftp_client:
            raise ConnectionError("Not connected")

        try:
            # Get file size for progress tracking
            stat_info = self.sftp_client.stat(remote_path)
            total_size = stat_info.st_size

            # Create progress wrapper if callback provided
            def progress_wrapper(transferred, total):
                if progress_callback:
                    progress_callback(transferred, total)

            # Ensure local directory exists
            local_dir = os.path.dirname(local_path)
            if local_dir and not os.path.exists(local_dir):
                os.makedirs(local_dir)

            # Download file
            self.sftp_client.get(remote_path, local_path, callback=progress_wrapper)

            # Verify download
            if os.path.exists(local_path):
                local_size = os.path.getsize(local_path)
                if local_size == total_size:
                    return True
                else:
                    raise TransferError(f"Size mismatch: expected {total_size}, got {local_size}")
            else:
                raise TransferError("Downloaded file not found")

        except FileNotFoundError:
            raise FileNotFoundError(f"Remote file not found: {remote_path}")
        except PermissionError:
            raise PermissionError(f"Permission denied: {remote_path}")
        except Exception as e:
            raise TransferError(f"Download failed: {e}")

    def upload_file(self, local_path: str, remote_path: str,
                    progress_callback: Optional[Callable[[int, int], None]] = None) -> bool:
        """Upload file from local to remote"""
        if not self.connected or not self.sftp_client:
            raise ConnectionError("Not connected")

        if not os.path.exists(local_path):
            raise FileNotFoundError(f"Local file not found: {local_path}")

        try:
            # Get file size for progress tracking
            total_size = os.path.getsize(local_path)

            # Create progress wrapper if callback provided
            def progress_wrapper(transferred, total):
                if progress_callback:
                    progress_callback(transferred, total)

            # Ensure remote directory exists
            remote_dir = os.path.dirname(remote_path).replace('\\', '/')
            if remote_dir and remote_dir != '/':
                try:
                    self.sftp_client.stat(remote_dir)
                except FileNotFoundError:
                    # Try to create directory
                    self._create_remote_directory(remote_dir)

            # Upload file
            self.sftp_client.put(local_path, remote_path, callback=progress_wrapper)

            # Verify upload
            try:
                stat_info = self.sftp_client.stat(remote_path)
                if stat_info.st_size == total_size:
                    return True
                else:
                    raise TransferError(f"Size mismatch: expected {total_size}, got {stat_info.st_size}")
            except:
                raise TransferError("Failed to verify uploaded file")

        except PermissionError:
            raise PermissionError(f"Permission denied: {remote_path}")
        except Exception as e:
            raise TransferError(f"Upload failed: {e}")

    def delete_file(self, path: str) -> bool:
        """Delete a file"""
        if not self.connected or not self.sftp_client:
            raise ConnectionError("Not connected")

        try:
            self.sftp_client.remove(path)
            return True
        except FileNotFoundError:
            raise FileNotFoundError(f"File not found: {path}")
        except PermissionError:
            raise PermissionError(f"Permission denied: {path}")
        except Exception as e:
            raise ProtocolError(f"Failed to delete file: {e}")

    def delete_directory(self, path: str, recursive: bool = False) -> bool:
        """Delete a directory"""
        if not self.connected or not self.sftp_client:
            raise ConnectionError("Not connected")

        try:
            if recursive:
                # Delete contents recursively
                for item in self.sftp_client.listdir_attr(path):
                    item_path = f"{path.rstrip('/')}/{item.filename}"
                    if stat.S_ISDIR(item.st_mode):
                        self.delete_directory(item_path, recursive=True)
                    else:
                        self.delete_file(item_path)

            # Delete the directory itself
            self.sftp_client.rmdir(path)
            return True

        except FileNotFoundError:
            raise FileNotFoundError(f"Directory not found: {path}")
        except PermissionError:
            raise PermissionError(f"Permission denied: {path}")
        except Exception as e:
            raise ProtocolError(f"Failed to delete directory: {e}")

    def create_directory(self, path: str) -> bool:
        """Create a directory"""
        if not self.connected or not self.sftp_client:
            raise ConnectionError("Not connected")

        try:
            self.sftp_client.mkdir(path)
            return True
        except PermissionError:
            raise PermissionError(f"Permission denied: {path}")
        except Exception as e:
            raise ProtocolError(f"Failed to create directory: {e}")

    def rename_file(self, old_path: str, new_path: str) -> bool:
        """Rename/move a file or directory"""
        if not self.connected or not self.sftp_client:
            raise ConnectionError("Not connected")

        try:
            self.sftp_client.rename(old_path, new_path)
            return True
        except FileNotFoundError:
            raise FileNotFoundError(f"Source not found: {old_path}")
        except PermissionError:
            raise PermissionError(f"Permission denied")
        except Exception as e:
            raise ProtocolError(f"Failed to rename: {e}")

    def get_file_info(self, path: str) -> Optional[FileInfo]:
        """Get file information"""
        if not self.connected or not self.sftp_client:
            raise ConnectionError("Not connected")

        try:
            stat_info = self.sftp_client.stat(path)
            return self._stat_to_fileinfo(stat_info, os.path.dirname(path), os.path.basename(path))
        except FileNotFoundError:
            return None
        except Exception:
            return None

    def _stat_to_fileinfo(self, stat_info, parent_path: str, filename: str = None) -> FileInfo:
        """Convert SFTP stat to FileInfo"""
        name = filename or stat_info.filename
        full_path = f"{parent_path.rstrip('/')}/{name}"

        # Determine file type
        file_type = self.get_file_type_from_mode(stat_info.st_mode)

        # Format modified time
        modified_time = None
        if hasattr(stat_info, 'st_mtime') and stat_info.st_mtime:
            modified_time = datetime.fromtimestamp(stat_info.st_mtime)

        # Format permissions
        permissions = self.format_permissions(stat_info.st_mode)

        # Check if hidden (starts with dot)
        is_hidden = name.startswith('.')

        return FileInfo(
            name=name,
            path=full_path,
            file_type=file_type,
            size=stat_info.st_size or 0,
            modified_time=modified_time,
            permissions=permissions,
            owner=str(stat_info.st_uid) if hasattr(stat_info, 'st_uid') else "",
            group=str(stat_info.st_gid) if hasattr(stat_info, 'st_gid') else "",
            is_hidden=is_hidden
        )

    def _create_remote_directory(self, path: str):
        """Create remote directory recursively"""
        parts = path.strip('/').split('/')
        current_path = ''

        for part in parts:
            if not part:
                continue

            current_path += '/' + part

            try:
                self.sftp_client.stat(current_path)
            except FileNotFoundError:
                try:
                    self.sftp_client.mkdir(current_path)
                except:
                    pass  # Ignore errors, might already exist

    def execute_command(self, command: str) -> tuple[str, str, int]:
        """
        Execute a command on the remote server

        Args:
            command: Command to execute

        Returns:
            Tuple of (stdout, stderr, exit_code)
        """
        if not self.connected or not self.ssh_client:
            raise ConnectionError("Not connected")

        try:
            stdin, stdout, stderr = self.ssh_client.exec_command(command, timeout=self.timeout)

            stdout_data = stdout.read().decode('utf-8')
            stderr_data = stderr.read().decode('utf-8')
            exit_code = stdout.channel.recv_exit_status()

            return stdout_data, stderr_data, exit_code

        except Exception as e:
            raise ProtocolError(f"Command execution failed: {e}")

    def set_permissions(self, path: str, mode: int) -> bool:
        """
        Set file permissions

        Args:
            path: File path
            mode: Permission mode (octal)

        Returns:
            True if successful
        """
        if not self.connected or not self.sftp_client:
            raise ConnectionError("Not connected")

        try:
            self.sftp_client.chmod(path, mode)
            return True
        except Exception as e:
            raise ProtocolError(f"Failed to set permissions: {e}")
"""
Protocols Package
Contains implementations for different file transfer protocols
"""

from .base_protocol import BaseProtocol, ProtocolError, FileInfo
from .sftp_protocol import SFTPProtocol

# Registry of available protocols
PROTOCOL_REGISTRY = {
    'sftp': SFTPProtocol,
    # Add other protocols as they are implemented
    # 'ftp': FTPProtocol,
    # 'scp': SCPProtocol,
    # 'samba': SambaProtocol,
    # 'ssh': SSHProtocol,
    # 'nfs': NFSProtocol,
    # 'webdav': WebDAVProtocol,
}

def get_protocol_class(protocol_name: str):
    """Get protocol class by name"""
    return PROTOCOL_REGISTRY.get(protocol_name.lower())

def get_available_protocols():
    """Get list of available protocol names"""
    return list(PROTOCOL_REGISTRY.keys())

def create_protocol(protocol_name: str, connection_config: dict):
    """Create a protocol instance"""
    protocol_class = get_protocol_class(protocol_name)
    if not protocol_class:
        raise ProtocolError(f"Unknown protocol: {protocol_name}")

    return protocol_class(connection_config)

__all__ = [
    'BaseProtocol',
    'ProtocolError',
    'FileInfo',
    'SFTPProtocol',
    'get_protocol_class',
    'get_available_protocols',
    'create_protocol',
    'PROTOCOL_REGISTRY'
]
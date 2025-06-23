#!/usr/bin/env python3
"""
Setup script for Multi-Protocol File Explorer
"""

from setuptools import setup, find_packages
import os
import sys

# Ensure we're using Python 3.8+
if sys.version_info < (3, 8):
    print("Error: Python 3.8 or higher is required")
    sys.exit(1)

# Read README for long description
def read_readme():
    readme_path = os.path.join(os.path.dirname(__file__), 'README.md')
    if os.path.exists(readme_path):
        with open(readme_path, 'r', encoding='utf-8') as f:
            return f.read()
    return "Multi-Protocol File Explorer with support for SFTP, FTP, SCP, Samba, SSH, NFS, and WebDAV"

# Read requirements
def read_requirements():
    req_path = os.path.join(os.path.dirname(__file__), 'requirements.txt')
    requirements = []
    if os.path.exists(req_path):
        with open(req_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#'):
                    requirements.append(line)
    return requirements

# Read version from main module (optional)
def get_version():
    version_file = os.path.join(os.path.dirname(__file__), 'version.py')
    if os.path.exists(version_file):
        with open(version_file, 'r') as f:
            exec(f.read())
            return locals().get('__version__', '1.0.0')
    return '1.0.0'

setup(
    name='multi-protocol-file-explorer',
    version=get_version(),
    description='Multi-Protocol File Explorer with PyQt6 GUI',
    long_description=read_readme(),
    long_description_content_type='text/markdown',
    author='Your Name',
    author_email='your.email@example.com',
    url='https://github.com/yourusername/file-explorer',

    # Package information
    packages=find_packages(),
    py_modules=[
        'main',
        'config_manager',
        'transfer_manager',
        'connection_panel',
        'connection_dialog',
        'file_explorer_panel',
        'transfer_panel',
        'launcher'
    ],

    # Dependencies
    install_requires=read_requirements(),

    # Optional dependencies
    extras_require={
        'dev': [
            'pytest>=7.0.0',
            'black>=22.0.0',
            'flake8>=4.0.0',
            'mypy>=0.991',
        ],
        'test': [
            'pytest>=7.0.0',
            'pytest-qt>=4.0.0',
            'pytest-cov>=3.0.0',
        ],
    },

    # Entry points
    entry_points={
        'console_scripts': [
            'file-explorer=launcher:main',
            'multi-file-explorer=launcher:main',
        ],
        'gui_scripts': [
            'file-explorer-gui=launcher:main',
        ],
    },

    # Package data
    package_data={
        '': ['*.txt', '*.md', '*.rst'],
        'protocols': ['*.py'],
    },

    # Include additional files
    include_package_data=True,

    # Metadata
    classifiers=[
        'Development Status :: 4 - Beta',
        'Intended Audience :: End Users/Desktop',
        'Intended Audience :: System Administrators',
        'License :: OSI Approved :: MIT License',
        'Operating System :: OS Independent',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.8',
        'Programming Language :: Python :: 3.9',
        'Programming Language :: Python :: 3.10',
        'Programming Language :: Python :: 3.11',
        'Programming Language :: Python :: 3.12',
        'Topic :: Communications :: File Sharing',
        'Topic :: Desktop Environment :: File Managers',
        'Topic :: Internet :: File Transfer Protocol (FTP)',
        'Topic :: System :: Archiving',
        'Topic :: System :: Networking',
        'Environment :: X11 Applications :: Qt',
    ],

    # Requirements
    python_requires='>=3.8',

    # Keywords
    keywords='file-manager file-explorer sftp ftp scp ssh file-transfer gui qt pyqt',

    # Project URLs
    project_urls={
        'Bug Reports': 'https://github.com/yourusername/file-explorer/issues',
        'Source': 'https://github.com/yourusername/file-explorer',
        'Documentation': 'https://github.com/yourusername/file-explorer/wiki',
    },

    # Zip safe
    zip_safe=False,
)
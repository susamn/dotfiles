#!/usr/bin/env python3
"""
Music Library Normalizer
Renames music files/folders and updates playlists accordingly
"""

import os
import sys
import argparse
import re
import unicodedata
from pathlib import Path
from collections import defaultdict
from typing import Dict, List, Tuple, Optional

try:
    from mutagen import File as MutagenFile
except ImportError:
    print("ERROR: mutagen not installed. Run: pip install mutagen")
    sys.exit(1)


class MusicLibraryNormalizer:
    def __init__(self, music_dir: str, playlist_input: Optional[str], playlist_output: Optional[str],
                 mode: str, dry_run_limit: int = 1000, duplicate_report: Optional[str] = None,
                 action: str = 'organize', ingest_dir: Optional[str] = None):
        self.music_dir = Path(music_dir).resolve()
        self.playlist_input = Path(playlist_input).resolve() if playlist_input else None
        self.playlist_output = Path(playlist_output).resolve() if playlist_output else None
        self.mode = mode.lower()
        self.dry_run_limit = dry_run_limit
        self.duplicate_report = Path(duplicate_report).resolve() if duplicate_report else None
        self.action = action.lower()
        self.ingest_dir = Path(ingest_dir).resolve() if ingest_dir else None

        # Track renames: old_path -> new_path
        self.rename_map: Dict[Path, Path] = {}
        self.processed_count = 0
        self.error_count = 0
        self.conflict_count = 0

        # Audio extensions to process
        self.audio_extensions = {'.mp3', '.flac', '.m4a', '.ogg', '.opus',
                                '.wav', '.wma', '.aac', '.ape', '.mpc'}

        # Directories to skip (including Apple Music package files)
        self.skip_dirs = {'.movpkg', '@eaDir', '.Spotlight-V100', '.Trashes'}
        # Also skip any directory ending with .movpkg (Apple Music packages)
        self.skip_extensions = {'.movpkg'}

        # Statistics
        self.stats = {
            'audio_files': 0,
            'audio_with_mcatalogid': 0,
            'audio_without_mcatalogid': 0,
            'directories': 0,
            'skipped_items': 0
        }

        # Track duplicates: (original_path, desired_name, actual_sequenced_name)
        self.duplicates: List[Tuple[Path, str, str]] = []

        # Track folder merges: (source_folder, target_folder, files_moved_count)
        self.folder_merges: List[Tuple[Path, Path, int]] = []

        # Track canonical folder names: stripped_name -> (normalized_name, parent_path)
        # This helps detect "R. D. Burman" vs "R.D. Burman" vs "R.D.Burman" as same
        self.canonical_folder_map: Dict[str, Dict[Path, str]] = {}

        # Track deleted empty folders
        self.deleted_folders: List[Path] = []

        # Ingest statistics
        self.ingest_stats = {
            'processed': 0,
            'moved': 0,
            'skipped': 0,
            'errors': 0,
            'artists_created': 0,
            'albums_created': 0
        }
        self.skipped_files: List[Tuple[Path, str]] = []  # (file_path, reason)
        self.created_artists: List[Path] = []  # Track newly created artist folders
        self.created_albums: List[Path] = []  # Track newly created album folders

        # Observe mode findings
        self.observe_findings = {
            'files_with_spaces': [],
            'files_without_mcatalogid': [],
            'files_mcatalogid_mismatch': [],
            'files_multiple_mcatalogid': [],  # Files with multiple [mid-...] in name
            'canonical_folder_groups': {},  # canonical -> [folder1, folder2, ...]
            'potential_duplicates': [],
            'non_audio_files': [],
            'folders_with_spaces': [],
            'empty_folders': [],  # Folders without any audio files
        }

        # Reconcile mode findings
        self.reconcile_findings = {
            'total_playlists': 0,
            'total_entries': 0,
            'broken_entries': [],  # (playlist_file, line_num, path, reason)
            'playlists_with_issues': {},  # playlist -> [broken_entries]
        }

    def get_mcatalogid(self, file_path: Path, debug: bool = False) -> Optional[str]:
        """
        Extract MCATALOGID tag from audio file using mutagen
        Supports multiple tag formats based on your tagging code
        """
        try:
            audio = MutagenFile(file_path, easy=False)
            if audio is None:
                if debug:
                    print(f"  [DEBUG] Could not read file: {file_path.name}")
                return None

            if debug:
                print(f"  [DEBUG] File type: {type(audio).__name__}")

            # ID3 tags (MP3)
            if hasattr(audio, 'tags') and audio.tags:
                tag_type = type(audio.tags).__name__
                if debug:
                    print(f"  [DEBUG] Tag type: {tag_type}")

                # For MP3 - check TXXX:mcatalogid or TXXX:MCATALOGID
                if 'ID3' in tag_type:
                    if debug:
                        print(f"  [DEBUG] Checking MP3 TXXX frames...")

                    # Check TXXX frames with desc='mcatalogid' or 'MCATALOGID'
                    try:
                        txxx_frames = audio.tags.getall('TXXX')
                        for frame in txxx_frames:
                            if debug:
                                print(f"  [DEBUG] TXXX frame desc: '{frame.desc}'")
                            if frame.desc and frame.desc.upper() == 'MCATALOGID':
                                value = str(frame.text[0]) if frame.text else None
                                if value and debug:
                                    print(f"  [DEBUG] ✓ Found in TXXX:MCATALOGID = {value}")
                                return value
                        if debug:
                            print(f"  [DEBUG] TXXX frames found: {[f.desc for f in txxx_frames]}")
                    except Exception as e:
                        if debug:
                            print(f"  [DEBUG] Error reading TXXX: {e}")

                # For M4A - check multiple freeform tags
                elif 'MP4Tags' in tag_type or 'MP4' in tag_type:
                    if debug:
                        print(f"  [DEBUG] Checking M4A/MP4 tags...")

                    # Check all possible M4A tag locations (from your create_M4A_Track code)
                    possible_keys = [
                        'mcat',  # mcatalogid1
                        'MCAT',  # mcatalogid2
                        '----:com.apple.iTunes:CUSTOM1',  # mcatalogid3
                        '----:com.apple.iTunes:CUSTOM2',  # mcatalogid4
                        '----:com.apple.iTunes:MusicIP PUID',  # mcatalogid5
                        'MCATALOGID',
                    ]

                    for key in possible_keys:
                        if key in audio.tags:
                            value = audio.tags[key]
                            if isinstance(value, list) and value:
                                value = value[0]
                            if isinstance(value, bytes):
                                value = value.decode('utf-8', errors='ignore')
                            value = str(value).strip()
                            if value and debug:
                                print(f"  [DEBUG] ✓ Found in M4A {key} = {value}")
                            if value:
                                return value

                    if debug:
                        print(f"  [DEBUG] M4A tags available: {list(audio.tags.keys())[:15]}")

            # Vorbis comments (FLAC, OGG, WMA)
            if hasattr(audio, 'tags') and audio.tags:
                # FLAC/OGG uses Vorbis comments
                if hasattr(audio.tags, 'get'):
                    if debug:
                        print(f"  [DEBUG] Checking Vorbis/ASF tags...")

                    # Check all possible Vorbis/ASF tag locations (from your create_FLAC_Track/WMA code)
                    possible_keys = [
                        'MCATALOGID',
                        'mcatalogid',
                        'CUSTOM1',
                        'CUSTOM2',
                        'MUSICIP_PUID',
                        'MUSICIP/PUID',  # WMA variant
                    ]

                    for key in possible_keys:
                        try:
                            value = audio.tags.get(key)
                            if value:
                                value = str(value[0]) if isinstance(value, list) else str(value)
                                value = value.strip()
                                if value and debug:
                                    print(f"  [DEBUG] ✓ Found in Vorbis/ASF {key} = {value}")
                                if value:
                                    return value
                        except Exception as e:
                            if debug:
                                print(f"  [DEBUG] Error checking {key}: {e}")

                    if debug and hasattr(audio.tags, 'keys'):
                        print(f"  [DEBUG] Vorbis/ASF tags available: {list(audio.tags.keys())[:15]}")

            if debug:
                print(f"  [DEBUG] ✗ No MCATALOGID found")
            return None

        except (PermissionError, OSError) as e:
            # File access errors - these are serious and should be logged
            print(f"ERROR: Cannot access file {file_path}: {e}")
            self.error_count += 1
            return None

        except Exception as e:
            # Mutagen-specific errors (corrupt tags, unsupported formats, etc.)
            # These are less critical - log but continue
            if debug:
                print(f"  [DEBUG] Error reading tags from {file_path.name}: {e}")
                import traceback
                traceback.print_exc()
            else:
                # In normal mode, just note it
                print(f"WARNING: Could not read tags from {file_path.name}: {type(e).__name__}")
            return None

    def get_canonical_key(self, name: str) -> str:
        """
        Get canonical key for folder name matching
        - Applies Unicode NFC normalization
        - Strips ALL non-alphanumeric characters and lowercases
        Example: "R. D. Burman" -> "rdburman"
        Example: "café" (NFD) -> "cafe" (NFC normalized)
        """
        # Normalize Unicode first for cross-platform compatibility
        name = unicodedata.normalize('NFC', name)
        return re.sub(r'[^a-z0-9]', '', name.lower())

    def get_artist_album_from_tags(self, file_path: Path) -> Tuple[Optional[str], Optional[str]]:
        """
        Extract artist and album from audio file tags.
        Prefers albumArtist over artist tag.
        Returns (artist, album) or (None, None) if no tags found.
        """
        try:
            audio = MutagenFile(file_path, easy=False)
            if audio is None:
                return None, None

            # Check if file has any tags at all
            if not hasattr(audio, 'tags') or not audio.tags:
                return None, None

            artist = None
            album = None
            tag_type = type(audio.tags).__name__

            # ID3 tags (MP3)
            if 'ID3' in tag_type:
                # Prefer album artist (TPE2) over artist (TPE1)
                if 'TPE2' in audio.tags and audio.tags['TPE2'].text:
                    artist = str(audio.tags['TPE2'].text[0])
                elif 'TPE1' in audio.tags and audio.tags['TPE1'].text:
                    artist = str(audio.tags['TPE1'].text[0])

                if 'TALB' in audio.tags and audio.tags['TALB'].text:
                    album = str(audio.tags['TALB'].text[0])

            # M4A tags
            elif 'MP4Tags' in tag_type or 'MP4' in tag_type:
                # Prefer album artist (aART) over artist (©ART)
                if 'aART' in audio.tags and audio.tags['aART']:
                    artist = str(audio.tags['aART'][0])
                elif '\xa9ART' in audio.tags and audio.tags['\xa9ART']:
                    artist = str(audio.tags['\xa9ART'][0])

                if '\xa9alb' in audio.tags and audio.tags['\xa9alb']:
                    album = str(audio.tags['\xa9alb'][0])

            # Vorbis comments (FLAC, OGG, WMA)
            elif hasattr(audio.tags, 'get'):
                # Prefer ALBUMARTIST over ARTIST
                artist_tag = audio.tags.get('ALBUMARTIST') or audio.tags.get('albumartist')
                if not artist_tag:
                    artist_tag = audio.tags.get('ARTIST') or audio.tags.get('artist')

                if artist_tag:
                    artist = str(artist_tag[0]) if isinstance(artist_tag, list) else str(artist_tag)

                album_tag = audio.tags.get('ALBUM') or audio.tags.get('album')
                if album_tag:
                    album = str(album_tag[0]) if isinstance(album_tag, list) else str(album_tag)

            return artist.strip() if artist else None, album.strip() if album else None

        except Exception as e:
            return None, None

    def find_artist_folder(self, artist: str) -> Optional[Path]:
        """
        Find matching artist folder in library using canonical matching.
        Returns artist folder path if found, None otherwise.
        """
        if not artist:
            return None

        canonical_artist = self.get_canonical_key(artist)

        # Search for artist folder
        for item in self.music_dir.iterdir():
            if not item.is_dir() or self.should_skip_dir(item.name):
                continue

            # Check canonical match
            if self.get_canonical_key(item.name) == canonical_artist:
                return item

        return None

    def find_album_folder(self, artist_folder: Path, album: str) -> Optional[Path]:
        """
        Find matching album folder within artist folder using canonical matching.
        Returns album folder path if found, None otherwise.
        """
        if not album or not artist_folder.exists():
            return None

        canonical_album = self.get_canonical_key(album)

        # Search for album folder
        for item in artist_folder.iterdir():
            if not item.is_dir() or self.should_skip_dir(item.name):
                continue

            # Check canonical match
            if self.get_canonical_key(item.name) == canonical_album:
                return item

        return None

    def normalize_name(self, name: str, is_file: bool = False,
                      file_path: Optional[Path] = None) -> str:
        """
        Normalize filename/dirname with input validation:
        - Apply Unicode NFC normalization (cross-platform compatibility)
        - Remove null bytes and path separators
        - Handle Windows reserved names
        - Enforce filesystem length limits
        - Strip leading non-alphanumeric characters
        - Lowercase
        - Remove spaces around punctuation (", " -> ",", " & " -> "&")
        - Replace remaining spaces and underscores with hyphens
        - Remove all dots (only file extension keeps the dot)
        - Keep UTF-8 and special characters (commas, ampersands, etc.)
        - Add MCATALOGID if it's a music file
        """
        # Input validation
        if not name or len(name) == 0:
            raise ValueError("Name cannot be empty")

        # Apply Unicode NFC normalization FIRST for cross-platform compatibility
        # macOS uses NFD, Linux/Windows use NFC - normalize to NFC
        name = unicodedata.normalize('NFC', name)

        # Remove null bytes (can truncate filenames)
        name = name.replace('\x00', '')

        # Remove path separators (security: prevent directory traversal)
        name = name.replace('/', '-').replace('\\', '-')

        if is_file and file_path:
            # Split name and extension
            stem = name.rsplit('.', 1)[0] if '.' in name else name
            ext = '.' + name.rsplit('.', 1)[1].lower() if '.' in name else ''

            # Strip leading non-alphanumeric characters from stem
            stem = re.sub(r'^[^a-zA-Z0-9]+', '', stem)

            # Check if MCATALOGID already exists in filename
            # Pattern matches: -[mid-value] or -[value] at end
            mcatalogid_pattern = r'-\[(?:mid-)?([^\]]+)\]$'
            existing_match = re.search(mcatalogid_pattern, stem)
            existing_mcatalogid = existing_match.group(1) if existing_match else None

            # Get MCATALOGID from file tags if it's an audio file
            mcatalogid = None
            if ext in self.audio_extensions:
                mcatalogid = self.get_mcatalogid(file_path)

            # If file already has MCATALOGID in name, check if it matches tags
            if existing_mcatalogid:
                if mcatalogid and existing_mcatalogid.lower() == mcatalogid.lower():
                    # Tag matches filename - keep it, don't duplicate
                    # Remove old format to re-add in new format
                    stem = re.sub(mcatalogid_pattern, '', stem)
                elif not mcatalogid:
                    # No tag found, but filename has one - keep filename version
                    mcatalogid = existing_mcatalogid
                    stem = re.sub(mcatalogid_pattern, '', stem)
                else:
                    # Tag differs from filename - use tag (more authoritative)
                    stem = re.sub(mcatalogid_pattern, '', stem)
            elif existing_match:
                # Has some bracketed suffix but not MCATALOGID - remove it
                stem = re.sub(mcatalogid_pattern, '', stem)

            # Normalize: lowercase first
            normalized_stem = stem.lower()

            # Replace underscores with hyphens
            normalized_stem = normalized_stem.replace('_', '-')

            # Remove all dots from the stem (only extension should have a dot)
            normalized_stem = normalized_stem.replace('.', '')

            # Remove spaces around non-word characters (punctuation like , & etc.)
            # This handles: ", " -> "," and " & " -> "&"
            normalized_stem = re.sub(r'\s*([^\w\s-])\s*', r'\1', normalized_stem)

            # Now replace remaining spaces with hyphens
            normalized_stem = normalized_stem.replace(' ', '-')

            # Collapse multiple consecutive hyphens into single hyphen
            normalized_stem = re.sub(r'-+', '-', normalized_stem)

            # Add MCATALOGID if available
            if mcatalogid:
                normalized_stem = f"{normalized_stem}-[mid-{mcatalogid}]"

            final_name = f"{normalized_stem}{ext}"

            # CRITICAL: Final check - ensure NO spaces in filename
            if ' ' in final_name:
                final_name = final_name.replace(' ', '-')
                # Re-collapse multiple hyphens that might result
                final_name = re.sub(r'-+', '-', final_name)

            # Check for Windows reserved names
            reserved_names = {'CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3',
                            'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
                            'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6',
                            'LPT7', 'LPT8', 'LPT9'}
            name_without_ext = final_name.rsplit('.', 1)[0] if '.' in final_name else final_name
            if name_without_ext.upper() in reserved_names:
                final_name = f"_{final_name}"  # Prefix with underscore

            # Enforce filesystem length limit (255 bytes for most filesystems)
            max_bytes = 255
            if len(final_name.encode('utf-8')) > max_bytes:
                # Truncate stem to fit within limit
                available_bytes = max_bytes - len(ext.encode('utf-8')) - 10  # Leave margin
                if available_bytes < 10:
                    raise ValueError(f"Extension too long to create valid filename: {ext}")

                # Truncate normalized_stem at UTF-8 byte boundary
                truncated_stem = normalized_stem.encode('utf-8')[:available_bytes].decode('utf-8', errors='ignore')
                # Remove trailing hyphen if truncation created one
                truncated_stem = truncated_stem.rstrip('-')
                final_name = f"{truncated_stem}{ext}"

            return final_name
        else:
            # Directory: strip leading non-alphanumeric
            clean_name = re.sub(r'^[^a-zA-Z0-9]+', '', name)

            # Lowercase
            clean_name = clean_name.lower()

            # Replace underscores with hyphens
            clean_name = clean_name.replace('_', '-')

            # Remove all dots from directory names
            clean_name = clean_name.replace('.', '')

            # Remove spaces around non-word characters (punctuation like , & etc.)
            # This handles: ", " -> "," and " & " -> "&"
            clean_name = re.sub(r'\s*([^\w\s-])\s*', r'\1', clean_name)

            # Now replace remaining spaces with hyphens
            clean_name = clean_name.replace(' ', '-')

            # Collapse multiple consecutive hyphens into single hyphen
            clean_name = re.sub(r'-+', '-', clean_name)

            # CRITICAL: Final check - ensure NO spaces in directory name
            if ' ' in clean_name:
                clean_name = clean_name.replace(' ', '-')
                # Re-collapse multiple hyphens that might result
                clean_name = re.sub(r'-+', '-', clean_name)

            # Check for Windows reserved names
            reserved_names = {'CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3',
                            'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
                            'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6',
                            'LPT7', 'LPT8', 'LPT9'}
            if clean_name.upper() in reserved_names:
                clean_name = f"_{clean_name}"  # Prefix with underscore

            # Enforce filesystem length limit (255 bytes for most filesystems)
            max_bytes = 255
            if len(clean_name.encode('utf-8')) > max_bytes:
                # Truncate at UTF-8 byte boundary
                clean_name = clean_name.encode('utf-8')[:max_bytes].decode('utf-8', errors='ignore')
                # Remove trailing hyphen if truncation created one
                clean_name = clean_name.rstrip('-')

            return clean_name

    def get_unique_name(self, parent_dir: Path, desired_name: str, original_path: Path,
                        max_attempts: int = 50000) -> Tuple[str, bool]:
        """
        Generate unique name by adding sequence number if conflict exists.
        Uses hash fallback if too many duplicates exist.
        Returns: (unique_name, is_duplicate)
        """
        if not (parent_dir / desired_name).exists():
            return desired_name, False

        # Split extension if it's a file
        if '.' in desired_name and not desired_name.startswith('.'):
            parts = desired_name.rsplit('.', 1)
            stem, ext = parts[0], '.' + parts[1]
        else:
            stem, ext = desired_name, ''

        # Try sequence numbers
        for i in range(1, max_attempts):
            candidate = f"{stem}-{i}{ext}"
            if not (parent_dir / candidate).exists():
                self.conflict_count += 1
                # Track this duplicate
                self.duplicates.append((original_path, desired_name, candidate))
                return candidate, True

        # Fallback: Use hash of original path for uniqueness
        import hashlib
        path_hash = hashlib.md5(str(original_path).encode()).hexdigest()[:8]
        candidate = f"{stem}-dup-{path_hash}{ext}"

        if not (parent_dir / candidate).exists():
            self.conflict_count += 1
            self.duplicates.append((original_path, desired_name, candidate))
            print(f"WARNING: Using hash-based name after {max_attempts} attempts: {candidate}")
            return candidate, True

        # Ultimate fallback: UUID (guaranteed unique)
        import uuid
        candidate = f"{stem}-{uuid.uuid4().hex[:8]}{ext}"
        self.conflict_count += 1
        self.duplicates.append((original_path, desired_name, candidate))
        print(f"WARNING: Using UUID-based name: {candidate}")
        return candidate, True

    def should_skip_dir(self, dirname: str) -> bool:
        """Check if directory should be skipped"""
        # Check if in skip list
        if dirname in self.skip_dirs:
            return True
        # Check if has a skip extension (e.g., .movpkg)
        for ext in self.skip_extensions:
            if dirname.endswith(ext):
                return True
        return False

    def is_safe_path(self, path: Path) -> bool:
        """
        Check if path is safe to operate on.
        Returns False if:
        - Path is a symlink
        - Any parent component is a symlink
        - Path resolves outside music library
        """
        try:
            # Check if the path itself is a symlink
            if path.is_symlink():
                return False

            # Check if path resolves outside music library (security check)
            resolved = path.resolve(strict=False)
            music_dir_resolved = self.music_dir.resolve(strict=False)

            try:
                resolved.relative_to(music_dir_resolved)
            except ValueError:
                # Path resolves outside music library - suspicious
                return False

            return True

        except (OSError, RuntimeError) as e:
            # If we can't check safely, err on the side of caution
            print(f"WARNING: Cannot verify safety of path {path}: {e}")
            return False

    def is_audio_file(self, file_path: Path) -> bool:
        """Check if file is an audio file"""
        return file_path.suffix.lower() in self.audio_extensions

    def has_audio_files(self, dir_path: Path) -> bool:
        """Check if directory or any subdirectory contains audio files"""
        try:
            for root, dirs, files in os.walk(dir_path):
                # Skip unwanted directories
                dirs[:] = [d for d in dirs if not self.should_skip_dir(d)]

                # Check for any audio files
                for filename in files:
                    if self.is_audio_file(Path(root) / filename):
                        return True
            return False
        except Exception:
            return False

    def delete_empty_folders(self):
        """
        Delete folders that don't contain any audio files (after renaming).
        Uses safe rmdir() which only works on empty directories - atomic operation.
        """
        print("\nScanning for empty folders...")

        # Collect all directories, deepest first (don't follow symlinks)
        dirs_to_check = []
        for root, dirs, files in os.walk(self.music_dir, topdown=False, followlinks=False):
            root_path = Path(root)

            # Skip unwanted directories and symlinks
            dirs[:] = [d for d in dirs if not self.should_skip_dir(d)
                      and not (root_path / d).is_symlink()]

            for dirname in dirs:
                dir_path = root_path / dirname

                # Skip symlinks - never delete symlinks
                if dir_path.is_symlink():
                    continue

                dirs_to_check.append(dir_path)

        # Check and delete empty folders (deepest first so parents become empty after children deleted)
        for dir_path in dirs_to_check:
            # Skip symlinks (paranoid double-check)
            if dir_path.is_symlink():
                continue

            if self.mode == 'dryrun':
                # Double-check before reporting in dry run
                if not self.has_audio_files(dir_path):
                    self.deleted_folders.append(dir_path)
                    rel_path = dir_path.relative_to(self.music_dir)
                    print(f"  [DELETE] {rel_path}/ (no audio files)")
            else:
                # Normal mode: use atomic rmdir (only works on empty dirs)
                try:
                    # rmdir only works on empty directories - safe!
                    dir_path.rmdir()
                    self.deleted_folders.append(dir_path)
                    rel_path = dir_path.relative_to(self.music_dir)
                    print(f"  [DELETED] {rel_path}/")
                except OSError as e:
                    # Common errors we can silently ignore
                    if e.errno == 39:  # ENOTEMPTY - directory not empty (files added after scan)
                        continue
                    elif e.errno == 2:  # ENOENT - directory doesn't exist (already deleted)
                        continue
                    elif e.errno == 66:  # ENOTEMPTY on macOS
                        continue
                    else:
                        # Unexpected error - report it
                        print(f"  [ERROR] Could not delete {dir_path}: {e}")

    def collect_items(self) -> List[Tuple[Path, int, str]]:
        """
        Collect music files and directories that contain audio files.
        Skips symlinks for safety.
        """
        items = []
        dirs_with_audio = set()

        # Don't follow symlinks - critical for safety
        for root, dirs, files in os.walk(self.music_dir, followlinks=False):
            root_path = Path(root)
            depth = len(root_path.relative_to(self.music_dir).parts)

            # Skip unwanted directories and symlinks
            dirs[:] = [d for d in dirs if not self.should_skip_dir(d)
                      and not (root_path / d).is_symlink()]

            # Collect audio files only (skip symlinks)
            for filename in files:
                file_path = root_path / filename

                # Skip symlinks for safety
                if file_path.is_symlink():
                    continue

                # Skip files outside music library (paranoid check)
                if not self.is_safe_path(file_path):
                    print(f"WARNING: Skipping unsafe path: {file_path}")
                    continue

                if self.is_audio_file(file_path):
                    items.append((file_path, depth, 'file'))

                    # Mark all parent directories as containing audio
                    parent = file_path.parent
                    while parent != self.music_dir:
                        dirs_with_audio.add(parent)
                        parent = parent.parent

        # Add only directories that contain audio files (directly or in subdirectories)
        for dir_path in dirs_with_audio:
            depth = len(dir_path.relative_to(self.music_dir).parts)
            items.append((dir_path, depth, 'dir'))

        # Sort by depth (deepest first), then by type (FILES before DIRS), then by path
        # Files must be processed before their parent directories are renamed
        items.sort(key=lambda x: (-x[1], x[2] == 'dir', str(x[0])))

        return items

    def update_rename_map_for_moved_dir(self, old_parent: Path, new_parent: Path):
        """Update all rename_map entries when a directory is moved/merged"""
        # Find all mappings that were under the old parent
        updated_mappings = {}

        for original_path, renamed_path in self.rename_map.items():
            try:
                # Check if the renamed path is under the old parent
                if renamed_path.is_relative_to(old_parent):
                    # Calculate new path under new parent
                    relative_part = renamed_path.relative_to(old_parent)
                    new_renamed_path = new_parent / relative_part
                    updated_mappings[original_path] = new_renamed_path
            except (ValueError, AttributeError):
                # Path not related to this parent
                continue

        # Apply updates
        self.rename_map.update(updated_mappings)

    def merge_directory(self, source_dir: Path, target_dir: Path) -> int:
        """
        Merge contents of source_dir into target_dir
        Returns number of items moved
        """
        try:
            import shutil
            files_moved = 0

            # Move all contents from source to target
            for item in source_dir.iterdir():
                source_item = source_dir / item.name
                target_item = target_dir / item.name

                if target_item.exists():
                    if target_item.is_dir() and source_item.is_dir():
                        # Recursive merge for subdirectories
                        count = self.merge_directory(source_item, target_item)
                        files_moved += count
                        # Update rename_map for all children
                        self.update_rename_map_for_moved_dir(source_item, target_item)
                    elif target_item.is_file() and source_item.is_file():
                        # File conflict - add sequence number
                        base_name = item.name
                        if '.' in base_name:
                            stem, ext = base_name.rsplit('.', 1)
                            ext = '.' + ext
                        else:
                            stem, ext = base_name, ''

                        # Find unique name
                        for i in range(1, 10000):
                            candidate = target_dir / f"{stem}-{i}{ext}"
                            if not candidate.exists():
                                if self.mode == 'normal':
                                    shutil.move(str(source_item), str(candidate))

                                # Update rename map (may need to update existing mapping)
                                for orig, renamed in list(self.rename_map.items()):
                                    if renamed == source_item:
                                        self.rename_map[orig] = candidate
                                        break
                                else:
                                    self.rename_map[source_item] = candidate

                                files_moved += 1
                                break
                else:
                    # No conflict, move directly
                    if self.mode == 'normal':
                        shutil.move(str(source_item), str(target_item))

                    # Update rename map (may need to update existing mapping)
                    for orig, renamed in list(self.rename_map.items()):
                        if renamed == source_item:
                            self.rename_map[orig] = target_item
                            break
                    else:
                        self.rename_map[source_item] = target_item

                    files_moved += 1

            # Remove empty source directory
            if self.mode == 'normal' and source_dir.exists():
                source_dir.rmdir()

            return files_moved

        except Exception as e:
            print(f"ERROR merging {source_dir} into {target_dir}: {e}")
            import traceback
            traceback.print_exc()
            return 0

    def rename_item(self, old_path: Path, item_type: str) -> Optional[Path]:
        """Rename a single file or directory"""
        try:
            # Check if the path still exists (parent might have been renamed already)
            if not old_path.exists():
                # Try to find the new path through parent renames
                resolved_path = old_path
                for old, new in self.rename_map.items():
                    try:
                        if resolved_path.is_relative_to(old):
                            # Replace the renamed parent in the path
                            relative_part = resolved_path.relative_to(old)
                            resolved_path = new / relative_part
                    except (ValueError, AttributeError):
                        continue

                if resolved_path.exists():
                    old_path = resolved_path
                else:
                    # Path doesn't exist and can't be resolved - skip
                    return None

            old_name = old_path.name
            parent = old_path.parent

            # Normalize the name
            is_file = item_type == 'file'
            new_name = self.normalize_name(old_name, is_file, old_path if is_file else None)

            # Track statistics
            if is_file and self.is_audio_file(old_path):
                self.stats['audio_files'] += 1
                mcatalogid = self.get_mcatalogid(old_path)
                if mcatalogid:
                    self.stats['audio_with_mcatalogid'] += 1
                else:
                    self.stats['audio_without_mcatalogid'] += 1
            elif not is_file:
                self.stats['directories'] += 1

            # If name unchanged, skip
            if new_name == old_name:
                # Still track canonical mapping for unchanged directories
                if not is_file:
                    canonical_key = self.get_canonical_key(old_name)
                    if parent not in self.canonical_folder_map:
                        self.canonical_folder_map[parent] = {}
                    self.canonical_folder_map[parent][canonical_key] = old_name
                return None

            # CRITICAL VALIDATION: Ensure absolutely NO spaces in final path
            if ' ' in new_name:
                error_msg = f"CRITICAL ERROR: Space detected in final name: '{new_name}'"
                print(error_msg)
                raise ValueError(error_msg)

            # FOR DIRECTORIES: Check canonical name matching
            # Example: "R. D. Burman", "R.D. Burman", "R.D.Burman" all map to same canonical "rdburman"
            if not is_file:
                canonical_key = self.get_canonical_key(old_name)

                # Check if we already have a folder with this canonical name in this parent
                if parent in self.canonical_folder_map:
                    if canonical_key in self.canonical_folder_map[parent]:
                        # Found existing folder with same canonical name!
                        existing_normalized_name = self.canonical_folder_map[parent][canonical_key]
                        new_path = parent / existing_normalized_name

                        if self.mode == 'dryrun':
                            print(f"  [CANONICAL MERGE] {old_path.relative_to(self.music_dir)}/ -> {new_path.relative_to(self.music_dir)}/ (canonical: {canonical_key})")

                        # Perform merge
                        items_moved = 0
                        if self.mode == 'normal':
                            items_moved = self.merge_directory(old_path, new_path)

                        self.folder_merges.append((old_path, new_path, items_moved))

                        # Map old directory to target directory
                        self.rename_map[old_path] = new_path
                        if self.mode == 'normal':
                            self.update_rename_map_for_moved_dir(old_path, new_path)

                        self.processed_count += 1
                        return new_path

                # No canonical match found, register this normalized name
                if parent not in self.canonical_folder_map:
                    self.canonical_folder_map[parent] = {}
                self.canonical_folder_map[parent][canonical_key] = new_name

            new_path = parent / new_name

            # Handle directory vs file conflicts differently
            if not is_file and new_path.exists() and new_path.is_dir():
                # Directory conflict: MERGE instead of renaming
                if self.mode == 'dryrun':
                    print(f"  [MERGE] {old_path.relative_to(self.music_dir)}/ -> {new_path.relative_to(self.music_dir)}/")

                # Perform merge and get count of items moved
                items_moved = 0
                if self.mode == 'normal':
                    items_moved = self.merge_directory(old_path, new_path)

                self.folder_merges.append((old_path, new_path, items_moved))

                # Map old directory to target directory and update all child mappings
                self.rename_map[old_path] = new_path
                if self.mode == 'normal':
                    self.update_rename_map_for_moved_dir(old_path, new_path)

                self.processed_count += 1
                return new_path

            elif is_file and new_path.exists():
                # File conflict: add sequence number
                unique_name, is_duplicate = self.get_unique_name(parent, new_name, old_path)
                new_path = parent / unique_name

            # Store the rename mapping
            self.rename_map[old_path] = new_path

            # Perform rename in normal mode
            if self.mode == 'normal':
                old_path.rename(new_path)

            self.processed_count += 1
            return new_path

        except Exception as e:
            self.error_count += 1
            print(f"ERROR renaming {old_path}: {e}")
            return None

    def write_duplicate_report(self, output_path: Path):
        """Write a report of files that got sequence numbers due to duplicates"""
        if not self.duplicates:
            return

        try:
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write("# Duplicate Files Report\n")
                f.write(f"# Generated: {Path.cwd()}\n")
                f.write(f"# Total duplicates found: {len(self.duplicates)}\n")
                f.write("#\n")
                f.write("# Format: Original Path | Desired Name | Actual Name (with sequence)\n")
                f.write("# These files likely have duplicate content and may need cleanup\n")
                f.write("#\n\n")

                for original_path, desired_name, sequenced_name in self.duplicates:
                    rel_path = original_path.relative_to(self.music_dir)
                    parent = rel_path.parent
                    f.write(f"{rel_path}\n")
                    f.write(f"  Desired:  {parent}/{desired_name}\n")
                    f.write(f"  Actual:   {parent}/{sequenced_name}\n")
                    f.write("\n")

            print(f"\nDuplicate report written to: {output_path}")

        except Exception as e:
            print(f"ERROR writing duplicate report: {e}")

    def find_normalized_path(self, original_path_str: str) -> Optional[Path]:
        """
        Find the normalized version of a playlist path by canonical matching.
        Returns the actual path after all renames and merges.
        """
        # Parse original path (could be absolute or relative)
        if Path(original_path_str).is_absolute():
            original_path = Path(original_path_str)
        else:
            original_path = self.music_dir / original_path_str

        # If original path still exists unchanged, use it
        if original_path.exists():
            return original_path

        # Try to find normalized path by canonical matching
        try:
            # Get path relative to music_dir
            if original_path.is_relative_to(self.music_dir):
                rel_parts = original_path.relative_to(self.music_dir).parts
            else:
                # Path is outside music_dir, can't help
                return None
        except (ValueError, AttributeError):
            return None

        # Walk through directory structure finding canonical matches
        current = self.music_dir

        for i, part in enumerate(rel_parts):
            is_last = (i == len(rel_parts) - 1)

            # Check if this is a file (last part with audio extension)
            is_file = is_last and any(part.lower().endswith(ext) for ext in self.audio_extensions)

            if is_file:
                # This is a file - look for canonical match
                if not current.exists() or not current.is_dir():
                    return None

                # Get canonical stem (without extension and MCATALOGID)
                stem = part.rsplit('.', 1)[0] if '.' in part else part
                ext = '.' + part.rsplit('.', 1)[1].lower() if '.' in part else ''

                # Remove any existing MCATALOGID from original stem for comparison
                stem_clean = re.sub(r'-\[(?:mid-)?[^\]]+\]$', '', stem)
                canonical_stem = self.get_canonical_key(stem_clean)

                # Search for matching file
                for item in current.iterdir():
                    if item.is_file() and item.suffix.lower() == ext:
                        # Get item's stem without MCATALOGID
                        item_stem = item.name.rsplit('.', 1)[0] if '.' in item.name else item.name
                        item_stem_clean = re.sub(r'-\[(?:mid-)?[^\]]+\]$', '', item_stem)

                        if self.get_canonical_key(item_stem_clean) == canonical_stem:
                            return item

                # File not found
                return None
            else:
                # This is a directory - look for canonical match
                canonical_key = self.get_canonical_key(part)

                found = False
                if current.exists() and current.is_dir():
                    for item in current.iterdir():
                        if item.is_dir() and not self.should_skip_dir(item.name):
                            if self.get_canonical_key(item.name) == canonical_key:
                                current = item
                                found = True
                                break

                if not found:
                    return None

        return current if current.exists() else None

    def strip_mcatalogid_from_path(self, path_str: str) -> str:
        """
        Remove MCATALOGID from a file path for comparison purposes.
        Example: "artist/album/song-[mid-abc123].mp3" -> "artist/album/song.mp3"
        """
        path = Path(path_str)
        parts = list(path.parts)

        if len(parts) > 0:
            # Check if last part (filename) has MCATALOGID
            filename = parts[-1]
            if '.' in filename:
                stem = filename.rsplit('.', 1)[0]
                ext = '.' + filename.rsplit('.', 1)[1]

                # Remove MCATALOGID pattern from stem
                stem_clean = re.sub(r'-\[(?:mid-)?[^\]]+\]$', '', stem)
                parts[-1] = stem_clean + ext
            else:
                # No extension, just clean the filename
                parts[-1] = re.sub(r'-\[(?:mid-)?[^\]]+\]$', '', filename)

        # Reconstruct path
        return str(Path(*parts)) if parts else path_str

    def update_playlists(self):
        """
        Update all .m3u playlist files with new paths.
        This runs AFTER all file renaming and folder merging is complete.
        Uses canonical path resolution to find renamed files.
        Ignores MCATALOGID when comparing paths (only updates if path structure changed).
        """
        if not self.playlist_input:
            return  # Playlist update not needed (e.g., ingest mode)

        if not self.playlist_input.exists():
            print(f"\nWARNING: Playlist input directory not found: {self.playlist_input}")
            return

        # Create output directory if it doesn't exist
        if self.mode == 'normal':
            self.playlist_output.mkdir(parents=True, exist_ok=True)

        playlist_files = list(self.playlist_input.glob('*.m3u'))
        print(f"\n{'[DRY RUN] ' if self.mode == 'dryrun' else ''}Updating {len(playlist_files)} playlist(s)...")
        print("Resolving paths using canonical matching (ignoring MCATALOGID differences)...")

        for playlist_file in playlist_files:
            try:
                self.update_single_playlist(playlist_file)
            except Exception as e:
                self.error_count += 1
                print(f"ERROR updating playlist {playlist_file.name}: {e}")

    def read_playlist_safe(self, playlist_file: Path) -> Optional[List[str]]:
        """
        Safely read playlist file with multiple encoding attempts.
        Properly manages file handles to prevent leaks.
        """
        encodings = ['utf-8', 'utf-8-sig', 'latin-1', 'cp1252', 'iso-8859-1']

        for encoding in encodings:
            try:
                with open(playlist_file, 'r', encoding=encoding) as f:
                    return f.readlines()
            except (UnicodeDecodeError, LookupError):
                continue
            except Exception as e:
                print(f"ERROR: Cannot read playlist {playlist_file.name}: {e}")
                return None

        # Last resort: binary read with error replacement
        try:
            with open(playlist_file, 'rb') as f:
                content = f.read().decode('utf-8', errors='replace')
                return content.splitlines(keepends=True)
        except Exception as e:
            print(f"ERROR: Cannot read playlist {playlist_file.name} even in binary mode: {e}")
            return None

    def update_single_playlist(self, playlist_file: Path):
        """
        Update a single .m3u playlist file using canonical path resolution.

        Process (runs AFTER all renaming is complete):
        1. Read each path from playlist
        2. Convert path to canonical format and check if it exists
        3. If exists AND different from original → replace with new path
        4. If exists AND same as original → keep as-is (already processed)
        5. If not exists → keep original (broken reference)
        """
        lines = self.read_playlist_safe(playlist_file)
        if lines is None:
            self.error_count += 1
            return

        updated_lines = []
        updates_count = 0
        not_found_count = 0

        for line in lines:
            stripped = line.strip()

            # Skip comments and empty lines
            if stripped.startswith('#') or not stripped:
                updated_lines.append(line)
                continue

            # This is a file path - convert to canonical format
            was_absolute = Path(stripped).is_absolute()

            # Find the normalized/canonical path
            normalized_path = self.find_normalized_path(stripped)

            if normalized_path and normalized_path.exists():
                # Path exists - check if it changed
                # Convert normalized path to same format as original (absolute or relative)
                if was_absolute:
                    new_path_str = str(normalized_path)
                else:
                    try:
                        new_path_str = str(normalized_path.relative_to(self.music_dir))
                    except ValueError:
                        new_path_str = str(normalized_path)

                # Always write the new path (with MCATALOGID)
                updated_lines.append(new_path_str + '\n')

                # Compare paths WITHOUT MCATALOGID to determine if we should count this as an update
                # This prevents counting "song.mp3" -> "song-[mid-abc].mp3" as a structural change
                original_without_mcid = self.strip_mcatalogid_from_path(stripped)
                new_without_mcid = self.strip_mcatalogid_from_path(new_path_str)

                if original_without_mcid != new_without_mcid:
                    # Path structure changed (rename/move) - count as update
                    updates_count += 1
            else:
                # File not found - keep original path (will be broken reference)
                updated_lines.append(line)
                not_found_count += 1

        # Write updated playlist
        output_file = self.playlist_output / playlist_file.name

        if self.mode == 'dryrun':
            if updates_count > 0 or not_found_count > 0:
                msg = f"  {playlist_file.name}:"
                if updates_count > 0:
                    msg += f" {updates_count} path(s) would be updated"
                if not_found_count > 0:
                    msg += f", {not_found_count} not found"
                print(msg)
        else:
            with open(output_file, 'w', encoding='utf-8') as f:
                f.writelines(updated_lines)
            if updates_count > 0 or not_found_count > 0:
                msg = f"  {playlist_file.name}:"
                if updates_count > 0:
                    msg += f" {updates_count} path(s) updated"
                if not_found_count > 0:
                    msg += f", {not_found_count} not found"
                print(msg)

    def test_mcatalogid_extraction(self, num_files: int = 10):
        """Test MCATALOGID extraction on sample files"""
        print(f"Testing MCATALOGID extraction on up to {num_files} audio files...\n")

        count = 0
        found_count = 0

        for root, dirs, files in os.walk(self.music_dir):
            if count >= num_files:
                break

            # Skip unwanted directories
            dirs[:] = [d for d in dirs if not self.should_skip_dir(d)]

            for filename in files:
                if count >= num_files:
                    break

                file_path = Path(root) / filename
                if self.is_audio_file(file_path):
                    count += 1
                    rel_path = file_path.relative_to(self.music_dir)
                    print(f"[{count}/{num_files}] {rel_path}")

                    mcatalogid = self.get_mcatalogid(file_path, debug=True)
                    if mcatalogid:
                        found_count += 1
                        print(f"  ✓ MCATALOGID: {mcatalogid}\n")
                    else:
                        print(f"  ✗ No MCATALOGID found\n")

        print(f"{'='*60}")
        print(f"Test Summary:")
        print(f"  Files tested: {count}")
        print(f"  With MCATALOGID: {found_count}")
        print(f"  Without MCATALOGID: {count - found_count}")
        print(f"{'='*60}")

    def ingest_file(self, file_path: Path) -> bool:
        """
        Ingest a single audio file into the library.

        Process:
        1. Check if file has any tags - skip if not
        2. Extract artist (prefer albumArtist) and album tags
        3. Find or CREATE artist folder using canonical matching
        4. Find or CREATE album folder using canonical matching
        5. Place file in album folder (handling name collisions)
        6. MOVE file (remove from ingest directory)

        Returns True if successful, False otherwise
        """
        try:
            self.ingest_stats['processed'] += 1

            # Get artist and album from tags (prefers albumArtist)
            artist, album = self.get_artist_album_from_tags(file_path)

            # Check if file has any tags at all
            if not artist and not album:
                reason = "No tags found in file"
                self.skipped_files.append((file_path, reason))
                self.ingest_stats['skipped'] += 1
                print(f"  ⚠️  SKIP: {file_path.name} - {reason}")
                return False

            # Artist is required
            if not artist:
                reason = "No artist/albumArtist tag found"
                self.skipped_files.append((file_path, reason))
                self.ingest_stats['skipped'] += 1
                print(f"  ⚠️  SKIP: {file_path.name} - {reason}")
                return False

            # Find or create artist folder using canonical matching
            artist_folder = self.find_artist_folder(artist)

            if not artist_folder:
                # Artist folder doesn't exist - CREATE it atomically
                normalized_artist = self.normalize_name(artist, is_file=False)
                artist_folder = self.music_dir / normalized_artist

                if self.mode == 'dryrun':
                    print(f"  👤 WOULD CREATE: {artist_folder.relative_to(self.music_dir)}/")
                    self.ingest_stats['artists_created'] += 1
                    self.created_artists.append(artist_folder)
                else:
                    try:
                        # Try atomic creation (fails if exists)
                        artist_folder.mkdir(parents=True, exist_ok=False)
                        self.ingest_stats['artists_created'] += 1
                        self.created_artists.append(artist_folder)
                        print(f"  👤 CREATED: {artist_folder.relative_to(self.music_dir)}/")
                    except FileExistsError:
                        # Another process created it - re-check canonical match
                        artist_folder = self.find_artist_folder(artist)
                        if not artist_folder:
                            # Still can't find it, use the path we tried to create
                            artist_folder = self.music_dir / normalized_artist
                            if not artist_folder.exists():
                                # Very rare race condition - create with exist_ok
                                artist_folder.mkdir(parents=True, exist_ok=True)

            # Determine target folder (artist root or album subfolder)
            target_folder = artist_folder

            if album:
                # Try to find existing album folder
                album_folder = self.find_album_folder(artist_folder, album)

                if album_folder:
                    # Album exists - use it
                    target_folder = album_folder
                else:
                    # Album doesn't exist - CREATE it atomically
                    normalized_album = self.normalize_name(album, is_file=False)
                    album_folder = artist_folder / normalized_album

                    if self.mode == 'dryrun':
                        print(f"  📁 WOULD CREATE: {album_folder.relative_to(self.music_dir)}/")
                        self.ingest_stats['albums_created'] += 1
                        self.created_albums.append(album_folder)
                    else:
                        try:
                            # Try atomic creation (fails if exists)
                            album_folder.mkdir(parents=True, exist_ok=False)
                            self.ingest_stats['albums_created'] += 1
                            self.created_albums.append(album_folder)
                            print(f"  📁 CREATED: {album_folder.relative_to(self.music_dir)}/")
                        except FileExistsError:
                            # Another process created it - re-check canonical match
                            album_folder = self.find_album_folder(artist_folder, album)
                            if not album_folder:
                                # Still can't find it, use the path we tried to create
                                album_folder = artist_folder / normalized_album
                                if not album_folder.exists():
                                    # Very rare race condition - create with exist_ok
                                    album_folder.mkdir(parents=True, exist_ok=True)

                    target_folder = album_folder

            # Normalize the filename
            normalized_filename = self.normalize_name(file_path.name, is_file=True, file_path=file_path)

            # Check for filename collision
            target_path = target_folder / normalized_filename
            if target_path.exists():
                # Find unique name with sequence number
                stem = normalized_filename.rsplit('.', 1)[0] if '.' in normalized_filename else normalized_filename
                ext = '.' + normalized_filename.rsplit('.', 1)[1] if '.' in normalized_filename else ''

                for i in range(1, 10000):
                    candidate = target_folder / f"{stem}-{i}{ext}"
                    if not candidate.exists():
                        target_path = candidate
                        break

            # Move file (removes from ingest directory)
            rel_target = target_path.relative_to(self.music_dir)

            if self.mode == 'dryrun':
                print(f"  ✓ WOULD MOVE: {file_path.name} → {rel_target}")
            else:
                print(f"  ✓ MOVED: {file_path.name} → {rel_target}")

            if self.mode == 'normal':
                import shutil
                shutil.move(str(file_path), str(target_path))

            self.ingest_stats['moved'] += 1
            return True

        except Exception as e:
            self.ingest_stats['errors'] += 1
            print(f"  ❌ ERROR: {file_path.name} - {e}")
            import traceback
            traceback.print_exc()
            return False

    def run_observe(self):
        """Observe library and report potential issues"""
        print(f"Music Library Observer")
        print(f"Analyzing: {self.music_dir}")
        print()

        if not self.music_dir.exists():
            print(f"ERROR: Music library not found: {self.music_dir}")
            return

        print("Scanning library...")

        # Track canonical groups by parent
        canonical_groups_by_parent = {}
        normalized_file_names = {}  # normalized_name -> [files]

        total_files = 0
        total_dirs = 0

        for root, dirs, files in os.walk(self.music_dir):
            root_path = Path(root)

            # Skip unwanted directories
            dirs[:] = [d for d in dirs if not self.should_skip_dir(d)]

            # Check directories
            for dirname in dirs:
                total_dirs += 1
                dir_path = root_path / dirname

                # Check for spaces
                if ' ' in dirname:
                    self.observe_findings['folders_with_spaces'].append(dir_path)

                # Check if folder is empty (no audio files)
                if not self.has_audio_files(dir_path):
                    self.observe_findings['empty_folders'].append(dir_path)

                # Track canonical groups
                canonical_key = self.get_canonical_key(dirname)
                if root_path not in canonical_groups_by_parent:
                    canonical_groups_by_parent[root_path] = {}

                if canonical_key not in canonical_groups_by_parent[root_path]:
                    canonical_groups_by_parent[root_path][canonical_key] = []
                canonical_groups_by_parent[root_path][canonical_key].append(dirname)

            # Check files
            for filename in files:
                file_path = root_path / filename
                total_files += 1

                # Check if audio file
                if not self.is_audio_file(file_path):
                    self.observe_findings['non_audio_files'].append(file_path)
                    continue

                # Check for spaces in filename
                if ' ' in filename:
                    self.observe_findings['files_with_spaces'].append(file_path)

                # Check MCATALOGID
                mcatalogid_from_tag = self.get_mcatalogid(file_path)

                # Extract MCATALOGID from filename
                stem = filename.rsplit('.', 1)[0] if '.' in filename else filename
                mcatalogid_pattern = r'-\[(?:mid-)?([^\]]+)\]'

                # Find ALL matches (to detect duplicates)
                all_matches = re.findall(mcatalogid_pattern, stem)

                # Check for multiple MCATALOGID in filename
                if len(all_matches) > 1:
                    self.observe_findings['files_multiple_mcatalogid'].append((file_path, all_matches))

                # Get the last match (most recent/authoritative)
                match = re.search(mcatalogid_pattern + r'$', stem)
                mcatalogid_from_filename = match.group(1) if match else None

                if not mcatalogid_from_tag and not mcatalogid_from_filename:
                    self.observe_findings['files_without_mcatalogid'].append(file_path)
                elif mcatalogid_from_tag and mcatalogid_from_filename:
                    if mcatalogid_from_tag.lower() != mcatalogid_from_filename.lower():
                        self.observe_findings['files_mcatalogid_mismatch'].append(
                            (file_path, mcatalogid_from_filename, mcatalogid_from_tag)
                        )

                # Check for potential duplicates (same normalized name in same folder)
                normalized = self.normalize_name(filename, is_file=True, file_path=file_path)
                key = (root_path, normalized)
                if key not in normalized_file_names:
                    normalized_file_names[key] = []
                normalized_file_names[key].append(filename)

        # Find canonical folder groups (multiple folders with same canonical key)
        for parent, groups in canonical_groups_by_parent.items():
            for canonical_key, folder_names in groups.items():
                if len(folder_names) > 1:
                    # Multiple folders with same canonical key
                    full_paths = [parent / name for name in folder_names]
                    self.observe_findings['canonical_folder_groups'][canonical_key] = full_paths

        # Find potential duplicate files
        for (parent, normalized), originals in normalized_file_names.items():
            if len(originals) > 1:
                self.observe_findings['potential_duplicates'].append((parent, normalized, originals))

        # Print report
        print(f"\n{'='*70}")
        print(f"OBSERVATION REPORT")
        print(f"{'='*70}\n")

        print(f"Library Statistics:")
        print(f"  Total directories: {total_dirs}")
        print(f"  Total files: {total_files}")
        print(f"  Audio files: {total_files - len(self.observe_findings['non_audio_files'])}")
        print(f"  Non-audio files: {len(self.observe_findings['non_audio_files'])}")

        # Empty folders (will be deleted)
        if self.observe_findings['empty_folders']:
            print(f"\n🗑️  Empty folders (will be DELETED) ({len(self.observe_findings['empty_folders'])}):")
            for folder in self.observe_findings['empty_folders'][:10]:
                print(f"  - {folder.relative_to(self.music_dir)}/")
            if len(self.observe_findings['empty_folders']) > 10:
                print(f"  ... and {len(self.observe_findings['empty_folders']) - 10} more")

        # Folders with spaces
        if self.observe_findings['folders_with_spaces']:
            print(f"\n⚠️  Folders with spaces ({len(self.observe_findings['folders_with_spaces'])}):")
            for folder in self.observe_findings['folders_with_spaces'][:10]:
                print(f"  - {folder.relative_to(self.music_dir)}/")
            if len(self.observe_findings['folders_with_spaces']) > 10:
                print(f"  ... and {len(self.observe_findings['folders_with_spaces']) - 10} more")

        # Files with spaces
        if self.observe_findings['files_with_spaces']:
            print(f"\n⚠️  Files with spaces ({len(self.observe_findings['files_with_spaces'])}):")
            for file in self.observe_findings['files_with_spaces'][:10]:
                print(f"  - {file.relative_to(self.music_dir)}")
            if len(self.observe_findings['files_with_spaces']) > 10:
                print(f"  ... and {len(self.observe_findings['files_with_spaces']) - 10} more")

        # Canonical folder groups (will be merged)
        if self.observe_findings['canonical_folder_groups']:
            print(f"\n🔀 Folders that will be MERGED ({len(self.observe_findings['canonical_folder_groups'])} groups):")
            for canonical_key, folders in list(self.observe_findings['canonical_folder_groups'].items())[:10]:
                print(f"  Canonical: '{canonical_key}'")
                for folder in folders:
                    print(f"    - {folder.relative_to(self.music_dir)}/")
            if len(self.observe_findings['canonical_folder_groups']) > 10:
                print(f"  ... and {len(self.observe_findings['canonical_folder_groups']) - 10} more groups")

        # Files with multiple MCATALOGID (CRITICAL ISSUE!)
        if self.observe_findings['files_multiple_mcatalogid']:
            print(f"\n🚨 Files with MULTIPLE MCATALOGID tags ({len(self.observe_findings['files_multiple_mcatalogid'])}):")
            print(f"    ⚠️  CRITICAL: These files have duplicate [mid-...] patterns!")
            for file, mcatalogids in self.observe_findings['files_multiple_mcatalogid'][:10]:
                print(f"  - {file.relative_to(self.music_dir)}")
                print(f"    Found: {', '.join([f'[mid-{mid}]' for mid in mcatalogids])}")
            if len(self.observe_findings['files_multiple_mcatalogid']) > 10:
                print(f"  ... and {len(self.observe_findings['files_multiple_mcatalogid']) - 10} more")

        # Files without MCATALOGID
        if self.observe_findings['files_without_mcatalogid']:
            print(f"\n📋 Files without MCATALOGID ({len(self.observe_findings['files_without_mcatalogid'])}):")
            for file in self.observe_findings['files_without_mcatalogid'][:10]:
                print(f"  - {file.relative_to(self.music_dir)}")
            if len(self.observe_findings['files_without_mcatalogid']) > 10:
                print(f"  ... and {len(self.observe_findings['files_without_mcatalogid']) - 10} more")

        # MCATALOGID mismatches
        if self.observe_findings['files_mcatalogid_mismatch']:
            print(f"\n⚠️  MCATALOGID mismatches (filename ≠ tag) ({len(self.observe_findings['files_mcatalogid_mismatch'])}):")
            for file, filename_id, tag_id in self.observe_findings['files_mcatalogid_mismatch'][:10]:
                print(f"  - {file.relative_to(self.music_dir)}")
                print(f"    Filename: {filename_id}, Tag: {tag_id}")
            if len(self.observe_findings['files_mcatalogid_mismatch']) > 10:
                print(f"  ... and {len(self.observe_findings['files_mcatalogid_mismatch']) - 10} more")

        # Potential duplicate files
        if self.observe_findings['potential_duplicates']:
            print(f"\n🔍 Potential duplicate files ({len(self.observe_findings['potential_duplicates'])} sets):")
            for parent, normalized, originals in self.observe_findings['potential_duplicates'][:10]:
                print(f"  Would normalize to: {normalized}")
                for orig in originals:
                    print(f"    - {(parent / orig).relative_to(self.music_dir)}")
            if len(self.observe_findings['potential_duplicates']) > 10:
                print(f"  ... and {len(self.observe_findings['potential_duplicates']) - 10} more sets")

        print(f"\n{'='*70}")
        print(f"RECOMMENDATIONS:")
        print(f"{'='*70}")

        if self.observe_findings['files_multiple_mcatalogid']:
            print(f"🚨 CRITICAL: {len(self.observe_findings['files_multiple_mcatalogid'])} files have MULTIPLE MCATALOGID tags!")
            print(f"   Run 'organize' in normal mode to fix (will keep only the last/correct one)")

        if self.observe_findings['empty_folders']:
            print(f"🗑️  {len(self.observe_findings['empty_folders'])} empty folders will be DELETED when organizing")

        if self.observe_findings['folders_with_spaces'] or self.observe_findings['files_with_spaces']:
            print(f"✓ Run 'organize' action to normalize names (remove spaces)")

        if self.observe_findings['canonical_folder_groups']:
            print(f"✓ Organize will merge {len(self.observe_findings['canonical_folder_groups'])} folder groups")

        if self.observe_findings['files_without_mcatalogid']:
            print(f"⚠️  {len(self.observe_findings['files_without_mcatalogid'])} files missing MCATALOGID tags")
            print(f"   Consider tagging them before organizing")

        if self.observe_findings['files_mcatalogid_mismatch']:
            print(f"⚠️  {len(self.observe_findings['files_mcatalogid_mismatch'])} files have mismatched MCATALOGID")
            print(f"   Organize will use tag value (more authoritative)")

        if self.observe_findings['potential_duplicates']:
            print(f"⚠️  {len(self.observe_findings['potential_duplicates'])} potential duplicates found")
            print(f"   Review duplicate report after organizing")

        if not any([
            self.observe_findings['files_multiple_mcatalogid'],
            self.observe_findings['folders_with_spaces'],
            self.observe_findings['files_with_spaces'],
            self.observe_findings['canonical_folder_groups'],
            self.observe_findings['files_without_mcatalogid'],
            self.observe_findings['files_mcatalogid_mismatch'],
            self.observe_findings['potential_duplicates'],
            self.observe_findings['empty_folders']
        ]):
            print(f"✅ Library looks good! No major issues found.")

        print(f"\n{'='*70}\n")

    def run_reconcile(self):
        """Reconcile playlists with music library - find broken references"""
        print(f"Playlist Reconciliation")
        print(f"Music library: {self.music_dir}")
        print(f"Playlist directory: {self.playlist_input}")
        print()

        if not self.music_dir.exists():
            print(f"ERROR: Music library not found: {self.music_dir}")
            return

        if not self.playlist_input or not self.playlist_input.exists():
            print(f"ERROR: Playlist directory not found: {self.playlist_input}")
            return

        # Find all .m3u playlists
        print("Scanning playlists...")
        playlist_files = list(self.playlist_input.glob('*.m3u'))

        if not playlist_files:
            print("No .m3u playlist files found.")
            return

        self.reconcile_findings['total_playlists'] = len(playlist_files)
        print(f"Found {len(playlist_files)} playlist(s)\n")

        print("Checking playlist entries...")

        for playlist_file in playlist_files:
            try:
                # Use safe playlist reading
                lines = self.read_playlist_safe(playlist_file)
                if lines is None:
                    continue

                playlist_issues = []

                for line_num, line in enumerate(lines, 1):
                    stripped = line.strip()

                    # Skip comments and empty lines
                    if not stripped or stripped.startswith('#'):
                        continue

                    self.reconcile_findings['total_entries'] += 1

                    # This is a file path
                    file_path = None
                    reason = None

                    # Determine if absolute or relative path
                    if Path(stripped).is_absolute():
                        file_path = Path(stripped)
                    else:
                        # Relative to music directory
                        file_path = self.music_dir / stripped

                    # Check if file exists
                    if not file_path.exists():
                        reason = "File not found"
                    elif not file_path.is_file():
                        reason = "Path is not a file"

                    if reason:
                        entry = (playlist_file.name, line_num, stripped, reason)
                        self.reconcile_findings['broken_entries'].append(entry)
                        playlist_issues.append(entry)

                # Track playlists with issues
                if playlist_issues:
                    self.reconcile_findings['playlists_with_issues'][playlist_file.name] = playlist_issues

            except Exception as e:
                print(f"ERROR reading playlist {playlist_file.name}: {e}")

        # Print report
        print(f"\n{'='*70}")
        print(f"RECONCILIATION REPORT")
        print(f"{'='*70}\n")

        total_broken = len(self.reconcile_findings['broken_entries'])
        total_working = self.reconcile_findings['total_entries'] - total_broken
        broken_percentage = (total_broken / self.reconcile_findings['total_entries'] * 100) if self.reconcile_findings['total_entries'] > 0 else 0

        print(f"Statistics:")
        print(f"  Total playlists: {self.reconcile_findings['total_playlists']}")
        print(f"  Total entries: {self.reconcile_findings['total_entries']}")
        print(f"  Working entries: {total_working}")
        print(f"  Broken entries: {total_broken} ({broken_percentage:.1f}%)")
        print(f"  Playlists with issues: {len(self.reconcile_findings['playlists_with_issues'])}")

        if self.reconcile_findings['broken_entries']:
            print(f"\n🚨 Broken References:")

            # Group by playlist
            for playlist_name, issues in sorted(self.reconcile_findings['playlists_with_issues'].items()):
                print(f"\n  📋 {playlist_name} ({len(issues)} broken):")
                for _, line_num, path, reason in issues[:5]:  # Show first 5 per playlist
                    print(f"    Line {line_num}: {reason}")
                    print(f"      {path}")
                if len(issues) > 5:
                    print(f"    ... and {len(issues) - 5} more broken entries")

            # Summary of most common issues
            print(f"\n{'='*70}")
            print(f"Common Issues:")
            print(f"{'='*70}")

            # Analyze patterns
            not_found_count = sum(1 for _, _, _, reason in self.reconcile_findings['broken_entries'] if reason == "File not found")

            if not_found_count > 0:
                print(f"  • {not_found_count} files not found (may have been moved/deleted)")

            # Sample some broken paths to help diagnose
            print(f"\n{'='*70}")
            print(f"Sample Broken Paths (first 10):")
            print(f"{'='*70}")

            for playlist_name, line_num, path, reason in self.reconcile_findings['broken_entries'][:10]:
                print(f"  [{playlist_name}:{line_num}] {reason}")
                print(f"    {path}")

        else:
            print(f"\n✅ All playlist entries are valid!")

        print(f"\n{'='*70}")
        print(f"RECOMMENDATIONS:")
        print(f"{'='*70}")

        if self.reconcile_findings['broken_entries']:
            print(f"⚠️  {total_broken} broken playlist entries need attention")
            print(f"   1. If you recently ran 'organize', re-run with playlist updates")
            print(f"   2. Check if files were moved/deleted manually")
            print(f"   3. Consider regenerating affected playlists")
        else:
            print(f"✅ All playlists are in sync with your library!")

        print(f"\n{'='*70}\n")

    def run_ingest(self):
        """
        Ingest new music files into the library.

        Features:
        - Automatically creates artist folders (if missing)
        - Automatically creates album folders (if missing)
        - Uses albumArtist tag preferentially
        - Places files in normalized folders with proper names
        - Successfully ingested files are MOVED (removed from ingest directory)
        - Skipped files remain in the ingest directory for manual review
        """
        print(f"Music Library Ingest")
        print(f"Mode: {self.mode.upper()}")
        print(f"Ingest directory: {self.ingest_dir}")
        print(f"Music library: {self.music_dir}")
        if self.mode == 'normal':
            print(f"⚠️  Files will be MOVED (permanently removed from ingest dir) when successfully placed")
            print(f"📁 Artist/Album folders will be auto-created as needed")
        else:
            print(f"ℹ️  Dry run mode - files will not be moved, folders will not be created")
        print()

        if not self.ingest_dir.exists():
            print(f"ERROR: Ingest directory not found: {self.ingest_dir}")
            return

        if not self.music_dir.exists():
            print(f"ERROR: Music library not found: {self.music_dir}")
            return

        # Collect all audio files from ingest directory
        print("Scanning ingest directory...")
        audio_files = []

        for root, dirs, files in os.walk(self.ingest_dir):
            # Skip unwanted directories
            dirs[:] = [d for d in dirs if not self.should_skip_dir(d)]

            for filename in files:
                file_path = Path(root) / filename
                if self.is_audio_file(file_path):
                    audio_files.append(file_path)

        print(f"Found {len(audio_files)} audio file(s) to ingest\n")

        if not audio_files:
            print("No audio files found to ingest.")
            return

        print("Processing files...")
        for file_path in audio_files:
            self.ingest_file(file_path)

        # Summary
        print(f"\n{'='*60}")
        print(f"Ingest Summary:")
        print(f"  Mode: {self.mode.upper()}")
        print(f"  Files processed: {self.ingest_stats['processed']}")
        print(f"  Files moved to library: {self.ingest_stats['moved']} (removed from ingest dir)")
        print(f"  Artist folders created: {self.ingest_stats['artists_created']}")
        print(f"  Album folders created: {self.ingest_stats['albums_created']}")
        print(f"  Files skipped: {self.ingest_stats['skipped']} (kept in ingest dir)")
        print(f"  Errors: {self.ingest_stats['errors']}")
        print(f"{'='*60}")

        if self.created_artists:
            print(f"\nNewly Created Artist Folders:")
            for artist in self.created_artists[:10]:
                print(f"  👤 {artist.relative_to(self.music_dir)}/")
            if len(self.created_artists) > 10:
                print(f"  ... and {len(self.created_artists) - 10} more")

        if self.created_albums:
            print(f"\nNewly Created Album Folders:")
            for album in self.created_albums[:10]:
                print(f"  📁 {album.relative_to(self.music_dir)}/")
            if len(self.created_albums) > 10:
                print(f"  ... and {len(self.created_albums) - 10} more")

        if self.skipped_files:
            print(f"\nSkipped Files (still in ingest directory):")
            for file_path, reason in self.skipped_files[:20]:
                print(f"  {file_path.name}: {reason}")
            if len(self.skipped_files) > 20:
                print(f"  ... and {len(self.skipped_files) - 20} more")

        if self.mode == 'dryrun':
            print("\nThis was a DRY RUN. No files were actually moved.")
            print("Run with '--mode normal' to apply changes.")
        else:
            if self.ingest_stats['moved'] > 0:
                print(f"\n✅ {self.ingest_stats['moved']} file(s) successfully moved to library and removed from ingest directory")
            if self.ingest_stats['artists_created'] > 0:
                print(f"👤 {self.ingest_stats['artists_created']} new artist folder(s) created")
            if self.ingest_stats['albums_created'] > 0:
                print(f"📁 {self.ingest_stats['albums_created']} new album folder(s) created")
            if self.ingest_stats['skipped'] > 0:
                print(f"⚠️  {self.ingest_stats['skipped']} file(s) remain in ingest directory (review reasons above)")

    def run(self):
        """Main execution"""
        print(f"Music Library Normalizer")
        print(f"Mode: {self.mode.upper()}")
        print(f"Music directory: {self.music_dir}")
        print(f"Playlist input: {self.playlist_input}")
        print(f"Playlist output: {self.playlist_output}")
        print()

        # Validate paths
        if not self.music_dir.exists():
            print(f"ERROR: Music directory not found: {self.music_dir}")
            sys.exit(1)

        # Collect all items
        print("Scanning directory tree...")
        print("(Skipping: .movpkg, @eaDir, system folders)")
        items = self.collect_items()
        total_items = len(items)

        # Count file types
        audio_count = sum(1 for item in items if item[2] == 'file')
        dir_count = sum(1 for item in items if item[2] == 'dir')

        print(f"Found {total_items} item(s): {audio_count} audio files, {dir_count} directories")

        if self.mode == 'dryrun':
            print(f"Dry run limited to {self.dry_run_limit} items\n")
            items = items[:self.dry_run_limit]
        else:
            print()

        # STEP 1: Rename files and folders (including canonical merges)
        print("Processing items...")
        for i, (item_path, depth, item_type) in enumerate(items, 1):
            # Show progress every 50 items
            if i % 50 == 0:
                print(f"Progress: {i}/{len(items)} items processed...")

            new_path = self.rename_item(item_path, item_type)

            if new_path and self.mode == 'dryrun':
                rel_old = item_path.relative_to(self.music_dir)
                rel_new = new_path.relative_to(self.music_dir)

                # Show MCATALOGID info for audio files
                if item_type == 'file':
                    mcatalogid = self.get_mcatalogid(item_path)
                    if mcatalogid:
                        print(f"  {rel_old} -> {rel_new} [MCATALOGID: {mcatalogid}]")
                    else:
                        print(f"  {rel_old} -> {rel_new}")
                else:
                    print(f"  {rel_old}/ -> {rel_new}/")

        # STEP 2: Delete empty folders (after all renaming is complete)
        self.delete_empty_folders()

        # STEP 3: Update playlists (after renaming and cleanup, using canonical path resolution)
        self.update_playlists()

        # Write duplicate report if requested
        if self.duplicate_report and self.duplicates:
            self.write_duplicate_report(self.duplicate_report)

        # Summary
        print(f"\n{'='*60}")
        print(f"Summary:")
        print(f"  Mode: {self.mode.upper()}")
        print(f"  Audio files: {self.stats['audio_files']}")
        print(f"    - With MCATALOGID: {self.stats['audio_with_mcatalogid']}")
        print(f"    - Without MCATALOGID: {self.stats['audio_without_mcatalogid']}")
        print(f"  Directories: {self.stats['directories']}")
        print(f"  Items renamed: {self.processed_count}")
        print(f"  Folder merges: {len(self.folder_merges)}")
        print(f"  Empty folders deleted: {len(self.deleted_folders)}")
        print(f"  File duplicates: {len(self.duplicates)}")
        print(f"  Errors: {self.error_count}")
        print(f"{'='*60}")

        # Show folder merges if any
        if self.folder_merges:
            print(f"\nFolder Merges (contents moved to existing folders):")
            print(f"  Note: Includes canonical merges (e.g., 'R. D. Burman' + 'R.D. Burman' → 'r-d-burman')")
            for source, target, count in self.folder_merges[:15]:  # Show first 15
                rel_source = source.relative_to(self.music_dir)
                rel_target = target.relative_to(self.music_dir)
                count_str = f"({count} items)" if count > 0 else ""
                print(f"  {rel_source}/ → {rel_target}/ {count_str}")
            if len(self.folder_merges) > 15:
                print(f"  ... and {len(self.folder_merges) - 15} more")
            print(f"\n  ℹ️  Playlists automatically updated to reflect merged folder paths")

        # Show deleted folders if any
        if self.deleted_folders:
            print(f"\nEmpty Folders Deleted (no audio files found):")
            for folder in self.deleted_folders[:20]:  # Show first 20
                try:
                    rel_path = folder.relative_to(self.music_dir)
                    print(f"  {rel_path}/")
                except ValueError:
                    print(f"  {folder}")
            if len(self.deleted_folders) > 20:
                print(f"  ... and {len(self.deleted_folders) - 20} more")

        if self.mode == 'dryrun':
            print("\nThis was a DRY RUN. No actual changes were made.")
            print("Run with '--mode normal' to apply changes.")


def main():
    parser = argparse.ArgumentParser(
        description="""
Music Library Normalizer - Organize your music library with intelligent tagging

This tool helps you maintain a clean, shell-friendly music library by:
  • Normalizing filenames (lowercase, hyphens, no spaces)
  • Adding MCATALOGID tags to filenames
  • Merging duplicate artist/album folders
  • Auto-organizing new music files
  • Updating playlists automatically
  • Deleting empty folders
        """,
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
═══════════════════════════════════════════════════════════════════════════════
ACTIONS
═══════════════════════════════════════════════════════════════════════════════

1. ORGANIZE - Normalize existing library
   ├─ Renames files: "01 Song Name.mp3" → "01-song-name-[mid-xyz123].mp3"
   ├─ Renames folders: "R. D. Burman" → "r-d-burman"
   ├─ Merges duplicate folders (canonical matching)
   ├─ Deletes empty folders
   └─ Updates playlists automatically

2. INGEST - Add new music to library
   ├─ Reads artist/album tags from files
   ├─ Auto-creates artist/album folders if needed
   ├─ Places files in correct location
   ├─ Normalizes filenames with MCATALOGID
   └─ MOVES files (removes from ingest directory)

3. OBSERVE - Analyze library (read-only)
   ├─ Shows files/folders with spaces
   ├─ Shows missing MCATALOGID
   ├─ Shows folders that will be merged
   ├─ Shows empty folders that will be deleted
   └─ No changes made to files

4. RECONCILE - Check playlists (read-only)
   ├─ Validates playlist entries against library
   ├─ Reports broken/missing references
   └─ No changes made to files

═══════════════════════════════════════════════════════════════════════════════
EXAMPLES
═══════════════════════════════════════════════════════════════════════════════

→ Test MCATALOGID extraction (test 20 files)
  %(prog)s --music /path/to/music --mode test --test-files 20

→ OBSERVE: Analyze library for issues (always run this first!)
  %(prog)s --action observe --music ~/Music

→ ORGANIZE: Normalize library (dry run first, then normal)
  %(prog)s --action organize --music ~/Music \\
           --playlist-input ~/.config/mpd/playlists \\
           --playlist-output ~/.config/mpd/playlists --mode dryrun

  %(prog)s --action organize --music ~/Music \\
           --playlist-input ~/.config/mpd/playlists \\
           --playlist-output ~/.config/mpd/playlists --mode normal \\
           --duplicate-report duplicates.txt

→ INGEST: Auto-organize new downloads
  # Dry run first to preview
  %(prog)s --action ingest --music ~/Music \\
           --ingest-dir ~/Downloads/new-music --mode dryrun

  # Run for real (files will be moved!)
  %(prog)s --action ingest --music ~/Music \\
           --ingest-dir ~/Downloads/new-music --mode normal

→ RECONCILE: Find broken playlist entries
  %(prog)s --action reconcile --music ~/Music \\
           --playlist-input ~/.config/mpd/playlists

═══════════════════════════════════════════════════════════════════════════════
TYPICAL WORKFLOW
═══════════════════════════════════════════════════════════════════════════════

  1. Run OBSERVE to see what will change
  2. Run ORGANIZE in dryrun mode to preview renames
  3. Run ORGANIZE in normal mode to apply changes
  4. Run RECONCILE to check playlists are still valid
  5. Use INGEST to add new music going forward

═══════════════════════════════════════════════════════════════════════════════
NAMING RULES
═══════════════════════════════════════════════════════════════════════════════

  Files:  "01 Love Song.mp3" → "01-love-song-[mid-abc123].mp3"
  Folders: "R. D. Burman" → "r-d-burman"

  • All lowercase
  • Spaces/underscores → hyphens
  • Dots removed (except file extension)
  • MCATALOGID appended as -[mid-value]
  • Leading junk characters stripped

═══════════════════════════════════════════════════════════════════════════════
        """
    )

    parser.add_argument('--action',
                       default='organize',
                       choices=['organize', 'ingest', 'observe', 'reconcile'],
                       metavar='ACTION',
                       help='Action to perform (default: organize)\n'
                            'organize  - Normalize library filenames and folders\n'
                            'ingest    - Auto-organize new music files\n'
                            'observe   - Analyze library (read-only)\n'
                            'reconcile - Check playlists (read-only)')

    parser.add_argument('--music',
                       required=True,
                       metavar='DIR',
                       help='Path to your music library root directory')

    parser.add_argument('--playlist-input',
                       required=False,
                       metavar='DIR',
                       help='Path to playlist directory (required for organize/reconcile)')

    parser.add_argument('--playlist-output',
                       required=False,
                       metavar='DIR',
                       help='Path to save updated playlists (required for organize)')

    parser.add_argument('--ingest-dir',
                       required=False,
                       metavar='DIR',
                       help='Path to directory with new music files (required for ingest)\n'
                            'Successfully ingested files will be MOVED from this directory')

    parser.add_argument('--mode',
                       required=False,
                       choices=['dryrun', 'normal', 'test'],
                       metavar='MODE',
                       help='Execution mode (not required for observe/reconcile)\n'
                            'dryrun - Preview changes without making them\n'
                            'normal - Apply changes to files\n'
                            'test   - Test MCATALOGID extraction')

    parser.add_argument('--dry-run-limit',
                       type=int,
                       default=1000,
                       metavar='N',
                       help='Number of items to process in dry run mode (default: 1000)')

    parser.add_argument('--duplicate-report',
                       type=str,
                       default=None,
                       metavar='FILE',
                       help='Write duplicate files report to this path (organize only)')

    parser.add_argument('--test-files',
                       type=int,
                       default=10,
                       metavar='N',
                       help='Number of files to test MCATALOGID extraction (default: 10)')

    args = parser.parse_args()

    # Validate mode is provided for actions that need it (observe and reconcile are read-only)
    if args.action not in ['observe', 'reconcile'] and not args.mode:
        parser.error(f"--mode is required for '{args.action}' action")

    # Test mode only needs music directory
    if args.mode == 'test':
        normalizer = MusicLibraryNormalizer(
            music_dir=args.music,
            playlist_input=None,
            playlist_output=None,
            mode=args.mode,
            dry_run_limit=args.dry_run_limit,
            duplicate_report=args.duplicate_report,
            action=args.action
        )
        normalizer.test_mcatalogid_extraction(args.test_files)

    elif args.action == 'ingest':
        # Ingest mode requires ingest-dir
        if not args.ingest_dir:
            parser.error("--ingest-dir is required for ingest action")

        normalizer = MusicLibraryNormalizer(
            music_dir=args.music,
            playlist_input=None,
            playlist_output=None,
            mode=args.mode,
            dry_run_limit=args.dry_run_limit,
            duplicate_report=None,
            action=args.action,
            ingest_dir=args.ingest_dir
        )
        normalizer.run_ingest()

    elif args.action == 'observe':
        # Observe mode only needs music directory
        normalizer = MusicLibraryNormalizer(
            music_dir=args.music,
            playlist_input=None,
            playlist_output=None,
            mode='dryrun',  # Observe is always read-only
            dry_run_limit=args.dry_run_limit,
            duplicate_report=None,
            action=args.action
        )
        normalizer.run_observe()

    elif args.action == 'reconcile':
        # Reconcile mode requires playlist directory
        if not args.playlist_input:
            parser.error("--playlist-input is required for reconcile action")

        normalizer = MusicLibraryNormalizer(
            music_dir=args.music,
            playlist_input=args.playlist_input,
            playlist_output=None,
            mode='dryrun',  # Reconcile is always read-only
            dry_run_limit=args.dry_run_limit,
            duplicate_report=None,
            action=args.action
        )
        normalizer.run_reconcile()

    elif args.action == 'organize':
        # Organize mode requires playlist directories
        if not args.playlist_input or not args.playlist_output:
            parser.error("--playlist-input and --playlist-output are required for organize action")

        normalizer = MusicLibraryNormalizer(
            music_dir=args.music,
            playlist_input=args.playlist_input,
            playlist_output=args.playlist_output,
            mode=args.mode,
            dry_run_limit=args.dry_run_limit,
            duplicate_report=args.duplicate_report,
            action=args.action
        )
        normalizer.run()


if __name__ == '__main__':
    main()

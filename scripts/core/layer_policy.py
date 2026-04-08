#!/usr/bin/env python3
"""
Layer Policy Module - Unified exclusion and scanning policies
Centralizes all file access and scanning policies to prevent Capa B
"""

from pathlib import Path
from typing import List


class LayerPolicy:
    """Unified layer policy for safe file operations across DJProducerTools"""

    # Directories that should NEVER be scanned (Capa B protection)
    EXCLUDED_DIRS = {
        '__pycache__', '.git', '.DS_Store', '.venv', 'venv',
        'node_modules', '.pytest_cache', '.mypy_cache',
        '_agent_checkpoints', '_SeratOrganizer_state_real_*',
        'archives_home', 'backup_configs', 'backup_files',
        '.vscode', '.idea', '*.egg-info'
    }

    # File patterns that should be excluded
    EXCLUDED_PATTERNS = {
        '*.pyc', '*.pyo', '*.pyd', '*.log', '*.tmp',
        '*.bak', '*.backup', '*.old', '*.orig',
        '.DS_Store', 'Thumbs.db', '*.swp', '*.swo'
    }

    # Safe file extensions for analysis
    SAFE_EXTENSIONS = {
        '.txt', '.md', '.py', '.sh', '.json', '.yaml', '.yml',
        '.tsv', '.csv', '.toml', '.conf', '.cfg'
    }

    # Maximum file size for analysis (10MB)
    MAX_FILE_SIZE = 10_000_000

    @classmethod
    def is_safe_directory(cls, path: Path) -> bool:
        """Check if directory is safe to scan"""
        name = path.name

        # Check excluded directory names
        if name in cls.EXCLUDED_DIRS:
            return False

        # Check pattern exclusions
        for pattern in cls.EXCLUDED_PATTERNS:
            if pattern.startswith('*') and name.endswith(pattern[1:]):
                return False
            elif pattern in name:
                return False

        return True

    @classmethod
    def is_safe_file(cls, path: Path) -> bool:
        """Check if file is safe to analyze"""
        name = path.name

        # Check excluded patterns
        for pattern in cls.EXCLUDED_PATTERNS:
            if pattern.startswith('*') and name.endswith(pattern[1:]):
                return False
            elif pattern in name:
                return False

        # Check file size
        if path.stat().st_size > cls.MAX_FILE_SIZE:
            return False

        return True

    @classmethod
    def safe_glob(cls, base_path: Path, pattern: str = "*") -> List[Path]:
        """Safe glob that respects layer policies"""
        if not base_path.exists():
            return []

        results = []

        try:
            for item in base_path.glob(pattern):
                # Skip if parent directory is excluded
                parent = item.parent
                if not cls.is_safe_directory(parent):
                    continue

                # For files, check safety
                if item.is_file():
                    if cls.is_safe_file(item):
                        results.append(item)
                # For directories, check if safe to recurse
                elif item.is_dir():
                    if cls.is_safe_directory(item):
                        results.append(item)

        except (OSError, PermissionError):
            # Silently handle permission errors
            pass

        return results

    @classmethod
    def safe_rglob(cls, base_path: Path, pattern: str = "*") -> List[Path]:
        """Safe recursive glob that respects layer policies"""
        if not base_path.exists():
            return []

        results = []

        try:
            for item in base_path.rglob(pattern):
                # Skip if any parent directory is excluded
                parent = item.parent
                current = parent
                excluded_parent = False

                while current != base_path.parent:
                    if not cls.is_safe_directory(current):
                        excluded_parent = True
                        break
                    current = current.parent

                if excluded_parent:
                    continue

                # For files, check safety
                if item.is_file():
                    if cls.is_safe_file(item):
                        results.append(item)
                # For directories, check if safe
                elif item.is_dir():
                    if cls.is_safe_directory(item):
                        results.append(item)

        except (OSError, PermissionError):
            # Silently handle permission errors
            pass

        return results

    @classmethod
    def get_safe_files(cls, base_path: Path, limit: int = 10) -> List[Path]:
        """Get safe files for analysis with limit"""
        safe_files = cls.safe_rglob(base_path, "*")

        # Filter by safe extensions
        filtered = [
            f for f in safe_files
            if f.is_file() and f.suffix.lower() in cls.SAFE_EXTENSIONS
        ]

        # Sort by size and limit
        filtered.sort(key=lambda x: x.stat().st_size)
        return filtered[:limit]


# Global policy instance
policy = LayerPolicy()

#!/usr/bin/env python3
"""
DJProducerTools Input Validation - Security and validation utilities
Provides comprehensive input validation for file paths, user inputs, and security checks.
"""

import re
from pathlib import Path
from typing import Optional, List, Union
import sys


class ValidationError(Exception):
    """Custom exception for validation failures."""

    pass


class InputValidator:
    """Comprehensive input validation for DJProducerTools."""

    @staticmethod
    def validate_file_path(
        file_path: Union[str, Path],
        must_exist: bool = True,
        must_be_file: bool = True,
        allowed_extensions: Optional[List[str]] = None,
        max_size_mb: Optional[int] = None,
    ) -> Path:
        """
        Validate and normalize file path with comprehensive checks.

        Args:
            file_path: Path to validate
            must_exist: Whether path must exist
            must_be_file: Whether must be a file (vs directory)
            allowed_extensions: List of allowed file extensions (e.g., ['.mp3', '.wav'])
            max_size_mb: Maximum file size in MB

        Returns:
            Normalized Path object

        Raises:
            ValidationError: If validation fails
        """
        path = Path(file_path).resolve()

        # Check for path traversal attempts
        if ".." in str(path) or str(path).startswith("/"):
            raise ValidationError(f"Invalid path: {file_path} (potential traversal)")

        # Check existence
        if must_exist and not path.exists():
            raise ValidationError(f"Path does not exist: {path}")

        # Check if file vs directory
        if path.exists():
            if must_be_file and not path.is_file():
                raise ValidationError(f"Path is not a file: {path}")
            if not must_be_file and path.is_file():
                raise ValidationError(f"Path is not a directory: {path}")

        # Check file extension
        if allowed_extensions and path.is_file():
            if path.suffix.lower() not in [ext.lower() for ext in allowed_extensions]:
                raise ValidationError(
                    f"File extension not allowed: {path.suffix}. Allowed: {', '.join(allowed_extensions)}"
                )

        # Check file size
        if max_size_mb and path.is_file():
            try:
                size_mb = path.stat().st_size / (1024 * 1024)
                if size_mb > max_size_mb:
                    raise ValidationError(f"File too large: {size_mb:.1f}MB > {max_size_mb}MB")
            except OSError as e:
                raise ValidationError(f"Cannot check file size: {e}")

        return path

    @staticmethod
    def validate_directory_path(
        dir_path: Union[str, Path],
        must_exist: bool = True,
        create_if_missing: bool = False,
    ) -> Path:
        """Validate directory path with optional creation."""
        path = Path(dir_path).resolve()

        # Check for path traversal
        if ".." in str(path) or str(path).startswith("/"):
            raise ValidationError(f"Invalid directory path: {dir_path}")

        if not path.exists():
            if must_exist and not create_if_missing:
                raise ValidationError(f"Directory does not exist: {path}")
            elif create_if_missing:
                try:
                    path.mkdir(parents=True, exist_ok=True)
                except OSError as e:
                    raise ValidationError(f"Cannot create directory {path}: {e}")
        elif not path.is_dir():
            raise ValidationError(f"Path is not a directory: {path}")

        return path

    @staticmethod
    def validate_user_input(
        input_value: str,
        field_name: str,
        min_length: int = 1,
        max_length: int = 1000,
        allowed_chars: Optional[str] = None,
        forbidden_patterns: Optional[List[str]] = None,
    ) -> str:
        """
        Validate user input for security and format.

        Args:
            input_value: User input string
            field_name: Name of the field for error messages
            min_length: Minimum allowed length
            max_length: Maximum allowed length
            allowed_chars: Regex pattern of allowed characters
            forbidden_patterns: List of regex patterns to forbid

        Returns:
            Sanitized input string
        """
        if not isinstance(input_value, str):
            raise ValidationError(f"{field_name} must be a string")

        # Length validation
        if len(input_value) < min_length:
            raise ValidationError(f"{field_name} too short (min {min_length} characters)")

        if len(input_value) > max_length:
            raise ValidationError(f"{field_name} too long (max {max_length} characters)")

        # Character validation
        if allowed_chars and not re.match(allowed_chars, input_value):
            raise ValidationError(f"{field_name} contains invalid characters")

        # Forbidden patterns (prevent injection attacks)
        forbidden_patterns = forbidden_patterns or [
            r"[<>]",  # HTML tags
            r"[;&|]",  # Command injection
            r"\$\(",  # Command substitution
            r"`.*`",  # Backtick execution
            r"\.\./",  # Path traversal
        ]

        for pattern in forbidden_patterns:
            if re.search(pattern, input_value, re.IGNORECASE):
                raise ValidationError(f"{field_name} contains forbidden pattern: {pattern}")

        return input_value.strip()

    @staticmethod
    def validate_numeric_input(
        input_value: str,
        field_name: str,
        min_value: Optional[Union[int, float]] = None,
        max_value: Optional[Union[int, float]] = None,
        allow_float: bool = False,
    ) -> Union[int, float]:
        """Validate numeric input with range checking."""
        try:
            if allow_float:
                value = float(input_value)
            else:
                value = int(input_value)
        except ValueError:
            raise ValidationError(f"{field_name} must be a number")

        if min_value is not None and value < min_value:
            raise ValidationError(f"{field_name} too small (minimum: {min_value})")

        if max_value is not None and value > max_value:
            raise ValidationError(f"{field_name} too large (maximum: {max_value})")

        return value

    @staticmethod
    def validate_url(url: str) -> str:
        """Validate URL format and security."""
        url = url.strip()

        # Basic URL format check
        url_pattern = re.compile(
            r"^https?://"  # http:// or https://
            r"(?:(?:[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?\.)+[A-Z]{2,6}\.?|"  # domain...
            r"localhost|"  # localhost...
            r"\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})"  # ...or IP
            r"(?::\d+)?"  # optional port
            r"(?:/?|[/?]\S+)$",
            re.IGNORECASE,
        )

        if not url_pattern.match(url):
            raise ValidationError(f"Invalid URL format: {url}")

        # Security checks
        if "file://" in url:
            raise ValidationError(f"Local file URLs not allowed: {url}")

        return url

    @staticmethod
    def sanitize_filename(filename: str) -> str:
        """Sanitize filename for cross-platform compatibility."""
        # Remove or replace dangerous characters
        dangerous_chars = ["<", ">", ":", '"', "|", "?", "*", "/", "\\"]
        sanitized = filename

        for char in dangerous_chars:
            sanitized = sanitized.replace(char, "_")

        # Remove control characters
        sanitized = re.sub(r"[\x00-\x1f\x7f]", "", sanitized)

        # Ensure reasonable length
        if len(sanitized) > 255:
            sanitized = sanitized[:255]

        # Ensure not empty
        if not sanitized:
            sanitized = "unnamed_file"

        return sanitized.strip()


# Convenience functions for backward compatibility
def validate_audio_file(file_path: Union[str, Path]) -> Path:
    """Validate audio file path."""
    audio_extensions = [".mp3", ".wav", ".flac", ".m4a", ".aac", ".ogg"]
    return InputValidator.validate_file_path(
        file_path,
        allowed_extensions=audio_extensions,
        max_size_mb=500,  # 500MB max for audio files
    )


def validate_config_file(file_path: Union[str, Path]) -> Path:
    """Validate configuration file path."""
    config_extensions = [".json", ".yaml", ".yml", ".conf", ".ini"]
    return InputValidator.validate_file_path(
        file_path,
        allowed_extensions=config_extensions,
        max_size_mb=10,  # 10MB max for config files
    )


def validate_scan_directory(dir_path: Union[str, Path]) -> Path:
    """Validate scan directory path."""
    return InputValidator.validate_directory_path(dir_path, create_if_missing=True)


def main():
    """CLI entry point for input validation."""
    import argparse

    parser = argparse.ArgumentParser(description="DJProducerTools Input Validator")
    subparsers = parser.add_subparsers(dest="command", help="Validation command")

    # Path validation
    path_parser = subparsers.add_parser("validate_path", help="Validate a file path")
    path_parser.add_argument("path", help="Path to validate")
    path_parser.add_argument("--must-exist", action="store_true", help="Path must exist")
    path_parser.add_argument("--allowed-ext", help="Comma-separated list of allowed extensions")

    # Directory validation
    dir_parser = subparsers.add_parser("validate_dir", help="Validate a directory path")
    dir_parser.add_argument("path", help="Directory path to validate")
    dir_parser.add_argument("--create", action="store_true", help="Create if missing")

    # Sanitize filename
    sanitize_parser = subparsers.add_parser("sanitize", help="Sanitize a filename")
    sanitize_parser.add_argument("filename", help="Filename to sanitize")

    args = parser.parse_args()

    try:
        if args.command == "validate_path":
            exts = args.allowed_ext.split(",") if args.allowed_ext else None
            result = InputValidator.validate_file_path(args.path, must_exist=args.must_exist, allowed_extensions=exts)
            print(result)

        elif args.command == "validate_dir":
            result = InputValidator.validate_directory_path(args.path, create_if_missing=args.create)
            print(result)

        elif args.command == "sanitize":
            result = InputValidator.sanitize_filename(args.filename)
            print(result)

        else:
            parser.print_help()
            sys.exit(1)

    except ValidationError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

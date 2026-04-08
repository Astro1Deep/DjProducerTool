#!/usr/bin/env python3
"""
DJProducerTools Logger - Centralized logging system
Provides consistent logging across all DJPT modules with rotation and structured output.
"""

import logging
import sys
import os
from pathlib import Path
from datetime import datetime
from typing import Optional
import json


class DJPTLogger:
    """Centralized logger for DJProducerTools with structured output."""

    def __init__(self, name: str, log_dir: Optional[Path] = None):
        self.name = name
        self.log_dir = log_dir or Path(os.environ.get("DJPT_LOGS_DIR", "./logs"))
        self.log_dir.mkdir(parents=True, exist_ok=True)

        # Create logger
        self.logger = logging.getLogger(f"djpt.{name}")
        self.logger.setLevel(logging.DEBUG)

        # Clear existing handlers
        self.logger.handlers.clear()

        # Console handler
        console_handler = logging.StreamHandler(sys.stderr)
        console_handler.setLevel(logging.INFO)
        console_formatter = logging.Formatter(
            "%(asctime)s [%(levelname)s] %(name)s: %(message)s",
            datefmt="%H:%M:%S",
        )
        console_handler.setFormatter(console_formatter)
        self.logger.addHandler(console_handler)

        # File handler with rotation
        log_file = self.log_dir / f"{name}.log"
        file_handler = logging.FileHandler(log_file, encoding="utf-8")
        file_handler.setLevel(logging.DEBUG)
        file_formatter = logging.Formatter(
            "%(asctime)s [%(levelname)s] %(name)s (%(filename)s:%(lineno)d): %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S",
        )
        file_handler.setFormatter(file_formatter)
        self.logger.addHandler(file_handler)

        # JSON structured log for errors
        error_file = self.log_dir / f"{name}_errors.json"
        self.error_file = error_file

    def info(self, message: str, **kwargs):
        """Log info message."""
        self.logger.info(message, extra=kwargs)

    def warning(self, message: str, **kwargs):
        """Log warning message."""
        self.logger.warning(message, extra=kwargs)

    def error(self, message: str, exception: Optional[Exception] = None, **kwargs):
        """Log error message with optional exception details."""
        self.logger.error(message, extra=kwargs, exc_info=exception is not None)

        # Also log to structured JSON for errors
        error_entry = {
            "timestamp": datetime.now().isoformat(),
            "level": "ERROR",
            "module": self.name,
            "message": message,
            "exception": str(exception) if exception else None,
            "context": kwargs,
        }

        try:
            with open(self.error_file, "a", encoding="utf-8") as f:
                f.write(json.dumps(error_entry) + "\n")
        except Exception as e:
            self.logger.error(f"Failed to write structured error log: {e}")

    def debug(self, message: str, **kwargs):
        """Log debug message."""
        self.logger.debug(message, extra=kwargs)

    def critical(self, message: str, exception: Optional[Exception] = None, **kwargs):
        """Log critical message."""
        self.logger.critical(message, extra=kwargs, exc_info=exception is not None)

        # Also log to structured JSON for critical errors
        error_entry = {
            "timestamp": datetime.now().isoformat(),
            "level": "CRITICAL",
            "module": self.name,
            "message": message,
            "exception": str(exception) if exception else None,
            "context": kwargs,
        }

        try:
            with open(self.error_file, "a", encoding="utf-8") as f:
                f.write(json.dumps(error_entry) + "\n")
        except Exception as e:
            self.logger.error(f"Failed to write structured error log: {e}")


# Global logger instances
_loggers = {}


def get_logger(name: str) -> DJPTLogger:
    """Get or create a logger instance for a module."""
    if name not in _loggers:
        _loggers[name] = DJPTLogger(name)
    return _loggers[name]


def log_subprocess_result(
    logger: DJPTLogger,
    cmd: list,
    result: "subprocess.CompletedProcess",
    timeout: int = 300,
):
    """Log subprocess execution result."""
    if result.returncode == 0:
        logger.info(
            f"Subprocess succeeded: {' '.join(cmd)}",
            returncode=result.returncode,
            duration=getattr(result, "duration", None),
        )
    else:
        logger.error(
            f"Subprocess failed: {' '.join(cmd)}",
            returncode=result.returncode,
            stdout=result.stdout[:500] if result.stdout else None,
            stderr=result.stderr[:500] if result.stderr else None,
            timeout=timeout,
        )

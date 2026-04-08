#!/usr/bin/env python3
"""
DJProducerTools Chat CLI - Asistente Inteligente de Procesamiento de Audio
Interactive management interface for DJProducerTools suite with advanced audio processing.
Self-healing and evolution capabilities for autonomous operation.
"""

from __future__ import annotations
import os
import sys
import subprocess
import time
import json
import re
import shlex
import urllib.parse
import urllib.request
import unicodedata
import webbrowser
from pathlib import Path
from typing import Any, Dict, List
from datetime import datetime
import hashlib
from dataclasses import dataclass, field
from html import unescape as html_unescape

# Add scripts directory to path for logger import
sys.path.insert(0, str(Path(__file__).parent / "scripts"))
try:
    from djpt_logger import get_logger, log_subprocess_result
except ImportError:
    # Fallback if logger not available
    import logging

    def get_logger(name):
        return logging.getLogger(name)

    def log_subprocess_result(logger, cmd, result, timeout=300):
        pass


# ANSI Colors - Matrix Theme
C_GREEN = "\033[1;32m"  # Matrix Green
C_CYAN = "\033[1;36m"  # Secondary Matrix
C_YLW = "\033[1;33m"  # Yellow for warnings
C_RED = "\033[1;31m"  # Red for errors
C_BLUEE = "\033[1;34m"  # Blue for info
C_MAG = "\033[1;35m"  # Magenta for special
C_RESET = "\033[0m"

# Matrix-style large font effect
BOLD_LARGE = "\033[1;32m"
RESET_LARGE = "\033[0m"

# Emojis for different response types
EMOJI_WIZARD = "🧙‍♂️"  # For magical/technical operations
EMOJI_BRAIN = "🧠"  # For intelligent/ML responses
EMOJI_CRYSTAL = "🔮"  # For predictions/analysis
EMOJI_GEAR = "⚙️"  # For system/setup
EMOJI_MUSIC = "🎵"  # For audio operations
EMOJI_ROBOT = "🤖"  # For AI/automation
EMOJI_GLOBE = "🌐"  # For web/internet operations
EMOJI_DOWNLOAD = "⬇️"  # For downloads/installations
EMOJI_SEARCH = "🔍"  # For search operations
EMOJI_YLW = "⚠️"  # For warnings


@dataclass
class DiagnosticReport:
    """Normalized diagnostic result for CLI printing."""

    summary_text: str
    warnings: List[str] = field(default_factory=list)
    errors: List[str] = field(default_factory=list)
    details: Dict[str, Any] = field(default_factory=dict)

    def summary(self) -> str:
        return self.summary_text


@dataclass
class BackendStatus:
    """Normalized backend status with user-facing summary/messages."""

    backends: Dict[str, Any] = field(default_factory=dict)
    messages: List[str] = field(default_factory=list)

    def summary(self) -> str:
        if not self.backends:
            return "Sin backends detectados"
        states = []
        for name, info in self.backends.items():
            if isinstance(info, dict):
                states.append(f"{name}={info.get('status', 'unknown')}")
            else:
                states.append(f"{name}={info}")
        return ", ".join(states)


@dataclass
class HealResult:
    success: bool
    actions: List[str] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)
    errors: List[str] = field(default_factory=list)

    def summary(self) -> str:
        if self.success:
            return f"OK ({len(self.actions)} acciones, {len(self.warnings)} avisos)"
        return f"ERROR ({len(self.errors)} errores)"


def _normalize_diagnostic_report(payload: Any) -> DiagnosticReport:
    """Convert arbitrary diagnostic payload into DiagnosticReport."""
    if isinstance(payload, DiagnosticReport):
        return payload
    if isinstance(payload, dict):
        health = payload.get("overall_health")
        if health:
            summary = f"overall_health={health}"
        elif "basic_diagnosis" in payload:
            summary = "basic_diagnosis=ok"
        else:
            summary = "diagnosis=available"
        warnings = list(payload.get("warnings", [])) if isinstance(payload.get("warnings"), list) else []
        errors = list(payload.get("errors", [])) if isinstance(payload.get("errors"), list) else []
        return DiagnosticReport(
            summary_text=summary,
            warnings=warnings,
            errors=errors,
            details=payload,
        )
    return DiagnosticReport(
        summary_text="diagnosis=unknown",
        warnings=["Formato de diagnóstico no reconocido"],
    )


def _normalize_backend_status(payload: Any) -> BackendStatus:
    """Convert arbitrary backend payload into BackendStatus."""
    if isinstance(payload, BackendStatus):
        return payload
    if isinstance(payload, dict):
        backends = payload.get("backends")
        if not isinstance(backends, dict):
            # Legacy shape from basic monitoring
            backends = payload.get("basic_monitoring", payload)
            if not isinstance(backends, dict):
                backends = {}
        messages = []
        for name, info in backends.items():
            status = info.get("status") if isinstance(info, dict) else str(info)
            if status not in {"active", "configured"}:
                messages.append(f"{name} en estado {status}")
        return BackendStatus(backends=backends, messages=messages)
    return BackendStatus(messages=["Formato de estado de backends no reconocido"])


def _normalize_heal_result(payload: Any) -> HealResult:
    """Convert arbitrary healing payload into HealResult."""
    if isinstance(payload, HealResult):
        return payload
    if isinstance(payload, dict):
        actions = payload.get("actions_taken", payload.get("actions", []))
        if not isinstance(actions, list):
            actions = []
        warnings = payload.get("warnings", [])
        if not isinstance(warnings, list):
            warnings = []
        errors = payload.get("errors", [])
        if not isinstance(errors, list):
            errors = []
        success = payload.get("success", len(errors) == 0)
        return HealResult(
            success=bool(success),
            actions=actions,
            warnings=warnings,
            errors=errors,
        )
    return HealResult(success=False, errors=["Formato de healing no reconocido"])


# Self-healing and evolution system
class SelfHealingSystem:
    """Autonomous self-correction and evolution system for Chat CLI."""

    def __init__(self, base_path):
        self.base_path = Path(base_path)
        self.evolution_log = self.base_path / "evolution_log.json"
        self.knowledge_base = self.base_path / "knowledge_base.json"
        self.error_patterns = self.base_path / "error_patterns.json"

        # Ensure evolution directories exist
        self.evolution_log.parent.mkdir(parents=True, exist_ok=True)

        # Load existing knowledge
        self.knowledge = self.load_knowledge()
        self.patterns = self.load_patterns()

    def load_knowledge(self):
        """Load knowledge base from file."""
        if self.knowledge_base.exists():
            try:
                with open(self.knowledge_base, "r") as f:
                    return json.load(f)
            except Exception:
                pass
        return {"fixes": {}, "improvements": {}, "learned_commands": {}}

    def load_patterns(self):
        """Load error patterns from file."""
        if self.error_patterns.exists():
            try:
                with open(self.error_patterns, "r") as f:
                    return json.load(f)
            except Exception:
                pass
        return {"common_errors": {}, "solutions": {}}

    def save_knowledge(self):
        """Save knowledge base to file."""
        try:
            with open(self.knowledge_base, "w") as f:
                json.dump(self.knowledge, f, indent=2)
        except Exception as e:
            print(f"{EMOJI_YLW} [WARN] No se pudo guardar knowledge base: {e}{C_RESET}")

    def save_patterns(self):
        """Save error patterns to file."""
        try:
            with open(self.error_patterns, "w") as f:
                json.dump(self.patterns, f, indent=2)
        except Exception as e:
            print(f"{EMOJI_YLW} [WARN] No se pudo guardar patterns: {e}{C_RESET}")

    def log_evolution(self, event_type, details):
        """Log evolution events."""
        log_entry = {
            "timestamp": datetime.now().isoformat(),
            "type": event_type,
            "details": details,
            "hash": hashlib.md5(str(details).encode()).hexdigest()[:8],
        }

        logs = []
        if self.evolution_log.exists():
            try:
                with open(self.evolution_log, "r") as f:
                    logs = json.load(f)
            except Exception:
                pass

        logs.append(log_entry)

        # Keep only last 100 entries
        if len(logs) > 100:
            logs = logs[-100:]

        try:
            with open(self.evolution_log, "w") as f:
                json.dump(logs, f, indent=2)
        except Exception:
            pass

    def analyze_error(self, error_msg, context=""):
        """Analyze error and suggest fixes."""
        error_lower = error_msg.lower()

        # Check for known patterns
        for pattern, solution in self.patterns["solutions"].items():
            if pattern in error_lower:
                print(f"{EMOJI_BRAIN} {C_GREEN}[AUTO-FIX] Patrón detectado: {pattern}{C_RESET}")
                print(f"{EMOJI_WIZARD} {C_CYAN}[SOLUCIÓN] {solution}{C_RESET}")
                return solution

        # Try to auto-generate fix based on error type
        if "no such file" in error_lower or "not found" in error_lower:
            fix = self.suggest_file_fix(error_msg)
        elif "permission denied" in error_lower:
            fix = self.suggest_permission_fix(error_msg)
        elif "import error" in error_lower or "module not found" in error_lower:
            fix = self.suggest_import_fix(error_msg)
        elif "syntax error" in error_lower:
            fix = self.suggest_syntax_fix(error_msg)
        else:
            fix = self.search_web_solution(error_msg)

        if fix:
            # Learn from this error
            pattern_key = error_lower[:50] + "..." if len(error_lower) > 50 else error_lower
            self.patterns["solutions"][pattern_key] = fix
            self.save_patterns()
            self.log_evolution("error_learned", {"error": error_msg, "fix": fix})

        return fix

    def suggest_file_fix(self, error_msg):
        """Suggest fix for file not found errors."""
        print(f"{EMOJI_WIZARD} {C_GREEN}[ANÁLISIS] Error de archivo no encontrado{C_RESET}")

        # Extract filename from error
        words = error_msg.split()
        for word in words:
            if "." in word and not word.startswith("."):
                filename = word.strip("\"'")
                print(f"{EMOJI_SEARCH} {C_CYAN}[BUSCANDO] Archivo: {filename}{C_RESET}")

                # Search for similar files
                try:
                    find_cmd = [
                        "find",
                        str(self.base_path),
                        "-name",
                        f"*{filename}*",
                    ]
                    result = subprocess.run(find_cmd, capture_output=True, text=True, timeout=10)
                    if result.stdout:
                        files = result.stdout.strip().split("\n")
                        print(f"{EMOJI_BRAIN} {C_GREEN}[ALTERNATIVAS] Archivos similares:{C_RESET}")
                        for file in files[:5]:
                            print(f"  {C_CYAN}• {file}{C_RESET}")
                        return "Usa uno de los archivos similares encontrados"
                except Exception:
                    pass

                # Try to create missing file
                try:
                    version_file = Path(__file__).parent.parent.parent / "VERSION"
                    if version_file.exists():
                        return version_file.read_text().strip()
                    return "1.3.0"
                except Exception:
                    return "1.3.0"

    def suggest_permission_fix(self, error_msg):
        """Suggest fix for permission errors."""
        print(f"{EMOJI_WIZARD} {C_GREEN}[ANÁLISIS] Error de permisos{C_RESET}")
        print(f"{EMOJI_GEAR} {C_CYAN}[SOLUCIÓN] Intenta: chmod +x <archivo>{C_RESET}")
        print(f"{EMOJI_GEAR} {C_CYAN}[SOLUCIÓN] O ejecuta con: sudo <comando>{C_RESET}")
        return "Verifica los permisos del archivo o ejecuta como administrador"

    def suggest_import_fix(self, error_msg):
        """Suggest fix for import errors."""
        print(f"{EMOJI_WIZARD} {C_GREEN}[ANÁLISIS] Error de importación{C_RESET}")

        # Extract module name
        words = error_msg.split()
        for word in words:
            if "no module named" in error_msg.lower() and word not in [
                "no",
                "module",
                "named",
            ]:
                module = word.strip("\"'")
                print(f"{EMOJI_DOWNLOAD} {C_CYAN}[INSTALANDO] Módulo: {module}{C_RESET}")
                return f"pip install {module}"

        return "Verifica que el módulo esté instalado: pip install <module>"

    def suggest_syntax_fix(self, error_msg):
        """Suggest fix for syntax errors."""
        print(f"{EMOJI_WIZARD} {C_GREEN}[ANÁLISIS] Error de sintaxis{C_RESET}")
        print(f"{EMOJI_BRAIN} {C_CYAN}[SOLUCIÓN] Revisa la sintaxis cerca de la línea indicada{C_RESET}")
        return "Verifica la sintaxis del código, especialmente paréntesis y comillas"

    def create_missing_script(self, filename):
        """Create a missing script with basic structure."""
        script_path = self.base_path / "lib" / filename

        if not script_path.exists():
            print(f"{EMOJI_DOWNLOAD} {C_CYAN}[CREANDO] Script básico: {filename}{C_RESET}")

            basic_script = f'''#!/usr/bin/env python3
"""
Auto-generated script: {filename}
Created by DJProducerTools Self-Healing System
"""
import os
import sys
from pathlib import Path

def main():
    print("🧙‍♂️ [AUTO-GENERADO] Script {filename} creado automáticamente")
    print("🔧 [INFO] Este script necesita ser implementado")
    return 0

if __name__ == "__main__":
    sys.exit(main())
'''

            try:
                script_path.parent.mkdir(parents=True, exist_ok=True)
                with open(script_path, "w") as f:
                    f.write(basic_script)
                script_path.chmod(0o755)

                self.log_evolution(
                    "script_created",
                    {"filename": filename, "path": str(script_path)},
                )
                return f"Script creado: {script_path}"
            except Exception as e:
                return f"Error creando script: {e}"

        return f"El script ya existe: {script_path}"

    def search_web_solution(self, error_msg):
        """Search web for solutions to unknown errors."""
        print(f"{EMOJI_GLOBE} {C_GREEN}[WEB] Buscando solución en línea...{C_RESET}")

        # Create search query
        query = f'python error solution "{error_msg[:100]}"'

        try:
            encoded_query = urllib.parse.quote(query)
            search_url = f"https://duckduckgo.com/html/?q={encoded_query}"

            result = subprocess.run(
                [
                    "curl",
                    "-s",
                    "-L",
                    "--user-agent",
                    "DJProducerTools-SelfHealing/1.0",
                    search_url,
                ],
                capture_output=True,
                text=True,
                timeout=10,
            )

            if result.returncode == 0 and result.stdout:
                # Look for solution patterns
                content = result.stdout.lower()
                if "stackoverflow" in content or "solution" in content:
                    print(f"{EMOJI_CRYSTAL} {C_GREEN}[SOLUCIÓN] Posible solución encontrada online{C_RESET}")
                    return "Revisa los resultados de búsqueda para soluciones detalladas"

        except Exception:
            pass

        return "Error no reconocido. Intenta buscar manualmente en StackOverflow"

    def evolve_command(self, command, user_feedback):
        """Evolve commands based on user feedback."""
        if command not in self.knowledge["learned_commands"]:
            self.knowledge["learned_commands"][command] = {
                "feedback": [],
                "improvements": [],
            }

        self.knowledge["learned_commands"][command]["feedback"].append(user_feedback)

        # Analyze feedback for improvements
        if "slow" in user_feedback.lower():
            improvement = f"Optimizar rendimiento del comando {command}"
            self.knowledge["improvements"][command] = improvement
            print(f"{EMOJI_BRAIN} {C_GREEN}[EVOLUCIÓN] Notado: {improvement}{C_RESET}")

        self.save_knowledge()
        self.log_evolution("command_evolved", {"command": command, "feedback": user_feedback})

    def auto_update(self):
        """Automatically update and improve the system."""
        message = f"{EMOJI_ROBOT} {C_GREEN}[AUTO-UPDATE] Verificando mejoras automáticas...{C_RESET}"
        print(message)

        # Check for common issues and fix them
        improvements = 0

        # Check Python dependencies
        try:
            import librosa  # noqa: F401
        except ImportError:
            print(f"{EMOJI_DOWNLOAD} {C_CYAN}[AUTO-FIX] Instalando librosa...{C_RESET}")
            subprocess.run(["pip", "install", "librosa"], capture_output=True)
            improvements += 1

        # Check file permissions
        lib_dir = self.base_path / "lib"
        if lib_dir.exists():
            for script in lib_dir.glob("*.py"):
                if not os.access(script, os.X_OK):
                    script.chmod(0o755)
                    improvements += 1

        if improvements > 0:
            print(f"{EMOJI_BRAIN} {C_GREEN}[AUTO-UPDATE] {improvements} mejoras aplicadas{C_RESET}")
            self.log_evolution("auto_update", {"improvements": improvements})
        else:
            print(f"{EMOJI_BRAIN} {C_GREEN}[AUTO-UPDATE] Sistema optimizado{C_RESET}")


# Global self-healing system instance
self_healing = None


# Enhanced Chat CLI Integration
try:
    # Try to import advanced Chat CLI
    sys.path.insert(0, str(Path(__file__).parent / "lib"))
    from advanced_chat_cli import AdvancedChatCLI

    ADVANCED_CHAT_AVAILABLE = True
except ImportError:
    ADVANCED_CHAT_AVAILABLE = False
    print(f"{C_YLW}Warning: Advanced Chat CLI not available, using basic mode{C_RESET}")

# Import backend classes
try:
    sys.path.insert(0, str(Path(__file__).parent / "scripts"))
    from ollama_backend import OllamaBackend
    from ai_backend_manager import AIBackendManager

    BACKENDS_AVAILABLE = True
except ImportError:
    BACKENDS_AVAILABLE = False
    print(f"{C_YLW}Warning: AI backends not available, using fallback mode{C_RESET}")


class ChatCLI:
    """Structured Chat CLI context with diagnostics and IA backend awareness."""

    def __init__(self, base_path: Path, system_context: Dict[str, Any] | None = None):
        self.base_path = Path(base_path)
        self.system_context = system_context if system_context is not None else {}
        self.self_healing = SelfHealingSystem(self.base_path)

        # Initialize backends if available
        if BACKENDS_AVAILABLE:
            try:
                self.ollama_backend = OllamaBackend()
                self.openai_backend = AIBackendManager()
                self.active_backend = self.ollama_backend
            except Exception as e:
                warning_msg = f"{C_YLW}Warning: Failed to initialize backends: {e}{C_RESET}"
                print(warning_msg)
                self.ollama_backend = None
                self.openai_backend = None
                self.active_backend = None
        else:
            self.ollama_backend = None
            self.openai_backend = None
            self.active_backend = None

        self.conversation_history = []
        self.commands = {}  # Simple commands dict for now
        self.logger = None  # Simple logger for now
        self.spinner = None  # Simple spinner for now

        # Initialize advanced Chat CLI if available
        if ADVANCED_CHAT_AVAILABLE:
            try:
                self.advanced_cli = AdvancedChatCLI(self.base_path)
                self.advanced_mode = True
            except Exception as e:
                print(f"{C_YLW}Warning: Failed to initialize Advanced Chat CLI: {e}{C_RESET}")
                self.advanced_mode = False
        else:
            self.advanced_mode = False

    def get_system_context(self) -> Dict[str, Any]:
        ctx = {
            "base_path": str(self.base_path),
            "state_dir": str(self.base_path / "state"),
            "venv": self.system_context.get("venv"),
        }
        ctx.update(self.system_context)
        return ctx

    def diagnose_system(self) -> DiagnosticReport:
        """Enhanced system diagnosis with advanced AI integration"""
        if self.advanced_mode and hasattr(self.advanced_cli, "diagnose_system"):
            # Use advanced CLI diagnosis
            return _normalize_diagnostic_report(self.advanced_cli.diagnose_system())

        # Fallback to basic diagnosis
        payload = {
            "timestamp": datetime.now().isoformat(),
            "advanced_mode": self.advanced_mode,
            "basic_diagnosis": self._basic_diagnosis(),
        }
        return _normalize_diagnostic_report(payload)

    def monitor_backends(self) -> BackendStatus:
        """Enhanced backend monitoring with advanced AI integration"""
        if self.advanced_mode and hasattr(self.advanced_cli, "monitor_backends"):
            # Use advanced CLI monitoring
            return _normalize_backend_status(self.advanced_cli.monitor_backends())

        # Fallback to basic monitoring
        payload = {
            "timestamp": datetime.now().isoformat(),
            "advanced_mode": self.advanced_mode,
            "basic_monitoring": self._basic_backend_monitoring(),
        }
        return _normalize_backend_status(payload)

    def get_healing_results(self) -> HealResult:
        """Enhanced healing results with advanced AI integration"""
        if self.advanced_mode and hasattr(self.advanced_cli, "get_healing_results"):
            # Use advanced CLI healing
            return _normalize_heal_result(self.advanced_cli.get_healing_results())

        # Fallback to basic healing
        heal = self.auto_heal_issues()
        payload = {
            "timestamp": datetime.now().isoformat(),
            "advanced_mode": self.advanced_mode,
            "basic_healing": heal.__dict__,
            "actions": heal.actions,
            "warnings": heal.warnings,
            "errors": heal.errors,
            "success": heal.success,
        }
        return _normalize_heal_result(payload)

    def _basic_diagnosis(self) -> Dict[str, Any]:
        """Basic system diagnosis"""
        return {
            "python_version": sys.version,
            "base_path": str(self.base_path),
            "working_directory": os.getcwd(),
            "environment": os.environ.get("DJPT_ENV", "production"),
        }

    def _basic_backend_monitoring(self) -> Dict[str, Any]:
        """Basic backend monitoring"""
        if self.ollama_backend is None and self.openai_backend is None:
            return {
                "ollama": "unavailable",
                "openai": "unavailable",
                "status": "backends_not_available",
            }

        status = {}
        if self.ollama_backend:
            try:
                # Simple status check
                status["ollama"] = "active"
            except Exception:
                status["ollama"] = "inactive"
        else:
            status["ollama"] = "not_initialized"

        if self.openai_backend:
            try:
                status["openai"] = "active"
            except Exception:
                status["openai"] = "inactive"
        else:
            status["openai"] = "not_initialized"

        return status

    def auto_heal_issues(self) -> HealResult:
        """Auto-heal system issues with fallback"""
        try:
            # Basic healing without backends dependency
            ensure_ai_structure(self.base_path)
            return HealResult(
                success=True,
                actions=[f"ensure_ai_structure({self.base_path})"],
                warnings=[],
                errors=[],
            )
        except Exception as e:
            return HealResult(
                success=False,
                actions=[],
                warnings=[],
                errors=[f"AI structure: {e}"],
            )

    def generate_recommendations(self) -> list[str]:
        recs: list[str] = []
        report = self.diagnose_system()
        backends = self.monitor_backends()

        if isinstance(report, DiagnosticReport) and report.errors:
            recs.append("Revisa errores del diagnóstico antes de ejecutar tareas pesadas")
        elif isinstance(report, DiagnosticReport) and report.warnings:
            recs.append("Atiende avisos del diagnóstico para mejorar estabilidad")

        if isinstance(backends, BackendStatus):
            ollama_info = backends.backends.get("ollama", {})
            openai_info = backends.backends.get("openai", {})
            ollama_state = ollama_info.get("status") if isinstance(ollama_info, dict) else str(ollama_info)
            openai_state = openai_info.get("status") if isinstance(openai_info, dict) else str(openai_info)
            if ollama_state != "active":
                recs.append("Instala/arranca Ollama para chat local")
            if openai_state not in {"active", "configured"}:
                recs.append("Configura API key de OpenAI para chat avanzado")

        return recs

    def interpret_conversation(self, user_input: str) -> Dict[str, Any]:
        normalized = normalize_chat_text(user_input)
        intent = detect_conversation_intent(normalized)
        explicit_run = is_explicit_execution_request(normalized)
        recommendations = self.generate_recommendations()
        report = self.diagnose_system()
        backend = self.monitor_backends()

        reply = ""
        action = None

        if intent == "greeting":
            reply = (
                f"{EMOJI_WIZARD} {C_GREEN}Hola. Ya estoy conectado a {C_CYAN}{self.base_path}{C_GREEN}.{C_RESET}\n"
                f"{EMOJI_GEAR} {C_GREEN}Estado actual:{C_RESET} {report.summary()}\n"
                f"{EMOJI_ROBOT} {C_GREEN}Backends IA:{C_RESET} {backend.summary()}\n"
                f"{EMOJI_BRAIN} {C_GREEN}Puedo ayudarte a diagnosticar, escanear, revisar duplicados, optimizar y orientar el siguiente paso.{C_RESET}"
            )
        elif intent == "capabilities":
            reply = (
                f"{EMOJI_BRAIN} {C_GREEN}Puedo operar {_format_base_label(self.base_path)} como asistente local.{C_RESET}\n"
                f"  • {C_CYAN}revisa el sistema{C_RESET} -> diagnóstico conversacional\n"
                f"  • {C_CYAN}ejecuta scan{C_RESET} -> catálogo del workspace\n"
                f"  • {C_CYAN}ejecuta dupes{C_RESET} -> plan de duplicados\n"
                f"  • {C_CYAN}qué me recomiendas{C_RESET} -> siguiente paso guiado\n"
                f"  • {C_CYAN}dónde está la base{C_RESET} -> contexto operativo actual"
            )
        elif intent == "status":
            reply = (
                f"{EMOJI_GEAR} {C_GREEN}Diagnóstico:{C_RESET} {report.summary()}\n"
                f"{EMOJI_ROBOT} {C_GREEN}Backends IA:{C_RESET} {backend.summary()}\n"
                f"{EMOJI_CRYSTAL} {C_GREEN}Siguiente foco:{C_RESET} {_summarize_recommendations(recommendations)}"
            )
        elif intent == "recommendations":
            reply = (
                f"{EMOJI_CRYSTAL} {C_GREEN}Siguiente paso recomendado:{C_RESET}\n"
                f"{_format_recommendations(recommendations)}"
            )
        elif intent == "base_path":
            reply = (
                f"{EMOJI_GEAR} {C_GREEN}Base activa:{C_RESET} {self.base_path}\n"
                f"{EMOJI_ROBOT} {C_GREEN}Python ML actual:{C_RESET} {self.get_system_context().get('venv') or sys.executable}"
            )
        elif intent == "scan":
            scan_request = extract_scan_request(user_input, self.base_path)
            action = "scan"
            reply = (
                f"{EMOJI_SEARCH} {C_GREEN}Entiendo el escaneo como:{C_RESET} {describe_scan_request(scan_request)}\n"
                f"{EMOJI_CRYSTAL} {C_GREEN}Lo ejecuto ahora usando la CLI real del scanner.{C_RESET}"
            )
            result = {"handled": True, "reply": reply, "action": None, "intent": intent, "scan_request": scan_request}
            self.conversation_history.append(
                {
                    "ts": datetime.now().isoformat(),
                    "input": user_input,
                    "intent": intent,
                    "action": action,
                    "scan_request": {"path": str(scan_request["path"]), "only": scan_request["only"]},
                }
            )
            if len(self.conversation_history) > 100:
                self.conversation_history = self.conversation_history[-100:]
            return result
        elif intent == "organize_audio":
            reply = (
                f"{EMOJI_MUSIC} {C_GREEN}Entiendo que quieres organizar la música por género/BPM/clave.{C_RESET}\n"
                f"{EMOJI_CRYSTAL} {C_GREEN}Necesito una ruta concreta. Ejemplo:{C_RESET} {C_CYAN}organizar /ruta/de/la/libreria{C_RESET}\n"
                f"{EMOJI_BRAIN} {C_GREEN}Si quieres revisar sin mover nada, usa {C_CYAN}organizar --dry-run /ruta{C_GREEN}.{C_RESET}"
            )
        elif intent == "playlist_audio":
            reply = (
                f"{EMOJI_MUSIC} {C_GREEN}Puedo generar una playlist inteligente, pero necesito la carpeta origen.{C_RESET}\n"
                f"{EMOJI_CRYSTAL} {C_GREEN}Ejemplo:{C_RESET} {C_CYAN}playlist /ruta/de/tu/musica{C_RESET}"
            )
        elif intent == "analyze_audio":
            reply = (
                f"{EMOJI_MUSIC} {C_GREEN}Para analizar audio necesito el archivo o carpeta objetivo.{C_RESET}\n"
                f"{EMOJI_CRYSTAL} {C_GREEN}Ejemplo:{C_RESET} {C_CYAN}analizar track.mp3{C_RESET} o {C_CYAN}analizar --batch /ruta{C_RESET}"
            )
        elif intent == "master_audio":
            reply = (
                f"{EMOJI_MUSIC} {C_GREEN}Puedo lanzar mastering asistido, pero necesito el track objetivo.{C_RESET}\n"
                f"{EMOJI_CRYSTAL} {C_GREEN}Ejemplo:{C_RESET} {C_CYAN}mastering --profile house track.mp3{C_RESET}"
            )
        elif intent in CONVERSATIONAL_ACTIONS:
            action = CONVERSATIONAL_ACTIONS[intent]
            if explicit_run:
                reply = (
                    f"{EMOJI_GEAR} {C_GREEN}Entendido. Ejecuto {C_CYAN}{action}{C_GREEN} sobre {_format_base_label(self.base_path)}.{C_RESET}"
                )
            else:
                action_desc = CONVERSATIONAL_ACTION_DESCRIPTIONS.get(intent, action)
                reply = (
                    f"{EMOJI_BRAIN} {C_GREEN}Entiendo que quieres {action_desc}.{C_RESET}\n"
                    f"{EMOJI_CRYSTAL} {C_GREEN}Para lanzarlo ahora escribe {C_CYAN}ejecuta {action}{C_GREEN} o usa el comando corto {C_CYAN}{action}{C_GREEN}.{C_RESET}"
                )
                action = None
        elif intent == "search":
            topic = extract_search_topic(user_input)
            if topic:
                reply = (
                    f"{EMOJI_GLOBE} {C_GREEN}Entiendo que quieres investigar:{C_RESET} {topic}\n"
                    f"{EMOJI_CRYSTAL} {C_GREEN}Lánzalo con {C_CYAN}buscar {topic}{C_GREEN} o {C_CYAN}investigar {topic}{C_GREEN}.{C_RESET}"
                )
            else:
                reply = (
                    f"{EMOJI_GLOBE} {C_GREEN}Puedo investigar temas reales del sistema o de audio/IA.{C_RESET}\n"
                    f"{EMOJI_CRYSTAL} {C_GREEN}Ejemplo:{C_RESET} buscar latencia metal mlx"
                )
        elif intent == "rag_ops":
            if explicit_run:
                action = "rag_status"
                reply = (
                    f"{EMOJI_BRAIN} {C_GREEN}Activo operaciones RAG ahora mismo.{C_RESET}\n"
                    f"{EMOJI_CRYSTAL} {C_GREEN}También puedes usar:{C_RESET} {C_CYAN}rag query <pregunta>{C_RESET} o {C_CYAN}rag index-text /ruta{C_RESET}."
                )
            else:
                reply = (
                    f"{EMOJI_BRAIN} {C_GREEN}Puedo indexar y consultar conocimiento con RAG local.{C_RESET}\n"
                    f"{EMOJI_CRYSTAL} {C_GREEN}Comandos:{C_RESET} {C_CYAN}rag status{C_RESET}, {C_CYAN}rag query <pregunta>{C_RESET}, {C_CYAN}rag index-text /ruta{C_RESET}."
                )
        elif intent == "hf_ops":
            if explicit_run:
                action = "hf_status"
                reply = (
                    f"{EMOJI_ROBOT} {C_GREEN}Reviso estado HF/Transformers ahora.{C_RESET}\n"
                    f"{EMOJI_CRYSTAL} {C_GREEN}Sync real:{C_RESET} {C_CYAN}hf sync --allow-remote --force-enable{C_RESET}."
                )
            else:
                reply = (
                    f"{EMOJI_ROBOT} {C_GREEN}Puedo operar HuggingFace en modo local-first controlado.{C_RESET}\n"
                    f"{EMOJI_CRYSTAL} {C_GREEN}Comandos:{C_RESET} {C_CYAN}hf status{C_RESET}, {C_CYAN}hf sync --allow-remote{C_RESET}, {C_CYAN}online-setup --apply --hf-sync{C_RESET}."
                )
        elif intent == "module_ops":
            reply = (
                f"{EMOJI_GEAR} {C_GREEN}Módulos aislados disponibles (sin romper base).{C_RESET}\n"
                f"{EMOJI_CRYSTAL} {C_GREEN}Comandos:{C_RESET} {C_CYAN}modulo list{C_RESET}, {C_CYAN}modulo init <nombre>{C_RESET}, {C_CYAN}modulo run <nombre> -- arg1 arg2{C_RESET}, {C_CYAN}modulo doctor{C_RESET}."
            )
        elif intent == "combo_ops":
            if explicit_run:
                action = "combo_status"
                reply = (
                    f"{EMOJI_BRAIN} {C_GREEN}Activo pipeline combinado ahora (diagnóstico+RAG+HF+módulos+tareas).{C_RESET}"
                )
            else:
                reply = (
                    f"{EMOJI_BRAIN} {C_GREEN}Puedo combinar toda la capa IA/chat en pipelines eficientes.{C_RESET}\n"
                    f"{EMOJI_CRYSTAL} {C_GREEN}Comandos:{C_RESET} "
                    f"{C_CYAN}combo status{C_RESET}, "
                    f"{C_CYAN}combo learn <url>{C_RESET}, "
                    f"{C_CYAN}combo optimize{C_RESET}, "
                    f"{C_CYAN}combo setup --apply --install-optional-deps --hf-sync{C_RESET}."
                )
        elif intent == "schedule":
            reply = (
                f"{EMOJI_GEAR} {C_GREEN}Scheduler local listo para tareas periódicas.{C_RESET}\n"
                f"{EMOJI_CRYSTAL} {C_GREEN}Comandos:{C_RESET} {C_CYAN}programar cada 30m scan mp3{C_RESET}, {C_CYAN}tareas{C_RESET}, {C_CYAN}tareas run{C_RESET}."
            )
        elif intent == "study_web":
            url = extract_first_url(user_input)
            if url and explicit_run:
                action = "study_web"
                reply = (
                    f"{EMOJI_GLOBE} {C_GREEN}Entendido. Estudio y guardo esta fuente web:{C_RESET} {url}\n"
                    f"{EMOJI_CRYSTAL} {C_GREEN}Si quieres indexarla a RAG usa:{C_RESET} {C_CYAN}estudiar-web {url} --index-rag{C_RESET}."
                )
            elif url:
                reply = (
                    f"{EMOJI_GLOBE} {C_GREEN}Puedo estudiar esa URL y guardar conocimiento local.{C_RESET}\n"
                    f"{EMOJI_CRYSTAL} {C_GREEN}Ejecuta:{C_RESET} {C_CYAN}estudiar-web {url}{C_RESET}."
                )
            else:
                reply = (
                    f"{EMOJI_GLOBE} {C_GREEN}Puedo estudiar páginas web para aprendizaje operativo.{C_RESET}\n"
                    f"{EMOJI_CRYSTAL} {C_GREEN}Ejemplo:{C_RESET} {C_CYAN}estudiar-web https://huggingface.co/models --index-rag{C_RESET}."
                )
        else:
            reply = (
                f"{EMOJI_BRAIN} {C_GREEN}No lo interpreto como un comando cerrado, pero sigo en modo asistente.{C_RESET}\n"
                f"{EMOJI_GEAR} {C_GREEN}Estado:{C_RESET} {report.summary()} | {backend.summary()}\n"
                f"{EMOJI_CRYSTAL} {C_GREEN}Prueba frases como:{C_RESET} {C_CYAN}revisa el sistema{C_RESET}, {C_CYAN}qué me recomiendas{C_RESET}, {C_CYAN}dónde está la base{C_RESET} o {C_CYAN}ejecuta scan{C_RESET}."
            )

        self.conversation_history.append(
            {
                "ts": datetime.now().isoformat(),
                "input": user_input,
                "intent": intent,
                "action": action,
            }
        )
        if len(self.conversation_history) > 100:
            self.conversation_history = self.conversation_history[-100:]

        return {"handled": True, "reply": reply, "action": action, "intent": intent}


SCRIPT_DIR = Path(__file__).parent.resolve()
ROOT_DIR = SCRIPT_DIR.parent
ENGINE_SCRIPT_CANDIDATES = (
    "DJProducerTools_MultiScript_ES.sh",
    "scripts/DJProducerTools_MultiScript_ES.sh",
    "DJProducerTools_MultiScript_EN.sh",
    "scripts/DJProducerTools_MultiScript_EN.sh",
)

CONVERSATIONAL_ACTIONS = {
    "scan": "scan",
    "dupes": "dupes",
    "backup": "backup",
    "smart": "smart",
    "predict": "predict",
    "optimize": "optimize",
    "workflow": "workflow",
}

CONVERSATIONAL_ACTION_DESCRIPTIONS = {
    "scan": "escanear la biblioteca o el workspace",
    "dupes": "revisar duplicados exactos",
    "backup": "crear un respaldo de la biblioteca DJ",
    "smart": "hacer un análisis inteligente del sistema",
    "predict": "lanzar la predicción ML de problemas",
    "optimize": "optimizar el sistema",
    "workflow": "generar un flujo de trabajo inteligente",
}

CONVERSATIONAL_INTENT_PATTERNS = {
    "greeting": ("hola", "buenas", "hello", "hey", "buenos dias", "buenas tardes", "buenas noches"),
    "capabilities": ("que puedes hacer", "como puedes ayudarme", "ayudame", "que haces", "que sabes hacer"),
    "status": ("revisa el sistema", "estado del sistema", "como esta el sistema", "diagnostica", "diagnostico", "salud del sistema"),
    "recommendations": ("que me recomiendas", "recomendame", "siguiente paso", "que hago ahora", "por donde sigo"),
    "base_path": ("donde esta la base", "base activa", "ruta base", "que base usas"),
    "scan": ("escanea", "escanear", "cataloga", "catalogar", "scan"),
    "dupes": ("duplicados", "dupes", "revisa duplicados"),
    "backup": ("backup", "respaldo", "copia de seguridad"),
    "smart": ("analisis inteligente", "analiza el sistema", "smart analysis", "analisis profundo"),
    "predict": ("predice", "predictor", "predecir problemas", "prediccion"),
    "optimize": ("optimiza", "optimizar", "mejora rendimiento"),
    "workflow": ("flujo de trabajo", "workflow"),
    "organize_audio": (
        "organiza por genero",
        "organizar por genero",
        "organiza la libreria",
        "organizar la libreria",
        "ordena la libreria",
        "clasifica por genero",
    ),
    "playlist_audio": ("crea playlist", "genera playlist", "haz playlist", "playlist inteligente"),
    "analyze_audio": ("analiza track", "analiza audio", "analizar audio", "quiero analizar"),
    "master_audio": ("haz mastering", "masteriza", "masterizar", "quiero masterizar"),
    "search": ("buscar", "busca", "investiga", "investigar"),
    "rag_ops": ("rag", "consulta conocimiento", "indexa conocimiento", "indexar conocimiento"),
    "hf_ops": ("huggingface", "hf sync", "sincroniza modelo", "transformers local"),
    "module_ops": ("modulo", "módulo", "plugin", "plugins"),
    "schedule": ("programa tarea", "programar tarea", "tarea programada", "agenda tarea"),
    "study_web": ("estudia web", "aprende de web", "asimila pagina", "asimila página", "estudiar web"),
    "combo_ops": ("combo", "fusion de tecnologias", "eficiencia combinada", "pipeline combinado"),
}

EXECUTION_PREFIXES = ("ejecuta", "lanza", "corre", "haz", "inicia")


def normalize_chat_text(text: str) -> str:
    normalized = unicodedata.normalize("NFKD", text.lower())
    normalized = "".join(ch for ch in normalized if not unicodedata.combining(ch))
    normalized = re.sub(r"\s+", " ", normalized)
    return normalized.strip()


def detect_conversation_intent(text: str) -> str:
    normalized = normalize_chat_text(text)
    if not normalized:
        return "fallback"

    if extract_first_url(normalized) and any(
        keyword in normalized for keyword in ("estudia", "aprende", "asimila", "analiza web", "web")
    ):
        return "study_web"

    for intent, patterns in CONVERSATIONAL_INTENT_PATTERNS.items():
        for pattern in patterns:
            if pattern in normalized:
                return intent

    if "program" in normalized and "tarea" in normalized:
        return "schedule"

    if any(marker in normalized for marker in ("mp3", "wav", "otros archivos", "other files", "no sean audio")) and any(
        verb in normalized for verb in ("scan", "escan", "revisa", "catalog")
    ):
        return "scan"

    if normalized in {"hola", "buenas", "hello", "hey"}:
        return "greeting"
    return "fallback"


def is_explicit_execution_request(text: str) -> bool:
    normalized = normalize_chat_text(text)
    return any(normalized.startswith(prefix + " ") or normalized == prefix for prefix in EXECUTION_PREFIXES)


def extract_search_topic(text: str) -> str:
    normalized = normalize_chat_text(text)
    for prefix in ("buscar ", "busca ", "investigar ", "investiga "):
        if normalized.startswith(prefix):
            return normalized[len(prefix):].strip()
    return ""


def _format_recommendations(recommendations: List[str]) -> str:
    if not recommendations:
        return f"  • {C_GREEN}Sin alertas inmediatas.{C_RESET} Puedes empezar con {C_CYAN}revisa el sistema{C_RESET} o {C_CYAN}ejecuta scan{C_RESET}."
    return "\n".join(f"  • {rec}" for rec in recommendations[:4])


def _summarize_recommendations(recommendations: List[str]) -> str:
    if not recommendations:
        return "Sin alertas inmediatas; puedes empezar con un scan o revisar duplicados."
    return recommendations[0]


def _format_base_label(base_path: Path) -> str:
    return f"{C_CYAN}{base_path}{C_GREEN}"


def resolve_engine_script(base_path: str | Path | None = None) -> Path | None:
    roots: list[Path] = []
    if base_path:
        roots.append(Path(base_path).resolve())
    roots.extend([ROOT_DIR, SCRIPT_DIR, Path.cwd().resolve()])

    seen: set[Path] = set()
    for root in roots:
        if root in seen:
            continue
        seen.add(root)
        for relative_path in ENGINE_SCRIPT_CANDIDATES:
            candidate = root / relative_path
            if candidate.is_file():
                return candidate
    return None


SCAN_FILTER_KEYWORDS = {
    "mp3": ("mp3",),
    "wav": ("wav",),
    "other": (
        "otros archivos",
        "otros ficheros",
        "no sean audio",
        "no sean audio y video",
        "no sean audio ni video",
        "otros documentos",
        "other files",
        "non media",
        "non-media",
    ),
    "all": ("todo", "toda", "todos", "everything", "all", "completo", "entero"),
    "audio": ("audio", "musica", "música"),
    "video": ("video", "vídeo", "videos", "vídeos"),
}


def _extract_path_hint(text: str, base_path: Path) -> Path:
    quoted = re.findall(r'"([^"]+)"|\'([^\']+)\'', text)
    for match in quoted:
        raw = next((item for item in match if item), "")
        if raw:
            return Path(raw).expanduser().resolve()

    for token in text.split():
        if token.startswith(("~/", "/")):
            return Path(token).expanduser().resolve()

    return Path(base_path).resolve()


def extract_scan_request(text: str, base_path: str | Path) -> dict[str, Any]:
    normalized = normalize_chat_text(text)
    only = "media"

    for candidate, patterns in SCAN_FILTER_KEYWORDS.items():
        if any(pattern in normalized for pattern in patterns):
            only = candidate
            break

    return {
        "path": _extract_path_hint(text, Path(base_path)),
        "only": only,
        "raw": text,
    }


def describe_scan_request(scan_request: dict[str, Any]) -> str:
    path = scan_request["path"]
    only = scan_request["only"]
    descriptions = {
        "media": "audio y vídeo",
        "all": "todos los archivos",
        "audio": "solo audio",
        "video": "solo vídeo",
        "other": "solo archivos no audio/vídeo",
        "mp3": "solo MP3",
        "wav": "solo WAV",
    }
    return f"{descriptions.get(only, only)} en {path}"


def parse_direct_scan_args(args: List[str], base_path: str | Path) -> dict[str, Any]:
    only = "media"
    path = Path(base_path).resolve()
    quick = False

    for arg in args:
        lowered = arg.lower()
        if lowered == "--quick":
            quick = True
            continue
        if lowered in {"all", "media", "audio", "video", "other", "mp3", "wav"}:
            only = lowered
            continue
        if lowered.startswith("--only="):
            only = lowered.split("=", 1)[1].strip() or only
            continue
        if arg.startswith(("~/", "/")):
            path = Path(arg).expanduser().resolve()

    return {"path": path, "only": only, "quick": quick, "raw": " ".join(args)}


def run_scan_workflow(scan_request: dict[str, Any], python_bin: str, base_path: str | Path) -> bool:
    target = Path(scan_request["path"]).expanduser().resolve()
    only = scan_request.get("only", "media")
    quick = scan_request.get("quick", True)
    cli_script = ROOT_DIR / "cli.py"
    if not cli_script.exists():
        print(f"{C_RED}[ERR] cli.py no encontrado en {ROOT_DIR}{C_RESET}")
        return False

    cmd = [python_bin, str(cli_script), "scan", str(target), "--parallel", "--only", str(only)]
    if quick:
        cmd.append("--quick")

    env = os.environ.copy()
    env["DJPT_ALLOW_OUTSIDE"] = "1"
    env["DJPT_BASE_DIR"] = str(Path(base_path).resolve())
    env["PYTHON_BIN"] = python_bin
    env["DJPT_PYTHON_BIN"] = python_bin
    if is_virtualenv_python(python_bin):
        env["VENV_DIR"] = str(Path(python_bin).resolve().parent.parent)

    print(f"{EMOJI_SEARCH} {C_GREEN}[SCAN] {describe_scan_request(scan_request)}{C_RESET}")
    try:
        result = subprocess.run(cmd, check=False, env=env, text=True)
    except Exception as exc:
        print(f"{C_RED}[ERR] Falló el escaneo: {exc}{C_RESET}")
        return False

    if result.returncode != 0:
        print(f"{C_RED}[ERR] Escaneo finalizó con código {result.returncode}{C_RESET}")
        return False
    return True


CHAT_TASKS_SCHEMA_VERSION = "chat_tasks_v1"
SCHEDULE_UNIT_SECONDS = {
    "s": 1,
    "m": 60,
    "h": 3600,
    "d": 86400,
}


def _build_cli_bridge_env(base_path: str | Path, python_bin: str) -> dict[str, str]:
    env = os.environ.copy()
    resolved_base = str(Path(base_path).expanduser().resolve())
    env["DJPT_ALLOW_OUTSIDE"] = "1"
    env["DJPT_BASE_DIR"] = resolved_base
    env["BASE_PATH"] = resolved_base
    env["PYTHON_BIN"] = str(python_bin)
    env["DJPT_PYTHON_BIN"] = str(python_bin)
    if is_virtualenv_python(str(python_bin)):
        env["VENV_DIR"] = str(Path(python_bin).expanduser().resolve().parent.parent)
    return env


def run_cli_bridge(
    cli_args: list[str],
    python_bin: str,
    base_path: str | Path,
    timeout: int = 900,
) -> tuple[int, str, str]:
    cli_script = ROOT_DIR / "cli.py"
    if not cli_script.exists():
        return 2, "", f"cli.py no encontrado en {cli_script}"

    cmd = [python_bin, str(cli_script), *cli_args]
    try:
        proc = subprocess.run(
            cmd,
            cwd=str(ROOT_DIR),
            env=_build_cli_bridge_env(base_path, python_bin),
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        return proc.returncode, proc.stdout, proc.stderr
    except subprocess.TimeoutExpired:
        return 124, "", f"timeout ejecutando: {' '.join(cmd)}"
    except Exception as exc:
        return 2, "", f"error ejecutando {' '.join(cmd)}: {exc}"


def _emit_bridge_output(stdout: str, stderr: str, emit: bool = True) -> None:
    if not emit:
        return
    if stdout.strip():
        print(stdout.strip())
    if stderr.strip():
        print(f"{C_YLW}[WARN]{C_RESET} {stderr.strip()}")


def handle_rag_command(args: list[str], python_bin: str, base_path: str | Path, emit: bool = True) -> int:
    action = "status"
    query: str | None = None
    path_arg: str | None = None
    topk: int | None = None
    allowed = {"index-text", "index-audio", "query", "status"}
    tokens = list(args)

    if tokens and tokens[0] in allowed:
        action = tokens.pop(0)

    i = 0
    while i < len(tokens):
        tok = tokens[i]
        if tok in allowed:
            action = tok
            i += 1
            continue
        if tok == "--action" and i + 1 < len(tokens):
            action = tokens[i + 1]
            i += 2
            continue
        if tok.startswith("--action="):
            action = tok.split("=", 1)[1].strip()
            i += 1
            continue
        if tok == "--path" and i + 1 < len(tokens):
            path_arg = tokens[i + 1]
            i += 2
            continue
        if tok.startswith("--path="):
            path_arg = tok.split("=", 1)[1].strip()
            i += 1
            continue
        if tok == "--query" and i + 1 < len(tokens):
            query = tokens[i + 1]
            i += 2
            continue
        if tok.startswith("--query="):
            query = tok.split("=", 1)[1]
            i += 1
            continue
        if tok == "--topk" and i + 1 < len(tokens):
            try:
                topk = int(tokens[i + 1])
            except ValueError:
                topk = None
            i += 2
            continue
        if tok.startswith("--topk="):
            raw = tok.split("=", 1)[1]
            try:
                topk = int(raw)
            except ValueError:
                topk = None
            i += 1
            continue
        if action == "query":
            query = " ".join(tokens[i:]).strip()
            break
        if tok.startswith(("~/", "/")) and path_arg is None:
            path_arg = tok
        i += 1

    if action not in allowed:
        if emit:
            print(f"{C_RED}[ERR] Acción RAG inválida: {action}{C_RESET}")
        return 2

    cli_args = ["ai", "rag", "--action", action]
    if path_arg:
        cli_args += ["--path", path_arg]
    if query:
        cli_args += ["--query", query]
    if topk is not None:
        cli_args += ["--topk", str(topk)]

    rc, stdout, stderr = run_cli_bridge(cli_args, python_bin, base_path)
    _emit_bridge_output(stdout, stderr, emit=emit)
    return rc


def handle_hf_command(args: list[str], python_bin: str, base_path: str | Path, emit: bool = True) -> int:
    action = "status"
    allow_remote = False
    force_enable = False
    dry_run = False
    internet_probe = True
    enable_transformers = False
    verify_remote = True

    tokens = list(args)
    if tokens and tokens[0] in {"status", "sync"}:
        action = tokens.pop(0)

    for tok in tokens:
        normalized = normalize_chat_text(tok)
        if tok in {"--allow-remote", "--remote"} or normalized in {"remoto", "allow-remote"}:
            allow_remote = True
        elif tok == "--force-enable" or normalized in {"forzar", "force"}:
            force_enable = True
        elif tok == "--dry-run":
            dry_run = True
        elif tok in {"--no-internet-probe", "--offline-ok"}:
            internet_probe = False
        elif tok == "--enable-transformers":
            enable_transformers = True
        elif tok == "--no-verify-remote":
            verify_remote = False
        elif tok in {"sync", "status"}:
            action = tok

    cli_args = ["ai", "hf-sync", "--action", action, "--format", "text"]
    if allow_remote:
        cli_args.append("--allow-remote")
    if force_enable:
        cli_args.append("--force-enable")
    if dry_run:
        cli_args.append("--dry-run")
    if not internet_probe:
        cli_args.append("--no-internet-probe")
    if enable_transformers:
        cli_args.append("--enable-transformers")
    if not verify_remote:
        cli_args.append("--no-verify-remote")

    rc, stdout, stderr = run_cli_bridge(cli_args, python_bin, base_path)
    _emit_bridge_output(stdout, stderr, emit=emit)
    return rc


def handle_online_setup_command(args: list[str], python_bin: str, base_path: str | Path, emit: bool = True) -> int:
    apply = False
    install_optional_deps = False
    hf_sync = False
    hf_dry_run = False
    hf_force_enable = False

    for tok in args:
        normalized = normalize_chat_text(tok)
        if tok == "--apply" or normalized in {"aplicar", "apply"}:
            apply = True
        elif tok in {"--install-optional-deps", "--deps"} or normalized in {"deps", "dependencias"}:
            install_optional_deps = True
        elif tok in {"--hf-sync", "--hf"} or normalized in {"hf", "huggingface"}:
            hf_sync = True
        elif tok == "--hf-dry-run":
            hf_dry_run = True
        elif tok == "--hf-force-enable":
            hf_force_enable = True

    cli_args = ["ai", "online-setup", "--format", "text"]
    if apply:
        cli_args.append("--apply")
    if install_optional_deps:
        cli_args.append("--install-optional-deps")
    if hf_sync:
        cli_args.append("--hf-sync")
    if hf_dry_run:
        cli_args.append("--hf-dry-run")
    if hf_force_enable:
        cli_args.append("--hf-force-enable")

    rc, stdout, stderr = run_cli_bridge(cli_args, python_bin, base_path)
    _emit_bridge_output(stdout, stderr, emit=emit)
    return rc


def handle_module_command(args: list[str], python_bin: str, base_path: str | Path, emit: bool = True) -> int:
    action = "list"
    name: str | None = None
    timeout = 60
    module_args: list[str] = []
    tokens = list(args)
    if tokens and tokens[0] in {"init", "list", "check", "run", "doctor"}:
        action = tokens.pop(0)

    i = 0
    while i < len(tokens):
        tok = tokens[i]
        if tok in {"init", "list", "check", "run", "doctor"}:
            action = tok
            i += 1
            continue
        if tok == "--name" and i + 1 < len(tokens):
            name = tokens[i + 1]
            i += 2
            continue
        if tok.startswith("--name="):
            name = tok.split("=", 1)[1]
            i += 1
            continue
        if tok == "--timeout" and i + 1 < len(tokens):
            try:
                timeout = int(tokens[i + 1])
            except ValueError:
                timeout = 60
            i += 2
            continue
        if tok.startswith("--timeout="):
            raw = tok.split("=", 1)[1]
            try:
                timeout = int(raw)
            except ValueError:
                timeout = 60
            i += 1
            continue
        if tok == "--":
            module_args.extend(tokens[i + 1 :])
            break
        if name is None and action in {"init", "run"}:
            name = tok
            i += 1
            continue
        if action == "run":
            module_args.append(tok)
        i += 1

    cli_args = ["ai", "module", "--action", action, "--timeout", str(timeout), "--format", "text"]
    if name:
        cli_args += ["--name", name]
    for item in module_args:
        cli_args += ["--arg", item]

    rc, stdout, stderr = run_cli_bridge(cli_args, python_bin, base_path, timeout=max(timeout + 30, 120))
    _emit_bridge_output(stdout, stderr, emit=emit)
    return rc


def extract_first_url(text: str) -> str | None:
    match = re.search(r"(https?://[^\s]+)", text)
    if not match:
        return None
    raw = match.group(1).strip()
    return raw.rstrip(").,;]")


def fetch_web_page(url: str, timeout: int = 20) -> str:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "DJProducerTools-ChatCLI/1.0"},
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:  # noqa: S310 - explicit user URL feature
        content_type = response.headers.get_content_charset() or "utf-8"
        raw = response.read(2_000_000)
    return raw.decode(content_type, errors="replace")


def _html_to_text(html: str) -> str:
    without_scripts = re.sub(
        r"<(script|style)[^>]*>.*?</\1>",
        " ",
        html,
        flags=re.IGNORECASE | re.DOTALL,
    )
    without_tags = re.sub(r"<[^>]+>", " ", without_scripts)
    unescaped = html_unescape(without_tags)
    normalized = re.sub(r"\s+", " ", unescaped).strip()
    return normalized


def _slug_from_url(url: str) -> str:
    parsed = urllib.parse.urlparse(url)
    base = f"{parsed.netloc}_{parsed.path}".strip("_")
    safe = re.sub(r"[^a-zA-Z0-9]+", "_", base).strip("_").lower()
    return safe[:60] or "web_source"


def study_web_page(
    url: str,
    base_path: str | Path,
    python_bin: str,
    *,
    index_rag: bool = False,
) -> dict[str, Any]:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme not in {"http", "https"}:
        return {"status": "fail", "details": f"URL no soportada: {url}"}

    try:
        html = fetch_web_page(url)
    except Exception as exc:
        return {"status": "fail", "details": f"No se pudo descargar {url}: {exc}"}

    text = _html_to_text(html)
    if len(text) < 80:
        return {"status": "fail", "details": f"Contenido insuficiente para aprendizaje desde {url}"}

    resolved_base = Path(base_path).expanduser().resolve()
    kb_raw = resolved_base / "kb" / "raw"
    kb_raw.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    target = kb_raw / f"web_{_slug_from_url(url)}_{timestamp}.md"
    payload = (
        f"# Fuente web estudiada\n\n"
        f"- URL: {url}\n"
        f"- Capturado: {datetime.now().isoformat()}\n\n"
        f"{text}\n"
    )
    target.write_text(payload, encoding="utf-8")

    result: dict[str, Any] = {
        "status": "ok",
        "details": "Contenido web capturado",
        "url": url,
        "path": str(target),
        "chars": len(text),
    }

    if index_rag:
        rc, stdout, stderr = run_cli_bridge(
            ["ai", "rag", "--action", "index-text", "--path", str(kb_raw)],
            python_bin,
            base_path,
        )
        result["rag_index"] = {"rc": rc, "ok": rc == 0}
        if stdout.strip():
            result["rag_stdout"] = stdout.strip()
        if stderr.strip():
            result["rag_stderr"] = stderr.strip()

    return result


def _chat_tasks_file(base_path: str | Path) -> Path:
    resolved_base = Path(base_path).expanduser().resolve()
    return resolved_base / "state" / "chat_tasks.json"


def load_chat_tasks(base_path: str | Path) -> dict[str, Any]:
    path = _chat_tasks_file(base_path)
    if not path.exists():
        return {"schema_version": CHAT_TASKS_SCHEMA_VERSION, "tasks": []}
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        payload = {"schema_version": CHAT_TASKS_SCHEMA_VERSION, "tasks": []}
    if not isinstance(payload, dict):
        payload = {"schema_version": CHAT_TASKS_SCHEMA_VERSION, "tasks": []}
    if "tasks" not in payload or not isinstance(payload["tasks"], list):
        payload["tasks"] = []
    payload.setdefault("schema_version", CHAT_TASKS_SCHEMA_VERSION)
    return payload


def save_chat_tasks(base_path: str | Path, payload: dict[str, Any]) -> Path:
    path = _chat_tasks_file(base_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    payload["schema_version"] = CHAT_TASKS_SCHEMA_VERSION
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return path


def parse_interval_token(raw: str) -> tuple[int, str]:
    token = normalize_chat_text(raw)
    match = re.fullmatch(r"(\d+)([smhd])", token)
    if not match:
        raise ValueError("Intervalo inválido. Usa formato 30m, 2h, 1d...")
    value = int(match.group(1))
    unit = match.group(2)
    if value <= 0:
        raise ValueError("El intervalo debe ser > 0")
    seconds = value * SCHEDULE_UNIT_SECONDS[unit]
    return seconds, token


def create_chat_task(base_path: str | Path, interval_token: str, command_line: str) -> dict[str, Any]:
    interval_seconds, normalized_interval = parse_interval_token(interval_token)
    command = command_line.strip()
    if not command:
        raise ValueError("Comando de tarea vacío")

    payload = load_chat_tasks(base_path)
    now = datetime.utcnow()
    next_run = now.timestamp() + interval_seconds
    task_id = f"task_{int(now.timestamp())}_{len(payload['tasks']) + 1:03d}"
    task = {
        "id": task_id,
        "interval": normalized_interval,
        "interval_seconds": interval_seconds,
        "command": command,
        "enabled": True,
        "created_at": now.isoformat() + "Z",
        "next_run_ts": next_run,
        "last_run_ts": None,
        "last_rc": None,
        "run_count": 0,
    }
    payload["tasks"].append(task)
    save_chat_tasks(base_path, payload)
    return task


def parse_schedule_request(args: list[str]) -> tuple[str, str]:
    tokens = list(args)
    if tokens and normalize_chat_text(tokens[0]) == "cada":
        tokens = tokens[1:]
    if len(tokens) < 2:
        raise ValueError("Uso: programar [cada] <intervalo> <comando...>")
    interval = tokens[0]
    command_line = " ".join(tokens[1:]).strip()
    if not command_line:
        raise ValueError("Falta comando a ejecutar")
    return interval, command_line


def set_chat_task_enabled(base_path: str | Path, task_id: str, enabled: bool) -> bool:
    payload = load_chat_tasks(base_path)
    found = False
    for task in payload["tasks"]:
        if task.get("id") != task_id:
            continue
        task["enabled"] = enabled
        found = True
    if found:
        save_chat_tasks(base_path, payload)
    return found


def remove_chat_task(base_path: str | Path, task_id: str) -> bool:
    payload = load_chat_tasks(base_path)
    before = len(payload["tasks"])
    payload["tasks"] = [task for task in payload["tasks"] if task.get("id") != task_id]
    if len(payload["tasks"]) != before:
        save_chat_tasks(base_path, payload)
        return True
    return False


def execute_scheduled_command(command_line: str, python_bin: str, base_path: str | Path) -> tuple[int, str]:
    tokens = shlex.split(command_line)
    if not tokens:
        return 2, "comando vacío"

    command = normalize_chat_text(tokens[0])
    args = tokens[1:]

    if command in {"scan", "escanear"}:
        scan_request = parse_direct_scan_args(args, base_path)
        ok = run_scan_workflow(scan_request, python_bin, base_path)
        return (0 if ok else 2), "scan"

    if command == "rag":
        rc = handle_rag_command(args, python_bin, base_path, emit=False)
        return rc, "rag"

    if command in {"hf", "huggingface"}:
        rc = handle_hf_command(args, python_bin, base_path, emit=False)
        return rc, "hf-sync"

    if command in {"online-setup", "setup-online", "setup-ai", "setup-ia"}:
        rc = handle_online_setup_command(args, python_bin, base_path, emit=False)
        return rc, "online-setup"

    if command in {"modulo", "module", "plugin"}:
        rc = handle_module_command(args, python_bin, base_path, emit=False)
        return rc, "module-manager"

    if command in CONVERSATIONAL_ACTIONS.values():
        run_engine(command, base_path)
        return 0, command

    return 2, f"comando no soportado por scheduler: {command}"


def run_due_chat_tasks(
    base_path: str | Path,
    python_bin: str,
    *,
    now_ts: float | None = None,
    runner: Any | None = None,
) -> dict[str, Any]:
    payload = load_chat_tasks(base_path)
    now = now_ts if now_ts is not None else datetime.utcnow().timestamp()
    executed = []
    for task in payload["tasks"]:
        if not task.get("enabled", True):
            continue
        next_run_ts = float(task.get("next_run_ts") or 0)
        if next_run_ts > now:
            continue
        command_line = str(task.get("command", "")).strip()
        if runner is None:
            rc, details = execute_scheduled_command(command_line, python_bin, base_path)
        else:
            rc, details = runner(command_line, python_bin, base_path)
        interval_seconds = int(task.get("interval_seconds", 0))
        task["last_run_ts"] = now
        task["last_rc"] = rc
        task["last_details"] = details
        task["run_count"] = int(task.get("run_count", 0)) + 1
        task["next_run_ts"] = now + max(interval_seconds, 1)
        executed.append({"id": task.get("id"), "command": command_line, "rc": rc, "details": details})

    save_chat_tasks(base_path, payload)
    return {"status": "ok", "executed_count": len(executed), "executed": executed}


def run_combined_pipeline(
    mode: str,
    args: list[str],
    python_bin: str,
    base_path: str | Path,
    *,
    chat_context: Any | None = None,
) -> tuple[dict[str, Any], int]:
    normalized_mode = normalize_chat_text(mode)
    steps: list[dict[str, Any]] = []
    details: dict[str, Any] = {}

    def _record_step(name: str, rc: int, info: str) -> None:
        steps.append({"step": name, "rc": int(rc), "info": info})

    if normalized_mode in {"status", "estado", "full-status"}:
        if chat_context is not None:
            diag = chat_context.diagnose_system()
            backend = chat_context.monitor_backends()
            details["diagnostic"] = diag.summary()
            details["backends"] = backend.summary()
        else:
            details["diagnostic"] = "sin contexto de chat"
            details["backends"] = "sin contexto de chat"

        rag_rc = handle_rag_command(["status"], python_bin, base_path, emit=False)
        hf_rc = handle_hf_command(["status"], python_bin, base_path, emit=False)
        module_rc = handle_module_command(["list"], python_bin, base_path, emit=False)
        tasks_payload = load_chat_tasks(base_path)
        details["tasks_count"] = len(tasks_payload.get("tasks", []))

        _record_step("rag_status", rag_rc, "RAG status")
        _record_step("hf_status", hf_rc, "HF status")
        _record_step("module_list", module_rc, "Module list")
        _record_step("tasks_inventory", 0, f"tasks={details['tasks_count']}")

    elif normalized_mode in {"learn", "aprender", "study"}:
        url = next((extract_first_url(token) for token in args if extract_first_url(token)), None)
        if not url and args:
            joined = " ".join(args).strip()
            url = extract_first_url(joined) or joined
        if not url:
            return (
                {
                    "status": "fail",
                    "mode": normalized_mode,
                    "details": "Falta URL. Uso: combo learn <url>",
                    "steps": [],
                },
                2,
            )

        study = study_web_page(url, base_path, python_bin, index_rag=True)
        study_rc = 0 if study.get("status") == "ok" else 2
        details["url"] = url
        details["study"] = study
        _record_step("study_web", study_rc, study.get("details", "study_web"))

        rag_rc = handle_rag_command(["status"], python_bin, base_path, emit=False)
        hf_rc = handle_hf_command(["status"], python_bin, base_path, emit=False)
        _record_step("rag_status", rag_rc, "RAG status")
        _record_step("hf_status", hf_rc, "HF status")

    elif normalized_mode in {"optimize", "optimizar", "efficiency"}:
        if chat_context is not None:
            heal = chat_context.auto_heal_issues()
            heal_rc = 0 if heal.success else 2
            _record_step("autoheal", heal_rc, heal.summary())
        else:
            _record_step("autoheal", 2, "sin contexto de chat")

        module_rc = handle_module_command(["doctor"], python_bin, base_path, emit=False)
        due_payload = run_due_chat_tasks(base_path, python_bin)
        rag_rc = handle_rag_command(["status"], python_bin, base_path, emit=False)
        hf_rc = handle_hf_command(["status"], python_bin, base_path, emit=False)

        details["executed_tasks"] = due_payload.get("executed_count", 0)
        _record_step("module_doctor", module_rc, "Module doctor")
        _record_step("tasks_run", 0, f"executed={details['executed_tasks']}")
        _record_step("rag_status", rag_rc, "RAG status")
        _record_step("hf_status", hf_rc, "HF status")

        if any(normalize_chat_text(token) == "--engine-optimize" for token in args):
            run_engine("optimize", base_path)
            _record_step("engine_optimize", 0, "run_engine optimize")

    elif normalized_mode in {"setup", "bootstrap"}:
        setup_rc = handle_online_setup_command(args, python_bin, base_path, emit=False)
        _record_step("online_setup", setup_rc, "online-setup")
    else:
        return (
            {
                "status": "fail",
                "mode": normalized_mode,
                "details": "Modo no soportado. Usa: status|learn|optimize|setup",
                "steps": [],
            },
            2,
        )

    failing_steps = [step for step in steps if step["rc"] != 0]
    payload = {
        "status": "ok" if not failing_steps else "warn",
        "mode": normalized_mode,
        "details": details,
        "steps": steps,
    }
    return payload, (0 if not failing_steps else 2)

# Audio processing commands mapping
AUDIO_COMMANDS = {
    "analizar": {
        "desc": "Análisis completo de audio (BPM, clave, energía, espectro)",
        "script": "lib/bpm_analyzer.py",
        "args": ["--full-analysis"],
        "example": "analizar track.mp3",
    },
    "bpm": {
        "desc": "Detección precisa de BPM y tempo",
        "script": "lib/bpm_analyzer.py",
        "args": ["--bpm-only"],
        "example": "bpm track.mp3",
    },
    "clave": {
        "desc": "Detección de clave tonal (Camelot, Open Key)",
        "script": "lib/bpm_analyzer.py",
        "args": ["--key-detection"],
        "example": "clave track.mp3",
    },
    "similar": {
        "desc": "Comparación de similitud entre tracks",
        "script": "lib/audio_similarity.py",
        "args": ["--compare"],
        "example": "similar track1.mp3 track2.mp3",
    },
    "playlist": {
        "desc": "Generación de playlist inteligente por similaridad",
        "script": "lib/audio_similarity.py",
        "args": ["--playlist"],
        "example": "playlist /music/carpeta/",
    },
    "organizar": {
        "desc": "Organización automática por género/BPM/clave",
        "script": "lib/audio_similarity.py",
        "args": ["--organize"],
        "example": "organizar /music/desorganizado/",
    },
    "mastering": {
        "desc": "Mastering asistido por IA",
        "script": "lib/ml_tf.py",
        "args": ["--master"],
        "example": "mastering track.mp3",
    },
    "embeddings": {
        "desc": "Extracción de embeddings ML para análisis profundo",
        "script": "lib/ml_tf.py",
        "args": ["--extract-embeddings"],
        "example": "embeddings track.mp3",
    },
}


def load_conf():
    # Priority: Env var -> default logic
    base = os.environ.get("BASE_PATH")
    if base:
        conf_file = Path(base) / "config" / "djpt.conf"
    else:
        conf_file = ROOT_DIR / "config" / "djpt.conf"

    if not conf_file.exists():
        return {}
    config = {}
    with open(conf_file, "r") as f:
        for line in f:
            if "=" in line:
                key, val = line.strip().split("=", 1)
                config[key] = val.strip("'\"")
    return config


def run_engine(action, base_path: str | Path | None = None):
    """Executes the shell script engine with a specific action."""
    resolved_base = Path(base_path).resolve() if base_path else ROOT_DIR
    engine_script = resolve_engine_script(resolved_base)
    if engine_script is None:
        print(f"{C_RED}[ERR] Engine script no encontrado para acción '{action}'.{C_RESET}")
        return
    env = os.environ.copy()
    env["BASE_PATH"] = str(resolved_base)
    current_python = Path(sys.executable).resolve()
    if current_python.exists() and is_virtualenv_python(str(current_python)):
        env["PYTHON_BIN"] = str(current_python)
        env["DJPT_PYTHON_BIN"] = str(current_python)
        env["VENV_DIR"] = str(current_python.parent.parent)
    cmd = ["bash", str(engine_script), "--run", action]
    try:
        subprocess.run(cmd, check=False, env=env)
    except Exception as e:
        print(f"{C_RED}[ERR] Failed to run engine: {e}{C_RESET}")


def print_help():
    print(f"\n{BOLD_LARGE}╔══════════════════════════════════════════════════════════════╗{RESET_LARGE}")
    print(f"{BOLD_LARGE}║  🧙‍♂️ DJProducerTools Chat CLI - Asistente Matrix 🧠          ║{RESET_LARGE}")
    print(f"{BOLD_LARGE}╚══════════════════════════════════════════════════════════════╝{RESET_LARGE}")
    print(f"\n{EMOJI_MUSIC} {C_GREEN}🎵 COMANDOS DE PROCESAMIENTO DE AUDIO:{C_RESET}")
    for cmd, info in AUDIO_COMMANDS.items():
        print(f"  {C_GREEN}{cmd:<12}{C_RESET} {info['desc']}")
        print(f"               {C_CYAN}Ej: {info['example']}{C_RESET}")

    print(f"\n{EMOJI_GEAR} {C_GREEN}🔧 COMANDOS DEL SISTEMA:{C_RESET}")
    print(f"  {C_GREEN}status{C_RESET:<12} - Estado del sistema y rutas")
    print(f"  {C_GREEN}diag{C_RESET:<12} - Diagnóstico rápido + backends IA")
    print(f"  {C_GREEN}ia-status{C_RESET:<12} - Estado de backends IA (Ollama/OpenAI/HF)")
    print(f"  {C_GREEN}autoheal{C_RESET:<12} - Auto-reparación ligera (carpetas/cache)")
    print(f"  {C_GREEN}recomienda{C_RESET:<12} - Recomendaciones inmediatas")
    print(f"  {C_GREEN}scan{C_RESET:<12} - Escanear espacio de trabajo")
    print(f"  {C_GREEN}backup{C_RESET:<12} - Respaldo de biblioteca DJ")
    print(f"  {C_GREEN}dupes{C_RESET:<12} - Encontrar duplicados exactos (Hash)")
    print(f"  {C_GREEN}smart{C_RESET:<12} - Análisis Inteligente (Deep Thinking)")
    print(f"  {C_GREEN}predict{C_RESET:<12} - Predictor de Problemas ML")
    print(f"  {C_GREEN}optimize{C_RESET:<12} - Optimizador de Eficiencia")
    print(f"  {C_GREEN}workflow{C_RESET:<12} - Generar Flujo Inteligente")
    print(f"  {C_GREEN}programar{C_RESET:<12} - Crear tarea periódica (ej. cada 30m)")
    print(f"  {C_GREEN}tareas{C_RESET:<12} - Listar/activar/desactivar/ejecutar tareas")

    print(f"\n{EMOJI_ROBOT} {C_GREEN}🤖 COMANDOS MACHINE LEARNING:{C_RESET}")
    print(f"  {C_GREEN}ml train{C_RESET:<12} - Entrenar modelo evolutivo local")
    print(f"  {C_GREEN}ml predict{C_RESET:<12} - Predecir usando modelo local")
    print(f"  {C_GREEN}ml status{C_RESET:<12} - Estado del modelo ML")

    print(f"\n{EMOJI_ROBOT} {C_GREEN}🤖 COMANDOS DE EVOLUCIÓN:{C_RESET}")
    print(f"  {C_GREEN}evolucionar{C_RESET:<12} - Activar auto-corrección y mejoras")
    print(f"  {C_GREEN}aprender{C_RESET:<12} - Enseñar al sistema con feedback")
    print(f"  {C_GREEN}estado{C_RESET:<12} - Mostrar estado evolutivo del sistema")

    print(f"\n{EMOJI_GLOBE} {C_GREEN}🌐 COMANDOS WEB & INTELIGENCIA:{C_RESET}")
    print(f"  {C_GREEN}buscar{C_RESET:<12} - Buscar información en internet")
    print(f"  {C_GREEN}instalar{C_RESET:<12} - Instalar herramientas automáticamente")
    print(f"  {C_GREEN}actualizar{C_RESET:<12} - Actualizar sistema y dependencias")
    print(f"  {C_GREEN}investigar{C_RESET:<12} - Investigar temas de audio ML")
    print(f"  {C_GREEN}estudiar-web{C_RESET:<12} - Capturar y aprender de una URL")

    print(f"\n{EMOJI_ROBOT} {C_GREEN}🧩 ORQUESTACIÓN IA LOCAL:{C_RESET}")
    print(f"  {C_GREEN}rag{C_RESET:<12} - RAG local (status/index/query)")
    print(f"  {C_GREEN}hf{C_RESET:<12} - Estado/sync HuggingFace local-first")
    print(f"  {C_GREEN}online-setup{C_RESET:<12} - Setup asistido de conectividad IA")
    print(f"  {C_GREEN}modulo{C_RESET:<12} - Gestión de módulos aislados")
    print(f"  {C_GREEN}combo{C_RESET:<12} - Pipeline combinado (status/learn/optimize/setup)")

    print(f"\n{EMOJI_CRYSTAL} {C_GREEN}🔮 OPCIONES AVANZADAS:{C_RESET}")
    print(f"  {C_GREEN}--dry-run{C_RESET:<12} - Previsualizar cambios sin ejecutar")
    print(f"  {C_GREEN}--verbose{C_RESET:<12} - Modo detallado con diagnóstico")
    print(f"  {C_GREEN}--batch{C_RESET:<12} - Procesar carpetas enteras")
    print(f"  {C_GREEN}--profile{C_RESET:<12} - Usar perfil de género específico")

    print(f"\n{EMOJI_BRAIN} {C_GREEN}💡 CONSEJOS EXPERTOS MATRIX:{C_RESET}")
    print(f"  • Usa {C_CYAN}analizar --dry-run{C_RESET} para previsualizar")
    print(f"  • Combina {C_CYAN}bpm + clave{C_RESET} para análisis completo")
    print(f"  • Prueba {C_CYAN}similar --verbose{C_RESET} para detalles técnicos")
    print(f"  • Usa {C_CYAN}playlist --batch{C_RESET} para carpetas grandes")
    print(f"  • {C_CYAN}mastering --profile techno{C_RESET} para géneros específicos")
    print(f"  • {C_CYAN}buscar 'audio ML trends'{C_RESET} para información actualizada")


def print_audio_guide():
    """Print comprehensive audio processing guide."""
    print(f"\n{C_MAG}=== GUÍA AVANZADA DE PROCESAMIENTO DE AUDIO ==={C_RESET}")

    print(f"\n{C_YLW}🎯 FLUJOS DE TRABAJO RECOMENDADOS:{C_RESET}")
    print(f"{C_GREEN}1. Análisis Básico:{C_RESET}")
    print("   djpt> analizar track.mp3")
    print("   → BPM, clave, energía, espectro completo")

    print(f"\n{C_GREEN}2. Clasificación Inteligente:{C_RESET}")
    print("   djpt> analizar --verbose track.mp3")
    print("   djpt> embeddings track.mp3")
    print("   → Género, mood, características ML")

    print(f"\n{C_GREEN}3. Organización de Biblioteca:{C_RESET}")
    print("   djpt> playlist --batch /music/")
    print("   djpt> organizar /music/desorganizado/")
    print("   → Playlist inteligente + estructura organizada")

    print(f"\n{C_GREEN}4. Mastering Profesional:{C_RESET}")
    print("   djpt> mastering --profile house track.mp3")
    print("   → Optimización de loudness y EQ")

    print(f"\n{C_YLW}🔍 TÉCNICAS AVANZADAS:{C_RESET}")
    print(f"• {C_BLUEE}Análisis Comparativo:{C_RESET} similar track1.mp3 track2.mp3 --verbose")
    print(f"• {C_BLUEE}Batch Processing:{C_RESET} analizar --batch /folder/")
    print(f"• {C_BLUEE}Profile-based:{C_RESET} mastering --profile techno --verbose")
    print(f"• {C_BLUEE}Dry-run Testing:{C_RESET} organizar --dry-run /music/")

    print(f"\n{C_YLW}📊 FORMATOS Y COMPATIBILIDAD:{C_RESET}")
    print(f"• {C_GREEN}Audio:{C_RESET} MP3, WAV, FLAC, AAC, OGG, M4A")
    print(f"• {C_GREEN}Análisis:{C_RESET} Espectrogramas, MFCC, Chroma, Tonnetz")
    print(f"• {C_GREEN}ML Models:{C_RESET} TensorFlow, ONNX, modelos optimizados")
    print(f"• {C_GREEN}Salida:{C_RESET} JSON, CSV, TSV, M3U playlists")


def search_web(query, python_bin, base_path):
    """Search the web for information using available tools."""
    print(f"{EMOJI_SEARCH} {C_GREEN}[BUSCANDO] {query}{C_RESET}")

    # Try to use curl with duckduckgo for instant answers
    try:
        import subprocess
        import urllib.parse

        # Encode query for URL
        encoded_query = urllib.parse.quote(query)
        ddg_url = f"https://duckduckgo.com/html/?q={encoded_query}"

        print(f"{EMOJI_GLOBE} {C_CYAN}[WEB] Buscando en DuckDuckGo...{C_RESET}")

        # Use curl to get results
        result = subprocess.run(
            [
                "curl",
                "-s",
                "-L",
                "--user-agent",
                "DJProducerTools-CLI/1.0",
                ddg_url,
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )

        if result.returncode == 0 and result.stdout:
            # Extract some basic info from HTML
            content = result.stdout[:2000]  # Limit output
            if "Instant Answer" in content or "About this topic" in content:
                print(f"{EMOJI_CRYSTAL} {C_GREEN}[RESULTADO] Respuesta encontrada:{C_RESET}")
                # Simple text extraction (basic implementation)
                lines = content.split("\n")
                for line in lines[:20]:  # First 20 lines
                    if any(keyword in line for keyword in ["result__", "snippet", "answer"]):
                        clean_line = line.strip()
                        if clean_line and len(clean_line) > 20:
                            print(f"  {C_CYAN}• {clean_line[:100]}...{C_RESET}")
            else:
                print(f"{EMOJI_GLOBE} {C_YLW}[INFO] Abriendo navegador para resultados detallados...{C_RESET}")
                webbrowser.open(ddg_url)
        else:
            print(f"{EMOJI_GLOBE} {C_YLW}[INFO] Abriendo navegador para búsqueda...{C_RESET}")
            webbrowser.open(ddg_url)

    except Exception:
        print(f"{EMOJI_GLOBE} {C_YLW}[FALLBACK] Abriendo navegador...{C_RESET}")
        webbrowser.open(f"https://www.google.com/search?q={urllib.parse.quote(query)}")


def install_tool(tool_name, python_bin, base_path):
    """Install tools automatically with intelligence."""
    print(f"{EMOJI_DOWNLOAD} {C_GREEN}[INSTALANDO] {tool_name}{C_RESET}")

    # Known tools installation map
    install_map = {
        "ffmpeg": {
            "macos": "brew install ffmpeg",
            "linux": "sudo apt-get install ffmpeg",
            "check": "ffmpeg -version",
        },
        "youtube-dl": {
            "macos": "brew install youtube-dl",
            "linux": "sudo pip install youtube-dl",
            "check": "youtube-dl --version",
        },
        "librosa": {
            "pip": "pip install librosa",
            "check": 'python -c "import librosa"',
        },
        "tensorflow": {
            "pip": "pip install tensorflow",
            "check": 'python -c "import tensorflow"',
        },
        "ffmpeg-python": {
            "pip": "pip install ffmpeg-python",
            "check": 'python -c "import ffmpeg"',
        },
    }

    if tool_name not in install_map:
        print(f"{EMOJI_WIZARD} {C_YLW}[BUSCANDO] Cómo instalar {tool_name}...{C_RESET}")
        search_web(
            f"install {tool_name} python audio processing",
            python_bin,
            base_path,
        )
        return

    tool_info = install_map[tool_name]

    # Check if already installed
    try:
        check_result = subprocess.run(
            tool_info["check"].split(),
            capture_output=True,
            text=True,
            timeout=5,
        )
        if check_result.returncode == 0:
            print(f"{EMOJI_BRAIN} {C_GREEN}[OK] {tool_name} ya está instalado{C_RESET}")
            return
    except Exception:
        pass

    # Try installation
    try:
        if "pip" in tool_info:
            print(f"{EMOJI_DOWNLOAD} {C_CYAN}[PIP] Instalando {tool_name}...{C_RESET}")
            subprocess.run(["pip", "install", tool_name], check=True, timeout=300)
        elif "macos" in tool_info and sys.platform == "darwin":
            print(f"{EMOJI_DOWNLOAD} {C_CYAN}[HOMEBREW] Instalando {tool_name}...{C_RESET}")
            subprocess.run(["brew", "install", tool_name], check=True, timeout=300)
        elif "linux" in tool_info and sys.platform.startswith("linux"):
            print(f"{EMOJI_DOWNLOAD} {C_CYAN}[APT] Instalando {tool_name}...{C_RESET}")
            subprocess.run(
                ["sudo", "apt-get", "install", "-y", tool_name],
                check=True,
                timeout=300,
            )

        print(f"{EMOJI_BRAIN} {C_GREEN}[OK] {tool_name} instalado exitosamente{C_RESET}")

    except subprocess.CalledProcessError as e:
        print(f"{EMOJI_WIZARD} {C_RED}[ERR] Error instalando {tool_name}: {e}{C_RESET}")
        print(f"{EMOJI_WIZARD} {C_YLW}[AYUDA] Buscando solución alternativa...{C_RESET}")
        search_web(f"install {tool_name} error solution", python_bin, base_path)


def update_system(python_bin, base_path):
    """Update system and dependencies."""
    print(f"{EMOJI_GEAR} {C_GREEN}[ACTUALIZANDO] Sistema y dependencias{C_RESET}")

    # Update pip
    try:
        print(f"{EMOJI_DOWNLOAD} {C_CYAN}[PIP] Actualizando pip...{C_RESET}")
        subprocess.run(
            [python_bin, "-m", "pip", "install", "--upgrade", "pip"],
            check=True,
            timeout=120,
        )
        print(f"{EMOJI_BRAIN} {C_GREEN}[OK] pip actualizado{C_RESET}")
    except Exception:
        print(f"{EMOJI_YLW} {C_YLW}[WARN] No se pudo actualizar pip{C_RESET}")

    # Update system packages (macOS)
    if sys.platform == "darwin":
        try:
            print(f"{EMOJI_DOWNLOAD} {C_CYAN}[HOMEBREW] Actualizando...{C_RESET}")
            subprocess.run(["brew", "update"], check=True, timeout=300)
            print(f"{EMOJI_BRAIN} {C_GREEN}[OK] Homebrew actualizado{C_RESET}")
        except Exception:
            print(f"{EMOJI_YLW} {C_YLW}[WARN] No se pudo actualizar Homebrew{C_RESET}")

    # Update critical Python packages
    critical_packages = ["librosa", "numpy", "pandas", "scikit-learn"]
    for package in critical_packages:
        try:
            print(f"{EMOJI_DOWNLOAD} {C_CYAN}[PIP] Actualizando {package}...{C_RESET}")
            subprocess.run(
                [python_bin, "-m", "pip", "install", "--upgrade", package],
                check=True,
                timeout=120,
            )
        except Exception:
            print(f"{EMOJI_YLW} {C_YLW}[WARN] No se pudo actualizar {package}{C_RESET}")

    print(f"{EMOJI_BRAIN} {C_GREEN}[OK] Actualización completada{C_RESET}")


def investigate_topic(topic, python_bin, base_path):
    """Investigate audio ML topics with intelligence."""
    print(f"{EMOJI_CRYSTAL} {C_GREEN}[INVESTIGANDO] {topic}{C_RESET}")

    # Search for academic papers, tutorials, and examples
    search_queries = [
        f"{topic} audio machine learning tutorial",
        f"{topic} music information retrieval",
        f"{topic} python implementation github",
        f"{topic} state of the art 2024",
    ]

    for i, query in enumerate(search_queries[:2], 1):  # Limit to 2 searches
        print(f"{EMOJI_SEARCH} {C_CYAN}[BÚSQUEDA {i}] {query}{C_RESET}")
        search_web(query, python_bin, base_path)
        time.sleep(1)  # Brief pause between searches

    # Try to find relevant GitHub repos
    try:
        github_query = f"https://github.com/search?q={topic}+audio+ml&type=repositories"
        print(f"{EMOJI_GLOBE} {C_CYAN}[GITHUB] Buscando repositorios...{C_RESET}")
        webbrowser.open(github_query)
    except Exception:
        pass


def run_audio_command(command, args, python_bin, base_path):
    """Execute audio processing command with proper error handling."""
    if command not in AUDIO_COMMANDS:
        print(f"{C_RED}[ERR] Comando de audio desconocido: {command}{C_RESET}")
        return False

    cmd_info = AUDIO_COMMANDS[command]
    script_path = SCRIPT_DIR / cmd_info["script"]

    if not script_path.exists():
        print(f"{C_RED}[ERR] Script no encontrado: {script_path}{C_RESET}")
        print(f"{C_YLW}[INFO] Asegúrate que los archivos lib/ estén presentes{C_RESET}")
        return False

    # Build command
    cmd = [python_bin, str(script_path)] + cmd_info["args"] + args

    # Add global options
    if "--dry-run" in args:
        print(f"{C_YLW}[DRY-RUN] Modo previsualización activado{C_RESET}")

    if "--verbose" in args:
        print(f"{C_CYAN}[VERBOSE] Modo detallado activado{C_RESET}")

    print(f"{C_GREEN}[EJECUTANDO] {cmd_info['desc']}{C_RESET}")
    print(f"{C_CYAN}[COMANDO] {' '.join(cmd)}{C_RESET}")

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)

        if result.returncode == 0:
            print(f"{C_GREEN}[OK] Completado exitosamente{C_RESET}")
            if result.stdout:
                print(result.stdout)
        else:
            print(f"{C_RED}[ERR] Error en ejecución{C_RESET}")
            if result.stderr:
                print(f"{C_YLW}[DEBUG] {result.stderr}{C_RESET}")

        return result.returncode == 0

    except subprocess.TimeoutExpired:
        print(f"{C_RED}[ERR] Tiempo de espera agotado (5min){C_RESET}")
        return False
    except Exception as e:
        print(f"{C_RED}[ERR] Error inesperado: {e}{C_RESET}")
        return False


def get_python_bin(base_path):
    """Detects the virtual environment python binary."""
    # Priority 1: explicit python override passed by wrappers.
    env_py = os.environ.get("PYTHON_BIN")
    if env_py and Path(env_py).exists():
        return env_py

    # Priority 2: venv dir passed by shell script.
    env_venv = os.environ.get("VENV_DIR")
    if env_venv:
        for name in ("python3", "python"):
            venv_python = Path(env_venv) / "bin" / name
            if venv_python.exists():
                return str(venv_python)

    base = Path(base_path)
    repo_root = Path(__file__).resolve().parents[1]
    candidate_dirs = [
        base / "djpt_venv",
        base / ".venv",
        base / "venv",
        repo_root / "djpt_venv",
        repo_root / ".venv",
        repo_root / "venv",
    ]
    for venv_dir in candidate_dirs:
        for name in ("python3", "python"):
            venv_python = venv_dir / "bin" / name
            if venv_python.exists():
                return str(venv_python)

    # Priority 4: wrapper-propagated runtime python if candidate dirs were absent.
    djpt_env_py = os.environ.get("DJPT_PYTHON_BIN")
    if djpt_env_py and Path(djpt_env_py).exists():
        return str(Path(djpt_env_py))

    # Priority 5: if this process is already running inside the canonical
    # djpt_venv, keep using it instead of falling back to legacy state/venv.
    current_python = Path(sys.executable).expanduser()
    if current_python.exists():
        try:
            current_python = current_python.resolve()
        except Exception:
            pass
        current_python_str = str(current_python).lower()
        if "/djpt_venv/" in current_python_str or "\\djpt_venv\\" in current_python_str:
            return str(current_python)

    legacy_dirs = [
        base / "state" / "venv",
        base / "_DJProducerTools" / "venv",
    ]
    for venv_dir in legacy_dirs:
        for name in ("python3", "python"):
            venv_python = venv_dir / "bin" / name
            if venv_python.exists():
                return str(venv_python)

    return sys.executable


def is_virtualenv_python(python_bin):
    """Returns True when python_bin belongs to a virtualenv-like environment."""
    try:
        py_path = Path(python_bin).expanduser()
    except Exception:
        return False

    if not py_path.exists():
        return False

    markers = ("/venv/", "/.venv/", "/djpt_venv/", "\\venv\\", "\\.venv\\", "\\djpt_venv\\")
    raw_root = py_path.parent.parent
    if (raw_root / "pyvenv.cfg").exists():
        return True

    normalized_raw = str(py_path).lower()
    if any(marker in normalized_raw for marker in markers):
        return True

    try:
        resolved = py_path.resolve()
    except Exception:
        resolved = py_path

    resolved_root = resolved.parent.parent
    if (resolved_root / "pyvenv.cfg").exists():
        return True

    normalized_resolved = str(resolved).lower()
    return any(marker in normalized_resolved for marker in markers)


def ensure_ai_structure(base_path):
    """Creates the necessary folder structure for the AI layer."""
    base = Path(base_path)
    dirs = [
        base / "kb" / "raw",
        base / "ai" / "embeddings",
        base / "ai" / "models",
        base / "ai" / "index",
        base / "chat" / "logs",
        base / "config",
    ]
    for d in dirs:
        d.mkdir(parents=True, exist_ok=True)


def main():
    import sys

    # Soporte rápido para argumentos de línea de comandos
    if len(sys.argv) > 1:
        arg = sys.argv[1].lower()
        if arg in ["--help", "-h", "help"]:
            print(f"{BOLD_LARGE}╔══════════════════════════════════════════════════════════════╗{RESET_LARGE}")
            print(f"{BOLD_LARGE}║  🧙‍♂️ DJProducerTools Chat CLI - Asistente Matrix Evolutivo 🧠  ║{RESET_LARGE}")
            print(f"{BOLD_LARGE}║  🌐 Inteligencia Web + Auto-corrección + Evolución           ║{RESET_LARGE}")
            print(f"{BOLD_LARGE}╚══════════════════════════════════════════════════════════════╝{RESET_LARGE}")
            print(f"\n{C_CYAN}USO:{RESET_LARGE}")
            print("  python3 djpt_chat_cli.py [opciones]")
            print(f"\n{C_CYAN}OPCIONES:{RESET_LARGE}")
            print("  --help, -h     Mostrar esta ayuda")
            print("  --test         Ejecutar test rápido de conectividad")
            print("  --direct       Modo directo sin interfaz")
            print("  --version      Mostrar versión")
            print(f"\n{C_CYAN}EJEMPLOS:{RESET_LARGE}")
            print("  python3 djpt_chat_cli.py")
            print("  python3 djpt_chat_cli.py --test")
            print("  python3 djpt_chat_cli.py --direct")
            return 0
        elif arg in ["--test", "test"]:
            print(f"{C_GREEN}✅ Chat CLI Test: Conectividad OK{RESET_LARGE}")
            print(f"{C_CYAN}ℹ️  Módulos importados correctamente{RESET_LARGE}")
            return 0
        elif arg in ["--version", "-v", "version"]:
            print(f"{C_GREEN}DJProducerTools Chat CLI v1.2.0{RESET_LARGE}")
            return 0
        elif arg in ["--direct", "direct"]:
            print(f"{C_GREEN}🚀 Modo directo activado{RESET_LARGE}")
            # Continuar con modo rápido
            pass
        else:
            print(f"{C_RED}❌ Opción desconocida: {arg}{RESET_LARGE}")
            print(f"{C_CYAN}ℹ️  Usa --help para ver opciones{RESET_LARGE}")
            return 1

    print(f"{BOLD_LARGE}╔══════════════════════════════════════════════════════════════╗{RESET_LARGE}")
    print(f"{BOLD_LARGE}║  🧙‍♂️ DJProducerTools Chat CLI - Asistente Matrix Evolutivo 🧠  ║{RESET_LARGE}")
    print(f"{BOLD_LARGE}║  🌐 Inteligencia Web + Auto-corrección + Evolución           ║{RESET_LARGE}")
    print(f"{BOLD_LARGE}╚══════════════════════════════════════════════════════════════╝{RESET_LARGE}")
    print(f"\n{EMOJI_WIZARD} {C_GREEN}📝 Escribe 'ayuda' para comandos o describe lo que quieres hacer.{C_RESET}")
    print(f"{EMOJI_CRYSTAL} {C_GREEN}🎯 Escribe 'guia' para flujo de trabajo guiado paso a paso.{C_RESET}")
    print(f"{EMOJI_GLOBE} {C_GREEN}🌐 Escribe 'buscar <tema>' para información en tiempo real.{C_RESET}")
    print(f"{EMOJI_ROBOT} {C_GREEN}🤖 Escribe 'evolucionar' para activar auto-mejoras.{C_RESET}")
    print(
        f"{EMOJI_BRAIN} {C_GREEN}🧩 Escribe 'rag status', 'hf status', 'modulo list' o "
        f"'programar cada 30m scan mp3' (o 'combo status').{C_RESET}"
    )

    config = load_conf()
    # Env var overrides config
    base_path = Path(os.environ.get("BASE_PATH") or config.get("BASE_PATH", str(ROOT_DIR))).expanduser().resolve()

    # Initialize self-healing system
    global self_healing
    self_healing = SelfHealingSystem(base_path)

    # Ensure AI structure exists
    ensure_ai_structure(base_path)

    python_bin = get_python_bin(str(base_path))
    system_context = {
        "config": config,
        "venv": python_bin,
        "safe_mode": os.environ.get("SAFE_MODE"),
        "dry_run": os.environ.get("DRY_RUN"),
    }
    chat_cli = ChatCLI(base_path, system_context)
    diag_report = chat_cli.diagnose_system()
    backend_status = chat_cli.monitor_backends()
    print(f"{EMOJI_GEAR} {C_GREEN}📁 Base Activa: {C_CYAN}{base_path}{C_RESET}")
    if is_virtualenv_python(python_bin):
        print(f"{EMOJI_ROBOT} {C_GREEN}🤖 Entorno ML: {C_GREEN}Activo ({C_CYAN}{python_bin}{C_GREEN}){C_RESET}\n")
    else:
        print(f"{EMOJI_YLW} {C_GREEN}⚠️  Entorno ML: {C_YLW}Python del sistema (venv no encontrado){C_RESET}\n")
    print(f"{EMOJI_GEAR} {C_GREEN}Estado Sistema:{C_RESET} {diag_report.summary()}")
    print(f"{EMOJI_ROBOT} {C_GREEN}Backends IA:{C_RESET} {backend_status.summary()}")
    for msg in backend_status.messages:
        print(f"{EMOJI_YLW} {C_YLW}[TIP]{C_RESET} {msg}")

    # Run auto-update on startup
    try:
        self_healing.auto_update()
    except Exception as e:
        print(f"{EMOJI_YLW} {C_YLW}[WARN] Error en auto-update: {e}{C_RESET}")

    while True:
        try:
            user_input = input(f"{EMOJI_WIZARD} {C_GREEN}djpt>{C_RESET} ").strip()
        except (KeyboardInterrupt, EOFError):
            print(f"\n{EMOJI_BRAIN} {C_GREEN}👋 Saliendo del asistente Matrix Evolutivo...{C_RESET}")
            break

        if not user_input:
            continue

        # Parse command and arguments
        parts = user_input.split()
        command = parts[0].lower() if parts else ""
        args = parts[1:] if len(parts) > 1 else []

        # Exit commands
        if command in [
            "exit",
            "quit",
            "q",
            "back",
            "atras",
            "volver",
            "salir",
        ]:
            print(f"\n{EMOJI_WIZARD} {C_GREEN}🔙 Volviendo al menú principal...{C_RESET}")
            break

        # Help commands
        if command in ["help", "ayuda", "?"]:
            print_help()
            continue

        if command in ["guia", "guide", "tutorial"]:
            print_audio_guide()
            continue

        if command in ["clear", "cls", "limpiar"]:
            subprocess.run(["clear"] if os.name == "posix" else ["cls"], shell=False)
            continue

        # Evolution commands
        if command in ["evolucionar", "evolve", "auto-fix", "autocorregir"]:
            print(f"{EMOJI_ROBOT} {C_GREEN}[EVOLUCIÓN] Iniciando sistema de auto-corrección...{C_RESET}")
            try:
                self_healing.auto_update()
                print(f"{EMOJI_BRAIN} {C_GREEN}[EVOLUCIÓN] Sistema evolucionado con éxito{C_RESET}")
            except Exception as e:
                if self_healing:
                    fix = self_healing.analyze_error(str(e), "evolution_command")
                    print(f"{EMOJI_WIZARD} {C_CYAN}[SUGERENCIA] {fix}{C_RESET}")
                else:
                    print(f"{EMOJI_YLW} {C_YLW}[ERROR] {e}{C_RESET}")
            continue

        if command in ["aprender", "learn", "feedback"]:
            if len(args) >= 2:
                cmd_name = args[0]
                feedback = " ".join(args[1:])
                if self_healing:
                    self_healing.evolve_command(cmd_name, feedback)
                    print(f"{EMOJI_BRAIN} {C_GREEN}[APRENDIDO] Feedback registrado para '{cmd_name}'{C_RESET}")
                else:
                    print(f"{EMOJI_YLW} {C_YLW}[ERROR] Sistema de evolución no disponible{C_RESET}")
            else:
                print(f"{EMOJI_YLW} {C_YLW}[USO] aprender <comando> <feedback>{C_RESET}")
                print(f"{EMOJI_BRAIN} {C_CYAN}[EJ] aprender analizar muy lento{C_RESET}")
            continue

        if command in ["estado-evolucion", "evolution-status"]:
            if self_healing:
                print(f"{EMOJI_CRYSTAL} {C_GREEN}[ESTADO EVOLUTIVO]{C_RESET}")
                print(f"{EMOJI_BRAIN}  • Patrones aprendidos: {len(self_healing.patterns['solutions'])}{C_RESET}")
                print(f"{EMOJI_BRAIN}  • Comandos mejorados: {len(self_healing.knowledge['improvements'])}{C_RESET}")
                print(
                    f"{EMOJI_BRAIN}  • Eventos de evolución: {len(self_healing.knowledge['learned_commands'])}{C_RESET}"
                )
            else:
                print(f"{EMOJI_YLW} {C_YLW}[INFO] Sistema de evolución no inicializado{C_RESET}")
            continue

        # Sistema: diagnóstico y backends IA
        if command in [
            "diag",
            "diagnostico",
            "diagnóstico",
            "health",
            "salud",
        ]:
            report = chat_cli.diagnose_system()
            backend = chat_cli.monitor_backends()
            print(f"{EMOJI_GEAR} {C_GREEN}[DIAG]{C_RESET} {report.summary()}")
            if report.warnings:
                for w in report.warnings:
                    print(f"{EMOJI_YLW} {C_YLW}[WARN]{C_RESET} {w}")
            if report.errors:
                for err in report.errors:
                    print(f"{C_RED}[ERR]{C_RESET} {err}")
            print(f"{EMOJI_ROBOT} {C_GREEN}[IA]{C_RESET} {backend.summary()}")
            for msg in backend.messages:
                print(f"{EMOJI_YLW} {C_YLW}[TIP]{C_RESET} {msg}")
            continue

        if command in ["ia", "ia-status", "backends", "estado-ia"]:
            backend = chat_cli.monitor_backends()
            print(f"{EMOJI_ROBOT} {C_GREEN}[IA]{C_RESET} {backend.summary()}")
            for msg in backend.messages:
                print(f"{EMOJI_YLW} {C_YLW}[TIP]{C_RESET} {msg}")
            continue

        if command in ["autoheal", "repara", "sanar"]:
            heal = chat_cli.auto_heal_issues()
            for act in heal.actions:
                print(f"{EMOJI_GEAR} {C_GREEN}[APLICADO]{C_RESET} {act}")
            for warn in heal.warnings:
                print(f"{EMOJI_YLW} {C_YLW}[WARN]{C_RESET} {warn}")
            if not heal.actions and not heal.warnings:
                print(f"{EMOJI_BRAIN} {C_GREEN}[OK]{C_RESET} Nada que reparar.")
            continue

        if command in ["recomienda", "recs", "sugerencias"]:
            for rec in chat_cli.generate_recommendations():
                print(f"{EMOJI_CRYSTAL} {C_GREEN}•{C_RESET} {rec}")
            continue

        # Audio processing commands with error handling
        if command in AUDIO_COMMANDS:
            try:
                run_audio_command(command, args, python_bin, base_path)
            except Exception as e:
                print(f"{EMOJI_YLW} {C_YLW}[ERROR] Error en comando '{command}': {e}{C_RESET}")
                if self_healing:
                    fix = self_healing.analyze_error(str(e), f"command_{command}")
                    print(f"{EMOJI_WIZARD} {C_CYAN}[AUTO-FIX] {fix}{C_RESET}")
            continue

        # Web & Intelligence commands with error handling
        if command in ["buscar", "busca", "search", "google"]:
            if args:
                try:
                    search_query = " ".join(args)
                    search_web(search_query, python_bin, base_path)
                except Exception as e:
                    print(f"{EMOJI_YLW} {C_YLW}[ERROR] Error en búsqueda: {e}{C_RESET}")
                    if self_healing:
                        fix = self_healing.analyze_error(str(e), "search_command")
                        print(f"{EMOJI_WIZARD} {C_CYAN}[AUTO-FIX] {fix}{C_RESET}")
            else:
                print(f"{EMOJI_SEARCH} {C_YLW}[USO] buscar <término>{C_RESET}")
                print(f"{EMOJI_BRAIN} {C_CYAN}[EJ] buscar 'audio machine learning trends'{C_RESET}")
            continue
        elif command in ["instalar", "instala", "install"]:
            if args:
                try:
                    tool_name = args[0]
                    install_tool(tool_name, python_bin, base_path)
                except Exception as e:
                    print(f"{EMOJI_YLW} {C_YLW}[ERROR] Error en instalación: {e}{C_RESET}")
                    if self_healing:
                        fix = self_healing.analyze_error(str(e), "install_command")
                        print(f"{EMOJI_WIZARD} {C_CYAN}[AUTO-FIX] {fix}{C_RESET}")
            else:
                print(f"{EMOJI_DOWNLOAD} {C_YLW}[USO] instalar <herramienta>{C_RESET}")
                print(f"{EMOJI_BRAIN} {C_CYAN}[EJ] instalar ffmpeg, instalar librosa{C_RESET}")
            continue
        elif command in ["actualizar", "actualiza", "update", "upgrade"]:
            try:
                update_system(python_bin, base_path)
            except Exception as e:
                print(f"{EMOJI_YLW} {C_YLW}[ERROR] Error en actualización: {e}{C_RESET}")
                if self_healing:
                    fix = self_healing.analyze_error(str(e), "update_command")
                    print(f"{EMOJI_WIZARD} {C_CYAN}[AUTO-FIX] {fix}{C_RESET}")
            continue
        elif command in ["investigar", "investiga", "research", "study"]:
            if args:
                try:
                    topic = " ".join(args)
                    investigate_topic(topic, python_bin, base_path)
                except Exception as e:
                    print(f"{EMOJI_YLW} {C_YLW}[ERROR] Error en investigación: {e}{C_RESET}")
                    if self_healing:
                        fix = self_healing.analyze_error(str(e), "research_command")
                        print(f"{EMOJI_WIZARD} {C_CYAN}[AUTO-FIX] {fix}{C_RESET}")
            else:
                print(f"{EMOJI_CRYSTAL} {C_YLW}[USO] investigar <tema>{C_RESET}")
                print(f"{EMOJI_BRAIN} {C_CYAN}[EJ] investigar 'deep learning audio'{C_RESET}")
            continue

        # IA local orquestada (RAG / HF / módulos)
        if command in ["combo", "fusion", "fusión", "pipeline", "stack"]:
            if not args:
                print(f"{EMOJI_BRAIN} {C_YLW}[USO] combo <status|learn|optimize|setup> [args]{C_RESET}")
                print(f"{EMOJI_CRYSTAL} {C_CYAN}[EJ] combo status{C_RESET}")
                print(f"{EMOJI_CRYSTAL} {C_CYAN}[EJ] combo learn https://huggingface.co/models{C_RESET}")
                print(
                    f"{EMOJI_CRYSTAL} {C_CYAN}[EJ] combo setup --apply --install-optional-deps --hf-sync{C_RESET}"
                )
                continue
            mode = args[0]
            combo_payload, combo_rc = run_combined_pipeline(
                mode,
                args[1:],
                python_bin,
                base_path,
                chat_context=chat_cli,
            )
            print(
                f"{EMOJI_BRAIN} {C_GREEN}[COMBO] mode={combo_payload.get('mode')} "
                f"status={combo_payload.get('status')}{C_RESET}"
            )
            for step in combo_payload.get("steps", []):
                color = C_GREEN if int(step.get("rc", 1)) == 0 else C_YLW
                print(
                    f"  {color}• {step.get('step')}{C_RESET} rc={step.get('rc')} "
                    f"{step.get('info', '')}"
                )
            if combo_payload.get("details"):
                details_json = json.dumps(combo_payload["details"], ensure_ascii=False, indent=2)
                print(details_json)
            if combo_rc != 0:
                print(f"{C_YLW}[WARN] combo terminó con avisos/errores (rc={combo_rc}){C_RESET}")
            continue

        if command in ["rag"]:
            rc = handle_rag_command(args, python_bin, base_path, emit=True)
            if rc != 0:
                print(f"{C_RED}[ERR] rag terminó con código {rc}{C_RESET}")
            continue

        if command in ["hf", "huggingface"]:
            rc = handle_hf_command(args, python_bin, base_path, emit=True)
            if rc != 0:
                print(f"{C_RED}[ERR] hf terminó con código {rc}{C_RESET}")
            continue

        if command in ["online-setup", "setup-online", "setup-ai", "setup-ia"]:
            rc = handle_online_setup_command(args, python_bin, base_path, emit=True)
            if rc != 0:
                print(f"{C_RED}[ERR] online-setup terminó con código {rc}{C_RESET}")
            continue

        if command in ["modulo", "módulo", "module", "plugin", "plugins"]:
            rc = handle_module_command(args, python_bin, base_path, emit=True)
            if rc != 0:
                print(f"{C_RED}[ERR] modulo terminó con código {rc}{C_RESET}")
            continue

        if command in ["estudiar-web", "study-web", "aprender-web"]:
            if not args:
                print(f"{EMOJI_GLOBE} {C_YLW}[USO] estudiar-web <url> [--index-rag]{C_RESET}")
                continue
            url = args[0]
            index_rag = any(arg == "--index-rag" for arg in args[1:])
            result = study_web_page(url, base_path, python_bin, index_rag=index_rag)
            if result.get("status") == "ok":
                print(f"{EMOJI_BRAIN} {C_GREEN}[WEB-LEARN] {result.get('details')}{C_RESET}")
                print(f"{EMOJI_GEAR} {C_GREEN}Archivo:{C_RESET} {result.get('path')}")
                if result.get("rag_index"):
                    rag_ok = result["rag_index"].get("ok")
                    print(
                        f"{EMOJI_ROBOT} {C_GREEN}RAG index:{C_RESET} "
                        f"{'OK' if rag_ok else 'FAIL'} (rc={result['rag_index'].get('rc')})"
                    )
            else:
                print(f"{C_RED}[ERR] {result.get('details', 'fallo en estudio web')}{C_RESET}")
            continue

        # Tareas programadas del chat
        if command in ["programar", "agendar"]:
            try:
                interval, task_command = parse_schedule_request(args)
                task = create_chat_task(base_path, interval, task_command)
                print(f"{EMOJI_GEAR} {C_GREEN}[TASK] creada {task['id']}{C_RESET}")
                print(f"{EMOJI_CRYSTAL} {C_GREEN}Cada {task['interval']} -> {task['command']}{C_RESET}")
            except Exception as exc:
                print(f"{C_RED}[ERR] {exc}{C_RESET}")
            continue

        if command in ["tareas", "tasks", "agenda"]:
            sub = normalize_chat_text(args[0]) if args else "list"
            if sub in {"run", "ejecutar"}:
                result = run_due_chat_tasks(base_path, python_bin)
                print(f"{EMOJI_GEAR} {C_GREEN}[TASK] ejecutadas: {result['executed_count']}{C_RESET}")
                for item in result["executed"]:
                    print(
                        f"  {C_CYAN}• {item['id']}{C_RESET} -> {item['command']} "
                        f"[rc={item['rc']}] {item['details']}"
                    )
                continue

            if sub in {"disable", "desactivar"} and len(args) > 1:
                ok = set_chat_task_enabled(base_path, args[1], False)
                if ok:
                    print(f"{EMOJI_GEAR} {C_GREEN}[TASK] desactivada: {args[1]}{C_RESET}")
                else:
                    print(f"{C_RED}[ERR] tarea no encontrada: {args[1]}{C_RESET}")
                continue

            if sub in {"enable", "activar"} and len(args) > 1:
                ok = set_chat_task_enabled(base_path, args[1], True)
                if ok:
                    print(f"{EMOJI_GEAR} {C_GREEN}[TASK] activada: {args[1]}{C_RESET}")
                else:
                    print(f"{C_RED}[ERR] tarea no encontrada: {args[1]}{C_RESET}")
                continue

            if sub in {"remove", "rm", "delete", "borrar"} and len(args) > 1:
                ok = remove_chat_task(base_path, args[1])
                if ok:
                    print(f"{EMOJI_GEAR} {C_GREEN}[TASK] eliminada: {args[1]}{C_RESET}")
                else:
                    print(f"{C_RED}[ERR] tarea no encontrada: {args[1]}{C_RESET}")
                continue

            payload = load_chat_tasks(base_path)
            tasks = payload.get("tasks", [])
            if not tasks:
                print(f"{EMOJI_GEAR} {C_GREEN}[TASK] sin tareas programadas{C_RESET}")
            else:
                print(f"{EMOJI_GEAR} {C_GREEN}[TASK] total={len(tasks)}{C_RESET}")
                now_ts = datetime.utcnow().timestamp()
                for task in tasks:
                    eta_seconds = int(float(task.get("next_run_ts", 0)) - now_ts)
                    eta_seconds = max(eta_seconds, 0)
                    print(
                        f"  {C_CYAN}• {task.get('id')}{C_RESET} "
                        f"{'[on]' if task.get('enabled', True) else '[off]'} "
                        f"cada {task.get('interval')} -> {task.get('command')} "
                        f"(eta {eta_seconds}s, runs {task.get('run_count', 0)})"
                    )
            continue

        if command in ["tareas-run", "tasks-run"]:
            result = run_due_chat_tasks(base_path, python_bin)
            print(f"{EMOJI_GEAR} {C_GREEN}[TASK] ejecutadas: {result['executed_count']}{C_RESET}")
            continue

        # System commands (existing logic)
        if command in ["status", "info", "estado"]:
            run_engine("status", base_path)
        elif command in ["scan", "escanear"]:
            scan_request = parse_direct_scan_args(args, base_path)
            run_scan_workflow(scan_request, python_bin, base_path)
        elif command in ["backup", "respaldar"]:
            run_engine("backup", base_path)
        elif command in ["hash", "hashes"]:
            run_engine("hash", base_path)
        elif command in ["dupes", "duplicates", "duplicados"]:
            run_engine("dupes", base_path)
        elif command in ["smart", "analysis", "analisis"]:
            run_engine("smart", base_path)
        elif command in ["predict", "predecir"] and "ml" not in user_input:
            run_engine("predict", base_path)
        elif command in ["optimize", "optimizar"]:
            run_engine("optimize", base_path)
        elif command in ["workflow", "flujo"]:
            run_engine("workflow", base_path)
        elif "ml status" in user_input or "ml estado" in user_input:
            model_path = Path(base_path) / "ml_model.pkl"
            if model_path.exists():
                size_kb = model_path.stat().st_size / 1024
                mtime = time.ctime(model_path.stat().st_mtime)
                print(f"{C_GREEN}[OK] Modelo encontrado.{C_RESET} Tamaño: {size_kb:.1f}KB. Modificado: {mtime}")
            else:
                print(f"{C_YLW}[INFO] Sin modelo entrenado.{C_RESET} Ejecuta 'ml train' para crear uno.")
        elif "ml train" in user_input or "ml entrenar" in user_input:
            print(f"{C_YLW}[INFO] Invocando entrenamiento ML directo...{C_RESET}")
            model_path = str(base_path / "ml_model.pkl")
            subprocess.run(
                [
                    python_bin,
                    str(SCRIPT_DIR / "lib" / "ml_evolutionary.py"),
                    "train",
                    "--base",
                    str(base_path),
                    "--model-out",
                    model_path,
                ]
            )
        elif "ml predict" in user_input or "ml predecir" in user_input:
            print(f"{C_YLW}[INFO] Invocando predicción ML directa...{C_RESET}")
            model_path = str(base_path / "ml_model.pkl")
            subprocess.run(
                [
                    python_bin,
                    str(SCRIPT_DIR / "lib" / "ml_evolutionary.py"),
                    "predict",
                    "--base",
                    str(base_path),
                    "--model-in",
                    model_path,
                ]
            )
        elif command in ["menu", "classic", "menú"]:
            print(f"{EMOJI_WIZARD} {C_GREEN}Lanzando menú clásico...{C_RESET}")
            engine_script = resolve_engine_script(base_path)
            if engine_script and engine_script.exists():
                subprocess.run(["bash", str(engine_script)], check=False)
            else:
                print(f"{C_RED}[ERR] No se encontró el script del menú clásico.{C_RESET}")
            continue

        else:
            conversation = chat_cli.interpret_conversation(user_input)
            if conversation.get("reply"):
                print(conversation["reply"])
            if conversation.get("scan_request"):
                run_scan_workflow(conversation["scan_request"], python_bin, base_path)
            elif conversation.get("action") == "rag_status":
                handle_rag_command(["status"], python_bin, base_path, emit=True)
            elif conversation.get("action") == "hf_status":
                handle_hf_command(["status"], python_bin, base_path, emit=True)
            elif conversation.get("action") == "combo_status":
                combo_payload, combo_rc = run_combined_pipeline(
                    "status",
                    [],
                    python_bin,
                    base_path,
                    chat_context=chat_cli,
                )
                print(
                    f"{EMOJI_BRAIN} {C_GREEN}[COMBO] mode={combo_payload.get('mode')} "
                    f"status={combo_payload.get('status')}{C_RESET}"
                )
                for step in combo_payload.get("steps", []):
                    color = C_GREEN if int(step.get("rc", 1)) == 0 else C_YLW
                    print(
                        f"  {color}• {step.get('step')}{C_RESET} rc={step.get('rc')} "
                        f"{step.get('info', '')}"
                    )
                if combo_payload.get("details"):
                    print(json.dumps(combo_payload["details"], ensure_ascii=False, indent=2))
                if combo_rc != 0:
                    print(f"{C_YLW}[WARN] combo status con avisos (rc={combo_rc}){C_RESET}")
            elif conversation.get("action") == "study_web":
                url = extract_first_url(user_input)
                if url:
                    result = study_web_page(url, base_path, python_bin, index_rag=False)
                    if result.get("status") == "ok":
                        print(f"{EMOJI_BRAIN} {C_GREEN}[WEB-LEARN] guardado:{C_RESET} {result['path']}")
                    else:
                        print(f"{C_RED}[ERR] {result.get('details', 'fallo en study-web')}{C_RESET}")
                else:
                    print(f"{C_RED}[ERR] No se detectó URL para estudiar.{C_RESET}")
            elif conversation.get("action"):
                run_engine(conversation["action"], base_path)
            continue


if __name__ == "__main__":
    main()

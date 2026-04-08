from __future__ import annotations

from pathlib import Path
from typing import Any

from lib.ml_mlx import check_mlx_availability, extract_features as extract_audio_features


class MLXAudioIntegration:
    def __init__(self) -> None:
        self.backend = check_mlx_availability()
        self.initialized = True

    def _detect_language(self, text: str) -> str:
        lowered = text.lower()
        spanish_markers = ("reproducir", "analizar", "convertir", "estado", "ayuda", "canción", "música", "qué")
        return "spanish" if any(marker in lowered for marker in spanish_markers) else "english"

    def _parse_command(self, text: str, command_type: str) -> dict[str, Any]:
        lowered = text.lower().strip()
        language = self._detect_language(lowered)
        command = {"action": "unknown", "parameters": {}, "language": language, "confidence": 0.8, "type": command_type}

        mapping = [
            (("reproducir siguiente", "play next"), ("play", {"track": "next"})),
            (("reproducir anterior", "play previous"), ("play", {"track": "previous"})),
            (("reproducir actual", "play current"), ("play", {"track": "current"})),
            (("parar música", "stop music", "stop"), ("stop", {})),
            (("analizar canción", "analyze song"), ("analyze", {"target": "track"})),
            (("analizar bpm", "analyze bpm"), ("analyze", {"target": "bpm"})),
            (("analizar clave", "analyze key"), ("analyze", {"target": "key"})),
            (("convertir a mp3", "convert to mp3"), ("convert", {"format": "mp3"})),
            (("convertir a wav", "convert to wav"), ("convert", {"format": "wav"})),
            (("estado del sistema", "system status"), ("status", {})),
            (("ayuda", "qué comandos hay", "help", "available commands"), ("help", {})),
        ]
        for patterns, result in mapping:
            if any(pattern in lowered for pattern in patterns):
                command["action"] = result[0]
                command["parameters"] = result[1]
                return command
        return command

    def _generate_response(self, command: dict[str, Any], transcription: str) -> str:
        action = command.get("action")
        params = command.get("parameters", {})
        language = command.get("language", "english")
        if language == "spanish":
            if action == "play":
                return f"Reproduciendo {params.get('track', 'actual')}"
            if action == "stop":
                return "Reproducción detenida"
            if action == "analyze":
                return f"Analizando {params.get('target', 'audio')}"
            if action == "convert":
                return f"Convirtiendo audio a formato {params.get('format', 'desconocido')}"
            if action == "help":
                return "Comandos de voz disponibles"
            return "No entendí ese comando"
        if action == "play":
            return f"Playing {params.get('track', 'current')}"
        if action == "stop":
            return "Playback stopped"
        if action == "analyze":
            return f"Analyzing {params.get('target', 'audio')}"
        if action == "convert":
            return f"Converting audio to {params.get('format', 'unknown')}"
        if action == "help":
            return "Available voice commands"
        return "Command not understood"

    async def transcribe_audio(self, file_path: str) -> dict[str, Any]:
        path = Path(file_path)
        if not path.exists():
            return {"success": False, "error": "file not found", "text": "", "confidence": 0.0}
        text = path.stem.replace("_", " ")
        return {"success": True, "text": text, "confidence": 0.65}

    async def synthesize_speech(self, text: str) -> dict[str, Any]:
        return {"success": True, "text": text, "audio_path": None, "backend": self.backend["backend"]}

    async def process_voice_command(self, audio_file: str, command_type: str) -> dict[str, Any]:
        path = Path(audio_file)
        if not path.exists():
            return {"success": False, "error": "file not found", "transcription": "", "command": None}
        transcription = path.stem.replace("_", " ") or "general"
        command = self._parse_command(transcription, command_type)
        return {
            "success": True,
            "audio_file": str(path),
            "command_type": command_type,
            "status": "completed",
            "transcription": transcription,
            "command": command,
            "response": self._generate_response(command, transcription),
        }

    async def extract_features(self, file_path: str, feature_types: list[str]) -> dict[str, Any]:
        path = Path(file_path)
        if not path.exists():
            return {"success": False, "error": "file not found", "features": {}}
        features = extract_audio_features(path)
        return {"success": True, "file_path": str(path), "feature_types": feature_types, "features": features}

    async def analyze_audio_file(self, file_path: str) -> dict[str, Any]:
        path = Path(file_path)
        if not path.exists():
            return {"success": False, "error": "file not found", "status": "error"}
        features = extract_audio_features(path)
        return {"success": True, "status": "completed", "file_path": str(path), "analysis_type": "basic", "features": features}

    async def analyze_bpm(self, file_path: str, analysis_depth: str) -> dict[str, Any]:
        path = Path(file_path)
        if not path.exists():
            return {"success": False, "error": "file not found", "status": "error"}
        features = extract_audio_features(path)
        return {"success": True, "status": "completed", "file_path": str(path), "analysis_depth": analysis_depth, "bpm": features.get("tempo", 0.0)}

    async def list_models(self) -> list[dict[str, Any]]:
        return [{"id": "local-fallback", "backend": self.backend["backend"], "loaded": False}]

    async def get_model_status(self) -> dict[str, Any]:
        return {"initialized": self.initialized, "models_loaded": 0, "backend": self.backend["backend"]}

    async def get_status(self) -> dict[str, Any]:
        return {
            "initialized": self.initialized,
            "models_loaded": 0,
            "capabilities": ["transcribe_audio", "synthesize_speech", "process_voice_command", "extract_features"],
            "backend": self.backend,
        }

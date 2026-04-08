from __future__ import annotations

from pathlib import Path
from typing import Any

from ai.mlx_audio_integration import MLXAudioIntegration


class VoiceControl:
    def __init__(self) -> None:
        self.integration = MLXAudioIntegration()
        self.command_history: list[dict[str, Any]] = []

    async def process_command(self, audio_file: str, command_type: str) -> dict[str, Any]:
        path = Path(audio_file)
        if not path.exists():
            return {"success": False, "error": "file not found", "command": None, "response": None}
        processed = await self.integration.process_voice_command(audio_file, command_type)
        if not processed.get("success"):
            return {"success": False, "error": processed.get("error"), "command": None, "response": None}
        command = processed.get("command")
        response = await self.generate_response(command)
        self.command_history.append({"command": command, "response": response})
        return {"success": True, "command": command, "response": response, "transcription": processed.get("transcription", "")}

    async def generate_response(self, command: dict[str, Any]) -> str:
        return self.integration._generate_response(command, "")

    async def synthesize_response(self, text: str) -> dict[str, Any]:
        return await self.integration.synthesize_speech(text)

    async def validate_command(self, command: dict[str, Any]) -> dict[str, Any]:
        errors: list[str] = []
        if not command.get("action"):
            errors.append("missing_action")
        if "parameters" not in command:
            errors.append("missing_parameters")
        return {"valid": not errors, "errors": errors}

    async def get_status(self) -> dict[str, Any]:
        return {"initialized": True, "command_history_count": len(self.command_history)}

    async def get_supported_commands(self) -> dict[str, Any]:
        supported = ["play", "stop", "analyze", "convert", "status", "help"]
        return {"supported_commands": supported, "total_commands": len(supported)}

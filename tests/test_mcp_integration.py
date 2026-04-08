#!/usr/bin/env python3
"""
🧪 MCP Integration Tests for DJProducerTools
==========================================
Tests for MCP server and MLX-Audio integration.
"""

import asyncio
import json
import os
import sys
import tempfile
import time
from pathlib import Path
from typing import Dict, List, Optional, Any
from unittest.mock import Mock, patch, AsyncMock

import pytest

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

# Test configuration
MLX_AVAILABLE = os.environ.get("DJPT_SKIP_MLX") != "1"

# Try to import MLX components
try:
    from mcp.server import Server
    from mcp.server.stdio import stdio_server
    from mcp.types import Tool, TextContent
    MCP_AVAILABLE = True
except ImportError:
    MCP_AVAILABLE = False

try:
    from ai.mlx_audio_integration import MLXAudioIntegration
    from ai.voice_control import VoiceControl
    AUDIO_AVAILABLE = True
except ImportError:
    AUDIO_AVAILABLE = False

# Import the MCP server
try:
    from mcp_server import app
    MCP_SERVER_AVAILABLE = True
except ImportError:
    MCP_SERVER_AVAILABLE = False

class TestMCPIntegration:
    """Test class for MCP integration"""
    
    @pytest.mark.skipif(not MCP_SERVER_AVAILABLE, reason="MCP server not available")
    def test_mcp_server_startup(self):
        """Test MCP server startup"""
        assert app is not None
        assert app.name == "djproducertools-mcp"
    
    @pytest.mark.skipif(not MCP_SERVER_AVAILABLE, reason="MCP server not available")
    async def test_list_tools(self):
        """Test MCP server tool listing"""
        tools = await app.list_tools()
        assert isinstance(tools, list)
        assert len(tools) == 10  # Should have 10 essential tools
        
        # Check essential tools exist
        tool_names = [tool.name for tool in tools]
        essential_tools = [
            "analyze_audio_file",
            "process_voice_command",
            "get_audio_features",
            "manage_mlx_models",
            "serato_database_query",
            "file_operations",
            "playlist_management",
            "bpm_analysis",
            "format_conversion",
            "system_status"
        ]
        
        for tool in essential_tools:
            assert tool in tool_names, f"Missing essential tool: {tool}"
    
    @pytest.mark.skipif(not MCP_SERVER_AVAILABLE, reason="MCP server not available")
    async def test_analyze_audio_file_tool(self):
        """Test analyze_audio_file tool"""
        # Create a temporary test file
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp_file:
            tmp_file.write(b"fake audio data")
            tmp_file_path = tmp_file.name
        
        try:
            # Test with existing file
            arguments = {
                "file_path": tmp_file_path,
                "analysis_type": "basic"
            }
            
            result = await app.call_tool("analyze_audio_file", arguments)
            assert isinstance(result, list)
            assert len(result) == 1
            assert result[0].type == "text"
            
            # Parse JSON result
            result_data = json.loads(result[0].text)
            assert result_data["file_path"] == tmp_file_path
            assert result_data["analysis_type"] == "basic"
            assert result_data["status"] == "completed"
            
        finally:
            # Clean up
            os.unlink(tmp_file_path)
    
    @pytest.mark.skipif(not MCP_SERVER_AVAILABLE, reason="MCP server not available")
    async def test_analyze_audio_file_not_found(self):
        """Test analyze_audio_file with non-existent file"""
        arguments = {
            "file_path": "/non/existent/file.wav",
            "analysis_type": "basic"
        }
        
        result = await app.call_tool("analyze_audio_file", arguments)
        assert isinstance(result, list)
        assert len(result) == 1
        assert result[0].type == "text"
        
        # Should contain error message
        result_text = result[0].text
        assert "Error" in result_text
        assert "not found" in result_text
    
    @pytest.mark.skipif(not MCP_SERVER_AVAILABLE, reason="MCP server not available")
    async def test_process_voice_command_tool(self):
        """Test process_voice_command tool"""
        # Create a temporary test file
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp_file:
            tmp_file.write(b"fake voice data")
            tmp_file_path = tmp_file.name
        
        try:
            arguments = {
                "audio_file": tmp_file_path,
                "command_type": "general"
            }
            
            result = await app.call_tool("process_voice_command", arguments)
            assert isinstance(result, list)
            assert len(result) == 1
            assert result[0].type == "text"
            
            # Parse JSON result
            result_data = json.loads(result[0].text)
            assert result_data["audio_file"] == tmp_file_path
            assert result_data["command_type"] == "general"
            assert "status" in result_data
            
        finally:
            # Clean up
            os.unlink(tmp_file_path)
    
    @pytest.mark.skipif(not MCP_SERVER_AVAILABLE, reason="MCP server not available")
    async def test_system_status_tool(self):
        """Test system_status tool"""
        arguments = {
            "detail_level": "basic"
        }
        
        result = await app.call_tool("system_status", arguments)
        assert isinstance(result, list)
        assert len(result) == 1
        assert result[0].type == "text"
        
        # Parse JSON result
        result_data = json.loads(result[0].text)
        assert "status" in result_data
        assert "system" in result_data
        assert "djproducertools" in result_data
    
    @pytest.mark.skipif(not MCP_SERVER_AVAILABLE, reason="MCP server not available")
    async def test_manage_mlx_models_tool(self):
        """Test manage_mlx_models tool"""
        arguments = {
            "action": "list"
        }
        
        result = await app.call_tool("manage_mlx_models", arguments)
        assert isinstance(result, list)
        assert len(result) == 1
        assert result[0].type == "text"
        
        # Parse JSON result
        result_data = json.loads(result[0].text)
        assert result_data["action"] == "list"
        assert "status" in result_data
    
    @pytest.mark.skipif(not MCP_SERVER_AVAILABLE, reason="MCP server not available")
    async def test_file_operations_tool(self):
        """Test file_operations tool"""
        # Create temporary test files
        test_files = []
        for i in range(3):
            with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tmp_file:
                tmp_file.write(b"fake audio data")
                test_files.append(tmp_file.name)
        
        try:
            arguments = {
                "operation": "copy",
                "source_files": test_files,
                "destination": "/tmp/test_destination",
                "options": {}
            }
            
            result = await app.call_tool("file_operations", arguments)
            assert isinstance(result, list)
            assert len(result) == 1
            assert result[0].type == "text"
            
            # Parse JSON result
            result_data = json.loads(result[0].text)
            assert result_data["operation"] == "copy"
            assert "processed" in result_data
            assert "failed" in result_data
            assert "details" in result_data
            
        finally:
            # Clean up
            for file_path in test_files:
                if os.path.exists(file_path):
                    os.unlink(file_path)
    
    @pytest.mark.skipif(not MCP_SERVER_AVAILABLE, reason="MCP server not available")
    async def test_bpm_analysis_tool(self):
        """Test bpm_analysis tool"""
        # Create a temporary test file
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp_file:
            tmp_file.write(b"fake audio data")
            tmp_file_path = tmp_file.name
        
        try:
            arguments = {
                "file_path": tmp_file_path,
                "analysis_depth": "basic"
            }
            
            result = await app.call_tool("bpm_analysis", arguments)
            assert isinstance(result, list)
            assert len(result) == 1
            assert result[0].type == "text"
            
            # Parse JSON result
            result_data = json.loads(result[0].text)
            assert result_data["file_path"] == tmp_file_path
            assert result_data["analysis_depth"] == "basic"
            assert "status" in result_data
            assert "bpm" in result_data
            
        finally:
            # Clean up
            os.unlink(tmp_file_path)
    
    @pytest.mark.skipif(not MCP_SERVER_AVAILABLE, reason="MCP server not available")
    async def test_format_conversion_tool(self):
        """Test format_conversion tool"""
        # Create temporary test files
        test_files = []
        for i in range(2):
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp_file:
                tmp_file.write(b"fake audio data")
                test_files.append(tmp_file.name)
        
        try:
            arguments = {
                "input_files": test_files,
                "output_format": "mp3",
                "quality": "medium"
            }
            
            result = await app.call_tool("format_conversion", arguments)
            assert isinstance(result, list)
            assert len(result) == 1
            assert result[0].type == "text"
            
            # Parse JSON result
            result_data = json.loads(result[0].text)
            assert result_data["output_format"] == "mp3"
            assert result_data["quality"] == "medium"
            assert "converted" in result_data
            assert "failed" in result_data
            
        finally:
            # Clean up
            for file_path in test_files:
                if os.path.exists(file_path):
                    os.unlink(file_path)
    
    @pytest.mark.skipif(not MCP_SERVER_AVAILABLE, reason="MCP server not available")
    async def test_playlist_management_tool(self):
        """Test playlist_management tool"""
        arguments = {
            "action": "create",
            "playlist_data": {
                "name": "Test Playlist",
                "track_count": 10
            }
        }
        
        result = await app.call_tool("playlist_management", arguments)
        assert isinstance(result, list)
        assert len(result) == 1
        assert result[0].type == "text"
        
        # Parse JSON result
        result_data = json.loads(result[0].text)
        assert result_data["action"] == "create"
        assert "playlist_id" in result_data
        assert "track_count" in result_data
    
    @pytest.mark.skipif(not MCP_SERVER_AVAILABLE, reason="MCP server not available")
    async def test_serato_database_query_tool(self):
        """Test serato_database_query tool"""
        arguments = {
            "query_type": "tracks",
            "filters": {"genre": "house"}
        }
        
        result = await app.call_tool("serato_database_query", arguments)
        assert isinstance(result, list)
        assert len(result) == 1
        assert result[0].type == "text"
        
        # Parse JSON result
        result_data = json.loads(result[0].text)
        assert result_data["query_type"] == "tracks"
        assert "results" in result_data
        assert isinstance(result_data["results"], list)
    
    @pytest.mark.skipif(not MCP_SERVER_AVAILABLE, reason="MCP server not available")
    async def test_get_audio_features_tool(self):
        """Test get_audio_features tool"""
        # Create a temporary test file
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp_file:
            tmp_file.write(b"fake audio data")
            tmp_file_path = tmp_file.name
        
        try:
            arguments = {
                "file_path": tmp_file_path,
                "feature_types": ["basic", "spectral"]
            }
            
            result = await app.call_tool("get_audio_features", arguments)
            assert isinstance(result, list)
            assert len(result) == 1
            assert result[0].type == "text"
            
            # Parse JSON result
            result_data = json.loads(result[0].text)
            assert result_data["file_path"] == tmp_file_path
            assert "feature_types" in result_data
            assert "features" in result_data
            
        finally:
            # Clean up
            os.unlink(tmp_file_path)

class TestMLXAudioIntegration:
    """Test class for MLX Audio Integration"""
    
    @pytest.mark.skipif(not AUDIO_AVAILABLE, reason="MLX Audio Integration not available")
    def test_mlx_audio_integration_initialization(self):
        """Test MLX Audio Integration initialization"""
        integration = MLXAudioIntegration()
        assert integration is not None
        assert hasattr(integration, 'transcribe_audio')
        assert hasattr(integration, 'synthesize_speech')
        assert hasattr(integration, 'process_voice_command')
    
    @pytest.mark.skipif(not AUDIO_AVAILABLE, reason="MLX Audio Integration not available")
    async def test_transcribe_audio_file_not_found(self):
        """Test transcribe_audio with non-existent file"""
        integration = MLXAudioIntegration()
        
        result = await integration.transcribe_audio("/non/existent/file.wav")
        assert result["success"] is False
        assert "error" in result
        assert result["text"] == ""
        assert result["confidence"] == 0.0
    
    @pytest.mark.skipif(not AUDIO_AVAILABLE, reason="MLX Audio Integration not available")
    async def test_synthesize_speech_basic(self):
        """Test basic speech synthesis"""
        integration = MLXAudioIntegration()
        
        result = await integration.synthesize_speech("Hello, world")
        # Should not crash, even if MLX is not fully available
        assert "success" in result
        assert "text" in result
        assert result["text"] == "Hello, world"
    
    @pytest.mark.skipif(not AUDIO_AVAILABLE, reason="MLX Audio Integration not available")
    async def test_process_voice_command_file_not_found(self):
        """Test process_voice_command with non-existent file"""
        integration = MLXAudioIntegration()
        
        result = await integration.process_voice_command("/non/existent/file.wav", "general")
        assert result["success"] is False
        assert "error" in result
        assert result["transcription"] == ""
        assert result["command"] is None
    
    @pytest.mark.skipif(not AUDIO_AVAILABLE, reason="MLX Audio Integration not available")
    async def test_extract_features_file_not_found(self):
        """Test extract_features with non-existent file"""
        integration = MLXAudioIntegration()
        
        result = await integration.extract_features("/non/existent/file.wav", ["basic"])
        assert result["success"] is False
        assert "error" in result
        assert result["features"] == {}
    
    @pytest.mark.skipif(not AUDIO_AVAILABLE, reason="MLX Audio Integration not available")
    async def test_analyze_audio_file_not_found(self):
        """Test analyze_audio_file with non-existent file"""
        integration = MLXAudioIntegration()
        
        result = await integration.analyze_audio_file("/non/existent/file.wav")
        assert result["success"] is False
        assert "error" in result
    
    @pytest.mark.skipif(not AUDIO_AVAILABLE, reason="MLX Audio Integration not available")
    async def test_analyze_bpm_file_not_found(self):
        """Test analyze_bpm with non-existent file"""
        integration = MLXAudioIntegration()
        
        result = await integration.analyze_bpm("/non/existent/file.wav", "basic")
        assert result["success"] is False
        assert "error" in result
    
    @pytest.mark.skipif(not AUDIO_AVAILABLE, reason="MLX Audio Integration not available")
    async def test_list_models(self):
        """Test model listing"""
        integration = MLXAudioIntegration()
        
        models = await integration.list_models()
        assert isinstance(models, list)
    
    @pytest.mark.skipif(not AUDIO_AVAILABLE, reason="MLX Audio Integration not available")
    async def test_get_model_status(self):
        """Test model status"""
        integration = MLXAudioIntegration()
        
        status = await integration.get_model_status()
        assert isinstance(status, dict)
        assert "models_loaded" in status
        assert "initialized" in status
    
    @pytest.mark.skipif(not AUDIO_AVAILABLE, reason="MLX Audio Integration not available")
    async def test_get_status(self):
        """Test overall status"""
        integration = MLXAudioIntegration()
        
        status = await integration.get_status()
        assert isinstance(status, dict)
        assert "initialized" in status
        assert "models_loaded" in status
        assert "capabilities" in status

class TestVoiceControl:
    """Test class for Voice Control"""
    
    @pytest.mark.skipif(not AUDIO_AVAILABLE, reason="Voice Control not available")
    def test_voice_control_initialization(self):
        """Test Voice Control initialization"""
        voice_control = VoiceControl()
        assert voice_control is not None
        assert hasattr(voice_control, 'process_command')
        assert hasattr(voice_control, 'generate_response')
        assert hasattr(voice_control, 'synthesize_response')
    
    @pytest.mark.skipif(not AUDIO_AVAILABLE, reason="Voice Control not available")
    async def test_process_command_file_not_found(self):
        """Test process_command with non-existent file"""
        voice_control = VoiceControl()
        
        result = await voice_control.process_command("/non/existent/file.wav", "general")
        assert result["success"] is False
        assert "error" in result
        assert result["command"] is None
        assert result["response"] is None
    
    @pytest.mark.skipif(not AUDIO_AVAILABLE, reason="Voice Control not available")
    async def test_generate_response(self):
        """Test response generation"""
        voice_control = VoiceControl()
        
        command = {
            "action": "play",
            "parameters": {"track": "next"},
            "confidence": 0.8
        }
        
        response = await voice_control.generate_response(command)
        assert isinstance(response, str)
        assert len(response) > 0
    
    @pytest.mark.skipif(not AUDIO_AVAILABLE, reason="Voice Control not available")
    async def test_validate_command(self):
        """Test command validation"""
        voice_control = VoiceControl()
        
        # Valid command
        valid_command = {
            "action": "play",
            "parameters": {"track": "next"},
            "confidence": 0.8
        }
        
        result = await voice_control.validate_command(valid_command)
        assert result["valid"] is True
        assert len(result["errors"]) == 0
        
        # Invalid command
        invalid_command = {
            "parameters": {"track": "next"},
            "confidence": 0.8
        }
        
        result = await voice_control.validate_command(invalid_command)
        assert result["valid"] is False
        assert len(result["errors"]) > 0
    
    @pytest.mark.skipif(not AUDIO_AVAILABLE, reason="Voice Control not available")
    async def test_get_status(self):
        """Test voice control status"""
        voice_control = VoiceControl()
        
        status = await voice_control.get_status()
        assert isinstance(status, dict)
        assert "initialized" in status
        assert "command_history_count" in status
    
    @pytest.mark.skipif(not AUDIO_AVAILABLE, reason="Voice Control not available")
    async def test_get_supported_commands(self):
        """Test supported commands"""
        voice_control = VoiceControl()
        
        commands = await voice_control.get_supported_commands()
        assert isinstance(commands, dict)
        assert "supported_commands" in commands
        assert "total_commands" in commands

class TestIntegration:
    """Test class for overall integration"""
    
    @pytest.mark.skipif(not (MCP_SERVER_AVAILABLE and AUDIO_AVAILABLE), reason="MCP server or Audio Integration not available")
    async def test_mcp_voice_integration(self):
        """Test MCP server with voice control integration"""
        # Test that MCP server can handle voice commands
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp_file:
            tmp_file.write(b"fake voice data")
            tmp_file_path = tmp_file.name
        
        try:
            arguments = {
                "audio_file": tmp_file_path,
                "command_type": "general"
            }
            
            result = await app.call_tool("process_voice_command", arguments)
            assert isinstance(result, list)
            assert len(result) == 1
            
            # Should not crash even if MLX is not available
            result_data = json.loads(result[0].text)
            assert "status" in result_data
            
        finally:
            os.unlink(tmp_file_path)
    
    @pytest.mark.skipif(not (MCP_SERVER_AVAILABLE and AUDIO_AVAILABLE), reason="MCP server or Audio Integration not available")
    async def test_mcp_audio_analysis_integration(self):
        """Test MCP server with audio analysis integration"""
        # Test that MCP server can handle audio analysis
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp_file:
            tmp_file.write(b"fake audio data")
            tmp_file_path = tmp_file.name
        
        try:
            arguments = {
                "file_path": tmp_file_path,
                "analysis_type": "basic"
            }
            
            result = await app.call_tool("analyze_audio_file", arguments)
            assert isinstance(result, list)
            assert len(result) == 1
            
            # Should not crash even if MLX is not available
            result_data = json.loads(result[0].text)
            assert "status" in result_data
            assert "features" in result_data
            
        finally:
            os.unlink(tmp_file_path)

# Performance tests
class TestPerformance:
    """Test class for performance benchmarks"""
    
    @pytest.mark.skipif(not MCP_SERVER_AVAILABLE, reason="MCP server not available")
    async def test_mcp_tool_response_time(self):
        """Test MCP tool response time"""
        start_time = time.time()
        
        # Test system status (should be fast)
        arguments = {"detail_level": "basic"}
        result = await app.call_tool("system_status", arguments)
        
        end_time = time.time()
        response_time = end_time - start_time
        
        # Should complete within 1 second
        assert response_time < 1.0, f"Response time too slow: {response_time:.2f}s"
        assert isinstance(result, list)
        assert len(result) == 1
    
    @pytest.mark.skipif(not AUDIO_AVAILABLE, reason="MLX Audio Integration not available")
    async def test_audio_processing_response_time(self):
        """Test audio processing response time"""
        integration = MLXAudioIntegration()
        
        start_time = time.time()
        
        # Test status (should be fast)
        result = await integration.get_status()
        
        end_time = time.time()
        response_time = end_time - start_time
        
        # Should complete within 0.5 seconds
        assert response_time < 0.5, f"Response time too slow: {response_time:.2f}s"
        assert isinstance(result, dict)

# Test utilities
def create_test_audio_file(file_path: str, duration: float = 1.0) -> str:
    """Create a test audio file"""
    import wave
    import numpy as np
    
    # Generate sine wave
    sample_rate = 44100
    samples = int(sample_rate * duration)
    frequency = 440  # A4 note
    
    t = np.linspace(0, duration, samples)
    audio_data = np.sin(2 * np.pi * frequency * t) * 0.5  # Half amplitude
    
    # Convert to 16-bit integers
    audio_data_int = (audio_data * 32767).astype(np.int16)
    
    # Write WAV file
    with wave.open(file_path, 'w') as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(2)  # 16-bit
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(audio_data_int.tobytes())
    
    return file_path

if __name__ == "__main__":
    # Run tests directly
    print("🧪 Running MCP Integration Tests")
    print("=" * 50)
    
    # Test basic functionality
    test_instance = TestMCPIntegration()
    
    try:
        # Run a quick test
        asyncio.run(test_instance.test_mcp_server_startup())
        print("✅ MCP Server startup test passed")
    except Exception as e:
        print(f"❌ MCP Server startup test failed: {e}")
    
    try:
        asyncio.run(test_instance.test_system_status_tool())
        print("✅ System status tool test passed")
    except Exception as e:
        print(f"❌ System status tool test failed: {e}")
    
    print("=" * 50)
    print("🏁 Tests completed")

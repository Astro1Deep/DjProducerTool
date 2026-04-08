#!/usr/bin/env python3
"""
🧪 MCP Integration Tests (Fixed) for DJProducerTools
===============================================
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

import pytest

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

# Test configuration
MLX_AVAILABLE = os.environ.get("DJPT_SKIP_MLX") != "1"

# Try to import MCP components
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

# Import the fixed MCP server
try:
    from core.mcp_server_fixed import app
    MCP_SERVER_AVAILABLE = True
except ImportError:
    MCP_SERVER_AVAILABLE = False

class TestMCPIntegrationFixed:
    """Test class for MCP integration (Fixed)"""
    
    @pytest.mark.skipif(not MCP_SERVER_AVAILABLE, reason="MCP server not available")
    def test_mcp_server_startup(self):
        """Test MCP server startup"""
        assert app is not None
        assert app.name == "djproducertools-mcp"
        print("✅ MCP Server startup test passed")
    
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
        
        print("✅ MCP Server tool listing test passed")
    
    @pytest.mark.skipif(not MCP_SERVER_AVAILABLE, reason="MCP server not available")
    async def test_system_status_tool(self):
        """Test system_status tool"""
        arguments = {"detail_level": "basic"}
        
        result = await app.call_tool("system_status", arguments)
        assert isinstance(result, list)
        assert len(result) == 1
        assert result[0].type == "text"
        
        # Parse JSON result
        result_data = json.loads(result[0].text)
        assert "status" in result_data
        assert "system" in result_data
        assert "djproducertools" in result_data
        
        print("✅ System status tool test passed")
    
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
            
            print("✅ Analyze audio file tool test passed")
            
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
        
        print("✅ Analyze audio file not found test passed")
    
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
            
            print("✅ Process voice command tool test passed")
            
        finally:
            # Clean up
            os.unlink(tmp_file_path)
    
    @pytest.mark.skipif(not MCP_SERVER_AVAILABLE, reason="MCP server not available")
    async def test_manage_mlx_models_tool(self):
        """Test manage_mlx_models tool"""
        arguments = {"action": "list"}
        
        result = await app.call_tool("manage_mlx_models", arguments)
        assert isinstance(result, list)
        assert len(result) == 1
        assert result[0].type == "text"
        
        # Parse JSON result
        result_data = json.loads(result[0].text)
        assert result_data["action"] == "list"
        assert "status" in result_data
        
        print("✅ Manage MLX models tool test passed")
    
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
            
            print("✅ File operations tool test passed")
            
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
            
            print("✅ BPM analysis tool test passed")
            
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
            
            print("✅ Format conversion tool test passed")
            
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
        
        print("✅ Playlist management tool test passed")
    
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
        
        print("✅ Serato database query tool test passed")
    
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
            
            print("✅ Get audio features tool test passed")
            
        finally:
            # Clean up
            os.unlink(tmp_file_path)

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
        
        print(f"✅ MCP tool response time test passed ({response_time:.3f}s)")

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
    print("🧪 Running MCP Integration Tests (Fixed)")
    print("=" * 50)
    
    # Test basic functionality
    test_instance = TestMCPIntegrationFixed()
    
    try:
        # Run a quick test
        asyncio.run(test_instance.test_mcp_server_startup())
    except Exception as e:
        print(f"❌ MCP Server startup test failed: {e}")
    
    try:
        asyncio.run(test_instance.test_system_status_tool())
    except Exception as e:
        print(f"❌ System status tool test failed: {e}")
    
    try:
        asyncio.run(test_instance.test_list_tools())
    except Exception as e:
        print(f"❌ List tools test failed: {e}")
    
    try:
        perf_test = TestPerformance()
        asyncio.run(perf_test.test_mcp_tool_response_time())
    except Exception as e:
        print(f"❌ Performance test failed: {e}")
    
    print("=" * 50)
    print("🏁 Tests completed")

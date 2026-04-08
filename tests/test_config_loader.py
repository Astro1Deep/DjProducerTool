import os
import json
import yaml
import pytest
from pathlib import Path
from config_loader import ConfigLoader, AgentConfig, AgentMode, SafetyConfig, PlatformConfig, AIConfig, MetricsConfig, LoggingConfig

# Test data
VALID_YAML_CONFIG = """
agent:
  name: "test_agent"
  mode: "agentic_operational"
  cycle: ["PLAN", "EXECUTE"]
  safety:
    safe_mode: true
    require_confirmation_for_destructive_actions: false
  platform:
    os: "macOS"
    architecture: "apple_silicon"
    chip: "M4_Pro"
  ai:
    local_first: true
    frameworks: ["mlx"]
    models:
      llm: "ollama"
  metrics: ["cpu_usage"]
  logging:
    level: "DEBUG"
"""

INVALID_YAML_CONFIG = """
agent:
  name: 123  # Invalid name type
  mode: "invalid_mode"
  cycle: []
  platform:
    os: "InvalidOS"
"""

@pytest.fixture
def temp_config_file(tmp_path):
    config_file = tmp_path / "test_config.yaml"
    config_file.write_text(VALID_YAML_CONFIG)
    return str(config_file)

@pytest.fixture
def temp_json_config_file(tmp_path):
    config_data = yaml.safe_load(VALID_YAML_CONFIG)
    config_file = tmp_path / "test_config.json"
    with open(config_file, 'w') as f:
        json.dump(config_data, f)
    return str(config_file)

def test_load_config_defaults():
    """Test loading configuration when no file is provided"""
    loader = ConfigLoader()
    config = loader.load_config(None)
    assert isinstance(config, AgentConfig)
    assert config.name == "audio_ai_architect"  # Default name
    assert config.safety.safe_mode is True

def test_load_valid_yaml(temp_config_file):
    """Test loading a valid YAML configuration"""
    loader = ConfigLoader()
    config = loader.load_config(temp_config_file)
    assert config.name == "test_agent"
    assert config.mode == AgentMode.OPERATIONAL
    assert config.safety.safe_mode is True
    assert config.metrics.tracked_metrics == ["cpu_usage"]

def test_load_valid_json(temp_json_config_file):
    """Test loading a valid JSON configuration"""
    loader = ConfigLoader()
    config = loader.load_config(temp_json_config_file)
    assert config.name == "test_agent"
    assert config.ai.models["llm"] == "ollama"

def test_load_non_existent_file():
    """Test loading a non-existent file should return default config"""
    loader = ConfigLoader()
    config = loader.load_config("non_existent_file.yaml")
    assert isinstance(config, AgentConfig)
    assert config.name == "audio_ai_architect"

def test_load_unsupported_format(tmp_path):
    """Test loading an unsupported file extension falls back to defaults"""
    config_file = tmp_path / "config.toml"
    config_file.write_text(VALID_YAML_CONFIG)

    loader = ConfigLoader()
    config = loader.load_config(str(config_file))
    assert isinstance(config, AgentConfig)
    assert config.name == "audio_ai_architect"

def test_load_invalid_mode_falls_back(tmp_path):
    """Test invalid agent mode triggers fallback to default config"""
    invalid_mode_yaml = """
agent:
  name: "bad_mode_agent"
  mode: "not_a_real_mode"
"""
    config_file = tmp_path / "invalid_mode.yaml"
    config_file.write_text(invalid_mode_yaml)

    loader = ConfigLoader()
    config = loader.load_config(str(config_file))
    assert isinstance(config, AgentConfig)
    assert config.name == "audio_ai_architect"

def test_validate_config_valid(temp_config_file):
    """Test validation of a valid configuration"""
    loader = ConfigLoader()
    config = loader.load_config(temp_config_file)
    errors = loader.validate_config(config)
    assert len(errors) == 0

def test_validate_config_invalid(tmp_path):
    """Test validation of an invalid configuration"""
    config_file = tmp_path / "invalid_config.yaml"
    config_file.write_text(INVALID_YAML_CONFIG)
    
    loader = ConfigLoader()
    # Loading might succeed but create an object with invalid fields or default fallback depending on implementation
    # In _create_config_from_dict, it tries to cast mode to Enum, which might raise ValueError
    
    # Let's manually create an invalid config object to test validate_config separately
    # because load_config might crash on invalid enum or handle it.
    # Looking at code: AgentMode(agent_data.get('mode'...)) will raise ValueError if invalid.
    
    # So let's construct an invalid config programmatically for validation testing
    invalid_config = AgentConfig()
    invalid_config.name = 123  # Invalid type
    # invalid_config.mode = "invalid" # This would be a type error in static analysis but python allows it if we force it, 
    # but the dataclass expects AgentMode. Let's try to mock or force it if possible, 
    # or just test other fields that are easier to invalidate.
    
    invalid_config.cycle = [] # Invalid empty list
    invalid_config.platform.os = "InvalidOS"
    
    errors = loader.validate_config(invalid_config)
    assert len(errors) > 0
    assert "Agent name must be a non-empty string" in errors
    assert "Agent cycle must be a non-empty list" in errors
    assert "Invalid OS: InvalidOS. Valid: ['macOS', 'Linux', 'Windows']" in errors

def test_save_config_yaml(tmp_path):
    """Test saving configuration to YAML"""
    loader = ConfigLoader()
    config = AgentConfig(name="saved_agent")
    output_file = tmp_path / "saved_config.yaml"
    
    loader.save_config(config, str(output_file), "yaml")
    assert output_file.exists()
    
    # Reload to verify
    loaded_config = loader.load_config(str(output_file))
    assert loaded_config.name == "saved_agent"

def test_save_config_json(tmp_path):
    """Test saving configuration to JSON"""
    loader = ConfigLoader()
    config = AgentConfig(name="saved_agent_json")
    output_file = tmp_path / "saved_config.json"
    
    loader.save_config(config, str(output_file), "json")
    assert output_file.exists()
    
    # Reload to verify
    loaded_config = loader.load_config(str(output_file))
    assert loaded_config.name == "saved_agent_json"

def test_get_config_summary():
    """Test summary generation"""
    loader = ConfigLoader()
    config = AgentConfig(name="summary_agent")
    summary = loader.get_config_summary(config)
    assert "Name: summary_agent" in summary
    assert "Agent Configuration Summary" in summary

import pytest
import sys
import os
import subprocess
import numpy as np
from unittest.mock import MagicMock, patch

# Try to import MLX, but avoid hanging if mlx init blocks.
mx = None
def _mlx_available(timeout_s: int = 5) -> bool:
    try:
        subprocess.run(
            [sys.executable, "-c", "import mlx.core as mx; print(mx.__name__)"],
            check=True,
            timeout=timeout_s,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return True
    except Exception:
        return False

if os.environ.get("DJPT_SKIP_MLX") == "1":
    MLX_AVAILABLE = False
else:
    MLX_AVAILABLE = _mlx_available()
if MLX_AVAILABLE:
    import mlx.core as mx  # type: ignore

from audio_ai_agent.ai.mlx_engine import MLXEngine, AudioMLXUtils

def test_mlx_engine_context_manager():
    """Test that MLXEngine can be used as a context manager."""
    with MLXEngine() as engine:
        assert engine is not None
        # Check if logger is initialized
        assert engine.logger is not None

def test_audio_mlx_utils_preprocess_numpy():
    """Test preprocessing with numpy input (fallback or convert)."""
    # Create stereo audio
    audio = np.random.rand(44100, 2).astype(np.float32)
    
    # Process
    processed = AudioMLXUtils.preprocess_audio(audio)
    
    # Check shape (should be mono 1D)
    if MLX_AVAILABLE:
        assert isinstance(processed, mx.array)
        assert processed.ndim == 1
        assert processed.shape[0] == 44100
        assert processed.dtype == mx.float32
    else:
        assert isinstance(processed, np.ndarray)
        assert processed.ndim == 1
        assert processed.shape[0] == 44100

def test_audio_mlx_utils_extract_features():
    """Test feature extraction."""
    # Create dummy audio
    audio = np.random.rand(44100).astype(np.float32)
    
    features = AudioMLXUtils.extract_features(audio)
    
    if MLX_AVAILABLE:
        assert isinstance(features, mx.array)
    else:
        assert isinstance(features, np.ndarray)
        
    # Shape should be (1, 4)
    assert features.shape == (1, 4)

def test_audio_mlx_utils_extract_features_empty_input():
    """Empty input should return a zero feature vector."""
    audio = np.array([], dtype=np.float32)
    features = AudioMLXUtils.extract_features(audio)

    assert features.shape == (1, 4)
    if MLX_AVAILABLE:
        assert isinstance(features, mx.array)
        assert np.allclose(np.array(features), np.zeros((1, 4), dtype=np.float32))
    else:
        assert isinstance(features, np.ndarray)
        assert np.allclose(features, np.zeros((1, 4), dtype=np.float32))

@pytest.mark.skipif(not MLX_AVAILABLE, reason="MLX not installed")
def test_create_audio_model():
    """Test model creation."""
    model = AudioMLXUtils.create_audio_model()
    import mlx.nn as nn
    assert isinstance(model, nn.Sequential)

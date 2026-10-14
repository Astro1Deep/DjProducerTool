from __future__ import annotations

import logging

import numpy as np

try:
    import mlx.core as mx  # type: ignore
    import mlx.nn as nn  # type: ignore

    MLX_AVAILABLE = True
except Exception:
    mx = None  # type: ignore
    nn = None  # type: ignore
    MLX_AVAILABLE = False


class MLXEngine:
    def __init__(self) -> None:
        self.logger = logging.getLogger("audio_ai_agent.ai.mlx_engine")

    def __enter__(self) -> "MLXEngine":
        return self

    def __exit__(self, exc_type, exc, tb) -> bool:
        return False


class AudioMLXUtils:
    @staticmethod
    def preprocess_audio(audio):
        arr = np.asarray(audio, dtype=np.float32)
        if arr.ndim == 2:
            arr = arr.mean(axis=1)
        if MLX_AVAILABLE:
            return mx.array(arr, dtype=mx.float32)
        return arr.astype(np.float32)

    @staticmethod
    def extract_features(audio):
        arr = np.asarray(audio, dtype=np.float32).reshape(-1)
        if arr.size == 0:
            features = np.zeros((1, 4), dtype=np.float32)
        else:
            rms = np.sqrt(np.mean(arr ** 2, dtype=np.float64))
            features = np.array(
                [[float(arr.mean()), float(arr.std()), float(np.max(np.abs(arr))), float(rms)]],
                dtype=np.float32,
            )
        if MLX_AVAILABLE:
            return mx.array(features, dtype=mx.float32)
        return features

    @staticmethod
    def create_audio_model():
        if not MLX_AVAILABLE:
            raise RuntimeError("MLX not available")
        return nn.Sequential(
            nn.Linear(4, 8),
            nn.ReLU(),
            nn.Linear(8, 4),
        )

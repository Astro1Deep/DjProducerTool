import io
import json
import sys
import types
from pathlib import Path

import pytest


REPO_ROOT = Path(__file__).resolve().parent.parent
LIB_DIR = REPO_ROOT / "lib"
if str(LIB_DIR) not in sys.path:
    sys.path.insert(0, str(LIB_DIR))

import ai_backend_manager as lib_ai_backend_manager  # noqa: E402


def test_scikit_learn_backend_returns_structured_response(tmp_path):
    sklearn = pytest.importorskip("sklearn")
    assert sklearn is not None

    manager = lib_ai_backend_manager.AIBackendManager(config_dir=tmp_path)
    response, error = manager.generate_response(
        "Necesito analizar BPM, key y mezcla armónica de varios temas",
        backend_name="scikit_learn",
    )

    assert error is None
    payload = json.loads(response)
    assert payload["backend"] == "scikit_learn"
    assert payload["top_category"] in {"dj_producing", "audio_analysis", "file_organization"}
    assert isinstance(payload["matched_categories"], list)
    assert payload["matched_categories"]


def test_openai_local_backend_uses_chat_completions_contract(tmp_path, monkeypatch):
    manager = lib_ai_backend_manager.AIBackendManager(config_dir=tmp_path)

    class _FakeResponse:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def read(self):
            return json.dumps(
                {
                    "choices": [
                        {
                            "message": {
                                "content": "Respuesta local estable",
                            }
                        }
                    ]
                }
            ).encode("utf-8")

    captured = {}

    def _fake_urlopen(request, timeout=0):
        captured["url"] = request.full_url
        captured["timeout"] = timeout
        captured["body"] = json.loads(request.data.decode("utf-8"))
        return _FakeResponse()

    monkeypatch.setattr(lib_ai_backend_manager.urllib.request, "urlopen", _fake_urlopen)

    response, error = manager.generate_response(
        "Resume el estado de mis backends",
        context="Contexto previo de prueba",
        backend_name="openai_local",
    )

    assert error is None
    assert response == "Respuesta local estable"
    assert captured["url"].endswith("/v1/chat/completions")
    assert captured["body"]["messages"][1]["content"].startswith("Contexto previo de prueba")


def test_transformers_backend_requires_local_model_config(tmp_path):
    manager = lib_ai_backend_manager.AIBackendManager(config_dir=tmp_path)
    response, error = manager.generate_response(
        "Genera una respuesta",
        backend_name="transformers",
    )

    assert response is None
    assert "requiere model_path/model local" in error


def test_transformers_backend_reads_canonical_config_when_state_config_missing(tmp_path, monkeypatch):
    repo_root = tmp_path / "repo"
    config_dir = repo_root / "config"
    model_dir = repo_root / "state" / "models" / "huggingface" / "all-MiniLM-L6-v2"
    config_dir.mkdir(parents=True, exist_ok=True)
    model_dir.mkdir(parents=True, exist_ok=True)
    (model_dir / "config.json").write_text("{}", encoding="utf-8")

    config_file = config_dir / "ai_model_params.toml"
    config_file.write_text(
        """
[transformers]
enabled = true
model_path = "state/models/huggingface/all-MiniLM-L6-v2"
local_files_only = true
max_tokens = 8
""".strip()
        + "\n",
        encoding="utf-8",
    )
    monkeypatch.setenv("DJPT_CONFIG_FILE", str(config_file))

    class _FakeTokenizer:
        called_with = None

        @classmethod
        def from_pretrained(cls, model_ref, local_files_only=True):
            cls.called_with = (model_ref, local_files_only)
            return cls()

        def __call__(self, text, return_tensors=None):
            self._text = text
            return {"input_ids": [1, 2, 3]}

        def decode(self, output, skip_special_tokens=True):
            return f"{self._text} RESPUESTA_LOCAL"

    class _FakeModel:
        called_with = None

        @classmethod
        def from_pretrained(cls, model_ref, local_files_only=True):
            cls.called_with = (model_ref, local_files_only)
            return cls()

        def generate(self, **kwargs):
            return [[1, 2, 3, 4]]

    fake_module = types.SimpleNamespace(
        AutoTokenizer=_FakeTokenizer,
        AutoModelForCausalLM=_FakeModel,
    )
    monkeypatch.setitem(sys.modules, "transformers", fake_module)

    manager = lib_ai_backend_manager.AIBackendManager(config_dir=tmp_path / "runtime")
    manager.repo_root = repo_root
    response, error = manager.generate_response("Genera una respuesta", backend_name="transformers")

    assert error is None
    assert response == "RESPUESTA_LOCAL"
    assert _FakeTokenizer.called_with == (str(model_dir.resolve()), True)
    assert _FakeModel.called_with == (str(model_dir.resolve()), True)

#!/usr/bin/env bash
# DJProducerTools AI runner compatibility layer.
# LOGS_DIR configurada sin shadowing para mantener un unico destino de logs.

# shellcheck shell=bash

DJPT_AI_TIMEOUT="${DJPT_AI_TIMEOUT:-300}"

_djpt_ai_runner_init() {
  if declare -f init_paths >/dev/null 2>&1; then
    init_paths
  fi

  local fallback_root fallback_log_dir
  fallback_root="${STATE_DIR:-${BASE_PATH:-$(pwd)}/state}"
  fallback_log_dir="$fallback_root/logs/ai"
  mkdir -p "$fallback_log_dir"

  if [ -z "${LOGS_DIR:-}" ]; then
    LOGS_DIR="$fallback_log_dir"  # LOGS_DIR configurada sin shadowing
  fi
}

_djpt_ai_runner_install_with_pip() {
  local pybin arch
  pybin="${PYTHON_BIN:-python3}"
  arch="$(uname -m)"

  if [ "$arch" = "arm64" ]; then
    "$pybin" -m pip install \
      mlx mlx-lm \
      tensorflow-macos==2.16.2 tensorflow-metal==1.2.0 onnxruntime-silicon \
      scikit-learn sentence-transformers torch psutil \
      PyPDF2 pdfplumber nltk requests beautifulsoup4 joblib
  else
    "$pybin" -m pip install \
      mlx mlx-lm \
      tensorflow==2.16.2 onnxruntime \
      scikit-learn sentence-transformers torch psutil \
      PyPDF2 pdfplumber nltk requests beautifulsoup4 joblib
  fi
}

install_ai_deps_robust() {
  _djpt_ai_runner_init

  local timeout_duration temp_file arch
  timeout_duration="${DJPT_AI_TIMEOUT:-300}"
  arch="$(uname -m)"
  temp_file="$(mktemp "${TMPDIR:-/tmp}/djpt_ai_runner.XXXXXX")"

  # El trap limpiará automáticamente el temp_file al terminar o fallar.
  trap 'rm -f "$temp_file"' EXIT
  printf 'timeout=%s\narch=%s\n' "$timeout_duration" "$arch" > "$temp_file"

  if declare -f ensure_python_deps >/dev/null 2>&1; then
    if [ "$arch" = "arm64" ]; then
      ensure_python_deps "AI_DEPS" \
        "mlx" "mlx-lm" \
        "tensorflow-macos==2.16.2" "tensorflow-metal==1.2.0" "onnxruntime-silicon" \
        "scikit-learn" "sentence-transformers" "torch" "psutil" \
        "PyPDF2" "pdfplumber" "nltk" "requests" "beautifulsoup4" "joblib"
    else
      ensure_python_deps "AI_DEPS" \
        "mlx" "mlx-lm" \
        "tensorflow==2.16.2" "onnxruntime" \
        "scikit-learn" "sentence-transformers" "torch" "psutil" \
        "PyPDF2" "pdfplumber" "nltk" "requests" "beautifulsoup4" "joblib"
    fi
    return $?
  fi

  _djpt_ai_runner_install_with_pip
}

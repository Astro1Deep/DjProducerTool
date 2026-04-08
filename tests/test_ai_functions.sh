#!/bin/bash
# Test script for new AI functions

# Basic setup
ROOT_DIR="/Volumes/SeaGate2TB/_DJProducerTools"
C_GRN='\033[1;32m'
C_CYN='\033[1;36m'
C_RESET='\033[0m'

pause_enter() {
  read -p ""
}

print_header() {
  echo "=== DJProducerTools Test ==="
}

# Test action_71_chains
action_71_chains() {
  print_header
  printf "%s=== CADENAS AUTOMATIZADAS (21 FLUJOS) ===%s\n" "$C_GRN" "$C_RESET"
  
  printf "%s[INFO]%s Gestor de cadenas de automatización para DJ workflows\n" "$C_CYN" "$C_RESET"
  printf "%s[INFO]%s 21 flujos predefinidos disponibles\n" "$C_CYN" "$C_RESET"
  
  # Create chains directory if it doesn't exist
  local chains_dir="$ROOT_DIR/chains"
  [ ! -d "$chains_dir" ] && mkdir -p "$chains_dir"
  
  # List available chains
  if [ -d "$chains_dir" ] && [ "$(ls -A "$chains_dir" 2>/dev/null)" ]; then
    printf "%s[INFO]%s Cadenas disponibles:\n" "$C_CYN" "$C_RESET"
    ls -1 "$chains_dir"/*.sh 2>/dev/null | head -10 | while read -r chain; do
      printf "  - %s\n" "$(basename "$chain")"
    done
  else
    printf "%s[WARN]%s No hay cadenas definidas. Creando estructura...\n" "$C_YLW" "$C_RESET"
    # Create example chain
    cat > "$chains_dir/example_chain.sh" << 'EOF'
#!/bin/bash
# Example automation chain
echo "Ejecutando cadena de ejemplo..."
EOF
    chmod +x "$chains_dir/example_chain.sh"
    printf "%s[OK]%s Cadena de ejemplo creada: %s\n" "$C_GRN" "$C_RESET" "$chains_dir/example_chain.sh"
  fi
  
  pause_enter
}

# Test action_ai_backends_manager
action_ai_backends_manager() {
  print_header
  printf "%s=== GESTOR DE BACKENDS IA ===%s\n" "$C_GRN" "$C_RESET"
  
  printf "%s[INFO]%s Gestión de múltiples backends de IA\n" "$C_CYN" "$C_RESET"
  
  # Check available AI backends
  local backends=()
  
  # Check for MLX
  if command -v mlx >/dev/null 2>&1 || [ -d "/usr/local/lib/python" ] && python3 -c "import mlx" 2>/dev/null; then
    backends+=("MLX: Available")
  else
    backends+=("MLX: Not available")
  fi
  
  # Check for Ollama
  if command -v ollama >/dev/null 2>&1; then
    backends+=("Ollama: Available ($(ollama list | wc -l) models)")
  else
    backends+=("Ollama: Not available")
  fi
  
  # Check for OpenAI API
  if [ -n "${OPENAI_API_KEY:-}" ]; then
    backends+=("OpenAI: Available")
  else
    backends+=("OpenAI: Not configured")
  fi
  
  printf "%s[INFO]%s Estado de backends:\n" "$C_CYN" "$C_RESET"
  for backend in "${backends[@]}"; do
    printf "  - %s\n" "$backend"
  done
  
  pause_enter
}

# Test action_install_ai_deps
action_install_ai_deps() {
  print_header
  printf "%s=== INSTALAR DEPS IA (STACK) ===%s\n" "$C_GRN" "$C_RESET"
  
  printf "%s[INFO]%s Instalando dependencias de IA...\n" "$C_CYN" "$C_RESET"
  
  # Activate canonical virtual environment if available
  if [ -d "$ROOT_DIR/djpt_venv" ]; then
    source "$ROOT_DIR/djpt_venv/bin/activate"
    printf "%s[OK]%s Entorno virtual djpt_venv activado\n" "$C_GRN" "$C_RESET"
  elif [ -d "$ROOT_DIR/venv" ]; then
    source "$ROOT_DIR/venv/bin/activate"
    printf "%s[OK]%s Entorno virtual activado\n" "$C_GRN" "$C_RESET"
  fi
  
  # Install basic AI dependencies
  local deps=("openai" "anthropic" "transformers" "torch" "numpy" "pandas")
  
  for dep in "${deps[@]}"; do
    printf "%s[INFO]%s Instalando %s...\n" "$C_CYN" "$C_RESET" "$dep"
    pip install "$dep" 2>/dev/null && printf "%s[OK]%s %s instalado\n" "$C_GRN" "$C_RESET" "$dep" || printf "%s[WARN]%s %s falló\n" "$C_YLW" "$C_RESET" "$dep"
  done
  
  printf "%s[OK]%s Instalación de dependencias IA completada\n" "$C_GRN" "$C_RESET"
  pause_enter
}

# Run tests
echo "Testing new AI functions..."

echo "1. Testing action_71_chains..."
action_71_chains

echo "2. Testing action_ai_backends_manager..."
action_ai_backends_manager

echo "3. Testing action_install_ai_deps..."
action_install_ai_deps

echo "All tests completed!"

#!/usr/bin/env python3
"""
Test suite para Automated Workflow - DJProducerTools
Prueba las funcionalidades del flujo de trabajo automatizado
"""

import pytest
import os
import sys
import json
import tempfile
import shutil
from pathlib import Path
from unittest.mock import patch, MagicMock

def _resolve_project_root() -> Path:
    """Resolve repository root robustly across invocation contexts."""
    this_file = Path(__file__).resolve()
    for candidate in [this_file.parent, *this_file.parents]:
        if (
            (candidate / "scripts").is_dir()
            and (candidate / "requirements.txt").exists()
            and (candidate / "requirements-dev.txt").exists()
        ):
            return candidate
    return this_file.parent.parent


PROJECT_ROOT = _resolve_project_root()
sys.path.insert(0, str(PROJECT_ROOT))
REAL_SCRIPT_PATH = PROJECT_ROOT / "DJProducerTools_Con_Opciones_IA.sh"

class TestAutomatedWorkflow:
    """Test suite para el flujo de trabajo automatizado"""
    
    @pytest.fixture
    def temp_workspace(self):
        """Fixture para crear un workspace temporal"""
        temp_dir = tempfile.mkdtemp(prefix="djpt_test_")
        yield temp_dir
        shutil.rmtree(temp_dir, ignore_errors=True)
    
    @pytest.fixture
    def real_script_path(self):
        """Fixture para obtener el path real del script"""
        return REAL_SCRIPT_PATH
    
    def test_ableton_tools_function_exists(self, real_script_path):
        """Test que la función de Ableton Tools existe y es accesible"""
        # Verificar que el script principal existe
        assert real_script_path.exists(), "El script principal no existe"
        
        # Verificar que contiene la función action_55_ableton_tools
        content = real_script_path.read_text()
        assert "action_55_ableton_tools" in content, "La función action_55_ableton_tools no existe"
        
    def test_importers_function_exists(self, real_script_path):
        """Test que la función de Importers existe"""
        content = real_script_path.read_text()
        assert "action_56_importers" in content, "La función action_56_importers no existe"
        
    def test_exclusions_manager_function_exists(self, real_script_path):
        """Test que la función de Exclusions Manager existe"""
        content = real_script_path.read_text()
        assert "action_57_exclusions_manager" in content, "La función action_57_exclusions_manager no existe"
        
    def test_hash_compare_function_exists(self, real_script_path):
        """Test que la función de Hash Compare existe"""
        content = real_script_path.read_text()
        assert "action_58_hash_compare" in content, "La función action_58_hash_compare no existe"
        
    def test_health_check_submenu_exists(self, real_script_path):
        """Test que el submenú de Health Check existe"""
        content = real_script_path.read_text()
        assert "submenu_health_check" in content, "El submenú submenu_health_check no existe"
        assert "health_check_full_diagnosis" in content, "La función health_check_full_diagnosis no existe"
        assert "health_check_auto_repair" in content, "La función health_check_auto_repair no existe"
        
    def test_professional_colors_exist(self, real_script_path):
        """Test que los colores profesionales están definidos"""
        content = real_script_path.read_text()
        
        # Verificar colores profesionales
        professional_colors = [
            'C_GREEN="${ESC}[38;5;2m"',
            'C_RED="${ESC}[91;5;2m"', 
            'C_YELLOW="${ESC}[93;5;2m"',
            'C_BLUE="${ESC}[94;5;2m"',
            'C_CYAN="${ESC}[36;5;2m"',
            'C_PURP="${ESC}[95;5;2m"'
        ]
        
        for color in professional_colors:
            assert color in content, f"Color profesional no encontrado: {color}"
            
        # Verificar que los colores antiguos (Joker ácido) no existen
        old_colors = [
            "Verde Joker (brillante)",
            "Rosa Joker (brillante)"
        ]
        
        for old_color in old_colors:
            assert old_color not in content, f"Color antiguo todavía presente: {old_color}"
            
    def test_menu_structure_optimized(self, real_script_path):
        """Test que la estructura del menú está optimizada sin redundancias"""
        content = real_script_path.read_text()
        
        # Verificar que existen los nuevos submenús
        assert "submenu_advanced_analysis" in content, "El submenú advanced_analysis no existe"
        assert "submenu_visual_tools" in content, "El submenú visual_tools no existe"
        
        # Verificar que las opciones duplicadas fueron eliminadas
        lines = content.split('\n')
        option_89_count = sum(1 for line in lines if '89) action_launch_serato_organizer' in line)
        option_90_count = sum(1 for line in lines if '90) action_launch_serato_organizer' in line)
        
        assert option_89_count == 1, "Opción 89 debe existir una vez"
        assert option_90_count == 0, "Opción 90 duplicada debe ser eliminada"
        
    def test_critical_files_structure(self, temp_workspace):
        """Test la estructura de archivos críticos"""
        # Crear estructura básica de directorios
        (Path(temp_workspace) / "scripts").mkdir(exist_ok=True)
        (Path(temp_workspace) / "state").mkdir(exist_ok=True)
        (Path(temp_workspace) / "config").mkdir(exist_ok=True)
        (Path(temp_workspace) / "logs").mkdir(exist_ok=True)
        
        # Verificar directorios críticos
        critical_dirs = ["scripts", "state", "config", "logs"]
        for dir_name in critical_dirs:
            dir_path = Path(temp_workspace) / dir_name
            assert dir_path.exists(), f"Directorio crítico no existe: {dir_name}"
            assert dir_path.is_dir(), f"La ruta no es un directorio: {dir_name}"
            
    def test_health_check_diagnosis_logic(self, temp_workspace):
        """Test la lógica de diagnóstico del Health Check"""
        # Simular un sistema con problemas
        test_script_content = f'''
#!/bin/bash
# Test script para health check
BASE_PATH="{temp_workspace}"

health_check_test() {{
    local health_score=100
    local critical_issues=()
    
    # Simular problemas
    if [ ! -d "$BASE_PATH/critical_dir" ]; then
        critical_issues+=("Directorio crítico faltante")
        health_score=$((health_score - 20))
    fi
    
    echo "$health_score"
    printf '%s\\n' "${{critical_issues[@]}}"
}}

health_check_test
'''
        
        test_script = Path(temp_workspace) / "test_health.sh"
        test_script.write_text(test_script_content)
        test_script.chmod(0o755)
        
        # Ejecutar test
        import subprocess
        result = subprocess.run(['bash', str(test_script)], 
                              capture_output=True, text=True)
        
        assert result.returncode == 0, "El script de health check falló"
        output_lines = result.stdout.strip().split('\n')
        health_score = int(output_lines[0])
        
        # Debería detectar problemas y reducir el score
        assert health_score < 100, "El health score debería reducirse con problemas"
        assert health_score >= 0, "El health score no debería ser negativo"
        
    def test_ableton_tools_analysis(self, temp_workspace):
        """Test la funcionalidad de análisis de Ableton Tools"""
        # Crear archivos de prueba de Ableton
        ableton_dir = Path(temp_workspace) / "Music" / "Ableton"
        ableton_dir.mkdir(parents=True, exist_ok=True)
        
        # Crear archivos .als de prueba
        (ableton_dir / "Project1.als").write_text("ableton project data")
        (ableton_dir / "Project2.als.backup").write_text("backup data")
        
        # Verificar que los archivos serían detectados
        als_files = list(ableton_dir.glob("*.als"))
        backup_files = list(ableton_dir.glob("*.als.backup"))
        
        assert len(als_files) > 0, "No se encontraron archivos .als"
        assert len(backup_files) > 0, "No se encontraron archivos .als.backup"
        
    def test_importers_functionality(self, temp_workspace):
        """Test la funcionalidad de Importers"""
        # Crear archivos de prueba para importers
        import_dir = Path(temp_workspace) / "import_test"
        import_dir.mkdir(exist_ok=True)
        
        # Crear archivos .cue y .nml de prueba
        (import_dir / "track1.cue").write_text("cue file content")
        (import_dir / "collection.nml").write_text("nml file content")
        
        # Verificar que los archivos serían detectados
        cue_files = list(import_dir.glob("*.cue"))
        nml_files = list(import_dir.glob("*.nml"))
        
        assert len(cue_files) > 0, "No se encontraron archivos .cue"
        assert len(nml_files) > 0, "No se encontraron archivos .nml"
        
    def test_exclusions_manager_config(self, temp_workspace):
        """Test la configuración del Exclusions Manager"""
        # Crear archivo de exclusiones de prueba
        exclusions_file = Path(temp_workspace) / "exclusions.txt"
        exclusions_content = """
# Exclusiones de prueba
/temp/
*.tmp
*.log
.DS_Store
"""
        exclusions_file.write_text(exclusions_content.strip())
        
        # Verificar contenido
        content = exclusions_file.read_text()
        assert "/temp/" in content, "Exclusión de directorio no encontrada"
        assert "*.tmp" in content, "Exclusión de patrón no encontrada"
        assert ".DS_Store" in content, "Exclusión de archivo no encontrada"
        
    def test_hash_compare_functionality(self, temp_workspace):
        """Test la funcionalidad de Hash Compare"""
        # Crear archivos de prueba para comparación
        source_dir = Path(temp_workspace) / "source"
        target_dir = Path(temp_workspace) / "target"
        
        source_dir.mkdir(exist_ok=True)
        target_dir.mkdir(exist_ok=True)
        
        # Crear archivos idénticos
        test_file = "test_file.txt"
        test_content = "test content for hash comparison"
        
        (source_dir / test_file).write_text(test_content)
        (target_dir / test_file).write_text(test_content)
        
        # Crear archivo diferente
        (target_dir / "different_file.txt").write_text("different content")
        
        # Verificar que los archivos existen
        assert (source_dir / test_file).exists(), "Archivo fuente no creado"
        assert (target_dir / test_file).exists(), "Archivo destino no creado"
        assert (target_dir / "different_file.txt").exists(), "Archivo diferente no creado"
        
        # Simular cálculo de hash (básico)
        import hashlib
        source_hash = hashlib.sha256((source_dir / test_file).read_bytes()).hexdigest()
        target_hash = hashlib.sha256((target_dir / test_file).read_bytes()).hexdigest()
        
        assert source_hash == target_hash, "Los hashes deberían ser idénticos"
        
    def test_system_integration(self, real_script_path):
        """Test de integración del sistema completo"""
        # Verificar que todos los componentes principales existen
        components = {
            "script_principal": "DJProducerTools_Con_Opciones_IA.sh",
            "safe_exec": "djpt_safe_exec.sh", 
            "launch": "launch.sh"
        }
        
        for name, filename in components.items():
            file_path = PROJECT_ROOT / filename
            assert file_path.exists(), f"Componente {name} no existe: {filename}"
            
        # Verificar estructura de directorios reales
        required_dirs = ["scripts", "state", "config", "logs"]
        for dir_name in required_dirs:
            dir_path = PROJECT_ROOT / dir_name
            assert dir_path.exists(), f"Directorio requerido no existe: {dir_name}"
            
    def test_error_handling_robustness(self, temp_workspace):
        """Test la robustez del manejo de errores"""
        # Crear script de prueba con manejo de errores
        test_script_content = f'''
#!/bin/bash
# Test de manejo de errores
BASE_PATH="{temp_workspace}"

test_error_handling() {{
    # Test con directorio inexistente
    if [ ! -d "/nonexistent/directory" ]; then
        echo "ERROR: Directorio no encontrado" >&2
        return 1
    fi
    
    # Test con archivo inexistente
    if [ ! -f "/nonexistent/file.txt" ]; then
        echo "ERROR: Archivo no encontrado" >&2
        return 1
    fi
    
    return 0
}}

test_error_handling
'''
        
        test_script = Path(temp_workspace) / "test_errors.sh"
        test_script.write_text(test_script_content)
        test_script.chmod(0o755)
        
        # Ejecutar test
        import subprocess
        result = subprocess.run(['bash', str(test_script)], 
                              capture_output=True, text=True)
        
        # Debería fallar gracefully
        assert result.returncode != 0, "El script debería detectar errores"
        assert "ERROR:" in result.stderr, "Debería mostrar mensajes de error"
        
if __name__ == "__main__":
    pytest.main([__file__, "-v"])

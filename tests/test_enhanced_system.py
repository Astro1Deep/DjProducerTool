#!/usr/bin/env python3
"""
Enhanced System Test Suite for DJProducerTools
Suite de pruebas completa para el sistema mejorado con capacidades avanzadas
"""

import pytest
import os
import sys
import json
import time
import tempfile
import shutil
from pathlib import Path
from unittest.mock import patch, MagicMock
import subprocess

# Agregar el path del proyecto
sys.path.insert(0, str(Path(__file__).parent.parent))

from lib.enhanced_workflow_engine import EnhancedWorkflowEngine, WorkflowTask, ExecutionMode
from lib.ai_power_analyzer import AIPowerAnalyzer
from lib.smart_execution_engine import SmartExecutionEngine, SmartTask, TaskPriority, ExecutionMode
from lib.predictive_system_optimizer import PredictiveSystemOptimizer

class TestEnhancedSystem:
    """Suite de pruebas para el sistema mejorado"""
    
    @pytest.fixture
    def temp_workspace(self):
        """Fixture para crear un workspace temporal"""
        temp_dir = tempfile.mkdtemp(prefix="djpt_enhanced_test_")
        yield Path(temp_dir)
        shutil.rmtree(temp_dir, ignore_errors=True)
    
    @pytest.fixture
    def enhanced_engine(self):
        """Fixture para crear motor mejorado"""
        return EnhancedWorkflowEngine(Path("/tmp"), max_workers=2)
    
    @pytest.fixture
    def smart_engine(self):
        """Fixture para crear motor inteligente"""
        return SmartExecutionEngine(Path("/tmp"), max_workers=2)
    
    @pytest.fixture
    def ai_analyzer(self):
        """Fixture para crear analizador IA"""
        return AIPowerAnalyzer(Path("/tmp"))
    
    @pytest.fixture
    def predictive_optimizer(self):
        """Fixture para crear optimizador predictivo"""
        return PredictiveSystemOptimizer(Path("/tmp"))
    
    def test_enhanced_workflow_basic_execution(self, enhanced_engine):
        """Prueba básica de ejecución de flujo mejorado"""
        # Crear tareas de prueba
        tasks = [
            WorkflowTask(
                name="test_task_1",
                command=["echo", "Test 1 completed"],
                priority=1,
                timeout=10
            ),
            WorkflowTask(
                name="test_task_2",
                command=["echo", "Test 2 completed"],
                priority=2,
                dependencies=["test_task_1"]
            )
        ]
        
        # Agregar tareas al motor
        for task in tasks:
            enhanced_engine.add_task(task)
        
        # Ejecutar flujo
        result = enhanced_engine.execute_workflow("test_workflow")
        
        # Verificaciones
        assert result["workflow_name"] == "test_workflow"
        assert result["tasks_executed"] == 2
        assert result["success_rate"] == 100.0
        assert len(result["results"]) == 2
        assert "total_duration" in result
    
    def test_smart_execution_parallel_mode(self, smart_engine):
        """Prueba de modo paralelo del motor inteligente"""
        # Crear tareas paralelas
        tasks = [
            SmartTask(
                name="parallel_task_1",
                command=["sleep", "1"],
                mode=ExecutionMode.PARALLEL,
                priority=TaskPriority.NORMAL,
                timeout=5
            ),
            SmartTask(
                name="parallel_task_2",
                command=["sleep", "1"],
                mode=ExecutionMode.PARALLEL,
                priority=TaskPriority.NORMAL,
                timeout=5
            )
        ]
        
        # Agregar tareas
        for task in tasks:
            smart_engine.add_task(task)
        
        # Ejecutar en modo paralelo
        result = smart_engine.execute_workflow("parallel_test", ExecutionMode.PARALLEL)
        
        # Verificaciones
        assert result["execution_mode"] == "parallel"
        assert result["tasks_executed"] == 2
        assert result["success_rate"] == 100.0
        assert "resource_usage" in result
    
    def test_smart_execution_adaptive_mode(self, smart_engine):
        """Prueba de modo adaptivo del motor inteligente"""
        # Crear tareas mixtas
        tasks = [
            SmartTask(
                name="adaptive_task_1",
                command=["echo", "Adaptive 1"],
                mode=ExecutionMode.SEQUENTIAL,
                priority=TaskPriority.HIGH,
                timeout=5
            ),
            SmartTask(
                name="adaptive_task_2",
                command=["echo", "Adaptive 2"],
                mode=ExecutionMode.PARALLEL,
                priority=TaskPriority.NORMAL,
                dependencies=["adaptive_task_1"],
                timeout=5
            ),
            SmartTask(
                name="adaptive_task_3",
                command=["echo", "Adaptive 3"],
                mode=ExecutionMode.PARALLEL,
                priority=TaskPriority.LOW,
                timeout=5
            )
        ]
        
        for task in tasks:
            smart_engine.add_task(task)
        
        # Ejecutar en modo adaptivo
        result = smart_engine.execute_workflow("adaptive_test", ExecutionMode.ADAPTIVE)
        
        # Verificaciones
        assert result["execution_mode"] == "adaptive"
        assert result["tasks_executed"] == 3
        assert result["success_rate"] == 100.0
    
    def test_ai_power_analyzer_basic(self, ai_analyzer, temp_workspace):
        """Prueba básica del analizador IA"""
        # Crear archivos de prueba
        test_script = temp_workspace / "test_script.sh"
        test_script.write_text("""#!/bin/bash
echo "Test script"
rm -rf /tmp/test_file  # This should trigger a security warning
eval 'echo "Test eval"'  # This should trigger a security warning
""")
        
        test_python = temp_workspace / "test_python.py"
        test_python.write_text("""import mlx  # This should trigger MLX warning
def test_function():
    pass  # Missing documentation
""")
        
        # Ejecutar análisis
        result = ai_analyzer.analyze_system_comprehensive(str(temp_workspace))
        
        # Verificaciones
        assert "analysis_results" in result
        assert "bash_analysis" in result["analysis_results"]
        assert "python_analysis" in result["analysis_results"]
        assert result["overall_score"] < 100  # Debe haber penalizado por issues
    
    def test_predictive_optimizer_basic(self, predictive_optimizer):
        """Prueba básica del optimizador predictivo"""
        # Crear datos de prueba simulados
        test_metrics = {
            "cpu": {"percent_usage": 85.0, "frequency_mhz": 2400, "core_count": 4},
            "memory": {"percent_usage": 75.0, "used_gb": 6.0, "available_gb": 2.0},
            "disk": {"percent_usage": 70.0, "used_gb": 350.0, "free_gb": 150.0},
            "network": {"bytes_sent": 1000000, "bytes_recv": 2000000},
            "processes": {"total_count": 150}
        }
        
        # Ejecutar optimización
        result = predictive_optimizer.analyze_and_optimize(test_metrics)
        
        # Verificaciones
        assert "current_metrics" in result
        assert "predictions" in result
        assert "recommendations" in result
        assert "optimization_plan" in result
        assert result["improvement_potential"] > 0
    
    def test_integration_workflow_ai_analysis(self, enhanced_engine, ai_analyzer, temp_workspace):
        """Prueba de integración entre motor de flujo y análisis IA"""
        # Crear tarea que ejecuta análisis IA
        analysis_task = WorkflowTask(
            name="ai_analysis_task",
            command=["python3", "lib/ai_power_analyzer.py", str(temp_workspace)],
            priority=TaskPriority.HIGH,
            timeout=60
        )
        
        enhanced_engine.add_task(analysis_task)
        
        # Ejecutar flujo
        workflow_result = enhanced_engine.execute_workflow("integration_test")
        
        # Verificar que el análisis IA se ejecutó
        assert workflow_result["success_rate"] == 100.0
        assert len(workflow_result["results"]) == 1
        
        # Verificar resultados del análisis IA
        analysis_result = workflow_result["results"][0]
        assert "analysis_results" in analysis_result["output"]
    
    def test_error_handling_and_recovery(self, smart_engine):
        """Prueba de manejo de errores y recuperación"""
        # Crear tarea que fallará intencionalmente
        failing_task = SmartTask(
            name="failing_task",
                command=["python3", "-c", "import sys; sys.exit(1)"],
                priority=TaskPriority.NORMAL,
                timeout=10,
                retry_count=2,
                rollback_commands=["echo", "Rollback executed"]
        )
        
        # Crear tarea de recuperación
        recovery_task = SmartTask(
            name="recovery_task",
            command=["echo", "Recovery completed"],
            priority=TaskPriority.LOW,
            dependencies=["failing_task"]
        )
        
        smart_engine.add_task(failing_task)
        smart_engine.add_task(recovery_task)
        
        # Ejecutar flujo
        result = smart_engine.execute_workflow("error_recovery_test")
        
        # Verificaciones
        assert result["tasks_executed"] == 2
        
        # Encontrar tarea fallida y tarea de recuperación
        failing_result = None
        recovery_result = None
        for task_result in result["results"]:
            if task_result["task_name"] == "failing_task":
                failing_result = task_result
            elif task_result["task_name"] == "recovery_task":
                recovery_result = task_result
        
        # Verificar manejo de error
        assert failing_result is not None
        assert failing_result["success"] == False
        assert failing_result["error"] is not None
        
        # Verificar recuperación exitosa
        assert recovery_result is not None
        assert recovery_result["success"] == True
    
    def test_performance_monitoring(self, smart_engine):
        """Prueba de monitoreo de rendimiento"""
        # Crear tareas con diferentes características de rendimiento
        cpu_intensive_task = SmartTask(
            name="cpu_intensive",
            command=["python3", "-c", "import time; [i**2 for i in range(1000000)]"],
            priority=TaskPriority.NORMAL,
            timeout=30,
            metadata={"cpu_intensive": True}
        )
        
        memory_intensive_task = SmartTask(
            name="memory_intensive",
            command=["python3", "-c", "import sys; data = b'x' * 10000000; len(data)"],
            priority=TaskPriority.NORMAL,
            timeout=30,
            metadata={"memory_intensive": True}
        )
        
        smart_engine.add_task(cpu_intensive_task)
        smart_engine.add_task(memory_intensive_task)
        
        # Ejecutar en modo rendimiento
        result = smart_engine.execute_workflow("performance_test", ExecutionMode.PERFORMANCE)
        
        # Verificaciones de monitoreo
        assert "resource_usage" in result
        resource_usage = result["resource_usage"]
        
        # Debe haber detectado alto uso de CPU y memoria
        assert resource_usage["avg_cpu_usage"] > 50  # CPU intensive task
        assert resource_usage["max_cpu_usage"] > 50
        assert resource_usage["avg_memory_usage"] > 100  # Memory intensive task
        assert resource_usage["max_memory_usage"] > 100
    
    def test_workflow_persistence(self, enhanced_engine):
        """Prueba de persistencia de flujos de trabajo"""
        # Crear flujo de prueba
        tasks = [
            WorkflowTask(
                name="persistence_test_1",
                command=["echo", "Persistence test 1"],
                priority=TaskPriority.NORMAL
            )
        ]
        
        for task in tasks:
            enhanced_engine.add_task(task)
        
        # Ejecutar primer flujo
        result1 = enhanced_engine.execute_workflow("persistence_test_1")
        
        # Verificar historial
        history = enhanced_engine.get_workflow_history(5)
        assert len(history) >= 1
        assert history[0]["workflow_name"] == "persistence_test_1"
        
        # Ejecutar segundo flujo
        result2 = enhanced_engine.execute_workflow("persistence_test_2")
        
        # Verificar que ambos flujos están en historial
        updated_history = enhanced_engine.get_workflow_history(10)
        workflow_names = [h["workflow_name"] for h in updated_history]
        assert "persistence_test_1" in workflow_names
        assert "persistence_test_2" in workflow_names
    
    def test_task_dependencies_and_priorities(self, enhanced_engine):
        """Prueba de dependencias y prioridades de tareas"""
        # Crear tareas con dependencias complejas
        tasks = [
            WorkflowTask(
                name="dep_task_1",
                command=["echo", "Dependency 1"],
                priority=TaskPriority.CRITICAL,
                timeout=10
            ),
            WorkflowTask(
                name="dep_task_2",
                command=["echo", "Dependency 2"],
                priority=TaskPriority.HIGH,
                dependencies=["dep_task_1"],
                timeout=10
            ),
            WorkflowTask(
                name="dep_task_3",
                command=["echo", "Dependency 3"],
                priority=TaskPriority.NORMAL,
                dependencies=["dep_task_1", "dep_task_2"],
                timeout=10
            ),
            WorkflowTask(
                name="dep_task_4",
                command=["echo", "Dependency 4"],
                priority=TaskPriority.LOW,
                dependencies=["dep_task_2", "dep_task_3"],
                timeout=10
            )
        ]
        
        # Agregar en orden desordenado para probar ordenamiento
        for task in tasks:
            enhanced_engine.add_task(task)
        
        # Ejecutar flujo
        result = enhanced_engine.execute_workflow("dependency_test")
        
        # Verificar orden de ejecución (debe ser por dependencias)
        executed_order = [r["task_name"] for r in result["results"]]
        
        # dep_task_1 debe ejecutarse primero (sin dependencias)
        assert executed_order[0] == "dep_task_1"
        
        # dep_task_2 debe ejecutarse segundo (solo depende de dep_task_1)
        assert executed_order[1] == "dep_task_2"
        
        # dep_task_3 debe ejecutarse tercero (depende de 1 y 2)
        assert executed_order[2] == "dep_task_3"
        
        # dep_task_4 debe ejecutarse cuarto (depende de 2 y 3)
        assert executed_order[3] == "dep_task_4"
    
    def test_optimization_recommendations(self, predictive_optimizer):
        """Prueba de generación de recomendaciones de optimización"""
        # Simular métricas que requieren optimización
        problematic_metrics = {
            "cpu": {"percent_usage": 95.0},  # Alto uso de CPU
            "memory": {"percent_usage": 90.0},  # Alto uso de memoria
            "disk": {"percent_usage": 95.0},  # Disco casi lleno
            "network": {"bytes_sent": 1000000, "bytes_recv": 2000000},
            "processes": {"total_count": 250}  # Muchos procesos
        }
        
        # Ejecutar optimización
        result = predictive_optimizer.analyze_and_optimize(problematic_metrics)
        
        # Verificaciones
        recommendations = result["recommendations"]
        
        # Debe haber recomendaciones para CPU, memoria y disco
        cpu_recs = [r for r in recommendations if "cpu" in r.action.lower()]
        memory_recs = [r for r in recommendations if "memory" in r.action.lower()]
        disk_recs = [r for r in recommendations if "disk" in r.action.lower()]
        
        assert len(cpu_recs) > 0
        assert len(memory_recs) > 0
        assert len(disk_recs) > 0
        
        # Verificar prioridades
        high_priority_recs = [r for r in recommendations if r.priority == "high"]
        assert len(high_priority_recs) > 0  # Debe haber recomendaciones de alta prioridad
        
        # Verificar potencial de mejora
        assert result["improvement_potential"] > 20  # Debe haber potencial significativo
    
    def test_system_health_calculation(self, predictive_optimizer):
        """Prueba de cálculo de salud del sistema"""
        # Probar diferentes escenarios de salud
        
        # Escenario 1: Sistema saludable
        healthy_metrics = {
            "cpu": {"percent_usage": 45.0},
            "memory": {"percent_usage": 50.0},
            "disk": {"percent_usage": 60.0},
            "network": {"bytes_sent": 1000, "bytes_recv": 2000},
            "processes": {"total_count": 80}
        }
        
        result1 = predictive_optimizer.analyze_and_optimize(healthy_metrics)
        assert result1["system_health_score"] >= 85  # Saludable
        
        # Escenario 2: Sistema con problemas
        unhealthy_metrics = {
            "cpu": {"percent_usage": 95.0},
            "memory": {"percent_usage": 90.0},
            "disk": {"percent_usage": 95.0},
            "network": {"bytes_sent": 1000, "bytes_recv": 2000},
            "processes": {"total_count": 200}
        }
        
        result2 = predictive_optimizer.analyze_and_optimize(unhealthy_metrics)
        assert result2["system_health_score"] < 50  # No saludable
        
        # Escenario 3: Sistema crítico
        critical_metrics = {
            "cpu": {"percent_usage": 99.0},
            "memory": {"percent_usage": 98.0},
            "disk": {"percent_usage": 99.0},
            "network": {"bytes_sent": 1000, "bytes_recv": 2000},
            "processes": {"total_count": 300}
        }
        
        result3 = predictive_optimizer.analyze_and_optimize(critical_metrics)
        assert result3["system_health_score"] < 30  # Crítico

if __name__ == "__main__":
    # Ejecutar pruebas directamente
    pytest.main([__file__, "-v"])

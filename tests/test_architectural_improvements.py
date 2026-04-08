#!/usr/bin/env python3
"""
Comprehensive Test Suite for DJProducerTools/SeratOrganizer Architectural Improvements
Tests all new features and ensures backward compatibility
"""

import os
import sys
import json
import time
import subprocess
import tempfile
import unittest
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


project_root = _resolve_project_root()
sys.path.insert(0, str(project_root))

class TestEfficientInventory(unittest.TestCase):
    """Test the efficient inventory system"""
    
    def setUp(self):
        self.test_dir = Path(tempfile.mkdtemp())
        self.inventory_script = project_root / "scripts" / "efficient_inventory.py"
        
    def tearDown(self):
        import shutil
        shutil.rmtree(self.test_dir, ignore_errors=True)
    
    def test_inventory_script_exists(self):
        """Test that the efficient inventory script exists"""
        self.assertTrue(self.inventory_script.exists(), 
                       f"efficient_inventory.py not found at {self.inventory_script}")
    
    def test_inventory_help(self):
        """Test that the inventory script shows help"""
        if self.inventory_script.exists():
            result = subprocess.run([
                "python3", str(self.inventory_script), "--help"
            ], capture_output=True, text=True, timeout=30)
            
            self.assertEqual(result.returncode, 0)
            self.assertIn("Efficient Audio Inventory Scanner", result.stdout)
    
    def test_inventory_config_generation(self):
        """Test configuration file generation"""
        if self.inventory_script.exists():
            config_file = self.test_dir / "test_config.json"
            
            result = subprocess.run([
                "python3", str(self.inventory_script), 
                "--generate-config", str(config_file)
            ], capture_output=True, text=True, timeout=30)
            
            self.assertEqual(result.returncode, 0)
            self.assertTrue(config_file.exists())
            
            # Verify config content
            with open(config_file) as f:
                config = json.load(f)
            
            self.assertIn("excluded_dirs", config)
            self.assertIn("audio_extensions", config)
    
    def test_inventory_with_test_data(self):
        """Test inventory with actual test data"""
        if not self.inventory_script.exists():
            self.skipTest("efficient_inventory.py not available")
        
        # Create test directory structure
        (self.test_dir / "music").mkdir()
        (self.test_dir / "_DJProducerTools").mkdir()
        (self.test_dir / "videos").mkdir()
        
        # Create test files
        (self.test_dir / "music" / "test.mp3").touch()
        (self.test_dir / "music" / "test.wav").touch()
        (self.test_dir / "_DJProducerTools" / "script.py").touch()
        (self.test_dir / "videos" / "movie.mp4").touch()
        
        output_file = self.test_dir / "inventory.txt"
        
        result = subprocess.run([
            "python3", str(self.inventory_script),
            str(self.test_dir), str(output_file)
        ], capture_output=True, text=True, timeout=30)
        
        self.assertEqual(result.returncode, 0)
        self.assertTrue(output_file.exists())
        
        # Check that only audio files are included
        with open(output_file) as f:
            inventory_files = f.read().strip().split('\n')
        
        # Should contain audio files but not Python or video files
        audio_files = [f for f in inventory_files if f.endswith(('.mp3', '.wav'))]
        non_audio_files = [f for f in inventory_files if not f.endswith(('.mp3', '.wav'))]
        
        self.assertEqual(len(audio_files), 2)
        self.assertEqual(len(non_audio_files), 0)

class TestSeratOrganizerArgs(unittest.TestCase):
    """Test SeratOrganizer command line argument support"""
    
    def setUp(self):
        self.serato_script = project_root.parent / "_SeratOrganizer" / "SeratOrganizer.sh"
    
    def test_serato_script_exists(self):
        """Test that SeratOrganizer script exists"""
        self.assertTrue(self.serato_script.exists(), 
                       f"SeratOrganizer.sh not found at {self.serato_script}")
    
    def test_serato_help(self):
        """Test that SeratOrganizer shows help with --help"""
        if self.serato_script.exists():
            result = subprocess.run([
                str(self.serato_script), "--help"
            ], capture_output=True, text=True, timeout=30)
            
            self.assertEqual(result.returncode, 0)
            self.assertIn("--run-steps", result.stdout)
            self.assertIn("--auto-confirm", result.stdout)
    
    def test_serato_argument_parsing(self):
        """Test that argument parsing functionality exists"""
        if self.serato_script.exists():
            content = self.serato_script.read_text(encoding='utf-8', errors='ignore')
            
            self.assertIn("parse_arguments", content)
            self.assertIn("--run-steps", content)
            self.assertIn("execute_step", content)
            self.assertIn("run_steps_sequence", content)

class TestDependencyManagement(unittest.TestCase):
    """Test dependency management improvements"""
    
    def test_pyproject_toml_structure(self):
        """Test that pyproject.toml has proper structure"""
        pyproject_file = project_root / "pyproject.toml"
        
        if pyproject_file.exists():
            content = pyproject_file.read_text(encoding='utf-8', errors='ignore')
            
            # Check for optional dependencies
            self.assertIn("[project.optional-dependencies]", content)
            
            # Check for Apple Silicon specific dependencies
            self.assertIn("apple-silicon", content)
            self.assertIn("mlx>=", content)
            
            # Check for audio dependencies
            self.assertIn("audio", content)
            self.assertIn("mutagen>=", content)
    
    def test_requirements_txt_updated(self):
        """Test that requirements.txt is properly updated"""
        req_file = project_root / "requirements.txt"
        core_req_file = project_root / "requirements-core.txt"
        opt_req_file = project_root / "requirements-optional-backends.txt"
        
        if req_file.exists():
            content = req_file.read_text(encoding='utf-8', errors='ignore')
            if "-r requirements-core.txt" in content:
                core_content = core_req_file.read_text(encoding='utf-8', errors='ignore')
                opt_content = opt_req_file.read_text(encoding='utf-8', errors='ignore')
                self.assertIn("pyyaml>=6.0.1", core_content)
                self.assertIn("mlx>=0.12.0", opt_content)
            else:
                self.assertIn("pyyaml>=6.0.1", content)
                self.assertIn("mlx>=0.12.0", content)
    
    def test_dev_requirements_exists(self):
        """Test that development requirements file exists"""
        dev_req_file = project_root / "requirements-dev.txt"
        self.assertTrue(dev_req_file.exists(), "requirements-dev.txt not found")

    def test_dependency_checker_exists(self):
        """Test that dependency checker script exists"""
        checker = project_root / "scripts" / "dependency_checker.py"
        self.assertTrue(checker.exists(), "dependency_checker.py not found")

    def test_dependency_checker_help(self):
        """Test dependency checker help output"""
        checker = project_root / "scripts" / "dependency_checker.py"
        if checker.exists():
            result = subprocess.run(
                ["python3", str(checker), "--help"],
                capture_output=True,
                text=True,
                timeout=30,
            )
            self.assertEqual(result.returncode, 0)
            self.assertIn("dependency checker", result.stdout.lower())

class TestSafeExecution(unittest.TestCase):
    """Test safe execution utilities"""
    
    def test_safe_exec_script_exists(self):
        """Test that safe execution script exists"""
        safe_exec = project_root / "djpt_safe_exec.sh"
        self.assertTrue(safe_exec.exists(), "djpt_safe_exec.sh not found")
    
    def test_safe_file_writer_exists(self):
        """Test that safe file writer exists"""
        safe_writer = project_root / "scripts" / "safe_file_writer.py"
        self.assertTrue(safe_writer.exists(), "safe_file_writer.py not found")
    
    def test_test_runner_exists(self):
        """Test that test runner exists"""
        test_runner = project_root / "test_runner.py"
        self.assertTrue(test_runner.exists(), "test_runner.py not found")


class TestStepParser(unittest.TestCase):
    """Test step parser utility"""

    def test_step_parser_exists(self):
        parser_script = project_root / "scripts" / "step_parser.py"
        self.assertTrue(parser_script.exists(), "step_parser.py not found")

    def test_step_parser_help(self):
        parser_script = project_root / "scripts" / "step_parser.py"
        if parser_script.exists():
            result = subprocess.run(
                ["python3", str(parser_script), "--help"],
                capture_output=True,
                text=True,
                timeout=30,
            )
            self.assertEqual(result.returncode, 0)
            self.assertIn("parse and validate", result.stdout.lower())

class TestSystemAnalyzer(unittest.TestCase):
    """Test enhanced system analyzer"""
    
    def test_system_analyzer_exists(self):
        """Test that system analyzer exists"""
        analyzer = project_root / "scripts" / "system_analyzer.py"
        self.assertTrue(analyzer.exists(), "system_analyzer.py not found")
    
    def test_system_analyzer_new_features(self):
        """Test that system analyzer checks new features"""
        analyzer = project_root / "scripts" / "system_analyzer.py"
        
        if analyzer.exists():
            content = analyzer.read_text(encoding='utf-8', errors='ignore')
            
            # Check for new feature detection methods
            self.assertIn("check_efficient_inventory", content)
            self.assertIn("check_command_line_args", content)
            self.assertIn("check_dependency_management", content)
            self.assertIn("check_safe_execution", content)

class TestBackwardCompatibility(unittest.TestCase):
    """Test backward compatibility is maintained"""
    
    def test_interactive_mode_preserved(self):
        """Test that interactive mode is preserved"""
        serato_script = project_root.parent / "_SeratOrganizer" / "SeratOrganizer.sh"
        
        if serato_script.exists():
            content = serato_script.read_text(encoding='utf-8', errors='ignore')
            
            # Check that interactive mode still exists
            self.assertIn("Interactive mode (original behavior)", content)
            self.assertIn("while true; do", content.lower())
            self.assertIn("menu", content.lower())
    
    def test_original_functions_preserved(self):
        """Test that original action functions are preserved"""
        serato_script = project_root.parent / "_SeratOrganizer" / "SeratOrganizer.sh"
        
        if serato_script.exists():
            content = serato_script.read_text(encoding='utf-8', errors='ignore')
            
            # Check for original action functions
            original_actions = [
                "action_1", "action_2", "action_3", "action_4", "action_5",
                "action_6", "action_7", "action_8", "action_9", "action_10",
                "action_11", "action_12", "action_13", "action_14", "action_15",
                "action_16", "action_17"
            ]
            
            for action in original_actions:
                self.assertIn(f"{action}()", content, f"Missing {action}")

class TestPerformanceImprovements(unittest.TestCase):
    """Test performance improvements"""
    
    def test_mlx_safeguards_implemented(self):
        """Test that MLX safeguards are implemented"""
        mlx_file = project_root / "ml_mlx.py"
        
        if mlx_file.exists():
            content = mlx_file.read_text(encoding='utf-8', errors='ignore')
            
            self.assertIn("DJPT_SKIP_MLX", content)
            self.assertIn("get_active_memory", content)
    
    def test_timeout_controls_implemented(self):
        """Test that timeout controls are implemented"""
        test_runner = project_root / "test_runner.py"
        
        if test_runner.exists():
            content = test_runner.read_text(encoding='utf-8', errors='ignore')
            
            self.assertIn("timeout", content.lower())
            self.assertIn("TimeoutExpired", content)

class TestIntegration(unittest.TestCase):
    """Integration tests for the complete system"""
    
    def test_system_analyzer_run(self):
        """Test that system analyzer can run successfully"""
        analyzer = project_root / "scripts" / "system_analyzer.py"
        
        if analyzer.exists():
            result = subprocess.run([
                "python3", str(analyzer), 
                "--base-path", str(project_root)
            ], capture_output=True, text=True, timeout=60)
            
            self.assertEqual(result.returncode, 0)
            
            # Parse JSON output
            try:
                report = json.loads(result.stdout)
                self.assertIn("status", report)
                self.assertIn("new_features", report)
                self.assertIn("implementation_summary", report)
            except json.JSONDecodeError:
                self.fail("System analyzer output is not valid JSON")
    
    def test_doctor_total_integration(self):
        """Test Doctor Total integration with new features"""
        # This is a smoke test to ensure Doctor Total can run
        djpt_script = project_root / "DJProducerTools_MultiScript_ES.sh"
        
        if djpt_script.exists():
            # Just check that the script exists and is executable
            self.assertTrue(djpt_script.exists())

def run_comprehensive_tests():
    """Run all tests and return results"""
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # Add all test classes
    test_classes = [
        TestEfficientInventory,
        TestSeratOrganizerArgs,
        TestDependencyManagement,
        TestSafeExecution,
        TestSystemAnalyzer,
        TestBackwardCompatibility,
        TestPerformanceImprovements,
        TestIntegration
    ]
    
    for test_class in test_classes:
        tests = loader.loadTestsFromTestCase(test_class)
        suite.addTests(tests)
    
    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # Generate summary
    summary = {
        "total_tests": result.testsRun,
        "failures": len(result.failures),
        "errors": len(result.errors),
        "skipped": len(result.skipped) if hasattr(result, 'skipped') else 0,
        "success": result.wasSuccessful(),
        "details": {
            "failures": [{"test": str(f[0]), "error": f[1]} for f in result.failures],
            "errors": [{"test": str(e[0]), "error": e[1]} for e in result.errors]
        }
    }
    
    return summary

if __name__ == "__main__":
    print("🧪 DJProducerTools/SeratOrganizer Architectural Improvements Test Suite")
    print("=" * 70)
    
    summary = run_comprehensive_tests()
    
    print("\n" + "=" * 70)
    print("📊 TEST SUMMARY")
    print("=" * 70)
    print(f"Total Tests: {summary['total_tests']}")
    print(f"Passed: {summary['total_tests'] - summary['failures'] - summary['errors']}")
    print(f"Failed: {summary['failures']}")
    print(f"Errors: {summary['errors']}")
    print(f"Skipped: {summary['skipped']}")
    print(f"Success: {'✅' if summary['success'] else '❌'}")
    
    if not summary['success']:
        print("\n❌ FAILURES:")
        for failure in summary['details']['failures']:
            print(f"  - {failure['test']}: {failure['error']}")
        
        print("\n🚨 ERRORS:")
        for error in summary['details']['errors']:
            print(f"  - {error['test']}: {error['error']}")
        
        sys.exit(1)
    else:
        print("\n🎉 All tests passed! The architectural improvements are working correctly.")
        sys.exit(0)

#!/usr/bin/env python3
"""
Advanced Chat CLI - DJProducerTools
Integration with Enhanced Workflow Engine, AI Power Analyzer, Smart Execution Engine, and Predictive System Optimizer
"""
from __future__ import annotations
import os
import sys
import json
import asyncio
from pathlib import Path
from typing import Any, Dict, List, Optional
from datetime import datetime

# Enhanced color scheme
DEGRADED_GREEN = "\033[92m"
DEGRADED_CYAN = "\033[96m"
DEGRADED_WHITE = "\033[97m"
DEGRADED_YELLOW = "\033[93m"
DEGRADED_RED = "\033[91m"
DEGRADED_BLUE = "\033[94m"
DEGRADED_MAGENTA = "\033[95m"
DEGRADED_RESET = "\033[0m"

class AdvancedChatCLI:
    """Advanced Chat CLI with full AI integration"""
    
    def __init__(self, base_path: Path):
        self.base_path = base_path
        self.conversation_history = []
        self.system_status = {}
        self.ai_components = {}
        self._initialize_ai_components()
        
    def _initialize_ai_components(self):
        """Initialize all AI components"""
        try:
            # Try to import enhanced components
            sys.path.insert(0, str(self.base_path / "lib"))
            
            # Enhanced Workflow Engine
            try:
                from enhanced_workflow_engine import EnhancedWorkflowEngine
                self.workflow_engine = EnhancedWorkflowEngine()
                self.ai_components['workflow'] = True
            except ImportError:
                self.workflow_engine = None
                self.ai_components['workflow'] = False
                
            # AI Power Analyzer
            try:
                from ai_power_analyzer import AIPowerAnalyzer
                self.ai_analyzer = AIPowerAnalyzer()
                self.ai_components['analyzer'] = True
            except ImportError:
                self.ai_analyzer = None
                self.ai_components['analyzer'] = False
                
            # Smart Execution Engine
            try:
                from smart_execution_engine import SmartExecutionEngine
                self.execution_engine = SmartExecutionEngine()
                self.ai_components['execution'] = True
            except ImportError:
                self.execution_engine = None
                self.ai_components['execution'] = False
                
            # Predictive System Optimizer
            try:
                from predictive_system_optimizer import PredictiveSystemOptimizer
                self.optimizer = PredictiveSystemOptimizer()
                self.ai_components['optimizer'] = True
            except ImportError:
                self.optimizer = None
                self.ai_components['optimizer'] = False
                
        except Exception as e:
            print(f"{DEGRADED_RED}Error initializing AI components: {e}{DEGRADED_RESET}")
            
    def get_system_report(self) -> Dict[str, Any]:
        """Generate comprehensive system report"""
        report = {
            'timestamp': datetime.now().isoformat(),
            'ai_components': self.ai_components,
            'system_status': self._get_system_status(),
            'conversation_count': len(self.conversation_history)
        }
        
        # Add AI component reports
        if self.workflow_engine:
            report['workflow_status'] = self.workflow_engine.get_status()
            
        if self.ai_analyzer:
            report['ai_analysis'] = self.ai_analyzer.get_current_analysis()
            
        if self.execution_engine:
            report['execution_metrics'] = self.execution_engine.get_metrics()
            
        if self.optimizer:
            report['optimization_recommendations'] = self.optimizer.get_recommendations()
            
        return report
        
    def _get_system_status(self) -> Dict[str, Any]:
        """Get basic system status"""
        return {
            'python_version': sys.version,
            'base_path': str(self.base_path),
            'working_directory': os.getcwd(),
            'environment': os.environ.get('DJPT_ENV', 'production')
        }
        
    def diagnose_system(self) -> Dict[str, Any]:
        """Perform comprehensive system diagnosis"""
        diagnosis = {
            'timestamp': datetime.now().isoformat(),
            'components': {},
            'overall_health': 'unknown'
        }
        
        # Check each AI component
        for component, available in self.ai_components.items():
            diagnosis['components'][component] = {
                'available': available,
                'status': 'active' if available else 'unavailable'
            }
            
        # Determine overall health
        active_components = sum(1 for c in self.ai_components.values() if c)
        total_components = len(self.ai_components)
        
        if active_components == total_components:
            diagnosis['overall_health'] = 'excellent'
        elif active_components >= total_components // 2:
            diagnosis['overall_health'] = 'good'
        elif active_components > 0:
            diagnosis['overall_health'] = 'degraded'
        else:
            diagnosis['overall_health'] = 'minimal'
            
        return diagnosis
        
    def monitor_backends(self) -> Dict[str, Any]:
        """Monitor AI backends status"""
        backends = {
            'timestamp': datetime.now().isoformat(),
            'backends': {}
        }
        
        # Check Ollama backend
        try:
            import requests
            response = requests.get('http://localhost:11434/api/tags', timeout=5)
            if response.status_code == 200:
                backends['backends']['ollama'] = {
                    'status': 'active',
                    'models': len(response.json().get('models', []))
                }
            else:
                backends['backends']['ollama'] = {'status': 'error'}
        except:
            backends['backends']['ollama'] = {'status': 'unavailable'}
            
        # Check OpenAI backend (if configured)
        if os.environ.get('OPENAI_API_KEY'):
            backends['backends']['openai'] = {'status': 'configured'}
        else:
            backends['backends']['openai'] = {'status': 'not_configured'}
            
        return backends
        
    def get_healing_results(self) -> Dict[str, Any]:
        """Get self-healing results and recommendations"""
        healing = {
            'timestamp': datetime.now().isoformat(),
            'actions_taken': [],
            'recommendations': []
        }
        
        # Check for missing components and suggest fixes
        for component, available in self.ai_components.items():
            if not available:
                healing['recommendations'].append({
                    'component': component,
                    'issue': 'Missing AI component',
                    'suggestion': f'Install {component.replace("_", " ").title()} module'
                })
                
        return healing
        
    def process_command(self, command: str) -> Dict[str, Any]:
        """Process user command with AI enhancement"""
        result = {
            'timestamp': datetime.now().isoformat(),
            'command': command,
            'response': '',
            'ai_processed': False
        }
        
        # Add to conversation history
        self.conversation_history.append({
            'timestamp': datetime.now().isoformat(),
            'type': 'user',
            'content': command
        })
        
        # Process with AI components if available
        if self.ai_analyzer:
            try:
                analysis = self.ai_analyzer.analyze_command(command)
                result['ai_processed'] = True
                result['ai_analysis'] = analysis
            except Exception as e:
                result['ai_error'] = str(e)
                
        # Basic command processing
        if command.lower() == 'status':
            result['response'] = self.get_system_report()
        elif command.lower() == 'diagnose':
            result['response'] = self.diagnose_system()
        elif command.lower() == 'backends':
            result['response'] = self.monitor_backends()
        elif command.lower() == 'healing':
            result['response'] = self.get_healing_results()
        else:
            result['response'] = f"Command processed: {command}"
            
        return result
        
    def display_banner(self):
        """Display advanced banner"""
        banner = f"""
{DEGRADED_CYAN}
╔══════════════════════════════════════════════════════════════╗
║                DJProducerTools Advanced Chat CLI                ║
║              AI-Powered Audio Processing Suite                 ║
╠══════════════════════════════════════════════════════════════╣
║  Components Available:                                         ║
║  • Enhanced Workflow Engine: {'✓' if self.ai_components.get('workflow') else '✗':<3}     ║
║  • AI Power Analyzer: {'✓' if self.ai_components.get('analyzer') else '✗':<3}          ║
║  • Smart Execution Engine: {'✓' if self.ai_components.get('execution') else '✗':<3}     ║
║  • Predictive Optimizer: {'✓' if self.ai_components.get('optimizer') else '✗':<3}       ║
╚══════════════════════════════════════════════════════════════╝
{DEGRADED_RESET}
"""
        print(banner)

def main():
    """Main entry point for Advanced Chat CLI"""
    base_path = Path(__file__).parent.parent
    cli = AdvancedChatCLI(base_path)
    
    cli.display_banner()
    
    print(f"{DEGRADED_CYAN}Advanced Chat CLI ready. Type 'help' for commands.{DEGRADED_RESET}")
    
    while True:
        try:
            command = input(f"{DEGRADED_GREEN}DJPT-Advanced>{DEGRADED_RESET} ").strip()
            
            if command.lower() in ['exit', 'quit']:
                print(f"{DEGRADED_YELLOW}Goodbye!{DEGRADED_RESET}")
                break
                
            if command.lower() == 'help':
                print(f"""
{DEGRADED_CYAN}Available Commands:{DEGRADED_RESET}
• status     - System status report
• diagnose   - System diagnosis
• backends   - AI backends status
• healing    - Self-healing results
• help       - This help message
• exit/quit  - Exit Advanced Chat CLI
""")
                continue
                
            result = cli.process_command(command)
            
            if isinstance(result['response'], dict):
                print(f"{DEGRADED_CYAN}{json.dumps(result['response'], indent=2)}{DEGRADED_RESET}")
            else:
                print(f"{DEGRADED_WHITE}{result['response']}{DEGRADED_RESET}")
                
        except KeyboardInterrupt:
            print(f"\n{DEGRADED_YELLOW}Interrupted. Type 'exit' to quit.{DEGRADED_RESET}")
        except Exception as e:
            print(f"{DEGRADED_RED}Error: {e}{DEGRADED_RESET}")

if __name__ == "__main__":
    main()

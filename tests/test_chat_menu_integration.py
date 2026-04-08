#!/usr/bin/env python3
"""
Test Suite for Chat-Menu Integration Bridge.
Verifies that the bridge correctly writes commands and handles state.
"""

import unittest
import os
import sys
import shutil
import json
from pathlib import Path

# Add project root to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from scripts.chat.chat_menu_bridge import ChatMenuBridge

class TestChatMenuBridge(unittest.TestCase):
    def setUp(self):
        self.test_dir = Path("./test_state_bridge")
        self.test_dir.mkdir(exist_ok=True)
        self.bridge = ChatMenuBridge(self.test_dir)

    def tearDown(self):
        if self.test_dir.exists():
            shutil.rmtree(self.test_dir)

    def test_request_action(self):
        """Test requesting a menu action."""
        success = self.bridge.request_action("80")
        self.assertTrue(success)
        
        cmd_file = self.test_dir / ".chat_cmd"
        self.assertTrue(cmd_file.exists())
        self.assertEqual(cmd_file.read_text(), "CMD:JUMP:80")

    def test_request_exit(self):
        """Test requesting exit."""
        success = self.bridge.request_exit()
        self.assertTrue(success)
        
        cmd_file = self.test_dir / ".chat_cmd"
        self.assertTrue(cmd_file.exists())
        self.assertEqual(cmd_file.read_text(), "CMD:EXIT")

    def test_state_persistence(self):
        """Test saving and loading chat history."""
        history = [{"role": "user", "content": "hi"}, {"role": "ai", "content": "hello"}]
        self.bridge.save_chat_state(history)
        
        loaded = self.bridge.load_chat_state()
        self.assertEqual(loaded, history)

    def test_get_last_result(self):
        """Test retrieving result from bash execution."""
        result_file = self.test_dir / ".chat_result"
        result_file.write_text("Operation successful")
        
        result = self.bridge.get_last_result()
        self.assertEqual(result, "Operation successful")
        self.assertFalse(result_file.exists())  # Should be consumed

if __name__ == '__main__':
    unittest.main()

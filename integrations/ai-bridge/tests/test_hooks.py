import json
from pathlib import Path
import tempfile
import unittest
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'hooks'))
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from antigravity_hooks import handle
from install_hooks import render, KEY_START, KEY_STOP

class TestHooks(unittest.TestCase):
    def test_start_does_not_ingest_transcript(self):
        result=handle('start','djproducertools',{'transcriptPath':'/secret/transcript.jsonl','api_key':'secret'},None,False)
        s=json.dumps(result)
        self.assertIn('list_handoffs',s)
        self.assertNotIn('transcript.jsonl',s)
        self.assertNotIn('secret',s)

    def test_stop_default_no_write(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); (root/'99_AUDIT').mkdir()
            out=handle('stop','djproducertools',{'fullyIdle':True,'conversationId':'sensitive'},str(root),False)
            self.assertEqual(out,{})
            self.assertEqual(list((root/'99_AUDIT').iterdir()),[])

    def test_stop_records_minimal_metadata_no_paths(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); (root/'99_AUDIT').mkdir()
            payload={'fullyIdle':True,'conversationId':'private-id','transcriptPath':'SECRET_FULL_PATH',
                     'error':'SECRET_ERROR','terminationReason':'model_stop',
                     'workspacePaths':['SECRET_PROJECT_PATH']}
            self.assertEqual(handle('stop','legal_inah',payload,str(root),True),{})
            event=list((root/'99_AUDIT'/'antigravity_events').glob('*.json'))
            self.assertEqual(len(event),1)
            text=event[0].read_text(encoding='utf-8')
            for secret in ('private-id','SECRET_FULL_PATH','SECRET_ERROR','SECRET_PROJECT_PATH'):
                self.assertNotIn(secret,text)
            self.assertIn('"project": "legal_inah"',text)

    def test_stop_not_fully_idle(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); (root/'99_AUDIT').mkdir()
            self.assertEqual(handle('stop','cerebro',{'fullyIdle':False},str(root),True),{})
            self.assertEqual(list((root/'99_AUDIT').iterdir()),[])

    def test_symlink_audit_denied(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); target=root/'other';target.mkdir()
            (root/'99_AUDIT').symlink_to(target,target_is_directory=True)
            with self.assertRaises(ValueError):
                handle('stop','djproducertools',{'fullyIdle':True},str(root),True)

    def test_merge_preserves_existing(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); script=root/'script.py'
            old={'existing-custom-hook': {'enabled': False}}
            merged=render(old,'cerebro',root,'/usr/bin/python3',script,False)
            self.assertEqual(merged['existing-custom-hook'],old['existing-custom-hook'])
            self.assertIn(KEY_START,merged)
            self.assertNotIn(KEY_STOP,merged)
            self.assertEqual(old,{'existing-custom-hook': {'enabled': False}})

    def test_duplicate_hook_blocked(self):
        with self.assertRaises(ValueError):
            render({KEY_START:{}},'cerebro',Path('/tmp'),'/bin/python3',Path('/tmp/test.py'),False)

if __name__=='__main__': unittest.main()
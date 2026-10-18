import json
from pathlib import Path
import tempfile
import unittest
import sys

sys.path.insert(0,str(Path(__file__).resolve().parent.parent))
from bridge_server import Bridge,BridgeError,rpc

class BridgeTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.root=Path(self.temp.name)
        (self.root/'project_one').mkdir()
        self.b=Bridge(self.root,None,True)
    def tearDown(self): self.temp.cleanup()
    def test_round_trip(self):
        info=self.b.publish_handoff('project_one','antigravity','Verified test',source_refs=['sha256:abc'],findings=['Test result'])
        entries=self.b.list_handoffs('project_one')
        self.assertEqual(len(entries['entries']),1)
        self.assertEqual(entries['entries'][0]['name'],info['name'])
        obj=self.b.read_handoff('project_one',info['name'])
        self.assertTrue(obj['verified_integrity'])
        self.assertEqual(obj['handoff']['review_status'],'unverified_agent_report')
    def test_write_disabled(self):
        with self.assertRaises(BridgeError): Bridge(self.root,None,False).publish_handoff('project_one','antigravity','No')
    def test_path_traversal(self):
        with self.assertRaises(BridgeError): self.b.folder('../anything')
        with self.assertRaises(BridgeError): self.b.read_handoff('project_one','../../test.json')
    def test_tamper_fails(self):
        info=self.b.publish_handoff('project_one','antigravity','Before')
        p=Path(info['path'])
        o=json.loads(p.read_text())
        o['summary']='After'
        p.write_text(json.dumps(o))
        with self.assertRaises(BridgeError): self.b.read_handoff('project_one',p.name)
    def test_rpc(self):
        msg={'jsonrpc':'2.0','id':1,'method':'initialize','params':{'protocolVersion':'2025-06-18'}}
        reply=rpc(self.b,msg)
        self.assertEqual(reply['result']['protocolVersion'],'2025-06-18')
        self.assertEqual(len(rpc(self.b,{'jsonrpc':'2.0','id':2,'method':'tools/list'})['result']['tools']),4)
        self.assertIsNone(rpc(self.b,{'jsonrpc':'2.0','method':'notifications/initialized'}))
    def test_symlink_escape(self):
        with tempfile.TemporaryDirectory() as t:
            (self.root/'out').symlink_to(Path(t),target_is_directory=True)
            with self.assertRaises(BridgeError): self.b.folder('out')
    def test_explicit_config(self):
        c=self.root/'map.json'
        c.write_text(json.dumps({'projects':{'dev':'project_one'}}))
        b=Bridge(self.root,c,False)
        self.assertEqual(b.status()['projects'],['dev'])
        with self.assertRaises(BridgeError): b.folder('project_one')

if __name__=='__main__': unittest.main()

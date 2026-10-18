#!/usr/bin/env python3
"""Conservative Model Context Protocol bridge over a private local synced folder.

Python 3.11+; stdlib only. This server never accesses source project directories.
It permits file creation only inside <bridge_root>/<project>/handoffs/.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import uuid
from typing import Any

MAX_FILE_BYTES = 512_000
MAX_SUMMARY = 12_000
MAX_FIELD_TEXT = 8_000
ALLOWED_ACTORS = {"antigravity", "chatgpt", "human", "other_agent"}
ALLOWED_SENSITIVITY = {"public", "internal", "confidential"}
PROJECT_RE = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$")
FILENAME_RE = re.compile(r"^[0-9]{8}T[0-9]{6}Z_[0-9a-f]{12}\.json$")


class BridgeError(ValueError):
    pass


def encoded(obj: Any) -> bytes:
    return json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


class Bridge:
    def __init__(self, root: Path, config: Path | None, writable: bool) -> None:
        if not root.is_dir():
            raise BridgeError("AI_BRIDGE_ROOT debe existir como directorio local sincronizado")
        self.root = root.resolve(strict=True)
        self.writable = writable
        self.projects: dict[str, str] = {}
        if config:
            cfg = json.loads(config.read_text(encoding="utf-8"))
            mapping = cfg.get("projects")
            if not isinstance(mapping, dict) or not mapping:
                raise BridgeError("Config requires non-empty projects mapping")
            for slug, folder in mapping.items():
                if not isinstance(slug, str) or not PROJECT_RE.fullmatch(slug):
                    raise BridgeError("Nombre de proyecto no válido")
                if not isinstance(folder, str) or not folder or Path(folder).is_absolute() or "/" in folder or "\\" in folder or folder in (".", ".."):
                    raise BridgeError("Carpeta de proyecto no válida")
                self.projects[slug] = folder
        else:
            # Only explicit subfolders; never recursively discover or index project sources.
            self.projects = {p.name: p.name for p in self.root.iterdir() if p.is_dir() and not p.is_symlink() and PROJECT_RE.fullmatch(p.name)}

    def folder(self, project: str) -> Path:
        if project not in self.projects:
            raise BridgeError("Proyecto no permitido en la configuración")
        target = (self.root / self.projects[project]).resolve(strict=True)
        if not target.is_relative_to(self.root) or not target.is_dir():
            raise BridgeError("Carpeta fuera de AI_BRIDGE")
        return target

    def status(self) -> dict[str, Any]:
        return {"version":"1.0.0", "root":str(self.root), "projects":list(self.projects),
                "write_enabled":self.writable, "source_projects_accessible":False,
                "external_api_calls":False}

    def list_handoffs(self, project: str, limit: int = 30) -> dict[str, Any]:
        if not isinstance(limit, int) or not 1 <= limit <= 100:
            raise BridgeError("limit debe estar entre 1 y 100")
        p = self.folder(project) / "handoffs"
        if not p.exists():
            return {"project":project,"entries":[]}
        if p.is_symlink() or not p.is_dir():
            raise BridgeError("handoffs no es un directorio seguro")
        entries=[]
        for f in sorted(p.iterdir(), key=lambda x:x.name, reverse=True):
            if f.is_symlink() or not f.is_file() or not FILENAME_RE.fullmatch(f.name):
                continue
            if f.stat().st_size > MAX_FILE_BYTES:
                continue
            entries.append({"name":f.name,"bytes":f.stat().st_size})
            if len(entries)>=limit:
                break
        return {"project":project,"entries":entries}

    def read_handoff(self, project: str, filename: str) -> dict[str, Any]:
        if not isinstance(filename,str) or not FILENAME_RE.fullmatch(filename):
            raise BridgeError("Nombre de archivo no válido")
        base = self.folder(project)
        p = base / "handoffs" / filename
        if p.is_symlink() or not p.is_file() or not p.resolve(strict=True).is_relative_to(base):
            raise BridgeError("Archivo inexistente o fuera del puente")
        if p.stat().st_size > MAX_FILE_BYTES:
            raise BridgeError("Archivo demasiado grande")
        obj=json.loads(p.read_text(encoding="utf-8"))
        if not isinstance(obj, dict) or obj.get("project") != project:
            raise BridgeError("Handoff inválido o pertenece a otro proyecto")
        claimed=obj.get("sha256")
        payload={k:v for k,v in obj.items() if k!="sha256"}
        verified=isinstance(claimed,str) and hashlib.sha256(encoded(payload)).hexdigest()==claimed
        if not verified:
            raise BridgeError("Falló la comprobación de integridad SHA-256")
        return {"verified_integrity":True,"handoff":obj}

    def publish_handoff(self, project: str, actor: str, summary: str,
                        source_refs: list[str] | None = None, findings: list[str] | None = None,
                        next_actions: list[str] | None = None,
                        sensitivity: str="internal") -> dict[str, Any]:
        if not self.writable:
            raise BridgeError("Escritura deshabilitada; requiere AI_BRIDGE_ALLOW_WRITE=1")
        base=self.folder(project)
        if actor not in ALLOWED_ACTORS:
            raise BridgeError("actor no permitido")
        if sensitivity not in ALLOWED_SENSITIVITY:
            raise BridgeError("sensitivity no permitida")
        if not isinstance(summary,str) or not summary.strip() or len(summary)>MAX_SUMMARY:
            raise BridgeError("summary obligatorio y con máximo 12000 caracteres")
        fields={"source_refs":source_refs or [],"findings":findings or [],"next_actions":next_actions or []}
        for key,values in fields.items():
            if not isinstance(values,list) or len(values)>100 or any(not isinstance(x,str) or len(x)>MAX_FIELD_TEXT for x in values):
                raise BridgeError(f"Campo {key} inválido")
        p=base / "handoffs"
        if p.is_symlink():
            raise BridgeError("handoffs no puede ser un enlace simbólico")
        p.mkdir(exist_ok=True)
        if not p.resolve(strict=True).is_relative_to(self.root):
            raise BridgeError("Destino fuera de raíz autorizada")
        utc=dt.datetime.now(dt.timezone.utc).replace(microsecond=0)
        payload={"schema":"ai-bridge/handoff-v1","project":project,"actor":actor,
                 "created_at":utc.isoformat().replace("+00:00","Z"),"sensitivity":sensitivity,
                 "summary":summary,"source_refs":fields["source_refs"],
                 "findings":fields["findings"],"next_actions":fields["next_actions"],
                 "review_status":"unverified_agent_report"}
        payload["sha256"]=hashlib.sha256(encoded(payload)).hexdigest()
        raw=json.dumps(payload,ensure_ascii=False,indent=2).encode("utf-8")+b"\n"
        if len(raw)>MAX_FILE_BYTES:
            raise BridgeError("Documento mayor de 512 KB")
        name=utc.strftime("%Y%m%dT%H%M%SZ_")+uuid.uuid4().hex[:12]+".json"
        output=p/name
        # Exclusive creation. Does not replace existing files or project originals.
        fd=os.open(str(output),os.O_WRONLY | os.O_CREAT | os.O_EXCL,0o600)
        with os.fdopen(fd,"wb") as f:
            f.write(raw)
            f.flush()
            os.fsync(f.fileno())
        return {"project":project,"name":name,"sha256":payload["sha256"],"path":str(output)}


TOOLS=[
 {"name":"bridge_status","description":"Read bridge state, project allowlist and permission mode; no project source access.","inputSchema":{"type":"object","properties":{},"additionalProperties":False}},
 {"name":"list_handoffs","description":"List signed-integrity handoff JSON files in the designated bridge project directory.","inputSchema":{"type":"object","properties":{"project":{"type":"string"},"limit":{"type":"integer","minimum":1,"maximum":100}},"required":["project"],"additionalProperties":False}},
 {"name":"read_handoff","description":"Read and verify SHA-256 integrity of a single handoff; integrity does NOT authenticate the author.","inputSchema":{"type":"object","properties":{"project":{"type":"string"},"filename":{"type":"string"}},"required":["project","filename"],"additionalProperties":False}},
 {"name":"publish_handoff","description":"Create a new handoff INSIDE the bridge only. Disabled unless the local owner explicitly sets AI_BRIDGE_ALLOW_WRITE=1. Do not submit case evidence or secrets here.","inputSchema":{"type":"object","properties":{"project":{"type":"string"},"actor":{"type":"string","enum":sorted(ALLOWED_ACTORS)},"summary":{"type":"string"},"source_refs":{"type":"array","items":{"type":"string"}},"findings":{"type":"array","items":{"type":"string"}},"next_actions":{"type":"array","items":{"type":"string"}},"sensitivity":{"type":"string","enum":sorted(ALLOWED_SENSITIVITY)}},"required":["project","actor","summary"],"additionalProperties":False}}
]


def dispatch(bridge:Bridge, name:str, args:dict) -> dict:
    if name=="bridge_status": return bridge.status()
    if name=="list_handoffs": return bridge.list_handoffs(**args)
    if name=="read_handoff": return bridge.read_handoff(**args)
    if name=="publish_handoff": return bridge.publish_handoff(**args)
    raise BridgeError("Herramienta desconocida")


def rpc(bridge:Bridge, msg:dict[str,Any])->dict[str,Any]|None:
    method=msg.get("method")
    mid=msg.get("id")
    if mid is None:
        return None  # Notifications must not receive a response.
    try:
        if method=="initialize":
            params=msg.get("params") or {}
            # Clients negotiate MCP protocolVersion at initialization.
            requested=params.get("protocolVersion")
            version=requested if requested in {"2024-11-05","2025-03-26","2025-06-18","2025-11-25"} else "2025-06-18"
            result={"protocolVersion":version,"capabilities":{"tools":{"listChanged":False}},"serverInfo":{"name":"ai-bridge-safe-local","version":"1.0.0"}}
        elif method=="ping": result={}
        elif method=="tools/list": result={"tools":TOOLS}
        elif method=="tools/call":
            args=msg.get("params") or {}
            response=dispatch(bridge,args.get("name",""),args.get("arguments") or {})
            result={"content":[{"type":"text","text":json.dumps(response,ensure_ascii=False)}],"isError":False}
        else: return {"jsonrpc":"2.0","id":mid,"error":{"code":-32601,"message":"Method not found"}}
        return {"jsonrpc":"2.0","id":mid,"result":result}
    except Exception as e:
        if method=="tools/call":
            result={"content":[{"type":"text","text":f"{type(e).__name__}: {e}"}],"isError":True}
            return {"jsonrpc":"2.0","id":mid,"result":result}
        return {"jsonrpc":"2.0","id":mid,"error":{"code":-32603,"message":f"{type(e).__name__}: {e}"}}


def main()->int:
    if not os.environ.get("AI_BRIDGE_ROOT"):
        print("AI_BRIDGE_ROOT no está establecido; cancelando",file=sys.stderr)
        return 2
    cfg=os.environ.get("AI_BRIDGE_CONFIG")
    try:
        bridge=Bridge(Path(os.environ["AI_BRIDGE_ROOT"]).expanduser(),Path(cfg).expanduser() if cfg else None,
                      os.environ.get("AI_BRIDGE_ALLOW_WRITE")=="1")
    except Exception as e:
        print(f"Error de configuración: {e}",file=sys.stderr)
        return 2
    for line in sys.stdin:
        if not line.strip(): continue
        try:
            msg=json.loads(line)
            if not isinstance(msg,dict): raise ValueError("Expected JSON object")
            ans=rpc(bridge,msg)
        except Exception as e:
            ans={"jsonrpc":"2.0","id":None,"error":{"code":-32700,"message":f"Parse error: {e}"}}
        if ans is not None:
            print(json.dumps(ans,ensure_ascii=False,separators=(",", ":")),flush=True)
    return 0


if __name__=="__main__":
    sys.exit(main())
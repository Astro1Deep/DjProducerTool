import asyncio
import inspect
import importlib
import importlib.util
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    # Ensure local project modules shadow similarly-named site packages.
    sys.path.insert(0, str(ROOT))
importlib.invalidate_caches()


def _ensure_local_scripts_package() -> None:
    pkg_dir = ROOT / "scripts"
    init_py = pkg_dir / "__init__.py"
    current = sys.modules.get("scripts")
    if current and str(getattr(current, "__file__", "")).startswith(str(pkg_dir)):
        return
    if not init_py.exists():
        return
    spec = importlib.util.spec_from_file_location(
        "scripts",
        init_py,
        submodule_search_locations=[str(pkg_dir)],
    )
    if spec is None or spec.loader is None:
        return
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    sys.modules["scripts"] = module


_ensure_local_scripts_package()


def pytest_pyfunc_call(pyfuncitem):
    """Allow async test functions to run without external plugins."""
    if inspect.iscoroutinefunction(pyfuncitem.obj):
        kwargs = dict(pyfuncitem.funcargs)
        # Ignore pytest-asyncio style fixtures if present
        kwargs.pop("event_loop_policy", None)
        kwargs.pop("event_loop", None)
        asyncio.run(pyfuncitem.obj(**kwargs))
        return True
    return None

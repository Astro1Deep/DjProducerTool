from __future__ import annotations

import module_manager


def test_module_manager_init_check_run_and_doctor(tmp_path):
    payload, rc = module_manager.run(action="init", repo_root=tmp_path, name="demo_mod")
    assert rc == 0
    assert payload["status"] == "ok"

    payload, rc = module_manager.run(action="check", repo_root=tmp_path)
    assert rc == 0
    assert payload["status"] == "ok"
    assert payload["modules"][0]["name"] == "demo_mod"

    payload, rc = module_manager.run(action="run", repo_root=tmp_path, name="demo_mod", args=["hello"])
    assert rc == 0
    assert payload["status"] == "ok"
    assert "demo_mod" in payload["stdout"]

    module_dir = tmp_path / "state" / "modules" / "demo_mod"
    (module_dir / "main.py").write_text("def broken(:\n", encoding="utf-8")

    payload, rc = module_manager.run(action="doctor", repo_root=tmp_path)
    assert rc == 0
    assert payload["status"] == "ok"
    assert payload["quarantined_count"] == 1
    assert (module_dir / ".disabled").exists()

    payload, rc = module_manager.run(action="check", repo_root=tmp_path)
    assert rc == 2
    assert payload["status"] == "warn"

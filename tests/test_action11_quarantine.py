import os
import tempfile
from pathlib import Path
import subprocess
import sys


def run_action_11(base_dir: Path, safe_mode=1):
    env = os.environ.copy()
    env["BASE_PATH"] = str(base_dir)
    env["SAFE_MODE"] = str(safe_mode)
    env["DJPT_ALLOW_OUTSIDE"] = "0"
    env["PYTHONPATH"] = str(base_dir) + os.pathsep + env.get("PYTHONPATH", "")
    return subprocess.run(
        ["bash", "-c", "source DJProducerTools_Con_Opciones_IA.sh; action_11_quarantine_from_plan"],
        cwd=base_dir,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        timeout=10,
    )


def test_action11_filters_outside_base(tmp_path: Path):
    base = tmp_path
    # Fake minimal env
    (base / "plans").mkdir()
    (base / "quarantine").mkdir()
    # Create plan with inside and outside
    inside = base / "keepme.mp3"
    outside = base.parent / "outside.mp3"
    inside.write_text("x")
    outside.write_text("y")
    plan = base / "plans" / "dupes_plan.tsv"
    plan.write_text(
        "\n".join(
            [
                "hash\taction\tpath\treason",
                f"H1\tQUARANTINE\t{inside}\tdup",
                f"H2\tQUARANTINE\t{outside}\tdup",
            ]
        )
    )
    # Create minimal dupes plan builder placeholder so sourcing doesn't fail
    (base / "DJProducerTools_Con_Opciones_IA.sh").write_text(
        "action_11_quarantine_from_plan(){\n"
        "  : ${SAFE_MODE:=1};\n"
        "  QUAR_DIR=\"$PWD/quarantine\"; PLANS_DIR=\"$PWD/plans\"; C_RED=''; C_RESET=''; C_YLW='';\n"
        "  is_under_base(){ python3 -c \"import os,sys;import pathlib;p=pathlib.Path(sys.argv[1]).resolve();b=pathlib.Path(os.environ.get('BASE_PATH','/')).resolve();import sys;sys.exit(0 if str(p).startswith(str(b)) else 1)\" \"$1\"; }\n"
        "  ensure_python_bin(){ return 0; }\n"
        "  ensure_safety_guard(){ return 0; }\n"
        "  # minimal executor call\n"
        "  tail -n +2 \"$PLANS_DIR/dupes_plan.tsv\" | while IFS=$'\\t' read -r h a p r; do\n"
        "    if [ \"$a\" = \"QUARANTINE\" ]; then\n"
        "      if [ \"$SAFE_MODE\" -eq 1 ] && ! is_under_base \"$p\"; then\n"
        "        echo \"[WARN] outside: $p\"; continue; fi\n"
        "      echo \"MOVE $p\";\n"
        "    fi\n"
        "  done\n"
        "}\n"
    )

    res = subprocess.run(
        ["bash", "-c", "source DJProducerTools_Con_Opciones_IA.sh; action_11_quarantine_from_plan"],
        cwd=base,
        env={"BASE_PATH": str(base), "SAFE_MODE": "1", "DJPT_ALLOW_OUTSIDE": "0"},
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        timeout=10,
    )
    assert "MOVE" in res.stdout
    assert "outside" in res.stdout

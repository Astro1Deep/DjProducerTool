import json
import os
import subprocess
import sys
from collections import Counter
from datetime import datetime
from pathlib import Path

try:
    from typing_extensions import Annotated
except ImportError:
    # Fallback para Python < 3.9 sin typing_extensions
    def Annotated(type_hint, description):
        return type_hint


import typer
from rich import print

# ---------------------------
# Lab / experimental commands
# ---------------------------
lab_app = typer.Typer(help="Comandos de laboratorio (experimental)", hidden=True)


from config_schema import (
    CONFIG_FILE,
    config_manager,
    export_all_env_vars,
    get_nested_setting,
    load_settings,
    save_settings,
    set_nested_setting,
)  # noqa: E402

# Cargar configuración global
settings = config_manager.settings

app = typer.Typer(
    name="djpt",
    help="🤖 DJ Producer Tools AI Suite - Quantum Engine",
    add_completion=False,
)

config_app = typer.Typer(name="config", help="Gestiona la configuración del sistema.")
app.add_typer(config_app)
ai_app = typer.Typer(name="ai", help="Comandos IA (proxy a ai_suite)")
app.add_typer(ai_app)
app.add_typer(lab_app, name="lab")
REPO_ROOT = Path(__file__).resolve().parent


def _run_ai_suite(args: list[str]) -> int:
    cmd = [
        sys.executable,
        str(Path(__file__).resolve().parent / "ai_suite.py"),
        *args,
    ]
    proc = subprocess.run(cmd)
    return proc.returncode


def _run_pip_install_attempt(label: str, args: list[str], mock_env_key=None) -> int:
    print(f"[cyan][INFO][/cyan] intento: {label}")
    if mock_env_key:
        mock_raw = os.environ.get(mock_env_key)
        if mock_raw is not None:
            try:
                rc = int(mock_raw)
            except ValueError:
                rc = 1
            if rc == 0:
                print(f"[green][OK][/green] {label} (mock)")
            else:
                print(f"[red][ERR][/red] {label} (mock, code={rc})")
            return rc

    cmd = [sys.executable, "-m", "pip", "install", *args]
    print(f"[dim]{' '.join(cmd)}[/dim]")
    proc = subprocess.run(cmd, cwd=REPO_ROOT)
    if proc.returncode == 0:
        print(f"[green][OK][/green] {label}")
    else:
        print(f"[red][ERR][/red] {label} (code={proc.returncode})")
    return proc.returncode


# ---------------------------
# Lab commands (experimental)
# ---------------------------


@lab_app.command("doctor")
def lab_doctor():
    """Diagnóstico experimental de dependencias (Lab/Quantum)."""
    import json

    lab_root = Path(os.environ.get("DJPT_LAB_ROOT", "/Volumes/SeaGate2TB/DJProducerTools_Lab"))
    lab_script = lab_root / "core" / "lab_doctor.py"
    if not lab_script.exists():
        print("[red]Lab doctor no disponible (lab_doctor.py ausente)[/red]")
        raise typer.Exit(code=1)
    proc = subprocess.run([sys.executable, str(lab_script)], capture_output=True, text=True)
    if proc.stdout:
        try:
            data = json.loads(proc.stdout)
            print(json.dumps(data, indent=2))
        except Exception:
            print(proc.stdout)
    if proc.returncode != 0:
        print(proc.stderr)
        raise typer.Exit(code=proc.returncode)


@lab_app.command("graph", hidden=True)
def lab_graph():
    """Genera un grafo ligero de activos del árbol actual o del base configurado."""

    def _is_project_root(path: Path) -> bool:
        return (path / "cli.py").exists() or (path / "scripts" / "DJProducerTools_MultiScript_ES.sh").exists()

    def _classify(path: Path) -> str:
        suffix = path.suffix.lower()
        if suffix in {".mp3", ".wav", ".flac", ".m4a", ".aac", ".ogg", ".aiff", ".aif"}:
            return "audio"
        if suffix in {".mp4", ".mov", ".mkv", ".avi", ".m4v"}:
            return "video"
        if suffix in {".md", ".txt", ".json", ".toml", ".yaml", ".yml", ".csv", ".tsv", ".py", ".sh"}:
            return "text"
        return "other"

    base = Path(os.environ.get("DJPT_BASE_DIR", os.getcwd())).resolve()
    reports_dir = (base / "reports") if _is_project_root(base) else (base / "_DJProducerTools" / "reports")
    reports_dir.mkdir(parents=True, exist_ok=True)
    ts = os.environ.get("DJPT_LAB_TS") or datetime.now().strftime("%Y%m%d_%H%M%S")
    out_json = reports_dir / f"lab_assets_graph_{ts}.json"
    out_mmd = reports_dir / f"lab_assets_graph_{ts}.mmd"
    skip_dirs = {".git", "__pycache__", "node_modules", ".venv", "venv", "djpt_venv", "_DJProducerTools"}

    counts: Counter[str] = Counter()
    top_dirs: Counter[str] = Counter()
    sample_files: list[str] = []

    for current_root, dirnames, filenames in os.walk(base):
        dirnames[:] = sorted(d for d in dirnames if d not in skip_dirs)
        root_path = Path(current_root)
        rel_root = "." if root_path == base else str(root_path.relative_to(base))
        top_token = rel_root.split("/", 1)[0]
        for name in sorted(filenames):
            path = root_path / name
            counts[_classify(path)] += 1
            top_dirs[top_token] += 1
            if len(sample_files) < 20:
                sample_files.append(str(path.relative_to(base)))

    payload = {
        "base_path": str(base),
        "summary": {
            "audio_files": counts["audio"],
            "video_files": counts["video"],
            "text_files": counts["text"],
            "other_files": counts["other"],
            "total_files": sum(counts.values()),
        },
        "top_roots": [{"name": name, "files": count} for name, count in top_dirs.most_common(10)],
        "sample_files": sample_files,
    }

    out_json.write_text(json.dumps(payload, indent=2, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")
    lines = ["graph LR", f'  ROOT["{base.name or "/"}"]']
    for label, value in (
        ("Audio", counts["audio"]),
        ("Video", counts["video"]),
        ("Text", counts["text"]),
        ("Other", counts["other"]),
    ):
        node = label.lower()
        lines.append(f'  ROOT --> {node}["{label} ({value})"]')
    for index, item in enumerate(payload["top_roots"], start=1):
        node = f"top{index}"
        safe_name = str(item["name"]).replace('"', "'")
        lines.append(f'  ROOT --> {node}["{safe_name} ({item["files"]})"]')
    out_mmd.write_text("\n".join(lines) + "\n", encoding="utf-8")
    sys.stdout.write(
        json.dumps({"json": str(out_json), "mermaid": str(out_mmd), "summary": payload["summary"]}, ensure_ascii=False)
        + "\n"
    )


@app.command("health")
def health():
    """Chequeo rápido: paths, venv, espacio y backends IA (delegado a ai_health.py)."""
    base = Path(os.environ.get("DJPT_BASE_DIR", Path(__file__).resolve().parent)).resolve()
    venv_py = Path(
        os.environ.get(
            "PYTHON_BIN",
            base / "djpt_venv" / "bin" / "python3",
        )
    )
    health_script = Path(__file__).resolve().parent / "ai_health.py"

    if not health_script.exists():
        print(json.dumps({"error": f"ai_health.py no encontrado en {health_script}"}))
        raise typer.Exit(code=2)

    cmd = [
        str(venv_py if venv_py.exists() else sys.executable),
        str(health_script),
    ]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True)
        sys.stdout.write(proc.stdout)
        if proc.returncode != 0:
            sys.stderr.write(proc.stderr)
        raise typer.Exit(code=proc.returncode)
    except Exception as e:
        print(json.dumps({"error": f"fallo ejecutando health: {e}"}))
        raise typer.Exit(code=2)


@config_app.command("show")
def config_show():
    """Muestra toda la configuración AI actual (ai_model_params.toml)."""
    print("[bold cyan]Configuración AI Completa (ai_model_params.toml)[/bold cyan]")
    print("=" * 50)

    sections = [
        ("🎛️ General", settings.general),
        ("🍎 MLX", settings.mlx),
        ("🧠 TensorFlow", settings.tensorflow),
        ("🦙 Ollama", settings.ollama),
        ("🧵 Threads", settings.threads),
        ("⚙️ Jobs", settings.jobs),
        ("⚡ Optimization", settings.optimization),
        ("🎓 Learning", settings.learning),
        ("🚦 Limits", settings.limits),
        ("📈 Trends", settings.trends),
    ]

    for section_name, section_obj in sections:
        print(f"\n[bold green]{section_name}[/bold green]")
        for attr, value in section_obj.__dict__.items():
            print(f"  {attr}: {value}")

    print(f"\n[dim]Archivo: {CONFIG_FILE}[/dim]")


@config_app.command("get")
def config_get(
    key: Annotated[str, typer.Argument(help="Clave a obtener (ej: mlx.device)")],
):
    """Obtiene un valor de la configuración con notación de puntos."""
    try:
        value = get_nested_setting(settings, key)
        print(f"[green]{key}[/green] = {value}")
    except ValueError as e:
        print(f"[bold red]Error:[/bold red] {e}")
        raise typer.Exit(code=1)


@config_app.command("set")
def config_set(key: str, value: str):
    """
    Modifica una clave en ai_model_params.toml.
    Soporta notación de puntos para todas las secciones.
    Ej: mlx.device metal, limits.max_memory_usage 0.9, ollama.timeout_seconds 60
    """
    global settings

    try:
        set_nested_setting(settings, key, value)
        save_settings(settings)
        print(f"[green]✅[/green] {key} = {value} → {CONFIG_FILE}")

        # Recargar settings para mantener consistencia
        settings = load_settings()

    except ValueError as e:
        print(f"[red]❌[/red] {e}")
        raise typer.Exit(code=1)


@config_app.command("export")
def config_export():
    """Exporta todas las variables de entorno AI."""
    env_vars = export_all_env_vars(settings)
    print("[bold cyan]Variables de Entorno AI:[/bold cyan]")
    print("=" * 40)

    for key, value in sorted(env_vars.items()):
        print(f"export {key}='{value}'")

    print(f"\n[dim]Total: {len(env_vars)} variables[/dim]")


@app.command()
def scan(
    path: Annotated[Path, typer.Argument(help="Directorio base para escanear.")],
    parallel: Annotated[
        bool,
        typer.Option("--parallel", "-p", help="Activa el escaneo en paralelo."),
    ] = False,
    threads: Annotated[int, typer.Option(help="Número de hilos a usar.")] = settings.jobs.scan_workers,
    quick: Annotated[
        bool,
        typer.Option("--quick", help="Realiza un escaneo rápido sin hashing."),
    ] = False,
    only: Annotated[
        str,
        typer.Option(
            "--only",
            "-o",
            help="Filtro por tipo/extensión: media,audio,video,other,all,mp3,wav,...",
        ),
    ] = "media",
):
    """Escanea un directorio con filtros reales de medios y archivos auxiliares."""
    from core.scanner import Scanner

    print(f"🔍 Escaneando [bold magenta]{path}[/bold magenta]...")
    print(f"   - Paralelo: {'✅' if parallel else '❌'}")
    print(f"   - Hilos: {threads}")
    print(f"   - Rápido: {'✅' if quick else '❌'}")
    print(f"   - Filtro: {only}")

    if not path.exists():
        print(f"[bold red]Error:[/bold red] El directorio no existe: {path}")
        raise typer.Exit(code=1)

    os.environ["DJPT_ALLOW_OUTSIDE"] = "1"
    os.environ.setdefault("DJPT_BASE_DIR", str(path.resolve()))
    if parallel and threads > 0:
        os.environ["DJPT_PARALLEL_THREADS"] = str(threads)

    try:
        scanner = Scanner(path, only=[only])
        output_dir = scanner.run(quick=quick, parallel=parallel, max_workers=threads if parallel else None)
        manifest = json.loads((output_dir / "manifest.json").read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"[bold red]Error:[/bold red] No se pudo completar el escaneo: {exc}")
        raise typer.Exit(code=2)

    print("\n[green]Escaneo completado.[/green]")
    print(f"   - Archivos: {manifest['file_count']}")
    print(f"   - Selección: {', '.join(manifest.get('selection', ['media']))}")
    sys.stdout.write(f"   - Salida: {output_dir}\n")


# ---------------------- AI subcommands ---------------------- #


@ai_app.command("install-deps")
def ai_install_deps():
    """Instala dependencias AI con fallback editable -> requirements.txt."""
    attempts = [
        (
            "editable extras [ai]",
            ["-e", ".[ai]"],
            "DJPT_PIP_INSTALL_MOCK_EDITABLE_RC",
        ),
    ]
    requirements_file = REPO_ROOT / "requirements.txt"
    if requirements_file.exists():
        attempts.append(
            (
                "requirements.txt",
                ["-r", str(requirements_file)],
                "DJPT_PIP_INSTALL_MOCK_REQUIREMENTS_RC",
            )
        )
    else:
        print(f"[yellow][WARN][/yellow] fallback omitido: no existe {requirements_file}")

    last_rc = 1
    for label, args, mock_key in attempts:
        last_rc = _run_pip_install_attempt(label, args, mock_key)
        if last_rc == 0:
            raise typer.Exit(code=0)

    raise typer.Exit(code=last_rc)


@ai_app.command("status")
def ai_status():
    """Estado IA vía ai_suite (optimiza y escribe perfil)."""
    rc = _run_ai_suite(["optimize"])
    raise typer.Exit(code=rc)


@ai_app.command("train")
def ai_train(
    model_type: str = typer.Option("classifier", "--type", "-t", help="classifier|recommender|generative"),
):
    rc = _run_ai_suite(["train", "--type", model_type])
    raise typer.Exit(code=rc)


@ai_app.command("docs")
def ai_docs(
    file: Path = typer.Argument(..., exists=True, help="Archivo a analizar"),
):
    rc = _run_ai_suite(["docs", "--file", str(file)])
    raise typer.Exit(code=rc)


@ai_app.command("kb")
def ai_kb(
    action: str = typer.Option(..., "--action", "-a", help="index-text|index-audio|embed|query|status"),
    path: Path = typer.Option(None, "--path", help="Ruta base", exists=False),
    ext: str = typer.Option(
        None,
        "--ext",
        help="Lista de extensiones separadas por coma para index-text",
    ),
    asr: str = typer.Option("mlx", "--asr", help="Backend ASR para index-audio"),
    query: str = typer.Option(None, "--query", help="Consulta para RAG"),
    topk: int = typer.Option(5, "--topk", help="Top resultados"),
):
    args = ["kb", "--action", action]
    if path:
        args += ["--path", str(path)]
    if ext:
        args += ["--ext", ext]
    if asr:
        args += ["--asr", asr]
    if query:
        args += ["--query", query]
    if topk:
        args += ["--topk", str(topk)]
    rc = _run_ai_suite(args)
    raise typer.Exit(code=rc)


@ai_app.command("rag")
def ai_rag(
    action: str = typer.Option("status", "--action", help="index-text|index-audio|query|status"),
    path: Path = typer.Option(None, "--path", help="Ruta base para indexado"),
    query: str = typer.Option(None, "--query", help="Consulta para RAG"),
    topk: int = typer.Option(5, "--topk", help="Top resultados en query"),
):
    """Alias simplificado para operaciones RAG sobre KB."""
    allowed = {"index-text", "index-audio", "query", "status"}
    chosen = action.strip().lower()
    if chosen not in allowed:
        print(json.dumps({"error": "action debe ser index-text|index-audio|query|status"}))
        raise typer.Exit(code=2)

    args = ["kb", "--action", chosen]
    if path is not None:
        args += ["--path", str(path)]
    if query is not None:
        args += ["--query", query]
    if topk:
        args += ["--topk", str(topk)]
    rc = _run_ai_suite(args)
    raise typer.Exit(code=rc)


@ai_app.command("learn")
def ai_learn(
    mode: str = typer.Option(..., "--mode", "-m", help="session|review|params"),
):
    rc = _run_ai_suite(["learn", "--mode", mode])
    raise typer.Exit(code=rc)


@ai_app.command("dynamic")
def ai_dynamic(
    task: str = typer.Option(..., "--task", "-t", help="sync|trends|update_llm"),
):
    rc = _run_ai_suite(["dynamic", "--task", task])
    raise typer.Exit(code=rc)


@ai_app.command("smoke")
def ai_smoke():
    """Smoke test para validar dependencias y estado IA"""
    print("[bold cyan]🔥 DJProducerTools AI Smoke Test[/bold cyan]")
    print("=" * 50)

    # 1. Test estado IA
    print("\n[bold green]1. Testing AI Status...[/bold green]")
    try:
        rc = _run_ai_suite(["optimize"])
        if rc == 0:
            print("✅ AI Status: OK")
        else:
            print(f"❌ AI Status: Failed (rc={rc})")
            raise typer.Exit(1)
    except Exception as e:
        print(f"❌ AI Status: {e}")
        raise typer.Exit(1)

    # 2. Test imports críticos
    print("\n[bold green]2. Testing Critical Imports...[/bold green]")
    critical_modules = [
        ("mlx.core", "MLX"),
        ("tensorflow", "TensorFlow"),
        ("sklearn", "Scikit-learn"),
        ("librosa", "Librosa"),
        ("numpy", "NumPy"),
    ]

    failed_modules = []
    for module_name, display_name in critical_modules:
        try:
            __import__(module_name)
            print(f"✅ {display_name}: OK")
        except ImportError:
            print(f"❌ {display_name}: Missing")
            failed_modules.append(display_name)

    # 3. Test configuración
    print("\n[bold green]3. Testing Configuration...[/bold green]")
    try:
        from config_schema import config_manager

        settings = config_manager.load_settings()
        capabilities = config_manager.detect_capabilities()
        best_backend = config_manager.select_best_backend()

        print(f"✅ Config loaded: {len(settings.__dict__)} sections")
        print(f"✅ Capabilities detected: {best_backend} backend")
    except Exception as e:
        print(f"❌ Configuration: {e}")
        failed_modules.append("Configuration")

    # 4. Resultado final
    print("\n" + "=" * 50)
    if not failed_modules:
        print("[bold green]🎉 SMOKE TEST PASSED - All systems ready![/bold green]")
        print("\n[bold cyan]Next steps:[/bold cyan]")
        print("• Run: djpt ai status")
        print("• Use menu options 70-87")
        print("• Check: djpt config show")
    else:
        print(f"[bold red]❌ SMOKE TEST FAILED - Missing: {', '.join(failed_modules)}[/bold red]")
        print("\n[bold yellow]To fix:[/bold yellow]")
        print("• Run: djpt ai install-deps")
        print("• Or: pip install -e .[ai]")
        raise typer.Exit(1)


@ai_app.command("hf-sync")
def ai_hf_sync(
    action: str = typer.Option("status", "--action", help="status|sync"),
    allow_remote: bool = typer.Option(False, "--allow-remote", help="Permite acceso remoto al HF Hub"),
    force_enable: bool = typer.Option(False, "--force-enable", help="Permite sync aunque esté disabled en config"),
    internet_probe: bool = typer.Option(True, "--internet-probe/--no-internet-probe", help="Exige prueba de internet previa"),
    dry_run: bool = typer.Option(False, "--dry-run", help="Valida sin descargar"),
    verify_remote: bool = typer.Option(True, "--verify-remote/--no-verify-remote", help="Verifica model_info remoto"),
    apply_transformers: bool = typer.Option(
        True,
        "--apply-transformers/--no-apply-transformers",
        help="Aplica model_path al backend transformers",
    ),
    enable_transformers: bool = typer.Option(
        False,
        "--enable-transformers",
        help="Activa transformers.enabled al aplicar binding",
    ),
    output_format: str = typer.Option("text", "--format", help="text|json"),
):
    """Sincroniza un modelo de HuggingFace al almacenamiento local de DJPT."""
    sync_script = REPO_ROOT / "hf_model_sync.py"
    if not sync_script.exists():
        print(json.dumps({"error": f"hf_model_sync.py no encontrado en {sync_script}"}))
        raise typer.Exit(code=2)

    chosen_action = action.strip().lower()
    if chosen_action not in {"status", "sync"}:
        print(json.dumps({"error": "action debe ser status o sync"}))
        raise typer.Exit(code=2)

    cmd = [sys.executable, str(sync_script), chosen_action, "--format", output_format]
    if allow_remote:
        cmd.append("--allow-remote")
    if force_enable:
        cmd.append("--force-enable")
    if not internet_probe:
        cmd.append("--no-internet-probe")
    if dry_run:
        cmd.append("--dry-run")
    if not verify_remote:
        cmd.append("--no-verify-remote")
    if not apply_transformers:
        cmd.append("--no-apply-transformers")
    if enable_transformers:
        cmd.append("--enable-transformers")

    proc = subprocess.run(cmd, capture_output=True, text=True)
    sys.stdout.write(proc.stdout)
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr)
    raise typer.Exit(code=proc.returncode)


@ai_app.command("online-setup")
def ai_online_setup(
    apply: bool = typer.Option(False, "--apply", help="Aplica acciones reales"),
    install_optional_deps: bool = typer.Option(False, "--install-optional-deps", help="Instala optional backends"),
    hf_sync: bool = typer.Option(False, "--hf-sync", help="Ejecuta sync de modelo HF"),
    hf_dry_run: bool = typer.Option(False, "--hf-dry-run", help="Ejecuta sync HF en dry-run"),
    hf_force_enable: bool = typer.Option(False, "--hf-force-enable", help="Fuerza sync HF aunque esté disabled"),
    output_format: str = typer.Option("text", "--format", help="text|json"),
):
    """Setup online asistido (internet + deps opcionales + sync HF)."""
    setup_script = REPO_ROOT / "ai_online_setup.py"
    if not setup_script.exists():
        print(json.dumps({"error": f"ai_online_setup.py no encontrado en {setup_script}"}))
        raise typer.Exit(code=2)

    cmd = [sys.executable, str(setup_script), "--format", output_format]
    if apply:
        cmd.append("--apply")
    if install_optional_deps:
        cmd.append("--install-optional-deps")
    if hf_sync:
        cmd.append("--hf-sync")
    if hf_dry_run:
        cmd.append("--hf-dry-run")
    if hf_force_enable:
        cmd.append("--hf-force-enable")

    proc = subprocess.run(cmd, capture_output=True, text=True)
    sys.stdout.write(proc.stdout)
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr)
    raise typer.Exit(code=proc.returncode)


@ai_app.command("module")
def ai_module(
    action: str = typer.Option("list", "--action", help="init|list|check|run|doctor"),
    name: str = typer.Option(None, "--name", help="Nombre del módulo para init/run"),
    arg: list[str] = typer.Option(None, "--arg", help="Args para run (repetible)"),
    timeout: int = typer.Option(60, "--timeout", help="Timeout para run"),
    output_format: str = typer.Option("text", "--format", help="text|json"),
):
    """Gestor de módulos aislados (plugins) no destructivo."""
    module_script = REPO_ROOT / "module_manager.py"
    if not module_script.exists():
        print(json.dumps({"error": f"module_manager.py no encontrado en {module_script}"}))
        raise typer.Exit(code=2)

    chosen_action = action.strip().lower()
    if chosen_action not in {"init", "list", "check", "run", "doctor"}:
        print(json.dumps({"error": "action debe ser init|list|check|run|doctor"}))
        raise typer.Exit(code=2)

    cmd = [sys.executable, str(module_script), chosen_action, "--format", output_format, "--timeout", str(timeout)]
    if name:
        cmd += ["--name", name]
    for item in (arg or []):
        cmd += ["--arg", item]

    proc = subprocess.run(cmd, capture_output=True, text=True)
    sys.stdout.write(proc.stdout)
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr)
    raise typer.Exit(code=proc.returncode)


if __name__ == "__main__":
    app()

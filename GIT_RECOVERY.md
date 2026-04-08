# Git Recovery

Este árbol no tiene un `.git` operativo. El fichero [.git](/Users/ivan/.codex/worktrees/3416/_DJProducerTools/.git) apunta a un `gitdir` externo inexistente:

```text
gitdir: /Volumes/SeaGate2TB/_DJProducerTools/.git/worktrees/_DJProducerTools5
```

## Qué significa

- El árbol de trabajo está vivo y validado para runtime y release.
- La trazabilidad Git original no puede reconstruirse automáticamente sin un repo fuente válido.
- Reescribir `.git` a ciegas destruiría la relación con el historial real.

## Recuperación segura

Usa [scripts/recover_git_worktree.sh](/Users/ivan/.codex/worktrees/3416/_DJProducerTools/scripts/recover_git_worktree.sh) con un repo sano como fuente:

```bash
bash scripts/recover_git_worktree.sh \
  --source /ruta/a/un/clone_o_repo_git_valido \
  --target /ruta/a/_DJProducerTools_recovered
```

Opcionalmente:

```bash
bash scripts/recover_git_worktree.sh \
  --source /ruta/a/un/repo_git_valido \
  --target /ruta/a/_DJProducerTools_recovered \
  --branch main \
  --mode clone
```

## Resultado esperado

- Se crea un árbol nuevo con `.git` sano.
- Se superpone el contenido actual encima, sin tocar el árbol roto.
- A partir de ahí ya puedes usar `git status`, commits y PR con trazabilidad real desde la fuente válida.

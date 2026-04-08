# Release Publish Checklist (Final)

Release canónico: `DJProducerTools_release_20260408_052132`

## 1) Artefactos de publicación
- [x] ZIP generado: `dist/DJProducerTools_release_20260408_052132.zip`
- [x] SHA256 generado: `dist/DJProducerTools_release_20260408_052132.zip.sha256`
- [x] Handoff testers generado: `dist/DJProducerTools_release_20260408_052132_TESTER_HANDOFF.md`
- [x] Certificación fresh-install: `reports/fresh_install_certification_20260408_052132.md`

## 2) Verificación local mínima previa
- [x] `bash scripts/build_release_package.sh` (incluye smoke + cert + handoff)
- [x] `python3 -m pytest -q tests/test_ml_tf.py`

## 3) Tag de release
Ejecutar desde la rama de release validada:

```bash
git tag -a v2026.04.08-052132 -m "Release DJProducerTools_release_20260408_052132"
git push origin v2026.04.08-052132
```

## 4) Publicación del ZIP + checksum
Subir ambos archivos al release:
- `dist/DJProducerTools_release_20260408_052132.zip`
- `dist/DJProducerTools_release_20260408_052132.zip.sha256`

Comprobación rápida de integridad:

```bash
ACTUAL="$(shasum -a 256 dist/DJProducerTools_release_20260408_052132.zip | awk '{print $1}')"
EXPECTED="$(awk '{print $1}' dist/DJProducerTools_release_20260408_052132.zip.sha256)"
[ "$ACTUAL" = "$EXPECTED" ] && echo "CHECKSUM OK" || echo "CHECKSUM FAIL"
```

## 5) Handoff testers
Compartir con testers:
- `dist/DJProducerTools_release_20260408_052132_TESTER_HANDOFF.md`

Ese documento ya incluye:
- instalación limpia
- smoke mínimo obligatorio
- captura de evidencia si hay fallo
- notas de backends opcionales (local-first)

## 6) Git remoto / PR
Estado esperado para publicar cambios de código:

```bash
git remote -v
git push -u origin main
git push -u origin codex/release-20260408_051458
```

Draft PR (si `gh` está autenticado):

```bash
gh pr create \
  --base main \
  --head codex/release-20260408_051458 \
  --draft \
  --title "Release: DJProducerTools 20260408_052132" \
  --body "Release package, checksum, fresh-install certification, and tester handoff."
```

## 7) Criterio de salida
- [ ] Tag publicado
- [ ] ZIP + SHA256 adjuntos al release
- [ ] Draft PR abierto
- [ ] Testers con handoff canónico

# Características de DJProducerTools (ES)

**Versión:** 2.0.0  
**Última actualización:** 4 de enero de 2024  
**Nota:** DMX (planes + envío ENTTEC en dry-run/confirmado), Video prep (ffprobe + plan transcode), playlists→OSC/DMX y servidor HTTP/OSC básico están parcialmente implementados. BPM (tags/librosa) disponible en modo ligero. ML/TF avanzado sigue en roadmap. Las funciones activas se centran en catálogo/hash, planes de duplicados, backups y reportes TSV.

---

## ✅ Implementado (CLI actual)

- 📂 **Catálogo + Hash**: inventario y TSV de hashes SHA-256 para duplicados exactos.
- 🛡️ **Plan de duplicados + Quarantine**: dupes_plan TSV/JSON, quarantine opcional con `SAFE_MODE`/`DJ_SAFE_LOCK` activos por defecto y soporte `--dry-run`.
- 💾 **Backups DJ**: rsync de `_Serato_` y metadatos DJ (Serato/Traktor/Rekordbox/Ableton) al estado `_DJProducerTools/`.
- 🔍 **Reportes TSV**: snapshot hash rápido, ffprobe de corrupción, relink helper, rescan inteligente, playlists `.m3u8` por carpeta.
- 🧭 **Progreso y safety**: spinners/barras, historial de rutas, gestor de exclusiones y visor de logs.

---

## 🚧 Placeholders / Roadmap

- ML/auto-tagging y TensorFlow Lab (solo planes/reportes).
- Visualización avanzada y exportes HTML/PDF.

---

## 📊 Calidad / Pruebas

- Sin cobertura automatizada; usar `./scripts/DJProducerTools_MultiScript_ES.sh --test` y `scripts/VERIFY_AND_TEST.sh --fast` como smoke tests.
- Acciones destructivas desactivadas por defecto; confirma antes de mover/borrar.

---

## 🔧 Compatibilidad

- macOS 10.15+ recomendado; Bash 4.0+ / zsh.
- Dependencias: ffprobe (ffmpeg), sox, jq, python3 para reportes básicos.

---

## 🗺️ Roadmap breve

- Implementar módulos DMX/Video/OSC/ML o eliminarlos si siguen siendo placeholders.
- Añadir pruebas funcionales automáticas para hash_index → dupes_plan → quarantine.

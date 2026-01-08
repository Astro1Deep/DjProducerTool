# DJProducerTools - Resumen de funcionalidades

- Flujo seguro: `SAFE_MODE=1`, `DJ_SAFE_LOCK=1`, `DRYRUN_FORCE=0`, con confirmaciones y cuarentena gestionada.
- Catálogo, hash index, plan de duplicados exactos, copias de `_Serato_` y reportes TSV (ffprobe, playlists, relink helper).
- Preparación de vídeo: inventario ffprobe + plan de transcodificación con ffmpeg en modo dry-run y códecs acelerados.
- Servidor OSC/API, análisis BPM/librosa, planificador de DMX/OSC y conversión de playlists a OSC/DMX.
- Lab ML/TF local: embeddings, tags, similitud, anomalías, segmentos, loudness, matching, video_tags (CLIP), music_tags (CLAP/MusicGen) y reporte maestro, con descargas ONNX/TFLite.
- Helpers de consolidación (plan + rsync por lotes) con chequeos de espacio, compatibilidad de rsync y reutilización de corpus compartidos.

#!/usr/bin/env python3
import argparse
import sys
import numpy as np
import tensorflow as tf
import tensorflow_hub as hub
import librosa
from sklearn.metrics.pairwise import cosine_similarity

# Desactivar logs de TensorFlow menos importantes
import os
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'

VGGISH_MODEL_URL = "https://tfhub.dev/google/vggish/1"
VGGISH_INPUT_TENSOR_NAME = "vggish/input_features"
VGGISH_OUTPUT_TENSOR_NAME = "vggish/embedding"

def load_audio_as_waveform(file_path, target_sr=16000):
    """Carga un archivo de audio y lo convierte a la forma de onda requerida por VGGish."""
    try:
        waveform, sr = librosa.load(file_path, sr=None, mono=True)
        if sr != target_sr:
            waveform = librosa.resample(waveform, orig_sr=sr, target_sr=target_sr)
        return waveform
    except Exception as e:
        print(f"Error al cargar o procesar el archivo {file_path}: {e}", file=sys.stderr)
        return None

def extract_vggish_embedding(model, waveform, target_sr=16000):
    """Extrae el embedding de VGGish de una forma de onda de audio."""
    if waveform is None:
        return None
    
    # VGGish espera ejemplos de 0.96s. Dividimos la forma de onda en fragmentos.
    # Para simplificar, aquí usamos solo el inicio del audio, pero un enfoque más
    # robusto promediaría los embeddings de varios fragmentos.
    num_samples = int(0.96 * target_sr)
    if len(waveform) < num_samples:
        # Rellenar con ceros si el audio es demasiado corto
        waveform = np.pad(waveform, (0, num_samples - len(waveform)))
    
    waveform = waveform[:num_samples]

    try:
        # El modelo VGGish espera un batch de ejemplos.
        input_data = np.expand_dims(waveform, axis=0)
        
        # Ejecutar el modelo
        embedding = model(input_data)
        
        return embedding.numpy().squeeze()
    except Exception as e:
        print(f"Error al extraer el embedding: {e}", file=sys.stderr)
        return None

def find_similar_audio(files, threshold, model):
    """Encuentra pares de archivos de audio con una similitud por encima del umbral."""
    embeddings = []
    valid_files = []
    
    total_files = len(files)
    for i, file_path in enumerate(files):
        print(f"Procesando archivo {i+1}/{total_files}: {os.path.basename(file_path)}", file=sys.stderr)
        waveform = load_audio_as_waveform(file_path)
        if waveform is not None:
            embedding = extract_vggish_embedding(model, waveform)
            if embedding is not None:
                embeddings.append(embedding)
                valid_files.append(file_path)

    if not embeddings:
        print("No se pudieron extraer embeddings de ningún archivo.", file=sys.stderr)
        return

    # Calcular la matriz de similitud de coseno
    similarity_matrix = cosine_similarity(np.array(embeddings))

    # Imprimir el encabezado del TSV
    print("SIMILARITY_SCORE\tFILE_A\tFILE_B")

    # Encontrar y reportar pares por encima del umbral
    num_files = len(valid_files)
    for i in range(num_files):
        for j in range(i + 1, num_files):
            similarity = similarity_matrix[i, j]
            if similarity >= threshold:
                print(f"{similarity:.4f}\t{valid_files[i]}\t{valid_files[j]}")

def main():
    parser = argparse.ArgumentParser(description="Encuentra archivos de audio similares usando VGGish de TensorFlow.")
    parser.add_argument('--files', nargs='+', required=True, help='Lista de rutas de archivos de audio a comparar.')
    parser.add_argument('--threshold', type=float, default=0.9, help='Umbral de similitud (0.0 a 1.0) para considerar un duplicado. Default: 0.9')
    
    args = parser.parse_args()

    if len(args.files) < 2:
        print("Error: Se requieren al menos dos archivos para la comparación.", file=sys.stderr)
        sys.exit(1)
        
    print("Cargando modelo VGGish desde TensorFlow Hub...", file=sys.stderr)
    try:
        vggish_model = hub.load(VGGISH_MODEL_URL)
        print("Modelo cargado correctamente.", file=sys.stderr)
    except Exception as e:
        print(f"Error fatal al cargar el modelo VGGish: {e}", file=sys.stderr)
        print("Asegúrate de tener conexión a internet la primera vez que se ejecuta.", file=sys.stderr)
        sys.exit(1)

    find_similar_audio(args.files, args.threshold, vggish_model)

if __name__ == "__main__":
    main()

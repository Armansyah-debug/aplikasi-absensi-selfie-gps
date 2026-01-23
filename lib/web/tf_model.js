let modelLoaded = false;

async function loadModel() {
  if (modelLoaded) return;
  // kalau belum punya model, skip dulu
  modelLoaded = true;
}

async function predictFace(imageBytes) {
  await loadModel();

  // simulasi: kalau image ada → wajah terdeteksi
  if (!imageBytes || imageBytes.length === 0) {
    return [];
  }

  // return embedding dummy
  return [0.12, 0.34, 0.56];
}

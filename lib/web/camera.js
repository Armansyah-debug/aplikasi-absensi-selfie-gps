let video;
let stream;

async function startCamera() {
  video = document.createElement('video');
  video.setAttribute('autoplay', '');
  video.setAttribute('playsinline', '');

  stream = await navigator.mediaDevices.getUserMedia({
    video: { facingMode: "user" }
  });

  video.srcObject = stream;
  document.body.appendChild(video);
}

function capturePhoto() {
  const canvas = document.createElement('canvas');
  canvas.width = video.videoWidth;
  canvas.height = video.videoHeight;

  const ctx = canvas.getContext('2d');
  ctx.drawImage(video, 0, 0);

  const dataUrl = canvas.toDataURL('image/jpeg');
  return dataUrl;
}

function stopCamera() {
  if (stream) {
    stream.getTracks().forEach(t => t.stop());
  }
  if (video) video.remove();
}

import 'dart:html' as html;
import 'dart:typed_data';

class WebCameraService {
  static html.VideoElement? _video;

  static Future<html.VideoElement> startCamera() async {
    final stream = await html.window.navigator.mediaDevices!
        .getUserMedia({'video': true});

    _video = html.VideoElement()
      ..srcObject = stream
      ..autoplay = true
      ..style.objectFit = 'cover';

    return _video!;
  }

  static Uint8List captureImage() {
    final canvas = html.CanvasElement(
      width: _video!.videoWidth,
      height: _video!.videoHeight,
    );

    final ctx = canvas.context2D;
    ctx.drawImage(_video!, 0, 0);

    final dataUrl = canvas.toDataUrl('image/jpeg');
    final base64 = dataUrl.split(',').last;

    return Uint8List.fromList(html.window.atob(base64).codeUnits);
  }

  static void stopCamera() {
    final stream = _video?.srcObject as html.MediaStream?;
    stream?.getTracks().forEach((t) => t.stop());
  }
}

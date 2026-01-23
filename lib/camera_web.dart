@JS()
library camera_web;

import 'dart:convert';
import 'dart:typed_data';
import 'package:js/js.dart';

@JS('startCamera')
external Future<void> startCamera();

@JS('capturePhoto')
external String capturePhoto();

@JS('stopCamera')
external void stopCamera();

Uint8List base64ToBytes(String base64Image) {
  final data = base64Image.split(',').last;
  return base64Decode(data);
}

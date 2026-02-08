import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:camera_windows/camera_windows.dart';
import 'package:flutter/foundation.dart';

void registerWindowsCamera() {
  if (defaultTargetPlatform != TargetPlatform.windows) {
    return;
  }
  CameraPlatform.instance = CameraWindows();
}

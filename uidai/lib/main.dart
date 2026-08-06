import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'screens/capture_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Obtain a list of the available cameras on the device.
  final cameras = await availableCameras();

  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UIDAI Capture Pipeline',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: CaptureScreen(cameras: cameras),
      debugShowCheckedModeBanner: false,
    );
  }
}

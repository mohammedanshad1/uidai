import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'screens/capture_screen.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatefulWidget {
  final List<CameraDescription> cameras;

  const MyApp({super.key, required this.cameras});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return MaterialApp(
        title: 'UIDAI Capture Pipeline',
        theme: ThemeData.dark().copyWith(
          primaryColor: Colors.blue,
          scaffoldBackgroundColor: Colors.black,
        ),
        home: SplashScreen(onDone: () => setState(() => _showSplash = false)),
        debugShowCheckedModeBanner: false,
      );
    }

    return MaterialApp(
      title: 'UIDAI Capture Pipeline',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: CaptureScreen(cameras: widget.cameras),
      debugShowCheckedModeBanner: false,
    );
  }
}

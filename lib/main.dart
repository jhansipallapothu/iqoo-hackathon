import 'package:smartbuildlabs/screens/homepage.dart';
import 'package:flutter/material.dart';
import 'package:smartbuildlabs/screens/constapi.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:camera/camera.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  CameraDescription? firstCamera;
  try {
    final cameras = await availableCameras();
    firstCamera = cameras.isNotEmpty ? cameras.first : null;
  } catch (e) {
    print("Error initializing camera: $e");
    firstCamera = null;
  }

  try {
    Gemini.init(apiKey: GEMINI_API_KEY);
  } catch (e) {
    print("Error initializing Gemini API: $e");
  }

  runApp(MyApp(camera: firstCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription? camera;

  const MyApp({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Logic Legends',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: HomeScreen(camera: camera),
    );
  }
}

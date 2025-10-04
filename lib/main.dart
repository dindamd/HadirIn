import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'pages/home_page.dart';
import 'services/api_service.dart';

// ✅ Hapus import camera_page.dart karena sudah tidak diperlukan

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Absensi App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Poppins',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontWeight: FontWeight.w400),
        ),
      ),
      home: HomePage(cameras: cameras),
    );
  }
}
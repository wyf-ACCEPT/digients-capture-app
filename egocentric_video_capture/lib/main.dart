import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const EgocentricVideoCaptureApp());
}

class EgocentricVideoCaptureApp extends StatelessWidget {
  const EgocentricVideoCaptureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Egocentric Video Capture',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
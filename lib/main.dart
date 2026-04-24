import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const DigientsApp());
}

class DigientsApp extends StatelessWidget {
  const DigientsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digients App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
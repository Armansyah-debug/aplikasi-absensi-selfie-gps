import 'package:flutter/material.dart';

class JurusanScreen extends StatelessWidget {
  const JurusanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Kelola Jurusan',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
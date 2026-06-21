import 'package:flutter/material.dart';

class DosenScreen extends StatelessWidget {
  const DosenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Kelola Dosen',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
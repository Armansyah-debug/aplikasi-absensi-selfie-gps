import 'package:flutter/material.dart';

class PengampuScreen extends StatelessWidget {
  const PengampuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Kelola Pengampu',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
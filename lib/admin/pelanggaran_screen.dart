import 'package:flutter/material.dart';

class PelanggaranScreen extends StatelessWidget {
  const PelanggaranScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Kelola Pelanggaran',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
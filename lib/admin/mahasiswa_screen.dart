import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'theme/admin_theme.dart';

class MahasiswaScreen extends StatefulWidget {
  const MahasiswaScreen({super.key});

  @override
  State<MahasiswaScreen> createState() => _MahasiswaScreenState();
}

class _MahasiswaScreenState extends State<MahasiswaScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.getMahasiswaList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final mahasiswa = snapshot.data!;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kelola Mahasiswa',
                style: AdminTheme.h1,
              ),
              const SizedBox(height: 6),
              const Text(
                'Manajemen data mahasiswa kampus',
                style: AdminTheme.body,
              ),

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: AdminTheme.cardDecoration,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: AdminTheme.inputDecoration(
                          label: 'Cari Mahasiswa',
                          prefixIcon: Icons.search,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Container(
                decoration: AdminTheme.cardDecoration,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Nama')),
                    DataColumn(label: Text('NPM')),
                    DataColumn(label: Text('Jurusan')),
                    DataColumn(label: Text('Semester')),
                    DataColumn(label: Text('Email')),
                  ],
                  rows: mahasiswa.map((m) {
                    return DataRow(
                      cells: [
                        DataCell(Text('${m['nama'] ?? '-'}')),
                        DataCell(Text('${m['npm'] ?? '-'}')),
                        DataCell(Text('${m['jurusan'] ?? '-'}')),
                        DataCell(Text('${m['semester'] ?? '-'}')),
                        DataCell(Text('${m['email'] ?? '-'}')),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
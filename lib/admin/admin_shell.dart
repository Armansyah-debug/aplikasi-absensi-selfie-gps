import 'package:flutter/material.dart';

import 'admin_screen.dart';
import 'mahasiswa_screen.dart';
import 'dosen_screen.dart';
import 'jurusan_screen.dart';
import 'pengampu_screen.dart';
import 'monitoring_screen.dart';
import 'statistik_screen.dart';
import 'mahasiswa_risiko_screen.dart';
import 'pelanggaran_screen.dart';
import 'profil_admin_screen.dart';

import 'kelola_mk_screen.dart';
import 'kelola_sesi_screen.dart';
import 'riwayat_admin_screen.dart';
import 'export_data_screen.dart';

import 'widgets/admin_sidebar.dart';
import 'widgets/admin_top_bar.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;

  Widget _getPage() {
  switch (_currentIndex) {
    case 0:
      return const AdminScreen();

    case 1:
      return const MahasiswaScreen();

    case 2:
      return const DosenScreen();

    case 3:
      return const JurusanScreen();

    case 4:
      return const KelolaMKScreen();

    case 5:
      return const PengampuScreen();

    case 6:
      return const MonitoringScreen();

    case 7:
      return const KelolaSesiScreen();

    case 8:
      return const RiwayatAdminScreen();

    case 9:
      return const StatistikScreen();

    case 10:
      return const MahasiswaRisikoScreen();

    case 11:
      return const PelanggaranScreen();

    case 12:
      return const ExportDataScreen();

    case 13:
      return const ProfilAdminScreen();

    default:
      return const AdminScreen();
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          AdminSidebar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),

          Expanded(
            child: Column(
              children: [
                const AdminTopBar(),

                Expanded(
                  child: Container(
                    color: const Color(0xFFF8FAFC),
                    child: _getPage(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';

import 'admin_screen.dart';
import 'mahasiswa_screen.dart';
import 'dosen_screen.dart';
import 'pengampu_screen.dart';
import 'monitoring_screen.dart';
import 'statistik_screen.dart';
import 'mahasiswa_risiko_screen.dart';
import 'pelanggaran_screen.dart';
import 'profil_admin_screen.dart';
import 'tools_akademik_screen.dart';

import 'kelola_mk_screen.dart';
import 'kelola_sesi_screen.dart';
import 'riwayat_admin_screen.dart';

import 'widgets/admin_sidebar.dart';
import 'widgets/admin_top_bar.dart';
import 'theme/admin_theme.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;

  // Sidebar menu index mapping:
  // 0  = Dashboard
  // 1  = Mahasiswa
  // 2  = Dosen
  // 3  = Mata Kuliah
  // 4  = Pengampu
  // 5  = Monitoring Absensi
  // 6  = Kelola Sesi
  // 7  = Laporan (Statistik/Rekapitulasi)
  // 8  = Riwayat
  // 9  = Mahasiswa Risiko
  // 10 = Pelanggaran
  // 11 = Tools Akademik
  // 12 = Profil

  Widget _getPage() {
    switch (_currentIndex) {
      case 0:
        return const AdminScreen();
      case 1:
        return const MahasiswaScreen();
      case 2:
        return const DosenScreen();
      case 3:
        return const KelolaMKScreen();
      case 4:
        return const PengampuScreen();
      case 5:
        return const MonitoringScreen();
      case 6:
        return const KelolaSesiScreen();
      case 7:
        return const StatistikScreen();
      case 8:
        return const RiwayatAdminScreen();
      case 9:
        return const MahasiswaRisikoScreen();
      case 10:
        return const PelanggaranScreen();
      case 11:
        return const ToolsAkademikScreen();
      case 12:
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
            onNewSession: () {
              setState(() => _currentIndex = 6);
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

                // ─── Footer ───
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    color: AdminTheme.surface,
                    border: Border(top: BorderSide(color: AdminTheme.border)),
                  ),
                  child: Center(
                    child: Text(
                      '© ${DateTime.now().year} UniCheck System • Direktorat Akademik',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AdminTheme.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
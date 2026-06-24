import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';

class NotifikasiScreen extends StatefulWidget {
  const NotifikasiScreen({super.key});

  @override
  State<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends State<NotifikasiScreen> {
  List<Map<String, dynamic>> _pengumuman = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchPengumuman();
  }

  Future<void> _fetchPengumuman() async {
    setState(() => _loading = true);
    final data = await SupabaseService.getPengumuman();
    if (mounted) {
      setState(() {
        _pengumuman = data;
        _loading = false;
      });
    }
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd MMM yyyy, HH:mm').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Notifikasi & Pengumuman', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF4343D9),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4343D9)))
          : RefreshIndicator(
              onRefresh: _fetchPengumuman,
              color: const Color(0xFF4343D9),
              child: _pengumuman.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 100),
                        Icon(Icons.notifications_off_outlined, size: 60, color: Colors.black26),
                        SizedBox(height: 16),
                        Center(child: Text('Belum ada pengumuman terbaru.', style: TextStyle(color: Colors.black54, fontSize: 16))),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _pengumuman.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        final item = _pengumuman[i];
                        final judul = item['judul'] ?? 'Pengumuman';
                        final pesan = item['pesan'] ?? '';
                        final tanggal = item['tanggal'] != null ? _formatDate(item['tanggal']) : '';

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.campaign_rounded, color: Color(0xFF4343D9), size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      judul,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1D20)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                pesan,
                                style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                tanggal,
                                style: const TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

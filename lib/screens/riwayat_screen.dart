import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';

class RiwayatScreen extends StatelessWidget {
  const RiwayatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('User belum login')));
    }

    return FutureBuilder<String?>(
      future: SupabaseService.getUserRole(user.id),
      builder: (context, roleSnapshot) {
        if (!roleSnapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final role = roleSnapshot.data ?? 'user';
        final isAdmin = role == 'admin';

        return Scaffold(
          appBar: AppBar(
            title: Text('Riwayat (${role.toUpperCase()})'),
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
          ),
          body: StreamBuilder<List<Map<String, dynamic>>>(
            stream: isAdmin
                ? SupabaseService.streamAllData()
                : SupabaseService.streamMyData(user.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final dataList = snapshot.data!;
              if (dataList.isEmpty) return const Center(child: Text('Belum ada data riwayat'));

              return ListView.builder(
                itemCount: dataList.length,
                itemBuilder: (context, index) {
                  final data = dataList[index];
                  final nama = data['nama'] ?? '-';
                  final npm = data['npm'] ?? '-';
                  final jenis = data['jenis'] ?? '-';
                  final alamat = data['alamat'] ?? 'Lokasi tidak tersedia';
                  final alasan = data['alasan'] ?? '-';
                  final fotoPath = data['foto_path'] as String? ?? '';
                  
                  // Mengambil URL foto dari bucket 'selfies'
                  final fotoUrl = SupabaseService.getFotoUrl(fotoPath, bucketName: 'selfies');
                  
                  final isHadir = jenis == 'Hadir';

                  String waktuText = '-';
                  if (data['waktu'] != null) {
                    try {
                      waktuText = DateFormat('dd MMM yyyy, HH:mm')
                          .format(DateTime.parse(data['waktu']));
                    } catch (_) {}
                  }

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      // TAMPILKAN FOTO UNTUK SEMUA JENIS (HADIR/IZIN/SAKIT)
                      leading: fotoUrl.isNotEmpty
                          ? GestureDetector(
                              onTap: () => _showFullImage(context, fotoUrl, jenis),
                              child: Hero(
                                tag: 'foto_$index',
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    fotoUrl,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return const SizedBox(width: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                                    },
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 60, color: Colors.grey[200],
                                      child: const Icon(Icons.broken_image, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : CircleAvatar(
                              radius: 30,
                              backgroundColor: isHadir ? Colors.blue.shade100 : Colors.orange.shade100,
                              child: Icon(isHadir ? Icons.person : Icons.assignment, color: isHadir ? Colors.blue : Colors.orange),
                            ),
                      title: Text('$nama ($npm)', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          isHadir ? '📍 $alamat\n📅 $waktuText' : '📝 $jenis - $alasan\n📅 $waktuText',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      trailing: isAdmin 
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () async {
                              final confirm = await _confirmDelete(context);
                              if (confirm) {
                                await SupabaseService.deleteAbsen(data['id'], fotoPath: fotoPath);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data berhasil dihapus')));
                                }
                              }
                            },
                          )
                        : null,
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  // Fungsi untuk konfirmasi hapus
  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hapus Data'),
            content: const Text('Yakin ingin menghapus data ini? Foto di storage juga akan terhapus.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Hapus'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // Fungsi untuk memperbesar foto bukti saat diklik
  void _showFullImage(BuildContext context, String url, String title) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(10), // Memberi jarak agar tidak mentok layar
      child: Column(
        mainAxisSize: MainAxisSize.min, // Agar dialog menyesuaikan ukuran konten
        children: [
          // Tombol Tutup di atas foto
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          
          // Container untuk Gambar agar tidak overflow
          Flexible(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: InteractiveViewer( // User bisa zoom (cubit) foto
                panEnabled: true, 
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  url,
                  fit: BoxFit.contain, // Memastikan seluruh foto terlihat tanpa terpotong
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    padding: const EdgeInsets.all(20),
                    color: Colors.white,
                    child: const Icon(Icons.broken_image, size: 50, color: Colors.red),
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 15),
          
          // Keterangan di bawah foto
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "Bukti $title",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20), // Padding bawah agar tidak mepet
        ],
      ),
    ),
  );
}
}
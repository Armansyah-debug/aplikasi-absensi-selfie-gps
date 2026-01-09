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
          appBar: AppBar(title: Text('Riwayat (${role.toUpperCase()})')),
          body: StreamBuilder<List<Map<String, dynamic>>>(
            stream: isAdmin
                ? SupabaseService.streamAllData()
                : SupabaseService.streamMyData(user.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final dataList = snapshot.data!;
              if (dataList.isEmpty) return const Center(child: Text('Belum ada data'));

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
                  final fotoUrl = SupabaseService.getFotoUrl(fotoPath);
                  final isHadir = jenis == 'Hadir';

                  String waktuText = '-';
                  if (data['waktu'] != null) {
                    try {
                      waktuText = DateFormat('dd MMM yyyy HH:mm')
                          .format(DateTime.parse(data['waktu']));
                    } catch (_) {}
                  }

                  final card = Card(
                    color: isHadir ? Colors.blue[50] : Colors.orange[50],
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: ListTile(
                      leading: isHadir && fotoUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(40),
                              child: Image.network(
                                fotoUrl,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.error),
                              ),
                            )
                          : Icon(isHadir ? Icons.face : Icons.sick, size: 60),
                      title: Text('$nama ($npm)', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(isHadir ? '$alamat\n$waktuText' : '$jenis - $alasan\n$waktuText'),
                      trailing: isAdmin ? const Icon(Icons.delete, color: Colors.red) : null,
                    ),
                  );

                  if (isAdmin) {
                    return Dismissible(
                      key: Key(data['id'].toString()),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async => await _confirmDelete(context),
                      onDismissed: (_) async {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('Menghapus data...')));
                        await SupabaseService.deleteData(data['id'], fotoPath: fotoPath.isNotEmpty ? fotoPath : null);
                      },
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white, size: 30),
                      ),
                      child: card,
                    );
                  }

                  return card;
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hapus Data'),
            content: const Text('Yakin ingin menghapus data absensi ini?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Hapus'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

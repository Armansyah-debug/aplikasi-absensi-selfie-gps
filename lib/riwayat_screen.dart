import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/firestore_service.dart';

class RiwayatScreen extends StatelessWidget {
  const RiwayatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Lengkap'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.getAllAbsen(),
        builder: (context, absenSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirestoreService.getAllIzinCuti(),
            builder: (context, izinSnapshot) {
              if (absenSnapshot.hasError || izinSnapshot.hasError) {
                return Center(child: Text('Error: ${absenSnapshot.error ?? izinSnapshot.error}'));
              }

              if (absenSnapshot.connectionState == ConnectionState.waiting ||
                  izinSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final absenDocs = absenSnapshot.data?.docs ?? [];
              final izinDocs = izinSnapshot.data?.docs ?? [];

              final allDocs = <Map<String, dynamic>>[
                ...absenDocs.map((doc) => {
                      'id': doc.id,
                      'data': doc.data() as Map<String, dynamic>,
                      'type': 'absen',
                    }),
                ...izinDocs.map((doc) => {
                      'id': doc.id,
                      'data': doc.data() as Map<String, dynamic>,
                      'type': 'izin_cuti',
                    }),
              ];

              if (allDocs.isEmpty) {
                return const Center(child: Text('Belum ada data riwayat'));
              }

              // Sort by timestamp descending
              allDocs.sort((a, b) {
                final Timestamp? aTime = a['data']['timestamp'] as Timestamp?;
                final Timestamp? bTime = b['data']['timestamp'] as Timestamp?;
                final DateTime aDate = aTime?.toDate() ?? DateTime(1970);
                final DateTime bDate = bTime?.toDate() ?? DateTime(1970);
                return bDate.compareTo(aDate);
              });

              return ListView.builder(
                itemCount: allDocs.length,
                itemBuilder: (context, index) {
                  final item = allDocs[index];
                  final data = item['data'] as Map<String, dynamic>;
                  final String docId = item['id'] as String;
                  final String type = item['type'] as String;
                  final bool isAbsen = type == 'absen';

                  return Dismissible(
                    key: Key(docId),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white, size: 30),
                    ),
                    onDismissed: (_) async {
                      if (isAbsen) {
                        await FirestoreService.deleteAbsen(docId);
                      } else {
                        await FirestoreService.deleteIzinCuti(docId);
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Data dihapus')),
                      );
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: isAbsen ? Colors.blue.shade50 : Colors.orange.shade50,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: isAbsen
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: data['photo_url'] != null && (data['photo_url'] as String).isNotEmpty
                                    ? Image.network(
                                        data['photo_url'],
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return const SizedBox(
                                            width: 80,
                                            height: 80,
                                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 80,
                                            height: 80,
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.person, size: 40, color: Colors.grey),
                                          );
                                        },
                                      )
                                    : Container(
                                        width: 80,
                                        height: 80,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.person, size: 40, color: Colors.grey),
                                      ),
                              )
                            : const Icon(Icons.note_alt_outlined, size: 40, color: Colors.orange),
                        title: Text(
                          isAbsen
                              ? '${data['name']} (${data['npm'] ?? '-'})'
                              : '${data['name']} (${data['npm'] ?? '-'}) - ${data['jenis']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('dd MMM yyyy HH:mm').format((data['timestamp'] as Timestamp).toDate()),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            if (isAbsen) Text('Lokasi: ${data['address'] ?? 'Tidak tersedia'}'),
                            if (!isAbsen) ...[
                              Text('Mulai: ${DateFormat('dd MMM yyyy').format((data['tanggal_mulai'] as Timestamp).toDate())}'),
                              Text('Akhir: ${DateFormat('dd MMM yyyy').format((data['tanggal_akhir'] as Timestamp).toDate())}'),
                              Text('Alasan: ${data['alasan']}'),
                            ],
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
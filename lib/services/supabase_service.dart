import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Untuk cek platform

class SupabaseService {
  static final _supabase = Supabase.instance.client;

  // =====================================================
  // GET USER ROLE
  // =====================================================
  static Future<String?> getUserRole(String userId) async {
    try {
      final res = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();

      return res['role'] as String?;
    } catch (e) {
      debugPrint('❌ ERROR GET USER ROLE: $e');
      return null;
    }
  }

  // =====================================================
  // UPLOAD SELFIE (WEB/MOBILE)
  // =====================================================
  // Fungsi ini sudah cukup generik, bisa digunakan untuk upload bukti juga
  static Future<String?> uploadFile({
    required Uint8List bytes,
    required String fileName,
    required String bucketName, // Menentukan bucket mana yang dituju
    String contentType = 'image/jpeg',
  }) async {
    try {
      await _supabase.storage.from(bucketName).uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(contentType: contentType),
          );
      // Mengembalikan path file relatif di bucket
      return fileName; 
    } catch (e) {
      debugPrint('❌ UPLOAD ERROR: $e');
      return null;
    }
  }
  
  // Fungsi helper untuk upload selfie yang sudah ada
  static Future<String?> uploadSelfieWeb(Uint8List bytes, String npm) async {
    final fileName = '${npm}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    // Menggunakan bucket 'selfies'
    return uploadFile(bytes: bytes, fileName: fileName, bucketName: 'selfies');
  }


  // =====================================================
  // INSERT ABSEN HADIR
  // =====================================================
  static Future<void> insertAbsen({
    required String name,
    required String npm,
    required String location,
    required String address,
    required String foto_path,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw 'User belum login';

    await _supabase.from('data_absensi').insert({
      'nama': name,
      'npm': npm,
      'lokasi': location,
      'alamat': address,
      'foto_path': foto_path, // Path foto selfie
      'jenis': 'Hadir',
      'status': 'Hadir',
      'user_id': userId,
      'waktu': DateTime.now().toIso8601String(),
    });
  }

  // =====================================================
  // INSERT IZIN / SAKIT / CUTI (Ditambahkan 'fotoBuktiUrl')
  // =====================================================
  static Future<void> insertIzin({
    required String name,
    required String npm,
    required String jenis,
    required String alasan,
    required DateTime tanggalMulai,
    required DateTime tanggalSelesai,
    required String fotoBuktiUrl, 
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw 'User belum login';

    final rentangTanggal =
        '${tanggalMulai.toIso8601String().split("T")[0]}'
        ' s/d '
        '${tanggalSelesai.toIso8601String().split("T")[0]}';

    await _supabase.from('data_absensi').insert({
      'nama': name,
      'npm': npm,
      'jenis': jenis,
      'alasan': '$alasan ($rentangTanggal)',
      'status': jenis,
      'user_id': userId,
      'waktu': tanggalMulai.toIso8601String(),
      'foto_path': fotoBuktiUrl, 
    });
  }

  // =====================================================
  // STREAM DATA ABSENSI (ADMIN)
  // =====================================================
  static Stream<List<Map<String, dynamic>>> streamAllData() {
    return _supabase
        .from('data_absensi')
        .stream(primaryKey: ['id'])
        .order('waktu', ascending: false);
  }

  // =====================================================
  // STREAM DATA ABSENSI USER
  // =====================================================
  static Stream<List<Map<String, dynamic>>> streamMyData(String userId) {
    return _supabase
        .from('data_absensi')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('waktu', ascending: false);
  }

  // =====================================================
  // GET FOTO URL (Diperbarui untuk dinamis)
  // =====================================================
  static String getFotoUrl(String path, {String bucketName = 'selfies'}) {
    if (path.isEmpty) return '';
    // Cek apakah path sudah berupa URL lengkap (bukti izin dari gallery)
    if (path.startsWith('http://') || path.startsWith('https://')) {
        return path;
    }
    // Jika masih path relatif, tambahkan URL publik Supabase
    return Supabase.instance.client.storage
        .from(bucketName)
        .getPublicUrl(path);
  }


  // =====================================================
  // DELETE ABSENSI + FOTO
  // =====================================================
  static Future<void> deleteAbsen(
    int id, {
    String? fotoPath,
  }) async {
    try {
      if (fotoPath != null && fotoPath.isNotEmpty && !fotoPath.startsWith('http')) {
        // Hapus file dari storage hanya jika path-nya relatif (asumsi dari bucket 'selfies')
        await _supabase.storage.from('selfies').remove([fotoPath]);
      }

      await _supabase.from('data_absensi').delete().eq('id', id);
    } catch (e) {
      debugPrint('❌ DELETE ERROR: $e');
      rethrow;
    }
  }
}

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final _supabase = Supabase.instance.client;

  // =====================================================
  // ROLE
  // =====================================================
  static Future<String?> getUserRole(String userId) async {
    try {
      final res = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      return res?['role'];
    } catch (e) {
      debugPrint('ROLE ERROR: $e');
      return null;
    }
  }

  // =====================================================
  // UPLOAD FILE (SELFIE / BUKTI)
  // =====================================================
  static Future<String?> uploadFile({
    required Uint8List bytes,
    required String fileName,
    required String bucketName,
    String contentType = 'image/jpeg',
  }) async {
    try {
      await _supabase.storage.from(bucketName).uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(contentType: contentType),
          );

      return fileName;
    } catch (e) {
      debugPrint('UPLOAD ERROR: $e');
      return null;
    }
  }

  static Future<String?> uploadSelfieWeb(Uint8List bytes, String npm) async {
    final fileName = '${npm}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    return uploadFile(
      bytes: bytes,
      fileName: fileName,
      bucketName: 'selfies',
    );
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
    bool isMocked = false,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw 'User belum login';

    await _supabase.from('data_absensi').insert({
      'nama': name,
      'npm': npm,
      'lokasi': location,
      'alamat': address,
      'foto_path': foto_path,
      'jenis': 'Hadir',
      'status': 'Hadir',
      'user_id': userId,
      'waktu': DateTime.now().toIso8601String(),
      'is_mocked': isMocked,
    });
  }

  // =====================================================
  // INSERT IZIN / CUTI / SAKIT
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

    await _supabase.from('data_absensi').insert({
      'nama': name,
      'npm': npm,
      'jenis': jenis,
      'alasan': alasan,
      'status': jenis,
      'foto_path': fotoBuktiUrl,
      'user_id': userId,

      // biar konsisten untuk filter tanggal
      'waktu': tanggalMulai.toIso8601String(),
    });
  }

  // =====================================================
  // STREAM ALL (ADMIN)
  // =====================================================
  static Stream<List<Map<String, dynamic>>> streamAllData() {
    return _supabase
        .from('data_absensi')
        .stream(primaryKey: ['id'])
        .order('waktu', ascending: false);
  }

  // =====================================================
  // STREAM USER
  // =====================================================
  static Stream<List<Map<String, dynamic>>> streamMyData(String userId) {
    return _supabase
        .from('data_absensi')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('waktu', ascending: false);
  }

  // =====================================================
  // FOTO URL (FIX AMAN)
  // =====================================================
  static String getFotoUrl(String path, {String bucketName = 'selfies'}) {
    if (path.isEmpty) return '';

    if (path.startsWith('http')) return path;

    return _supabase.storage
        .from(bucketName)
        .getPublicUrl(path);
  }

  // =====================================================
  // DELETE ABSEN + FOTO
  // =====================================================
  static Future<void> deleteAbsen(
    dynamic id, {
    String? fotoPath,
  }) async {
    try {
      if (fotoPath != null &&
          fotoPath.isNotEmpty &&
          !fotoPath.startsWith('http')) {
        await _supabase.storage
            .from('selfies')
            .remove([fotoPath]);
      }

      await _supabase
          .from('data_absensi')
          .delete()
          .eq('id', id);
    } catch (e) {
      debugPrint('DELETE ERROR: $e');
      rethrow;
    }
  }
}
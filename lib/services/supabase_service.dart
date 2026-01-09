import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final _supabase = Supabase.instance.client;

  /// Upload selfie ke bucket 'selfies'
  static Future<String?> uploadSelfie(File imageFile, String npm) async {
    if (!await imageFile.exists()) return null;

    final fileName = '${npm}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    try {
      await _supabase.storage.from('selfies').upload(fileName, imageFile);
      return fileName; // simpan di DB sebagai foto_path
    } catch (e) {
      debugPrint('❌ ERROR UPLOAD SELFIE: $e');
      return null;
    }
  }

  /// Generate public URL dari nama file
  static String getFotoUrl(String fileName) {
    if (fileName.isEmpty) return '';

    try {
      final response = _supabase.storage.from('selfies').getPublicUrl(fileName);
      return response;
    } catch (e) {
      debugPrint('❌ ERROR GET FOTO URL: $e');
      return '';
    }
  }

  /// Ambil role user
  static Future<String> getUserRole(String userId) async {
    try {
      final res = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();
      return res['role'] as String;
    } catch (e) {
      debugPrint('❌ ERROR GET ROLE: $e');
      return 'user';
    }
  }

  /// Ambil NPM user
  static Future<String?> getUserNpm(String userId) async {
    try {
      final res = await _supabase
          .from('profiles')
          .select('npm')
          .eq('id', userId)
          .single();
      return res['npm'] as String?;
    } catch (e) {
      debugPrint('❌ ERROR GET NPM: $e');
      return '';
    }
  }

  /// Insert absen hadir
  static Future<void> insertAbsen({
    required String name,
    required String npm,
    required String location,
    required String address,
    required String foto_path,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User is not authenticated");

    try {
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
      });
    } catch (e) {
      debugPrint('❌ ERROR INSERT ABSEN: $e');
      rethrow;
    }
  }

  /// Insert izin / absen khusus
  static Future<void> insertIzin({
    required String name,
    required String npm,
    required String jenis,
    required String alasan,
    required DateTime tanggalMulai,
    required DateTime tanggalSelesai,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User is not authenticated");

    final rentangTanggal =
        "Dari: ${tanggalMulai.toString().split(' ')[0]} Sampai: ${tanggalSelesai.toString().split(' ')[0]}";
    final alasanLengkap = "$alasan ($rentangTanggal)";

    try {
      await _supabase.from('data_absensi').insert({
        'nama': name,
        'npm': npm,
        'jenis': jenis,
        'alasan': alasanLengkap,
        'status': jenis,
        'user_id': userId,
        'waktu': tanggalMulai.toIso8601String(),
      });
    } catch (e) {
      debugPrint('❌ ERROR INSERT IZIN: $e');
      rethrow;
    }
  }

  /// Stream semua data absensi (admin)
  static Stream<List<Map<String, dynamic>>> streamAllData() {
    return _supabase
        .from('data_absensi')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  /// Stream data absensi user tertentu
  static Stream<List<Map<String, dynamic>>> streamMyData(String userId) {
    return _supabase
        .from('data_absensi')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false);
  }

  /// Delete data absensi + hapus file storage
  static Future<void> deleteData(int id, {String? fotoPath}) async {
    try {
      if (fotoPath != null && fotoPath.isNotEmpty) {
        await _supabase.storage.from('selfies').remove([fotoPath]);
      }
      await _supabase.from('data_absensi').delete().eq('id', id);
    } catch (e) {
      debugPrint('❌ ERROR DELETE DATA: $e');
      rethrow;
    }
  }
}

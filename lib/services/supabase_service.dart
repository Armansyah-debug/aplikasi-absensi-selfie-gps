import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
class SupabaseService {
  static final _supabase = Supabase.instance.client;

  // =====================================================
  // PROFILE
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

  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final res = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return res;
    } catch (e) {
      debugPrint('GET PROFILE ERROR: $e');
      return null;
    }
  }

  static Future<void> updateProfile({
    required String userId,
    required String nama,
    required String npm,
  }) async {
    await _supabase.from('profiles').update({
      'nama': nama,
      'npm': npm,
    }).eq('id', userId);
  }

  static Future<void> updateMahasiswaAdmin({
    required String userId,
    required String nama,
    required String npm,
    required String jurusan,
    required int semester,
  }) async {
    await _supabase.from('profiles').update({
      'nama': nama,
      'npm': npm,
      'jurusan': jurusan,
      'semester': semester,
    }).eq('id', userId);
  }

  static Future<void> updateDosenAdmin({
    required String userId,
    required String nama,
    required String nidn,
  }) async {
    await _supabase.from('profiles').update({
      'nama': nama,
      'npm': nidn, // NIDN disimpan di field npm
    }).eq('id', userId);
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
      'waktu': DateTime.now().toUtc().toIso8601String(),
      'is_mocked': isMocked,
    });
  }

  // =====================================================
  // INSERT IZIN / SAKIT
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
      'waktu': tanggalMulai.toUtc().toIso8601String(),
    });
  }

  // =====================================================
  // STREAM ALL (ADMIN)
  // =====================================================
  static Stream<List<Map<String, dynamic>>> streamAllData() {
    return _supabase
        .from('data_absensi')
        .stream(primaryKey: ['id']).order('waktu', ascending: false);
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

  static Future<List<Map<String, dynamic>>> getDosenHistoryRaw(
      String dosenId) async {
    try {
      print('DOSEN ID: $dosenId');

      // 1. Dapatkan daftar MK milik dosen ini
      final mkRes = await _supabase
          .from('mata_kuliah')
          .select('id')
          .eq('dosen_id', dosenId);
      final mkIds = List<dynamic>.from(mkRes.map((e) => e['id']));
      print('MK IDS: $mkIds');

      if (mkIds.isEmpty) {
        print('DEBUG: Dosen tidak memiliki mata kuliah.');
        return [];
      }

      // 2. Dapatkan seluruh ID Sesi dari MK-MK tersebut
      final sesiRes = await _supabase
          .from('sesi_absensi')
          .select('id')
          .filter('mata_kuliah_id', 'in', mkIds);
      final sesiIds = List<dynamic>.from(sesiRes.map((e) => e['id']));
      print('SESI IDS: $sesiIds');

      if (sesiIds.isEmpty) {
        print('DEBUG: Tidak ada sesi ditemukan untuk MK tersebut.');
        return [];
      }

      // 3. Ambil data absensi mahasiswa yang terhubung ke ID Sesi milik dosen
      final res = await _supabase
          .from('data_absensi')
          .select('*')
          .inFilter('sesi_id', sesiIds)
          .order('waktu', ascending: false);

      print('MK IDS: $mkIds');
      print('SESI IDS: $sesiIds');
      print('ABSENSI COUNT: ${res.length}');
      // print('ABSENSI DATA: $res'); // Dikomentari agar log tidak terlalu panjang

      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print('DEBUG getDosenHistoryRaw error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getHistoryRaw(String userId) async {
    try {
      final res = await _supabase
          .from('data_absensi')
          .select('*')
          .eq('user_id', userId)
          .order('waktu', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('GET HISTORY RAW ERROR: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAllHistoryRaw() async {
    try {
      final res = await _supabase
          .from('data_absensi')
          .select('*')
          .order('waktu', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('GET ALL HISTORY RAW ERROR: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getSesiList() async {
    try {
      final res = await _supabase
          .from('sesi_absensi')
          .select('id, mata_kuliah_id, pertemuan_ke, materi');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('GET SESI LIST ERROR: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAllMK() async {
    try {
      final res =
          await _supabase.from('mata_kuliah').select('*').order('nama_mk');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('GET ALL MK ERROR: $e');
      return [];
    }
  }

  static Future<void> insertMK({
    required String namaMk,
    required String jurusan,
    required int semester,
    String? dosenId,
  }) async {
    await _supabase.from('mata_kuliah').insert({
      'nama_mk': namaMk,
      'jurusan': jurusan,
      'semester': semester,
      'dosen_id': dosenId,
    });
  }

  static Future<void> updateMK({
    required int id,
    required String namaMk,
    required String jurusan,
    required int semester,
    String? dosenId,
  }) async {
    await _supabase.from('mata_kuliah').update({
      'nama_mk': namaMk,
      'jurusan': jurusan,
      'semester': semester,
      'dosen_id': dosenId,
    }).eq('id', id);
  }

  static Future<void> deleteMK(int id) async {
    await _supabase.from('sesi_absensi').delete().eq('mata_kuliah_id', id);

    await _supabase.from('mata_kuliah').delete().eq('id', id);
  }

  static Future<List<Map<String, dynamic>>> getDosenList() async {
    try {
      final res = await _supabase
          .from('profiles')
          .select('id, nama, npm')
          .eq('role', 'dosen')
          .order('nama');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('GET DOSEN LIST ERROR: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getMahasiswaList() async {
  try {
    final res = await _supabase
        .from('profiles')
        .select('id, nama, npm, email, jurusan, semester')
        .eq('role', 'user')
        .order('nama');

    return List<Map<String, dynamic>>.from(res);
  } catch (e) {
    debugPrint('GET MAHASISWA LIST ERROR: $e');
    return [];
  }
}

  // =====================================================
  // FOTO URL (FIX AMAN)
  // =====================================================
  static String getFotoUrl(String path, {String bucketName = 'selfies'}) {
    if (path.isEmpty) return '';

    if (path.startsWith('http')) return path;

    return _supabase.storage.from(bucketName).getPublicUrl(path);
  }

  // =====================================================
  // AKADEMIK & SESI
  // =====================================================
  static Future<List<Map<String, dynamic>>> getMataKuliah(
      {String? dosenId}) async {
    try {
      var query = _supabase.from('mata_kuliah').select();

      if (dosenId != null) {
        query = query.eq('dosen_id', dosenId);
      }

      final res = await query.order('nama_mk');
      print('DEBUG getMataKuliah result: $res');
      print('DEBUG getMataKuliah count: ${res.length}');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print('DEBUG getMataKuliah error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getKelasByMK(String mkId) async {
    try {
      final res = await _supabase
          .from('kelas_perkuliahan')
          .select()
          .eq('mk_id', mkId)
          .order('nama_kelas');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('GET KELAS ERROR: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getPertemuanByKelas(
      String kelasId) async {
    try {
      final res = await _supabase
          .from('pertemuan')
          .select()
          .eq('kelas_id', kelasId)
          .order('pertemuan_ke');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('GET PERTEMUAN ERROR: $e');
      return [];
    }
  }

  static Future<void> createSesiAbsensi({
    required String mkId,
    int? pertemuan_ke,
    String? materi,
    int radius = 50,
  }) async {
    final now = DateTime.now();
    final Map<String, dynamic> data = {
      'mata_kuliah_id': mkId,
      'is_open': true,
      'radius_meter': radius,
      'tanggal': now.toIso8601String().split('T')[0],
      'pertemuan_ke': pertemuan_ke,
      'materi': materi,
    };

    await _supabase.from('sesi_absensi').insert(data);
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
        await _supabase.storage.from('selfies').remove([fotoPath]);
      }

      await _supabase.from('data_absensi').delete().eq('id', id);
    } catch (e) {
      debugPrint('DELETE ERROR: $e');
      rethrow;
    }
  }

  // =====================================================
  // JURUSAN DINAMIS
  // =====================================================
  static Future<List<String>> getJurusanList() async {
    try {
      final res = await _supabase.from('mata_kuliah').select('jurusan');
      final list = List<Map<String, dynamic>>.from(res);
      final jurusanSet = list
          .map((e) => e['jurusan'] as String?)
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      
      final sortedList = jurusanSet.toList()..sort();
      return sortedList;
    } catch (e) {
      debugPrint('GET JURUSAN LIST ERROR: $e');
      return [];
    }
  }
  // =====================================================
  // PENGUMUMAN / NOTIFIKASI
  // =====================================================
  static Future<void> createPengumuman({
    required String judul,
    required String pesan,
  }) async {
    try {
      await _supabase.from('pengumuman').insert({
        'judul': judul,
        'pesan': pesan,
      });
    } catch (e) {
      debugPrint('CREATE PENGUMUMAN ERROR: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getPengumuman() async {
    try {
      final res = await _supabase
          .from('pengumuman')
          .select()
          .order('tanggal', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('GET PENGUMUMAN ERROR: $e');
      return [];
    }
  }
}

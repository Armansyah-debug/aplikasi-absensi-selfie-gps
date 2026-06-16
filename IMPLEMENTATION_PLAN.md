# Rencana Implementasi: Modernisasi Absensi Selfie Lokasi

Dokumen ini menjelaskan tahapan perbaikan aplikasi berdasarkan hasil audit. Perbaikan dilakukan secara bertahap untuk menjaga stabilitas aplikasi.

## Phase 1: Perbaikan UI (Standardisasi & Estetika)
**Tujuan:** Menyamakan bahasa desain (Design Language) di seluruh halaman aplikasi agar konsisten dan modern.

*   **Daftar Perubahan:**
    1.  Standardisasi **AppBar**: Menggunakan gaya transparan atau putih bersih dengan tipografi tebal (iOS Style) di semua screen.
    2.  Standardisasi **Card & Container**: Menerapkan radius yang konsisten (20px) dan shadow halus di halaman Riwayat, Statistik, dan Kelola Sesi.
    3.  Modernisasi **Login/Register**: Memperbaiki tata letak input field agar lebih lega dan estetis.
*   **File yang akan diubah:**
    *   `lib/absensi/riwayat_screen.dart`
    *   `lib/absensi/statistik_screen.dart`
    *   `lib/admin/kelola_sesi_screen.dart`
    *   `lib/screens/login_screen.dart`
    *   `lib/screens/register_screen.dart`
*   **Risiko:** Perubahan kosmetik mungkin memerlukan penyesuaian padding agar elemen tidak terlihat "sesak" di layar kecil.
*   **Dampak:** Meningkatkan kepercayaan pengguna karena aplikasi terlihat profesional dan terawat.

---

## Phase 2: Perbaikan Navigasi (Efisiensi Alur)
**Tujuan:** Mempermudah mobilitas pengguna antar fitur utama dan menyusun ulang hirarki informasi.

*   **Daftar Perubahan:**
    1.  Implementasi **Bottom Navigation Bar**: Sebagai navigasi utama (Home, Riwayat, Profil).
    2.  Pembuatan **Profile Screen**: Memindahkan fitur Logout dan informasi akun ke halaman khusus.
    3.  Penyederhanaan **HomeScreen**: Fokus pada ringkasan kehadiran dan status sesi aktif.
*   **File yang akan diubah:**
    *   `lib/main.dart` (Penentuan root screen baru)
    *   `lib/home/home_screen.dart` (Penyesuaian layout)
    *   `lib/screens/profile_screen.dart` (Baru)
    *   `lib/navigation/main_nav.dart` (Baru - Wrapper untuk BottomNav)
*   **Risiko:** Perubahan alur navigasi memerlukan penanganan tombol "Back" (WillPopScope) agar user tidak keluar aplikasi secara tidak sengaja.
*   **Dampak:** User dapat berpindah dari "Absen" ke "Riwayat" hanya dengan satu tap, mengurangi jumlah klik secara signifikan.

---

## Phase 3: Perbaikan Fitur (Automasi & Validasi)
**Tujuan:** Mengurangi beban input manual user dan mempercepat proses inti aplikasi.

*   **Daftar Perubahan:**
    1.  **Automasi Identitas**: Menghapus dialog input Nama & NPM di `AbsenScreen`. Data akan diambil otomatis dari session Supabase.
    2.  **Pre-fill Data Izin**: Nama dan NPM pada `IzinCutiScreen` akan otomatis terisi (read-only).
    3.  **Status Real-time**: Menampilkan indikator jika ada sesi absensi yang sedang terbuka langsung di dashboard.
*   **File yang akan diubah:**
    *   `lib/absensi/absenScreen.dart`
    *   `lib/absensi/izin_cuti_screen.dart`
    *   `lib/services/supabase_service.dart` (Menambah helper fetch profil)
*   **Risiko:** Jika data di tabel `profiles` belum lengkap, automasi mungkin mengambil string kosong (Perlu validasi data profil saat pertama kali login).
*   **Dampak:** Waktu yang dibutuhkan untuk absen berkurang dari ~30 detik menjadi ~10 detik.

---

## Phase 4: Penyederhanaan Admin (Konsolidasi Dashboard)
**Tujuan:** Memberikan pengalaman manajemen yang lebih baik dan terorganisir bagi Admin.

*   **Daftar Perubahan:**
    1.  **Admin Dashboard Tab**: Jika role user adalah admin, akan muncul tab khusus "Admin" di Bottom Navigation.
    2.  **Penyatuan Riwayat**: Menggunakan satu file `riwayat_screen.dart` yang secara cerdas menampilkan data personal (User) atau data global (Admin).
    3.  **Pembersihan File Redundant**: Menghapus file yang tidak lagi digunakan setelah integrasi.
*   **File yang akan diubah:**
    *   `lib/home/home_screen.dart`
    *   `lib/admin/admin_screen.dart` (Akan dihapus setelah integrasi)
    *   `lib/navigation/main_nav.dart` (Logika penambahan tab Admin)
*   **Risiko:** Kerumitan logika peran (role-based access) pada navigasi harus diuji ketat agar user biasa tidak bisa mengakses menu admin.
*   **Dampak:** Aplikasi menjadi lebih ringan (sedikit file) dan manajemen sesi menjadi lebih intuitif.

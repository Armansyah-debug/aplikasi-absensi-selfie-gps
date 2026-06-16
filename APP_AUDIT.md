# Audit Aplikasi: Absensi Selfie Lokasi

## 1. Ringkasan Tujuan Aplikasi
Aplikasi ini dirancang sebagai sistem absensi berbasis mobile yang mengintegrasikan verifikasi wajah (Selfie) dan lokasi (GPS) secara real-time. Berdasarkan penggunaan istilah "NPM" dan "Mata Kuliah", diasumsikan aplikasi ini ditujukan untuk lingkungan institusi pendidikan (Universitas) guna mencatat kehadiran mahasiswa dalam sesi perkuliahan tertentu dengan validasi anti-fraud (cek Fake GPS & validasi wajah).

## 2. Analisis UI/UX Saat Ini
*   **Kelebihan:**
    *   Tampilan Home cukup modern dengan efek Glassmorphism.
    *   Penggunaan warna biru (iOS-style) memberikan kesan profesional dan bersih.
    *   Feedback status di `AbsenScreen` cukup informatif.
*   **Kekurangan:**
    *   **Inkonsistensi Style:** Beberapa halaman menggunakan AppBar standar, sementara yang lain mencoba gaya kustom. `AdminScreen` terlihat sangat berbeda (tua) dibanding `HomeScreen`.
    *   **UX Manual:** User dipaksa mengetik Nama dan NPM setiap kali akan absen. Ini sangat tidak efisien dan rentan typo.
    *   **Navigasi "Deep":** Penggunaan sistem Push/Pop murni tanpa Bottom Navigation membuat user harus banyak kembali (back) untuk berpindah fitur.
    *   **Admin Experience:** Menu admin tercampur dengan menu user di `HomeScreen`, yang bisa membingungkan jika tidak dipisahkan secara visual dengan tegas.

## 3. Analisis Alur Pengguna (User Flow)
1.  **Login:** Standar menggunakan Supabase Auth.
2.  **Dashboard:** Menampilkan ringkasan kehadiran (persentase) dan menu fitur.
3.  **Proses Absen:** Klik Menu -> Ambil Foto -> **Input Nama/NPM (Hambatan)** -> Cek Wajah & GPS -> Submit.
4.  **Riwayat:** Melihat daftar absensi yang sudah dilakukan dengan filter tanggal.
5.  **Admin:** Membuka/menutup sesi perkuliahan agar mahasiswa bisa absen di jam tersebut.

## 4. Fitur yang Tidak Nyambung dengan Tujuan Aplikasi
*   **Input Nama/NPM Manual:** Dalam aplikasi absensi modern yang sudah memiliki sistem login, identitas user seharusnya sudah diketahui oleh sistem. Input manual ini tidak nyambung dengan tujuan automasi dan keamanan.

## 5. Fitur yang Redundant atau Membingungkan
*   **`AdminScreen` vs Menu Admin di `HomeScreen`:** Terdapat dua tempat untuk akses admin. Di `HomeScreen` sudah ada menu admin, tapi ada juga file `admin_screen.dart` yang isinya hampir sama namun dengan desain berbeda.
*   **Pilihan Jenis "Hadir" di Form Izin:** Pada `IzinCutiScreen`, status default adalah Izin tapi alurnya mirip dengan absen hadir, perlu penyederhanaan.

## 6. Fitur yang Sebaiknya Dipindahkan
*   **Input Data Identitas:** Pindahkan ke halaman **Profil / Setup Awal**. User cukup mengisi Nama dan NPM satu kali seumur hidup aplikasi, bukan setiap kali absen.
*   **Logout:** Sebaiknya dipindahkan ke dalam halaman Profil, bukan sebagai icon di AppBar utama (untuk menghindari ketidaksengajaan).

## 7. Fitur yang Sebaiknya Dihapus
*   **TextField Nama & NPM** di dalam `AbsenScreen` dan `IzinCutiScreen`. Ambil data langsung dari `profiles` di Supabase.
*   **`AdminScreen` widget:** Hapus dan satukan logika admin ke dalam dashboard yang lebih terstruktur.

## 8. Fitur yang Perlu Ditambahkan
*   **Bottom Navigation Bar:** Untuk akses cepat antara Home, Riwayat, dan Profil.
*   **Halaman Profil:** Tempat mengelola data diri (Nama, NPM, Foto Profil, Jabatan/Role).
*   **Map View di Riwayat:** Agar admin bisa melihat posisi absen user di peta, bukan hanya koordinat teks.
*   **Notifikasi Sesi:** Memberitahu user jika ada sesi absensi yang baru dibuka.
*   **Dashboard yang Lebih Dinamis:** Menampilkan sesi apa yang sedang aktif saat ini tanpa user harus mencari-cari.

## 9. Saran Struktur Navigasi Baru
Menggunakan **Bottom Navigation Bar** dengan 3-4 menu utama:
1.  **Home:** Dashboard ringkasan, status sesi aktif, dan tombol cepat "Absen Sekarang".
2.  **Riwayat:** Daftar kehadiran user (User) atau Rekap semua user (Admin).
3.  **Admin (Khusus Admin):** Panel kontrol untuk Kelola Sesi dan Statistik Global.
4.  **Profil:** Pengaturan akun, data NPM/Nama, dan tombol Logout.

## 10. Prioritas Perbaikan
| Prioritas | Fitur / Perbaikan | Dampak |
| :--- | :--- | :--- |
| **HIGH** | Automasi Data User (Hapus input manual Nama/NPM) | Efisiensi & Keamanan Data |
| **HIGH** | Implementasi Bottom Navigation Bar | Navigasi & Kemudahan Penggunaan |
| **MEDIUM** | Penyeragaman Style UI (Standardisasi AppBar & Card) | Estetika & Konsistensi |
| **MEDIUM** | Pemisahan Menu Admin & User yang lebih tegas | Kejelasan Fungsi |
| **LOW** | Integrasi Map View di Riwayat | Validasi Lokasi Visual |
| **LOW** | Fitur "Profil Saya" | Kelengkapan Data User |

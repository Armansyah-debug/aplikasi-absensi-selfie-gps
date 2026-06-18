import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _namaController = TextEditingController();
  final _npmController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _selectedJurusan;
  int? _selectedSemester;

  final List<String> _jurusanList = [
    'Informatika',
    'Sistem Informasi',
    'Manajemen',
    'Akuntansi',
  ];

  final List<int> _semesterList = List.generate(14, (index) => index + 1);

  String _message = '';
  bool _obscure = true;
  bool _isLoading = false;

  Future<void> _register() async {
    if (_namaController.text.isEmpty ||
        _npmController.text.isEmpty ||
        _selectedJurusan == null ||
        _selectedSemester == null ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _message = 'Semua field harus diisi');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = response.user;

      if (user != null) {
        await Supabase.instance.client.from('profiles').insert({
          'id': user.id,
          'email': user.email,
          'role': 'user',
          'nama': _namaController.text.trim(),
          'npm': _npmController.text.trim(),
          'jurusan': _selectedJurusan,
          'semester': _selectedSemester,
        });

        setState(() {
          _message = 'Pendaftaran berhasil! Silakan cek email atau login.';
        });
      }
    } on AuthException catch (e) {
      setState(() => _message = e.message);
    } catch (e) {
      setState(() => _message = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.person_add_alt_1_rounded,
                size: 64,
                color: Color(0xFF007AFF),
              ),
              const SizedBox(height: 24),
              const Text(
                "Buat Akun Baru",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Daftar untuk mendapatkan akses absensi",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 40),

              // ================= NAMA =================
              _buildLabel("Nama Lengkap"),
              _buildTextField(
                controller: _namaController,
                hint: "Masukkan nama lengkap",
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 20),

              // ================= NPM =================
              _buildLabel("NPM / ID"),
              _buildTextField(
                controller: _npmController,
                hint: "Masukkan NPM",
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 20),

              // ================= JURUSAN & SEMESTER =================
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("Jurusan"),
                        _buildDropdown<String>(
                          value: _selectedJurusan,
                          hint: "Pilih",
                          items: _jurusanList,
                          onChanged: (v) => setState(() => _selectedJurusan = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("Semester"),
                        _buildDropdown<int>(
                          value: _selectedSemester,
                          hint: "Pilih",
                          items: _semesterList,
                          onChanged: (v) => setState(() => _selectedSemester = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ================= EMAIL =================
              _buildLabel("Email"),
              _buildTextField(
                controller: _emailController,
                hint: "Masukkan email",
                icon: Icons.email_outlined,
              ),
              const SizedBox(height: 20),

              // ================= PASSWORD =================
              _buildLabel("Password"),
              _buildTextField(
                controller: _passwordController,
                hint: "Masukkan password",
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                obscure: _obscure,
                onToggleObscure: () => setState(() => _obscure = !_obscure),
              ),

              const SizedBox(height: 40),

              // ================= REGISTER BUTTON =================
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isLoading ? null : _register,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Daftar Sekarang",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              if (_message.isNotEmpty) ...[
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _message.contains('berhasil')
                          ? const Color(0xFF34C759)
                          : Colors.red,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Sudah punya akun? ",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      "Login",
                      style: TextStyle(
                        color: Color(0xFF007AFF),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggleObscure,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscure ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  onPressed: onToggleObscure,
                )
              : null,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<T>(
          value: value,
          hint: Text(hint, style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(item.toString(), style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
          onChanged: onChanged,
          decoration: const InputDecoration(border: InputBorder.none),
        ),
      ),
    );
  }
}
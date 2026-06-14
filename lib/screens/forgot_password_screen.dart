import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {

  final _emailController = TextEditingController();

  String _message = '';

  Future<void> resetPassword() async {
  try {
    await Supabase.instance.client.auth.resetPasswordForEmail(
      _emailController.text.trim(),
      redirectTo: 'com.example.absensi_face_detection://reset-password',
    );

    setState(() {
      _message = 'Link reset password dikirim ke email';
    });
  } on AuthException catch (e) {
    setState(() {
      _message = e.message;
    });
  } catch (e) {
    setState(() {
      _message = e.toString();
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade700,
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        title: const Text('Lupa Password'),
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(36),
            topRight: Radius.circular(36),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 20),

            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                hintText: 'Masukkan Email',
                prefixIcon: Icon(
                  Icons.email,
                  color: Colors.blue.shade700,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: resetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Kirim Link Reset',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              _message,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}
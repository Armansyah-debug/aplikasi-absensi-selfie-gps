import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState
    extends State<ResetPasswordScreen> {

  final _passwordController = TextEditingController();
  String _message = '';

  Future<void> updatePassword() async {
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          password: _passwordController.text.trim(),
        ),
      );

      setState(() {
        _message = 'Password berhasil diubah';
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
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password Baru',
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: updatePassword,
              child: const Text('Simpan Password'),
            ),

            const SizedBox(height: 20),

            Text(_message),
          ],
        ),
      ),
    );
  }
}
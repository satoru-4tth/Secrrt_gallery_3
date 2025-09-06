import 'package:flutter/material.dart';
import '../services/password_service.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});
  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _old = TextEditingController();
  final _new1 = TextEditingController();
  final _new2 = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _old.dispose(); _new1.dispose(); _new2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      final svc = PasswordService();
      final has = await svc.hasPassword();

      if (_new1.text.length < 4) {
        throw Exception('4文字以上にしてください');
      }
      if (_new1.text != _new2.text) {
        throw Exception('新しいパスワードが一致しません');
      }

      await svc.setPassword(
        oldPass: has ? _old.text : null,
        newPass: _new1.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('パスワードを更新しました')),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('パスワード変更')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            FutureBuilder<bool>(
              future: PasswordService().hasPassword(),
              builder: (_, snap) {
                final has = snap.data ?? true;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (has) ...[
                      const Text('現在のパスワード'),
                      TextField(controller: _old, obscureText: true),
                      const SizedBox(height: 16),
                    ],
                    const Text('新しいパスワード'),
                    TextField(controller: _new1, obscureText: true),
                    const SizedBox(height: 16),
                    const Text('新しいパスワード（確認）'),
                    TextField(controller: _new2, obscureText: true),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading ? const CircularProgressIndicator() : const Text('更新'),
            ),
          ],
        ),
      ),
    );
  }
}

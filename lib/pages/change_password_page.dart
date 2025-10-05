// パスワード変更画面（4桁PIN専用）
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ★ 追加：フォーマッタ用
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

  // ★ 追加：4桁数字のみ
  static final _pinRegex = RegExp(r'^[0-9]{4}$');

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

      // ★ 変更：4桁数字チェック
      if (!_pinRegex.hasMatch(_new1.text)) {
        throw Exception('新しいPINは「4桁の数字のみ」です');
      }
      if (_new1.text != _new2.text) {
        throw Exception('新しいPINが一致しません');
      }
      // ★ 旧PINも（ある場合は）4桁数字チェック
      if (has && !_pinRegex.hasMatch(_old.text)) {
        throw Exception('現在のPINは「4桁の数字のみ」です');
      }

      await svc.setPassword(
        oldPass: has ? _old.text : null,
        newPass: _new1.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PINを更新しました')),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ★ 共通のTextFieldビルダー（数字のみ/4桁固定/非表示）
  Widget _pinField({
    required TextEditingController controller,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,                 // ★ 数字キーボード
      maxLength: 4,                                       // ★ 4桁
      inputFormatters: [
        // ★ ここを置き換え：半角0-9のみ許可（全角は入らない）
        FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
        LengthLimitingTextInputFormatter(4),
      ],
      decoration: InputDecoration(
        hintText: hint ?? '4桁のPIN',
        counterText: '', // “0/4”のカウンタ非表示
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PIN変更')),
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
                      const Text('現在のPIN'),
                      _pinField(controller: _old, hint: '現在の4桁PIN'),
                      const SizedBox(height: 16),
                    ],
                    const Text('新しいPIN'),
                    _pinField(controller: _new1, hint: '新しい4桁PIN'),
                    const SizedBox(height: 16),
                    const Text('新しいPIN（確認）'),
                    _pinField(controller: _new2, hint: 'もう一度入力'),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('更新'),
            ),
          ],
        ),
      ),
    );
  }
}

// 回復コードでPINを再設定する画面（PINを忘れたとき用）
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/password_service.dart';
import '../widgets/recovery_code_dialog.dart';

class RecoveryPage extends StatefulWidget {
  const RecoveryPage({super.key, PasswordService? service})
    : _service = service;
  final PasswordService? _service;

  @override
  State<RecoveryPage> createState() => _RecoveryPageState();
}

class _RecoveryPageState extends State<RecoveryPage> {
  final _code = TextEditingController();
  final _new1 = TextEditingController();
  final _new2 = TextEditingController();
  late final PasswordService _svc = widget._service ?? PasswordService();
  bool _loading = false;
  String? _error;

  static final _pinRegex = RegExp(r'^[0-9]{4}$');

  @override
  void dispose() {
    _code.dispose();
    _new1.dispose();
    _new2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_pinRegex.hasMatch(_new1.text)) {
        throw Exception('新しいPINは「4桁の数字のみ」です');
      }
      if (_new1.text != _new2.text) {
        throw Exception('新しいPINが一致しません');
      }
      final res = await _svc.resetPinWithRecoveryCode(
        code: _code.text,
        newPin: _new1.text,
      );
      if (!mounted) return;
      if (!res.ok) {
        if (res.noRecoveryCode) {
          throw Exception('回復コードが登録されていません');
        }
        if (res.lockedSeconds != null) {
          throw Exception('失敗が続いたためロック中です。あと${res.lockedSeconds}秒お待ちください');
        }
        throw Exception('回復コードが正しくありません');
      }
      // 使用済みコードは無効になるので、新しいコードを必ず表示する
      await showRecoveryCodeDialog(
        context,
        res.newCode!,
        title: 'PINを再設定しました',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('新しいPINで解錠できます')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _pinField(TextEditingController c, String hint) => TextField(
    controller: c,
    obscureText: true,
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
      LengthLimitingTextInputFormatter(4),
    ],
    decoration: InputDecoration(hintText: hint, counterText: ''),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PINの再設定')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              const Text('回復コード'),
              TextField(
                key: const Key('recovery_code_field'),
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\- ]')),
                  LengthLimitingTextInputFormatter(20),
                ],
                decoration: const InputDecoration(hintText: 'XXXX-XXXX-XXXX'),
              ),
              const SizedBox(height: 16),
              const Text('新しいPIN（数字4桁）'),
              _pinField(_new1, '新しい4桁PIN'),
              const SizedBox(height: 16),
              const Text('新しいPIN（確認）'),
              _pinField(_new2, 'もう一度入力'),
              const SizedBox(height: 12),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('再設定'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

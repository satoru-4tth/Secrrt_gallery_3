// パスワード変更画面（4桁PIN専用）
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/password_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // ★ 追加

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

  // ★ 4桁数字のみ
  static final _pinRegex = RegExp(r'^[0-9]{4}$');

  // ★ バナー
  BannerAd? _banner;

  @override
  void initState() {
    super.initState();
    _banner = BannerAd(
      // 本番では「パスワード変更画面」用のユニットIDに差し替え
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // 公式テスト用(バナー/Android)
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() {}),
        onAdFailedToLoad: (ad, err) {
          debugPrint('Password banner failed: $err');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    _old.dispose();
    _new1.dispose();
    _new2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = PasswordService();
      final has = await svc.hasPassword();

      if (!_pinRegex.hasMatch(_new1.text)) {
        throw Exception('新しいPINは「4桁の数字のみ」です');
      }
      if (_new1.text != _new2.text) {
        throw Exception('新しいPINが一致しません');
      }
      if (has && !_pinRegex.hasMatch(_old.text)) {
        throw Exception('現在のPINは「4桁の数字のみ」です');
      }

      await svc.setPassword(
        oldPass: has ? _old.text : null,
        newPass: _new1.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PINを更新しました')));
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 共通のPIN入力フィールド
  Widget _pinField({required TextEditingController controller, String? hint}) {
    return TextField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 4,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
        LengthLimitingTextInputFormatter(4),
      ],
      decoration: InputDecoration(hintText: hint ?? '4桁のPIN', counterText: ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PIN変更')),
      // キーボードでレイアウトが押し上がるように
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // 上: スクロール領域
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ListView(
                  children: [
                    // 案内
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '「数字4桁」+「＝」でログインできます。',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade100),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '注意：パスワードを忘れるとログインできなくなります。',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    FutureBuilder<bool>(
                      future: PasswordService().hasPassword(),
                      builder: (_, snap) {
                        final has = snap.data ?? true;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (has) ...[
                              const Text('現在のPIN（数字4桁）'),
                              _pinField(controller: _old, hint: '現在の4桁PIN'),
                              const SizedBox(height: 16),
                            ],
                            const Text('新しいPIN（数字4桁）'),
                            _pinField(controller: _new1, hint: '新しい4桁PIN'),
                            const SizedBox(height: 16),
                            const Text('新しいPIN（確認）'),
                            _pinField(controller: _new2, hint: 'もう一度入力'),
                          ],
                        );
                      },
                    ),
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
                          : const Text('更新'),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // 下: バナー（固定）
            if (_banner != null)
              SizedBox(
                width: _banner!.size.width.toDouble(),
                height: _banner!.size.height.toDouble(),
                child: AdWidget(ad: _banner!),
              ),
          ],
        ),
      ),
    );
  }
}

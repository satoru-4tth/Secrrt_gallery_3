import 'package:flutter/material.dart';
import 'controllers/calculator_controller.dart';
import 'ui/widgets/calc_button.dart';
import 'pages/secret_gallery_page.dart';
import 'pages/change_password_page.dart';
import 'services/password_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculator Disguise App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const CalculatorPage(title: 'Calculator'),
    );
  }
}

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key, required this.title});
  final String title;

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  final controller = CalculatorController();

  // ▼ ここにバナーのフィールドを置く
  BannerAd? _banner;

  @override
  void initState() {
    super.initState();
    _maybeShowInitPassInfo();

    // ▼ バナー読み込み
    _banner = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // Androidバナーの公式テストID
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() {}),
        onAdFailedToLoad: (ad, err) {
          debugPrint('Banner failed: $err');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  // ★ 追加：初回だけダイアログを出す
  Future<void> _maybeShowInitPassInfo() async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'init_pass_info_shown_v1';
    final shown = prefs.getBool(key) ?? false;
    if (shown) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('初回のご案内'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ダウンロードありがとうございます！'),
              SizedBox(height: 12),
              Text('初期パスワードは 1234 です。'),
              Text('計算機で「1 2 3 4」と入力して「=」を押すと秘密ギャラリーが開きます。'),
              SizedBox(height: 8),
              Text('※ パスワードは後から「設定 > パスワード変更」で変更できます。'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      await prefs.setBool(key, true);
    });
  }

  // ★ async 化。setState の中で await はしない
  Future<void> _handleKey(String value) async {
    switch (value) {
      case 'AC':
        setState(controller.clear);
        break;
      case '⌫':
        setState(controller.backspace);
        break;
      case '=':
        final svc = PasswordService();
        final has = await svc.hasPassword();
        final input = controller.input;
        final ok = has ? await svc.verify(input) : (input == '1234');

        if (ok) {
          setState(controller.clear);
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SecretGalleryPage()),
            );
            if (!has && context.mounted) {
              _promptSetPassword(context);
            }
          });
        } else {
          setState(controller.evaluate);
        }
        break;
      default:
        setState(() => controller.add(value));
    }
  }

  void _promptSetPassword(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('パスワード未設定'),
        content: const Text('次回からの解錠に使うパスワードを設定してください。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('後で'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
              );
            },
            child: const Text('設定する'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 表示
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                alignment: Alignment.bottomRight,
                child: FittedBox(
                  alignment: Alignment.bottomRight,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    controller.display,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ),
            // キーパッド
            Column(
              children: [
                Row(
                  children: [
                    CalcButton('AC', type: ButtonType.helper,
                      onPressed: () { _handleKey('AC'); },
                      onLongPress: () => setState(controller.clear),
                    ),
                    CalcButton('⌫', type: ButtonType.helper, onPressed: () { _handleKey('⌫'); }),
                    CalcButton('(', type: ButtonType.helper, onPressed: () { _handleKey('('); }),
                    CalcButton(')', type: ButtonType.helper, onPressed: () { _handleKey(')'); }),
                  ],
                ),
                Row(
                  children: [
                    CalcButton('7', onPressed: () { _handleKey('7'); }),
                    CalcButton('8', onPressed: () { _handleKey('8'); }),
                    CalcButton('9', onPressed: () { _handleKey('9'); }),
                    CalcButton('÷', type: ButtonType.operator, onPressed: () { _handleKey('÷'); }),
                  ],
                ),
                Row(
                  children: [
                    CalcButton('4', onPressed: () { _handleKey('4'); }),
                    CalcButton('5', onPressed: () { _handleKey('5'); }),
                    CalcButton('6', onPressed: () { _handleKey('6'); }),
                    CalcButton('×', type: ButtonType.operator, onPressed: () { _handleKey('×'); }),
                  ],
                ),
                Row(
                  children: [
                    CalcButton('1', onPressed: () { _handleKey('1'); }),
                    CalcButton('2', onPressed: () { _handleKey('2'); }),
                    CalcButton('3', onPressed: () { _handleKey('3'); }),
                    CalcButton('-', type: ButtonType.operator, onPressed: () { _handleKey('-'); }),
                  ],
                ),
                Row(
                  children: [
                    CalcButton('0', flex: 2, onPressed: () { _handleKey('0'); }),
                    CalcButton('.', onPressed: () { _handleKey('.'); }),
                    CalcButton('=', type: ButtonType.equals, onPressed: () { _handleKey('='); }),
                  ],
                ),
                Row(
                  children: [
                    CalcButton('+', type: ButtonType.operator, flex: 4, onPressed: () { _handleKey('+'); }),
                  ],
                ),
              ],
            ),
            // ▼ バナー表示（一番下）
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

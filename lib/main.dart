import 'package:flutter/material.dart';
import 'controllers/calculator_controller.dart';
import 'ui/widgets/calc_button.dart';
import 'pages/secret_gallery_page.dart';
import 'pages/change_password_page.dart';
import 'services/password_service.dart'; // ★ 追加

//アプリケーションのエントリーポイント
void main() {
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
        // 未設定なら '1234' を暫定で許可
        final ok = has ? await svc.verify(input) : (input == '1234');

        if (ok) {
          setState(controller.clear); // 表示を消してから遷移予約
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SecretGalleryPage()),
            );
            if (!has && context.mounted) {
              _promptSetPassword(context); // ★ 定義を下に追加
            }
          });
        } else {
          setState(controller.evaluate); // 通常の計算として評価
        }
        break;

      default:
        setState(() => controller.add(value));
    }
  }

  // ★ 追加：未設定時にパスワード設定を促すダイアログ
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
                    CalcButton(
                      'AC',
                      type: ButtonType.helper,
                      onPressed: () { _handleKey('AC'); }, // ★ () {} で包む
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
          ],
        ),
      ),
    );
  }
}

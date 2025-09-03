import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';
import 'secret_gallery_page.dart';
import 'package:characters/characters.dart';

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
      home: const MyHomePage(title: 'Calculator'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String input = '';

  // 表示用：空のときは 0 を見せる
  String get _display => input.isEmpty ? '0' : input;

  void _onButtonPressed(String value) {
    setState(() {
      switch (value) {
        case 'AC':
          input = '';
          break;
        case '⌫':
          if (input.isNotEmpty) input = input.substring(0, input.length - 1);
          break;
        case '=':
          if (input == '1234') {
            final nav = Navigator.of(context);
            input = ''; // 画面遷移前に消しておく
            WidgetsBinding.instance.addPostFrameCallback((_) {
              nav.push(
                MaterialPageRoute(builder: (_) => const SecretGalleryPage()),
              );
            });
            break;
          }
          try {
            final result = _calculate(input);
            input = (result.isFinite)
                ? (result % 1 == 0
                ? result.toInt().toString()
                : _trimTrailingZeros(result.toStringAsFixed(10)))
                : 'Error';
          } catch (_) {
            input = 'Error';
          }
          break;
        default:
        // 連続演算子の軽いガード（例: ++, ** などの連続入力を1つに圧縮）
          if (_isOperator(value) &&
              input.isNotEmpty &&
              _isOperator(input.characters.last)) {
            input = input.substring(0, input.length - 1) + value;
          } else {
            input += value;
          }
      }
    });
  }

  bool _isOperator(String s) => const ['+', '-', '×', '÷'].contains(s);

  String _trimTrailingZeros(String s) {
    // "1.2300000000" -> "1.23", "2.0000000000" -> "2"
    if (!s.contains('.')) return s;
    s = s.replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }

  double _calculate(String expression) {
    final expStr = expression
        .replaceAll('×', '*')
        .replaceAll('÷', '/');
    final parser = Parser();
    final exp = parser.parse(expStr);
    final cm = ContextModel();
    final v = exp.evaluate(EvaluationType.REAL, cm);
    return (v is num) ? v.toDouble() : double.nan;
  }

  // 見た目をタイプごとに分ける
  Widget _calcButton(
      String text, {
        ButtonType type = ButtonType.normal,
        int flex = 1,
        VoidCallback? onLongPress,
      }) {
    final bool isOperator =
        type == ButtonType.operator || type == ButtonType.equals;

    final Color base = switch (type) {
      ButtonType.normal => const Color(0xFF2A2A2A),
      ButtonType.helper => const Color(0xFF3A3A3A),
      ButtonType.operator => const Color(0xFFFB8C00), // オレンジ
      ButtonType.equals => const Color(0xFF2962FF),   // ブルー強調
    };

    final TextStyle labelStyle = TextStyle(
      fontSize: 24,
      fontWeight: isOperator ? FontWeight.w700 : FontWeight.w600,
      color: type == ButtonType.operator || type == ButtonType.equals
          ? Colors.white
          : Colors.white,
    );

    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: SizedBox(
          height: 64,
          child: ElevatedButton(
            onPressed: () => _onButtonPressed(text),
            onLongPress: onLongPress,
            style: ElevatedButton.styleFrom(
              backgroundColor: base,
              foregroundColor: Colors.white,
              shadowColor: Colors.black.withOpacity(0.4),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
            ),
            child: Text(text, style: labelStyle),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1段目: AC / ⌫ / ( / )
    // 2段目: 7 8 9 ÷
    // 3段目: 4 5 6 ×
    // 4段目: 1 2 3 -
    // 5段目: 0(横長) . =
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
            // 表示部
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                alignment: Alignment.bottomRight,
                child: FittedBox(
                  alignment: Alignment.bottomRight,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _display,
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
                    _calcButton('AC',
                        type: ButtonType.helper,
                        onLongPress: () {
                          // 長押しで更に全消去（今は同じ動作にしているが、将来履歴も消す等に拡張可）
                          setState(() => input = '');
                        }),
                    _calcButton('⌫', type: ButtonType.helper),
                    _calcButton('(', type: ButtonType.helper),
                    _calcButton(')', type: ButtonType.helper),
                  ],
                ),
                Row(
                  children: [
                    _calcButton('7'),
                    _calcButton('8'),
                    _calcButton('9'),
                    _calcButton('÷', type: ButtonType.operator),
                  ],
                ),
                Row(
                  children: [
                    _calcButton('4'),
                    _calcButton('5'),
                    _calcButton('6'),
                    _calcButton('×', type: ButtonType.operator),
                  ],
                ),
                Row(
                  children: [
                    _calcButton('1'),
                    _calcButton('2'),
                    _calcButton('3'),
                    _calcButton('-', type: ButtonType.operator),
                  ],
                ),
                Row(
                  children: [
                    _calcButton('0', flex: 2),
                    _calcButton('.'),
                    _calcButton('=', type: ButtonType.equals),
                    // 右端を + にするなら ↓ のように調整
                    // _calcButton('+', type: ButtonType.operator),
                  ],
                ),
                // 最終行に + を置きたい場合は、上の行を
                // [0(2), ., +] として、その上の行の右端を '=' にする等で調整可
                Row(
                  children: [
                    _calcButton('+', type: ButtonType.operator, flex: 4),
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

enum ButtonType { normal, helper, operator, equals }
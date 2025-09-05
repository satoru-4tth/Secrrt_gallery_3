import 'package:flutter/material.dart';
import 'controllers/calculator_controller.dart';
import 'ui/widgets/calc_button.dart';
import 'pages/secret_gallery_page.dart';

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

  void _handleKey(String value) {
    setState(() {
      switch (value) {
        case 'AC':
          controller.clear();
          break;
        case '⌫':
          controller.backspace();
          break;
        case '=':
        // 秘密パスワード
          if (controller.input == '1234') {
            final nav = Navigator.of(context);
            controller.clear();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              nav.push(MaterialPageRoute(builder: (_) => const SecretGalleryPage()));
            });
          } else {
            controller.evaluate();
          }
          break;
        default:
          controller.add(value);
      }
    });
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
                    CalcButton('AC',
                      type: ButtonType.helper,
                      onPressed: () => _handleKey('AC'),
                      onLongPress: () => setState(controller.clear),
                    ),
                    CalcButton('⌫', type: ButtonType.helper, onPressed: () => _handleKey('⌫')),
                    CalcButton('(', type: ButtonType.helper, onPressed: () => _handleKey('(')),
                    CalcButton(')', type: ButtonType.helper, onPressed: () => _handleKey(')')),
                  ],
                ),
                Row(
                  children: [
                    CalcButton('7', onPressed: () => _handleKey('7')),
                    CalcButton('8', onPressed: () => _handleKey('8')),
                    CalcButton('9', onPressed: () => _handleKey('9')),
                    CalcButton('÷', type: ButtonType.operator, onPressed: () => _handleKey('÷')),
                  ],
                ),
                Row(
                  children: [
                    CalcButton('4', onPressed: () => _handleKey('4')),
                    CalcButton('5', onPressed: () => _handleKey('5')),
                    CalcButton('6', onPressed: () => _handleKey('6')),
                    CalcButton('×', type: ButtonType.operator, onPressed: () => _handleKey('×')),
                  ],
                ),
                Row(
                  children: [
                    CalcButton('1', onPressed: () => _handleKey('1')),
                    CalcButton('2', onPressed: () => _handleKey('2')),
                    CalcButton('3', onPressed: () => _handleKey('3')),
                    CalcButton('-', type: ButtonType.operator, onPressed: () => _handleKey('-')),
                  ],
                ),
                Row(
                  children: [
                    CalcButton('0', flex: 2, onPressed: () => _handleKey('0')),
                    CalcButton('.', onPressed: () => _handleKey('.')),
                    CalcButton('=', type: ButtonType.equals, onPressed: () => _handleKey('=')),
                  ],
                ),
                Row(
                  children: [
                    CalcButton('+', type: ButtonType.operator, flex: 4, onPressed: () => _handleKey('+')),
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
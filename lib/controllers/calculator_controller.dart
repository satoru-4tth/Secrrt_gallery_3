import 'package:characters/characters.dart';
import 'package:math_expressions/math_expressions.dart';

class CalculatorController {
  String _input = '';

  String get input => _input;
  String get display => _input.isEmpty ? '0' : _input;

  /// 入力をクリア
  void clear() => _input = '';

  /// 末尾1文字削除
  void backspace() {
    if (_input.isNotEmpty) {
      _input = _input.substring(0, _input.length - 1);
    }
  }

  /// 文字を追加（連続演算子を1つに圧縮）
  void add(String value) {
    if (_isOperator(value) &&
        _input.isNotEmpty &&
        _isOperator(_input.characters.last)) {
      _input = _input.substring(0, _input.length - 1) + value;
    } else {
      _input += value;
    }
  }

  /// = 押下時に使う。成功なら文字列で結果を返す。失敗は 'Error'
  String evaluate() {
    try {
      final result = _calculate(_input);
      final text = result.isFinite
          ? (result % 1 == 0
          ? result.toInt().toString()
          : _trimTrailingZeros(result.toStringAsFixed(10)))
          : 'Error';
      _input = text;
      return text;
    } catch (_) {
      _input = 'Error';
      return 'Error';
    }
  }

  // ---- 内部ユーティリティ ----
  bool _isOperator(String s) => const ['+', '-', '×', '÷'].contains(s);

  double _calculate(String expression) {
    final expStr = expression.replaceAll('×', '*').replaceAll('÷', '/');
    final parser = Parser();
    final exp = parser.parse(expStr);
    final cm = ContextModel();
    final v = exp.evaluate(EvaluationType.REAL, cm);
    return (v is num) ? v.toDouble() : double.nan;
    // 例外は上位で握る
  }

  String _trimTrailingZeros(String s) {
    if (!s.contains('.')) return s;
    s = s.replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }
}
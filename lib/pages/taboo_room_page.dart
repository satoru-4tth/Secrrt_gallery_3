import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class TabooRoomPage extends StatefulWidget {
  const TabooRoomPage({super.key});

  @override
  State<TabooRoomPage> createState() => _TabooRoomPageState();
}

class _TabooRoomPageState extends State<TabooRoomPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  Future<void> _openDiscordProfile() async {
    const url = 'https://discord.com/users/969598160831930469';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      HapticFeedback.heavyImpact();
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Discordプロフィールを開けませんでした。')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060608),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _ac,
          builder: (context, _) {
            final t = _ac.value; // 0.0 → 1.0
            return Stack(
              fit: StackFit.expand,
              children: [
                // 1) 闇のグラデーション（黒＋深紅のうねり）
                _NoirGradient(t: t),

                // 2) ダークミスト（薄霧が漂う）
                _MistBlob(
                  t: t,
                  base: const Alignment(-0.75, -0.6),
                  size: 520,
                  color: const Color(0x33FF0033), // 深紅の霧（半透明）
                  phase: 0.0,
                  blur: 28,
                ),
                _MistBlob(
                  t: t,
                  base: const Alignment(0.75, 0.5),
                  size: 620,
                  color: const Color(0x22FF0022),
                  phase: 0.35,
                  blur: 36,
                ),
                _MistBlob(
                  t: t,
                  base: const Alignment(0.0, -0.1),
                  size: 680,
                  color: const Color(0x1AFF1122),
                  phase: 0.18,
                  blur: 42,
                ),

                // 3) 微細ノイズ（フィルム粒子）
                IgnorePointer(
                  child: CustomPaint(painter: _FilmGrainPainter(t)),
                ),

                // 4) 走査線（ごく薄いCRT風）
                IgnorePointer(
                  child: CustomPaint(painter: _ScanlinePainter(opacity: 0.06)),
                ),

                // 5) ビネット（周辺減光で中央を強調）
                Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0.0, -0.05),
                      radius: 1.05,
                      colors: [Colors.transparent, Color(0xCC000000)],
                      stops: [0.62, 1.0],
                    ),
                  ),
                ),

                // 6) コンテンツ
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 左上：戻る（黒ガラス）
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: _GlassBackButton(
                        icon: Icons.arrow_back,
                        label: 'Back',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(context);
                        },
                      ),
                    ),

                    const Spacer(),

                    // 中央：黒ガラスカード
                    Center(
                      child: _ObsidianCard(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 8),
                            // 薄いオーナメント（怪しげなライン）
                            const _OccultDivider(),
                            const SizedBox(height: 14),

                            // タイトル：微グリッチ＋深紅グロー
                            _CryptTitle(text: "ENTER TABOO'S ROOM", t: t),

                            const SizedBox(height: 12),
                            const Text(
                              "If I ever stop responding after 3 weeks, just assume I'm dead.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xCCFFFFFF),
                                fontSize: 13,
                                letterSpacing: 1.3,
                              ),
                            ),

                            const SizedBox(height: 28),

                            // 深紅ボタン（不穏な脈動）
                            _CrimsonButton(
                              t: t,
                              icon: Icons.door_front_door_outlined,
                              label: "ENTER TABOO'S ROOM",
                              onTap: _openDiscordProfile,
                            ),

                            const SizedBox(height: 10),
                            const Text(
                              'Tap to continue in Discord',
                              style: TextStyle(
                                color: Color(0x77FFFFFF),
                                fontSize: 11.5,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/* ===================== 背景/効果 ===================== */

class _NoirGradient extends StatelessWidget {
  const _NoirGradient({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    final angle = t * 2 * pi;
    final begin = Alignment(cos(angle) * 0.18, sin(angle) * 0.18);
    final end = Alignment(-cos(angle) * 0.18, -sin(angle) * 0.18);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: const [
            Color(0xFF060709), // ほぼ黒
            Color(0xFF0A0B10), // 漆黒に近い群青黒
            Color(0xFF07080B),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
    );
  }
}

class _MistBlob extends StatelessWidget {
  const _MistBlob({
    required this.t,
    required this.base,
    required this.size,
    required this.color,
    required this.phase,
    required this.blur,
  });

  final double t;
  final Alignment base;
  final double size;
  final Color color;
  final double phase;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final a = sin((t + phase) * 2 * pi) * 0.12;
    final b = cos((t + phase) * 2 * pi) * 0.10;
    final align = Alignment(
      (base.x + a).clamp(-1.0, 1.0),
      (base.y + b).clamp(-1.0, 1.0),
    );
    return Align(
      alignment: align,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

class _FilmGrainPainter extends CustomPainter {
  _FilmGrainPainter(this.t) {
    _rng ??= Random(7);
  }
  final double t;
  static Random? _rng;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    // ランダム粒子を軽く散らす（ごく薄く）
    for (int i = 0; i < 220; i++) {
      final x = _rng!.nextDouble() * size.width;
      final y = _rng!.nextDouble() * size.height;
      final o = 0.015 + 0.02 * _rng!.nextDouble();
      paint.color = Colors.white.withOpacity(o);
      canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FilmGrainPainter oldDelegate) => true;
}

class _ScanlinePainter extends CustomPainter {
  _ScanlinePainter({required this.opacity});
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(opacity);
    const gap = 3.0;
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter oldDelegate) => false;
}

/* ===================== カード/タイトル/ボタン ===================== */

class _ObsidianCard extends StatelessWidget {
  const _ObsidianCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 540),
      padding: const EdgeInsets.all(1.8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0x22FF1133), Color(0x11444455)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 26,
            spreadRadius: 2,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0x2212161E),
                  Color(0x3312161E),
                  Color(0x4412161E),
                ],
              ),
              border: Border.all(color: const Color(0x44FF1133), width: 1.0),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _OccultDivider extends StatelessWidget {
  const _OccultDivider();

  @override
  Widget build(BuildContext context) {
    Widget bar() => Expanded(
      child: Container(
        height: 1,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0x11FF1133), Color(0x88FF1133), Color(0x11FF1133)],
          ),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 8),
        bar(),
        const SizedBox(width: 8),
        const Icon(Icons.circle, size: 6, color: Color(0xFFFF1133)),
        const SizedBox(width: 8),
        bar(),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _CryptTitle extends StatelessWidget {
  const _CryptTitle({required this.text, required this.t});
  final String text;
  final double t;

  @override
  Widget build(BuildContext context) {
    // 赤/青に微オフセット → グリッチ風の不穏なにじみ
    final dx = sin(t * 2 * pi) * 1.2;
    final dy = cos(t * 2 * pi) * 0.8;

    Widget layer(Color c, Offset o, double blur) => Transform.translate(
      offset: o,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: 4.0,
          color: c,
          shadows: [Shadow(color: c.withOpacity(0.5), blurRadius: blur)],
        ),
      ),
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        layer(const Color(0xFFFF1133).withOpacity(0.9), Offset(dx, 0), 18), // 赤
        layer(
          const Color(0xFF1BA1FF).withOpacity(0.8),
          Offset(-dx, dy),
          14,
        ), // 青
        layer(Colors.white, Offset.zero, 8),
      ],
    );
  }
}

class _CrimsonButton extends StatelessWidget {
  const _CrimsonButton({
    required this.t,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final double t;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pulse = 0.55 + 0.45 * sin(t * 2 * pi);
    final red = const Color(0xFFFF1133);
    final deep = const Color(0xFF330008);

    return GestureDetector(
      onTap: () {
        HapticFeedback.heavyImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [deep.withOpacity(0.66), const Color(0x2212161E)],
          ),
          border: Border.all(color: red.withOpacity(0.85), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: red.withOpacity(0.22 * pulse),
              blurRadius: 28 + 10 * pulse,
              spreadRadius: 1.2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: red.withOpacity(0.95)),
            const SizedBox(width: 10),
            ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                colors: [Color(0xFFFF96A3), Color(0xFFFF1133)],
              ).createShader(r),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: Colors.white, // ShaderMaskで上書き
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassBackButton extends StatelessWidget {
  const _GlassBackButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x2212161E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x33FF1133)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: const Color(0xFFFF96A3).withOpacity(0.95),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: const Color(0xFFFF96A3).withOpacity(0.95),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

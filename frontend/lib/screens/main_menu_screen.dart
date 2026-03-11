import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'game_screen.dart';
import 'sprite_picker_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  late AnimationController _buttonsController;
  late Animation<double> _buttonsFade;
  late Animation<Offset> _buttonsSlide;

  @override
  void initState() {
    super.initState();

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _headerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOut),
    );
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _headerController, curve: Curves.easeOut),
        );

    _buttonsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _buttonsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _buttonsController, curve: Curves.easeOut),
    );
    _buttonsSlide =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
          CurvedAnimation(parent: _buttonsController, curve: Curves.easeOut),
        );

    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 350), () {
      _buttonsController.forward();
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _buttonsController.dispose();
    super.dispose();
  }

  void _onStart() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const GameScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _onSettings() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SpritePickerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _onQuit() {
    if (Platform.isAndroid || Platform.isIOS) {
      SystemNavigator.pop();
    } else {
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background ──────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0A0E1A),
                  Color(0xFF11172B),
                  Color(0xFF0D1022),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Subtle radial glow
          Positioned(
            top: -80,
            left: MediaQuery.of(context).size.width * 0.5 - 180,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7B61FF).withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Pixel-style decorative dots
          ..._buildDecorativeDots(),

          // ── Content ─────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),

                // ── Header ──────────────────────────────────────────
                FadeTransition(
                  opacity: _headerFade,
                  child: SlideTransition(
                    position: _headerSlide,
                    child: Column(
                      children: [
                        // Game Icon
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7B61FF), Color(0xFF3B1FA3)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF7B61FF,
                                ).withValues(alpha: 0.5),
                                blurRadius: 30,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.search_rounded,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Game title
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Color(0xFFB29CFF),
                              Color(0xFF7B61FF),
                              Color(0xFF4A90E2),
                            ],
                          ).createShader(bounds),
                          child: Text(
                            'HIDE N SEEK',
                            style: GoogleFonts.orbitron(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '— A Stealth Adventure —',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white30,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // ── Buttons ─────────────────────────────────────────
                FadeTransition(
                  opacity: _buttonsFade,
                  child: SlideTransition(
                    position: _buttonsSlide,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48.0),
                      child: Column(
                        children: [
                          _MenuButton(
                            label: 'START GAME',
                            icon: Icons.play_arrow_rounded,
                            isPrimary: true,
                            onTap: _onStart,
                          ),
                          const SizedBox(height: 16),
                          _MenuButton(
                            label: 'SETTINGS',
                            icon: Icons.settings_rounded,
                            isPrimary: false,
                            onTap: _onSettings,
                          ),
                          const SizedBox(height: 16),
                          _MenuButton(
                            label: 'QUIT',
                            icon: Icons.power_settings_new_rounded,
                            isPrimary: false,
                            isDanger: true,
                            onTap: _onQuit,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 1),

                // Version label
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'v1.0.0',
                    style: GoogleFonts.inter(
                      color: Colors.white12,
                      fontSize: 11,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDecorativeDots() {
    final dots = <Widget>[];
    final positions = [
      [0.05, 0.12],
      [0.92, 0.08],
      [0.88, 0.75],
      [0.04, 0.65],
      [0.5, 0.95],
      [0.15, 0.90],
      [0.78, 0.45],
    ];
    for (final p in positions) {
      dots.add(
        Positioned(
          left: MediaQuery.of(context).size.width * p[0],
          top: MediaQuery.of(context).size.height * p[1],
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF7B61FF).withValues(alpha: 0.25),
            ),
          ),
        ),
      );
    }
    return dots;
  }
}

// ── Reusable Menu Button ──────────────────────────────────────────────────────
class _MenuButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final bool isDanger;
  final VoidCallback onTap;

  const _MenuButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
    this.isDanger = false,
  });

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _scaleAnim;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _hoverController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  Color get _baseColor {
    if (widget.isDanger) return const Color(0xFFFF4D6A);
    if (widget.isPrimary) return const Color(0xFF7B61FF);
    return const Color(0xFF1E2244);
  }

  Color get _borderColor {
    if (widget.isDanger) return const Color(0xFFFF4D6A).withValues(alpha: 0.5);
    if (widget.isPrimary) return const Color(0xFF9E8CFF).withValues(alpha: 0.6);
    return const Color(0xFF7B61FF).withValues(alpha: 0.2);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovering = true);
        _hoverController.forward();
      },
      onExit: (_) {
        setState(() => _hovering = false);
        _hoverController.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnim,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: widget.isPrimary
                  ? _baseColor.withValues(alpha: _hovering ? 1.0 : 0.85)
                  : _baseColor.withValues(alpha: _hovering ? 0.85 : 0.55),
              border: Border.all(color: _borderColor, width: 1.5),
              gradient: widget.isPrimary
                  ? LinearGradient(
                      colors: _hovering
                          ? [const Color(0xFF9E8CFF), const Color(0xFF5B43CC)]
                          : [const Color(0xFF7B61FF), const Color(0xFF3B1FA3)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              boxShadow: widget.isPrimary
                  ? [
                      BoxShadow(
                        color: const Color(
                          0xFF7B61FF,
                        ).withValues(alpha: _hovering ? 0.5 : 0.25),
                        blurRadius: _hovering ? 24 : 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : widget.isDanger
                  ? [
                      BoxShadow(
                        color: const Color(
                          0xFFFF4D6A,
                        ).withValues(alpha: _hovering ? 0.35 : 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  widget.label,
                  style: GoogleFonts.orbitron(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 2.5,
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

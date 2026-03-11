import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../game/hide_and_seek_game.dart';
import '../game/core/game_settings.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  HideAndSeekGame? _game;
  int _level = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showRolePicker());
  }

  void _showRolePicker() {
    showDialog<PlayerRole>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RolePickerDialog(level: _level),
    ).then((role) {
      if (role == null || !mounted) return;
      setState(() {
        _game = HideAndSeekGame(playerRole: role, level: _level);
      });
    });
  }

  // ── Overlay builders ──────────────────────────────────────────────────────
  Widget _buildWinOverlay(BuildContext ctx, HideAndSeekGame game) =>
      _EndOverlay(
        title: 'YOU WIN!',
        subtitle: game.playerRole == PlayerRole.seeker
            ? 'You found the hider!'
            : 'The seeker was trapped!',
        color: const Color(0xFF00C896),
        isWin: true,
        onNext: _nextLevel,
        onRestart: _restart,
        onMenu: _backToMenu,
      );

  Widget _buildLoseOverlay(BuildContext ctx, HideAndSeekGame game) =>
      _EndOverlay(
        title: 'YOU LOSE',
        subtitle: game.playerRole == PlayerRole.seeker
            ? 'You got trapped — hider escapes!'
            : 'The seeker found you!',
        color: const Color(0xFFFF4D6A),
        isWin: false,
        onNext: _restart, // on loss, 'next' button = retry same level
        onRestart: _restart,
        onMenu: _backToMenu,
      );

  Widget _buildStepBackOverlay(BuildContext ctx, HideAndSeekGame game) {
    return ListenableBuilder(
      listenable: globalSettings,
      builder: (context, _) {
        return ValueListenableBuilder<int>(
          valueListenable: game.historyStateNotifier,
          builder: (context, historyCount, child) {
            final availableCount = globalSettings.availableStepBacks;
            // The button is inactive if the player has 0 charges or hasn't made any moves to step back from
            final isActive = availableCount > 0 && historyCount > 0;

            return SafeArea(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24, right: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton(
                        heroTag: 'step_back',
                        onPressed: isActive ? game.stepBack : null,
                        backgroundColor: isActive
                            ? const Color(0xFF7B61FF)
                            : const Color(0xFF333344),
                        foregroundColor: isActive ? Colors.white : Colors.grey,
                        elevation: isActive ? 4 : 0,
                        child: const Icon(Icons.undo_rounded),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'STEP BACK ($availableCount)',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _nextLevel() {
    setState(() {
      _level++;
      _game = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _showRolePicker());
  }

  void _restart() {
    setState(() => _game = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showRolePicker());
  }

  void _backToMenu() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    if (_game == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E1A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF7B61FF)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Stack(
        children: [
          GameWidget(
            game: _game!,
            overlayBuilderMap: {
              HideAndSeekGame.overlayWin: (ctx, game) =>
                  _buildWinOverlay(ctx, game as HideAndSeekGame),
              HideAndSeekGame.overlayLose: (ctx, game) =>
                  _buildLoseOverlay(ctx, game as HideAndSeekGame),
              HideAndSeekGame.overlayStepBack: (ctx, game) =>
                  _buildStepBackOverlay(ctx, game as HideAndSeekGame),
            },
          ),
          // Back button.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF7B61FF),
                ),
                onPressed: _backToMenu,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Role Picker Dialog ────────────────────────────────────────────────────────
class _RolePickerDialog extends StatelessWidget {
  final int level;
  const _RolePickerDialog({required this.level});

  @override
  Widget build(BuildContext context) {
    final dims = HideAndSeekGame.gridSizeForLevel(level);
    final gridLabel = '${dims.$2}\u00d7${dims.$1} grid';
    return Dialog(
      backgroundColor: const Color(0xFF11172B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'LEVEL $level',
              style: GoogleFonts.orbitron(
                color: const Color(0xFF7B61FF),
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              gridLabel,
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose your role',
              style: GoogleFonts.orbitron(
                color: const Color(0xFFB29CFF),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'The other role will be controlled by AI.',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _RoleButton(
              label: 'PLAY AS HIDER',
              description: 'Hide in a safe spot before time runs out',
              icon: Icons.person_outline_rounded,
              color: const Color(0xFF00C896),
              onTap: () => Navigator.of(context).pop(PlayerRole.hider),
            ),
            const SizedBox(height: 14),
            _RoleButton(
              label: 'PLAY AS SEEKER',
              description: 'Navigate the maze and find the hidden AI',
              icon: Icons.search_rounded,
              color: const Color(0xFFFF6B35),
              onTap: () => Navigator.of(context).pop(PlayerRole.seeker),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoleButton({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.orbitron(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: color.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

// ── End Overlay ───────────────────────────────────────────────────────────────
class _EndOverlay extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final bool isWin;
  final VoidCallback onNext;
  final VoidCallback onRestart;
  final VoidCallback onMenu;

  const _EndOverlay({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isWin,
    required this.onNext,
    required this.onRestart,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF11172B).withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.55), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: GoogleFonts.orbitron(
                color: color,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: GoogleFonts.inter(color: Colors.white60, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onNext,
                child: Text(
                  isWin ? 'NEXT LEVEL' : 'TRY AGAIN',
                  style: GoogleFonts.orbitron(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  side: BorderSide(
                    color: Colors.white24.withValues(alpha: 0.3),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onMenu,
                child: Text(
                  'MAIN MENU',
                  style: GoogleFonts.orbitron(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';

import '../game/components/player_sprite_config.dart';

/// Full-screen sprite picker that lets the user assign a sprite-sheet frame
/// to each of the 7 movement directions for both Hider and Seeker.
class SpritePickerScreen extends StatefulWidget {
  const SpritePickerScreen({super.key});

  @override
  State<SpritePickerScreen> createState() => _SpritePickerScreenState();
}

class _SpritePickerScreenState extends State<SpritePickerScreen>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  late PlayerSpriteConfig _config;
  bool _editingHider = true; // toggle between hider / seeker tab
  MoveDir _selectedDir = MoveDir.idle;
  bool _unsaved = false;

  ui.Image? _sheetImage;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _config = PlayerSpriteConfig(
      hider: CharSpriteConfig(Map.from(globalSpriteConfig.hider.frames)),
      seeker: CharSpriteConfig(Map.from(globalSpriteConfig.seeker.frames)),
    );
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _editingHider = _tabController.index == 0);
    });
    _loadSheet();
  }

  Future<void> _loadSheet() async {
    try {
      final data = await rootBundle.load(
        'resources/Small-8-Direction-Characters_by_AxulArt.png',
      );
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final frame = await codec.getNextFrame();
      if (mounted) setState(() => _sheetImage = frame.image);
    } catch (e) {
      debugPrint('SpritePickerScreen: failed to load sheet: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  CharSpriteConfig get _current =>
      _editingHider ? _config.hider : _config.seeker;

  void _setFrame(int col, int row) {
    final bool flip = _current.frameFor(_selectedDir).flip;
    final frame = SpriteFrame(col: col, row: row, flip: flip);
    setState(() {
      if (_editingHider) {
        _config = PlayerSpriteConfig(
          hider: _config.hider.copyWithFrame(_selectedDir, frame),
          seeker: _config.seeker,
        );
      } else {
        _config = PlayerSpriteConfig(
          hider: _config.hider,
          seeker: _config.seeker.copyWithFrame(_selectedDir, frame),
        );
      }
      _unsaved = true;
    });
  }

  void _toggleFlip() {
    final existing = _current.frameFor(_selectedDir);
    _setFrameObj(existing.copyWith(flip: !existing.flip));
  }

  void _setFrameObj(SpriteFrame frame) {
    setState(() {
      if (_editingHider) {
        _config = PlayerSpriteConfig(
          hider: _config.hider.copyWithFrame(_selectedDir, frame),
          seeker: _config.seeker,
        );
      } else {
        _config = PlayerSpriteConfig(
          hider: _config.hider,
          seeker: _config.seeker.copyWithFrame(_selectedDir, frame),
        );
      }
      _unsaved = true;
    });
  }

  Future<void> _save() async {
    globalSpriteConfig = _config;
    await _config.save();
    setState(() => _unsaved = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1C1C2E),
          content: Text(
            'Sprite config saved! Restart a game to see changes.',
            style: GoogleFonts.inter(color: const Color(0xFFB29CFF)),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1022),
        foregroundColor: Colors.white,
        title: Text(
          'SPRITE PICKER',
          style: GoogleFonts.orbitron(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
            color: const Color(0xFFB29CFF),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF7B61FF),
          labelColor: const Color(0xFFB29CFF),
          unselectedLabelColor: Colors.white38,
          labelStyle: GoogleFonts.orbitron(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
          tabs: const [
            Tab(text: 'HIDER'),
            Tab(text: 'SEEKER'),
          ],
        ),
        actions: [
          if (_unsaved)
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(
                Icons.save_rounded,
                size: 18,
                color: Color(0xFF7B61FF),
              ),
              label: Text(
                'SAVE',
                style: GoogleFonts.orbitron(
                  color: const Color(0xFF7B61FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 600;
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 260,
                  child: _DirectionPanel(
                    config: _current,
                    selectedDir: _selectedDir,
                    sheetImage: _sheetImage,
                    onDirSelected: (d) => setState(() => _selectedDir = d),
                    onFlipToggle: _toggleFlip,
                  ),
                ),
                const VerticalDivider(width: 1, color: Color(0xFF1E2244)),
                Expanded(
                  child: _SheetGrid(
                    sheetImage: _sheetImage,
                    config: _current,
                    selectedDir: _selectedDir,
                    onCellTapped: _setFrame,
                  ),
                ),
              ],
            );
          }
          return Column(
            children: [
              _DirectionPanel(
                config: _current,
                selectedDir: _selectedDir,
                sheetImage: _sheetImage,
                onDirSelected: (d) => setState(() => _selectedDir = d),
                onFlipToggle: _toggleFlip,
              ),
              const Divider(height: 1, color: Color(0xFF1E2244)),
              Expanded(
                child: _SheetGrid(
                  sheetImage: _sheetImage,
                  config: _current,
                  selectedDir: _selectedDir,
                  onCellTapped: _setFrame,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Direction panel ──────────────────────────────────────────────────────────
class _DirectionPanel extends StatelessWidget {
  final CharSpriteConfig config;
  final MoveDir selectedDir;
  final ui.Image? sheetImage;
  final ValueChanged<MoveDir> onDirSelected;
  final VoidCallback onFlipToggle;

  const _DirectionPanel({
    required this.config,
    required this.selectedDir,
    required this.sheetImage,
    required this.onDirSelected,
    required this.onFlipToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D1022),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              'MOVEMENT DIRECTION',
              style: GoogleFonts.orbitron(
                fontSize: 10,
                color: Colors.white30,
                letterSpacing: 2,
              ),
            ),
          ),
          ...MoveDir.values.map(
            (dir) => _DirRow(
              dir: dir,
              frame: config.frameFor(dir),
              sheetImage: sheetImage,
              isSelected: dir == selectedDir,
              onTap: () => onDirSelected(dir),
            ),
          ),
          const Divider(height: 24, color: Color(0xFF1E2244)),
          // Flip toggle for selected dir
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Flip Horizontal',
                  style: GoogleFonts.inter(color: Colors.white60, fontSize: 13),
                ),
                Switch(
                  value: config.frameFor(selectedDir).flip,
                  onChanged: (_) => onFlipToggle(),
                  activeThumbColor: const Color(0xFF7B61FF),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Tap a cell in the sprite sheet →\nto assign it to the selected direction.',
              style: GoogleFonts.inter(
                color: Colors.white24,
                fontSize: 11,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DirRow extends StatelessWidget {
  final MoveDir dir;
  final SpriteFrame frame;
  final ui.Image? sheetImage;
  final bool isSelected;
  final VoidCallback onTap;

  const _DirRow({
    required this.dir,
    required this.frame,
    required this.sheetImage,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: isSelected
            ? const Color(0xFF7B61FF).withValues(alpha: 0.18)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Mini preview of assigned frame
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF111830),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF7B61FF)
                      : const Color(0xFF1E2244),
                  width: 1.5,
                ),
              ),
              child: sheetImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: _FramePreview(image: sheetImage!, frame: frame),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                dir.label,
                style: GoogleFonts.inter(
                  color: isSelected ? const Color(0xFFB29CFF) : Colors.white54,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF7B61FF),
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Sheet grid ───────────────────────────────────────────────────────────────
class _SheetGrid extends StatelessWidget {
  final ui.Image? sheetImage;
  final CharSpriteConfig config;
  final MoveDir selectedDir;
  final void Function(int col, int row) onCellTapped;

  // Sheet is 128 × 288 px → 8 cols × 12 rows of 16×24 px cells.
  static const int _cols = 8;
  static const int _rows = 12;

  const _SheetGrid({
    required this.sheetImage,
    required this.config,
    required this.selectedDir,
    required this.onCellTapped,
  });

  @override
  Widget build(BuildContext context) {
    final img = sheetImage;
    if (img == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF7B61FF)),
      );
    }

    final selectedFrame = config.frameFor(selectedDir);

    // Build a set of all currently assigned cells for this character.
    final assignedFrames = <SpriteFrame>{};
    for (final dir in MoveDir.values) {
      assignedFrames.add(
        SpriteFrame(
          col: config.frameFor(dir).col,
          row: config.frameFor(dir).row,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SPRITE SHEET',
            style: GoogleFonts.orbitron(
              fontSize: 10,
              color: Colors.white30,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a frame to assign it to "${selectedDir.label}"',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
          ),
          const SizedBox(height: 16),
          // The actual grid
          LayoutBuilder(
            builder: (context, c) {
              // Scale cells up so they're easy to tap.
              const scale = 5.0;
              const cellW = 16.0 * scale;
              const cellH = 24.0 * scale;

              return Wrap(
                spacing: 0,
                runSpacing: 0,
                children: [
                  for (int row = 0; row < _rows; row++)
                    for (int col = 0; col < _cols; col++)
                      _SheetCell(
                        image: img,
                        col: col,
                        row: row,
                        cellW: cellW,
                        cellH: cellH,
                        isSelected:
                            selectedFrame.col == col &&
                            selectedFrame.row == row,
                        isAssigned: assignedFrames.any(
                          (f) => f.col == col && f.row == row,
                        ),
                        onTap: () => onCellTapped(col, row),
                      ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          // Legend
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _LegendItem(
                color: const Color(0xFF7B61FF),
                label: 'Currently selected',
              ),
              _LegendItem(
                color: const Color(0xFF4A90E2).withValues(alpha: 0.5),
                label: 'Used by another direction',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SheetCell extends StatelessWidget {
  final ui.Image image;
  final int col;
  final int row;
  final double cellW;
  final double cellH;
  final bool isSelected;
  final bool isAssigned;
  final VoidCallback onTap;

  const _SheetCell({
    required this.image,
    required this.col,
    required this.row,
    required this.cellW,
    required this.cellH,
    required this.isSelected,
    required this.isAssigned,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor = Colors.white.withValues(alpha: 0.06);
    double borderWidth = 1;

    if (isSelected) {
      borderColor = const Color(0xFF7B61FF);
      borderWidth = 2;
    } else if (isAssigned) {
      borderColor = const Color(0xFF4A90E2).withValues(alpha: 0.5);
      borderWidth = 1.5;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cellW,
        height: cellH,
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: borderWidth),
          color: isSelected
              ? const Color(0xFF7B61FF).withValues(alpha: 0.15)
              : Colors.transparent,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF7B61FF).withValues(alpha: 0.4),
                    blurRadius: 6,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: CustomPaint(
          painter: _CellPainter(
            image: image,
            srcRect: Rect.fromLTWH(col * 16.0, row * 24.0, 16, 24),
            dstRect: Rect.fromLTWH(0, 0, cellW, cellH),
          ),
        ),
      ),
    );
  }
}

class _CellPainter extends CustomPainter {
  final ui.Image image;
  final Rect srcRect;
  final Rect dstRect;

  const _CellPainter({
    required this.image,
    required this.srcRect,
    required this.dstRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      srcRect,
      dstRect,
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(_CellPainter old) =>
      old.srcRect != srcRect || old.dstRect != dstRect;
}

// ─── Tiny frame preview (used in the direction list) ─────────────────────────
class _FramePreview extends StatelessWidget {
  final ui.Image image;
  final SpriteFrame frame;

  const _FramePreview({required this.image, required this.frame});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FramePreviewPainter(image: image, frame: frame),
    );
  }
}

class _FramePreviewPainter extends CustomPainter {
  final ui.Image image;
  final SpriteFrame frame;

  const _FramePreviewPainter({required this.image, required this.frame});

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(frame.col * 16.0, frame.row * 24.0, 16, 24);
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);

    if (frame.flip) {
      canvas.save();
      canvas.translate(size.width / 2, 0);
      canvas.scale(-1, 1);
      canvas.translate(-size.width / 2, 0);
    }

    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.none,
    );

    if (frame.flip) canvas.restore();
  }

  @override
  bool shouldRepaint(_FramePreviewPainter old) =>
      old.frame != old.frame || old.image != image;
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }
}

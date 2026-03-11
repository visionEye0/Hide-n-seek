import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Direction keys ───────────────────────────────────────────────────────────
/// The 7 states a player can be in (standstill + 6 hex directions).
enum MoveDir {
  idle,
  up, // North
  upRight, // NE
  upLeft, // NW
  down, // South
  downLeft, // SW
  downRight, // SE
}

extension MoveDirLabel on MoveDir {
  String get label {
    switch (this) {
      case MoveDir.idle:
        return 'Idle / Standstill';
      case MoveDir.up:
        return 'Up (North)';
      case MoveDir.upRight:
        return 'Up-Right (NE)';
      case MoveDir.upLeft:
        return 'Up-Left (NW)';
      case MoveDir.down:
        return 'Down (South)';
      case MoveDir.downLeft:
        return 'Down-Left (SW)';
      case MoveDir.downRight:
        return 'Down-Right (SE)';
    }
  }
}

// ─── Single frame reference ───────────────────────────────────────────────────
/// Points at one frame in the sprite sheet (16 × 24 px cells).
class SpriteFrame {
  /// Column index (0-based). x = col * 16.
  final int col;

  /// Row index (0-based). y = row * 24.
  final int row;

  /// Whether to flip the frame horizontally when rendering.
  final bool flip;

  const SpriteFrame({required this.col, required this.row, this.flip = false});

  SpriteFrame copyWith({int? col, int? row, bool? flip}) => SpriteFrame(
    col: col ?? this.col,
    row: row ?? this.row,
    flip: flip ?? this.flip,
  );

  Map<String, dynamic> toJson() => {'col': col, 'row': row, 'flip': flip};

  factory SpriteFrame.fromJson(Map<String, dynamic> j) => SpriteFrame(
    col: j['col'] as int,
    row: j['row'] as int,
    flip: j['flip'] as bool? ?? false,
  );

  @override
  bool operator ==(Object other) =>
      other is SpriteFrame &&
      col == other.col &&
      row == other.row &&
      flip == other.flip;

  @override
  int get hashCode => Object.hash(col, row, flip);
}

// ─── Per-character config ─────────────────────────────────────────────────────
class CharSpriteConfig {
  final Map<MoveDir, SpriteFrame> frames;

  const CharSpriteConfig(this.frames);

  SpriteFrame frameFor(MoveDir dir) =>
      frames[dir] ?? frames[MoveDir.idle] ?? const SpriteFrame(col: 0, row: 1);

  CharSpriteConfig copyWithFrame(MoveDir dir, SpriteFrame frame) {
    final updated = Map<MoveDir, SpriteFrame>.from(frames);
    updated[dir] = frame;
    return CharSpriteConfig(updated);
  }

  Map<String, dynamic> toJson() =>
      frames.map((k, v) => MapEntry(k.name, v.toJson()));

  factory CharSpriteConfig.fromJson(Map<String, dynamic> j) {
    final frames = <MoveDir, SpriteFrame>{};
    for (final dir in MoveDir.values) {
      if (j.containsKey(dir.name)) {
        frames[dir] = SpriteFrame.fromJson(
          Map<String, dynamic>.from(j[dir.name] as Map),
        );
      }
    }
    return CharSpriteConfig(frames);
  }

  // ── Defaults ──
  /// The AxulArt sheet layout has 8 columns for directions:
  /// Col 0: Up | 1: Up-Right | 2: Right | 3: Down-Right
  /// Col 4: Down | 5: Down-Left | 6: Left | 7: Up-Left
  ///
  /// Walk animations are 3 frames deep down the columns.
  /// Base rows:
  /// Row 1: White char
  /// Row 5: Blue char (Hider)
  /// Row 9: Orange char (Seeker)

  static CharSpriteConfig defaultHider() => CharSpriteConfig({
    MoveDir.idle: const SpriteFrame(col: 4, row: 5), // Down
    MoveDir.up: const SpriteFrame(col: 0, row: 5),
    MoveDir.upRight: const SpriteFrame(col: 1, row: 5),
    MoveDir.upLeft: const SpriteFrame(col: 7, row: 5),
    MoveDir.down: const SpriteFrame(col: 4, row: 5),
    MoveDir.downLeft: const SpriteFrame(col: 5, row: 5),
    MoveDir.downRight: const SpriteFrame(col: 3, row: 5),
  });

  static CharSpriteConfig defaultSeeker() => CharSpriteConfig({
    MoveDir.idle: const SpriteFrame(col: 4, row: 9), // Down
    MoveDir.up: const SpriteFrame(col: 0, row: 9),
    MoveDir.upRight: const SpriteFrame(col: 1, row: 9),
    MoveDir.upLeft: const SpriteFrame(col: 7, row: 9),
    MoveDir.down: const SpriteFrame(col: 4, row: 9),
    MoveDir.downLeft: const SpriteFrame(col: 5, row: 9),
    MoveDir.downRight: const SpriteFrame(col: 3, row: 9),
  });
}

// ─── Top-level config + persistence ──────────────────────────────────────────
class PlayerSpriteConfig {
  CharSpriteConfig hider;
  CharSpriteConfig seeker;

  PlayerSpriteConfig({required this.hider, required this.seeker});

  factory PlayerSpriteConfig.defaults() => PlayerSpriteConfig(
    hider: CharSpriteConfig.defaultHider(),
    seeker: CharSpriteConfig.defaultSeeker(),
  );

  static const _prefsKey = 'player_sprite_config_v3';

  static Future<PlayerSpriteConfig> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return PlayerSpriteConfig.defaults();
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return PlayerSpriteConfig(
        hider: CharSpriteConfig.fromJson(
          Map<String, dynamic>.from(j['hider'] as Map),
        ),
        seeker: CharSpriteConfig.fromJson(
          Map<String, dynamic>.from(j['seeker'] as Map),
        ),
      );
    } catch (_) {
      return PlayerSpriteConfig.defaults();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode({'hider': hider.toJson(), 'seeker': seeker.toJson()}),
    );
  }
}

// ─── Global singleton (loaded once at startup) ────────────────────────────────
PlayerSpriteConfig globalSpriteConfig = PlayerSpriteConfig.defaults();

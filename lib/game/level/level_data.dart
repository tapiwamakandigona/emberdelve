// game/level/level_data.dart — ASCII level format: parser + linter.
// Pure Dart (no Flame/Flutter imports) so levels are headless-testable.
//
// FORMAT (assets/levels/*.txt):
//   Lines starting with "meta:" set key=value pairs (name, music, par_s, world).
//   All other non-empty lines are grid rows (top to bottom). Short rows are
//   padded with '.' to the widest row.
//
// LEGEND (the integration contract — do not change meanings, only add):
//   .  empty            #  solid block         =  one-way platform
//   ^  spikes (hazard)  ~  fire (hazard)       B  cracked wall (breakable)
//   P  player spawn     E  exit door           s  tutorial sign
//   c  coin             a  apple pickup        f  feather (rare currency)
//   C  chest            X  secret chest (counts as chest + secret)
//   T  Thornling        V  Ashbat (flyer)      O  Ember Totem (spitter)
//   R  Rotshield        G  Grove Golem (boss)

enum TileKind { empty, solid, platform, spikes, fire, crackedWall }

enum SpawnKind {
  player,
  exit,
  sign,
  coin,
  apple,
  feather,
  chest,
  secretChest,
  thornling,
  ashbat,
  emberTotem,
  rotshield,
  groveGolem,
}

class Spawn {
  final SpawnKind kind;
  final int x, y; // tile coords, (0,0) = top-left
  const Spawn(this.kind, this.x, this.y);

  @override
  String toString() => '$kind@($x,$y)';
}

class LevelParseException implements Exception {
  final String message;
  LevelParseException(this.message);
  @override
  String toString() => 'LevelParseException: $message';
}

const Map<String, TileKind> _tileChars = {
  '.': TileKind.empty,
  '#': TileKind.solid,
  '=': TileKind.platform,
  '^': TileKind.spikes,
  '~': TileKind.fire,
  'B': TileKind.crackedWall,
};

const Map<String, SpawnKind> _spawnChars = {
  'P': SpawnKind.player,
  'E': SpawnKind.exit,
  's': SpawnKind.sign,
  'c': SpawnKind.coin,
  'a': SpawnKind.apple,
  'f': SpawnKind.feather,
  'C': SpawnKind.chest,
  'X': SpawnKind.secretChest,
  'T': SpawnKind.thornling,
  'V': SpawnKind.ashbat,
  'O': SpawnKind.emberTotem,
  'R': SpawnKind.rotshield,
  'G': SpawnKind.groveGolem,
};

class LevelData {
  final int width, height;
  final List<List<TileKind>> tiles; // [y][x]
  final List<Spawn> spawns;
  final Map<String, String> meta;

  LevelData._(this.width, this.height, this.tiles, this.spawns, this.meta);

  String get name => meta['name'] ?? 'Unnamed';
  String get music => meta['music'] ?? 'combat';
  int get parSeconds => int.tryParse(meta['par_s'] ?? '') ?? 120;

  Spawn get playerSpawn => spawns.firstWhere((s) => s.kind == SpawnKind.player);
  Spawn get exit => spawns.firstWhere((s) => s.kind == SpawnKind.exit);
  int get chestCount => spawns
      .where((s) =>
          s.kind == SpawnKind.chest || s.kind == SpawnKind.secretChest)
      .length;
  int get secretCount =>
      spawns.where((s) => s.kind == SpawnKind.secretChest).length;
  int get featherCount =>
      spawns.where((s) => s.kind == SpawnKind.feather).length;

  TileKind tileAt(int x, int y) {
    if (x < 0 || x >= width) return TileKind.solid; // walls beyond level edges
    if (y < 0) return TileKind.empty; // open sky
    if (y >= height) return TileKind.empty; // fall = death plane
    return tiles[y][x];
  }

  bool solidAt(int x, int y) => tileAt(x, y) == TileKind.solid ||
      tileAt(x, y) == TileKind.crackedWall;

  static LevelData parse(String source) {
    final meta = <String, String>{};
    final rows = <String>[];
    for (final raw in source.split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty) continue;
      if (line.startsWith('meta:')) {
        final body = line.substring(5).trim();
        final eq = body.indexOf('=');
        if (eq <= 0) {
          throw LevelParseException('bad meta line: "$line"');
        }
        meta[body.substring(0, eq).trim()] = body.substring(eq + 1).trim();
        continue;
      }
      rows.add(line);
    }
    if (rows.isEmpty) throw LevelParseException('level has no grid rows');

    final width = rows.fold<int>(0, (w, r) => r.length > w ? r.length : w);
    final height = rows.length;
    final tiles = List.generate(
        height, (_) => List.filled(width, TileKind.empty),
        growable: false);
    final spawns = <Spawn>[];

    for (var y = 0; y < height; y++) {
      final row = rows[y];
      for (var x = 0; x < row.length; x++) {
        final ch = row[x];
        final tile = _tileChars[ch];
        if (tile != null) {
          tiles[y][x] = tile;
          continue;
        }
        final spawn = _spawnChars[ch];
        if (spawn != null) {
          spawns.add(Spawn(spawn, x, y));
          continue;
        }
        throw LevelParseException('unknown char "$ch" at ($x,$y)');
      }
    }

    final level = LevelData._(width, height, tiles, spawns, meta);
    _lint(level);
    return level;
  }

  /// Structural sanity: exactly one spawn/exit, nothing embedded in solids,
  /// hazards can't sit on the spawn row-adjacent tile, level is bounded below
  /// the spawn column (no instant-death starts).
  static void _lint(LevelData l) {
    int count(SpawnKind k) => l.spawns.where((s) => s.kind == k).length;
    if (count(SpawnKind.player) != 1) {
      throw LevelParseException(
          'need exactly 1 player spawn, got ${count(SpawnKind.player)}');
    }
    if (count(SpawnKind.exit) != 1) {
      throw LevelParseException(
          'need exactly 1 exit, got ${count(SpawnKind.exit)}');
    }
    for (final s in l.spawns) {
      if (l.tiles[s.y][s.x] != TileKind.empty) {
        throw LevelParseException('$s overlaps a non-empty tile');
      }
    }
    // Spawn must have ground somewhere below it.
    final p = l.playerSpawn;
    var grounded = false;
    for (var y = p.y + 1; y < l.height; y++) {
      final t = l.tiles[y][p.x];
      if (t == TileKind.solid || t == TileKind.platform) {
        grounded = true;
        break;
      }
      if (t == TileKind.spikes || t == TileKind.fire) break;
    }
    if (!grounded) {
      throw LevelParseException('player spawn has no safe ground below');
    }
  }
}

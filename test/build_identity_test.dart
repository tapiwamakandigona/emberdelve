import 'package:emberdelve/ui/build_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RunBuildIdentity', () {
    test('plain or empty pools are Emberbound', () {
      expect(buildIdentity(const []).path, BuildPath.ember);
      final id = buildIdentity(const ['d4', 'd6', 'd8', 'd10', 'd12']);
      expect(id.path, BuildPath.ember);
      expect(id.dominantSize, 12);
      expect(id.dominantTier, 3);
      expect(id.specialDice, 0);
      for (final sides in [4, 6, 8, 10, 12]) {
        expect(id.countFor(sides), 1);
      }
    });

    test('attack, block and consistency pools select distinct paths', () {
      expect(
        buildIdentity(const ['d6_brand', 'd8_blade', 'd10_keen']).path,
        BuildPath.blade,
      );
      expect(
        buildIdentity(const ['d6_ward', 'd8_aegis', 'd10_aegis']).path,
        BuildPath.aegis,
      );
      expect(
        buildIdentity(const ['d4_lucky', 'd8_surge', 'd12_heart']).path,
        BuildPath.heart,
      );
    });

    test('tie break is stable and order independent', () {
      // +1 Blade, +1 Aegis and +1 Ember: Ember wins the deliberate tie.
      final a = buildIdentity(const ['d6_keen', 'd6_stout', 'd6']);
      final b = buildIdentity(const ['d6', 'd6_stout', 'd6_keen']);
      expect(a.path, BuildPath.ember);
      expect(b.path, a.path);
      expect(b.sizeCounts, a.sizeCounts);
      expect(b.specialDice, a.specialDice);
    });

    test('unknown die ids are ignored without corrupting counts', () {
      final id = buildIdentity(const ['future_die', 'd8_blade', 'bad']);
      expect(id.path, BuildPath.blade);
      expect(id.countFor(8), 1);
      expect(id.specialDice, 1);
      expect(id.dominantSize, 8);
      expect(id.dominantTier, 2);
    });
  });
}

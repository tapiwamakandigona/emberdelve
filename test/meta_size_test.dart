// THE SLIM SATCHEL (2026-09-01): the meta save file is read (and json-
// decoded) inside controller.boot(), which the boot path awaits BEFORE
// the first frame (Swifter Lantern Future.wait in main.dart). Probed
// 2026-09-01: a fully maxed veteran save serializes to ~7.6 KB and
// loads in ~2.5 ms — invisible. This gate exists so that stays true:
// if a future field balloons the maxed save past 64 KB, first-frame
// time is now on the table and the change must justify itself.
// Timing probes live in tool/boot_cost_probe_test.dart (run explicitly).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'support/maxed_meta.dart';

void main() {
  test('maxed veteran meta save stays under 64 KB', () {
    final bytes = utf8.encode(jsonEncode(maxedMeta().toJson())).length;
    expect(bytes, lessThan(64 * 1024),
        reason: 'meta save grew past 64 KB — its read+decode sits on the '
            'first-frame critical path (controller.boot before runApp); '
            'investigate what ballooned before raising this gate');
  });
}

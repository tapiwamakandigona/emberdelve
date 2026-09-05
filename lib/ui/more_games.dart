// "More from Tsoro Studios" — one quiet cross-promotion row (owner directive
// 2026-09-05b). Settings only, below the Redeem row. No badge, no modal, no
// telemetry event: the Play install-referrer already measures the tap.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';
import 'widgets.dart';

/// This game's id, used as the utm_source / install referrer on Android.
const kThisGame = 'emberdelve';

/// Fliptide's Play listing is still in closed testing (2026-09-05): send
/// everyone to the itch.io page until it is public.
const kFliptideOnPlay = false;

/// Pyregrove's Play listing is still in review (2026-09-05). Flip to true once
/// it is public; the entry is hidden until then.
const kShowPyregrove = false;

class MoreGame {
  const MoreGame({
    required this.name,
    required this.hook,
    required this.packageId,
    this.webUrl,
    this.preferWeb = false,
  });
  final String name;
  final String hook;
  final String packageId;

  /// Where web builds (and the https fallback) go. Defaults to the Play listing.
  final String? webUrl;

  /// True while the Play listing is not public: skip market:// and use [webUrl].
  final bool preferWeb;

  Uri get playUri =>
      Uri.parse('https://play.google.com/store/apps/details?id=$packageId');
  Uri get marketUri => Uri.parse(
    'market://details?id=$packageId&referrer=utm_source%3D$kThisGame',
  );
  Uri get httpsUri => webUrl != null ? Uri.parse(webUrl!) : playUri;
}

const kFliptide = MoreGame(
  name: 'Fliptide',
  hook: 'One tap flips gravity. Same course for everyone today.',
  packageId: 'com.tsorostudios.fliptide',
  webUrl: 'https://tsorostudios.itch.io/fliptide',
  preferWeb: !kFliptideOnPlay,
);

const kPyregrove = MoreGame(
  name: 'Pyregrove',
  hook: 'Pixel platformer. Two worlds of handcrafted levels, no ads.',
  packageId: 'com.tsorostudios.pyregrove',
);

/// The entries shown in this game, in order.
List<MoreGame> moreGames({bool showPyregrove = kShowPyregrove}) => [
  kFliptide,
  if (showPyregrove) kPyregrove,
];

typedef UriLauncher = Future<bool> Function(Uri uri, {LaunchMode mode});

/// Android: try the Play app (market://) first, then https. Everywhere else,
/// or while the listing is not public: the https URL in an external browser.
Future<bool> openMoreGame(
  MoreGame g, {
  UriLauncher? launcher,
  TargetPlatform? platform,
  bool? isWeb,
}) async {
  final launch = launcher ?? launchUrl;
  final web = isWeb ?? kIsWeb;
  final tp = platform ?? defaultTargetPlatform;
  if (!web && tp == TargetPlatform.android && !g.preferWeb) {
    try {
      if (await launch(g.marketUri, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {
      // No Play app on this device — fall through to https.
    }
  }
  try {
    return await launch(g.httpsUri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// The Settings section: micro header + one row per game inside a [Panel].
class MoreFromTsoro extends StatelessWidget {
  const MoreFromTsoro({super.key, this.games, this.onOpen});
  final List<MoreGame>? games;

  /// Test seam; defaults to [openMoreGame].
  final Future<bool> Function(MoreGame g)? onOpen;

  @override
  Widget build(BuildContext context) {
    final list = games ?? moreGames();
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const Key('more-from-tsoro'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('MORE FROM TSORO STUDIOS', style: EmberText.micro),
        const SizedBox(height: Space.s),
        Panel(
          child: Column(
            children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0)
                  const Divider(color: EmberColors.line, height: Space.xl),
                Row(
                  children: [
                    const Icon(
                      Icons.sports_esports,
                      color: EmberColors.textDim,
                      size: 20,
                    ),
                    const SizedBox(width: Space.m),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: list[i].name,
                              style: EmberText.body.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text: ' — ${list[i].hook}',
                              style: EmberText.body,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.m),
                    EmberButton(
                      list[i].preferWeb ? 'Play' : 'Get',
                      key: ValueKey('more-${list[i].packageId}'),
                      dense: true,
                      onTap: () => (onOpen ?? openMoreGame)(list[i]),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

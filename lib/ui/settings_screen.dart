// lib/ui/settings_screen.dart — audio settings (music/SFX volume + mutes),
// persisted via SettingsStore, applied live to the AudioService. Also the
// route to Credits & Licenses.
import 'package:flutter/material.dart';
import '../game/tour.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../audio/audio_service.dart';
import '../audio/settings.dart';
import '../meta/play_games_service.dart';
import '../meta/reminder_service.dart';
import '../meta/cloud_merge.dart';
import '../meta/meta.dart';
import '../meta/save_transfer.dart';
import '../meta/store_service.dart';
import '../meta/unlock_codes.dart';
import '../meta/update_service.dart';
import '../telemetry/telemetry_service.dart';
import 'credits_screen.dart';
import 'news_screen.dart';
import 'haptics.dart';
import 'motion.dart';
import 'theme.dart';
import 'widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Guided Delve replay: reflect the pending request in the button label.
  bool _tourQueued = TourDirector.replayRequested;
  AudioSettings get _s => AudioService.instance?.settings ?? _fallback;
  static final AudioSettings _fallback = AudioSettings();

  /// "Copy link" feedback for the Watchtower row (resets when leaving).
  bool _linkCopied = false;

  /// Neutral-fact status line for the Carried Ember panel (v0.24.0):
  /// states what just happened, nothing more.
  String? _transferLine;

  /// Neutral-fact status line for the unlock-code row: what happened, only.
  String? _redeemLine;

  /// Neutral-fact status line for the update panel (§Ethics: no pressure,
  /// no loss frame — a newer release is stated like a weather report).
  String _updateLine(UpdateService up) => switch (up.status) {
    UpdateStatus.checking => 'Checking the watchtower…',
    UpdateStatus.newer =>
      'v${up.latest} is out — you have v${up.installedVersion}.',
    UpdateStatus.current => "You're on the latest release.",
    UpdateStatus.error => "Couldn't reach the watchtower. Try again later.",
    UpdateStatus.unknown => 'Compare this build to the newest release.',
  };

  void _changed({bool preview = false, bool persist = true}) {
    AudioService.instance?.applySettings();
    if (persist) SettingsStore.save(_s);
    if (preview) AudioService.instance?.playSfx('ui_tap');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: EmberText.h2),
        backgroundColor: EmberColors.bg,
        leading: BackButton(
          onPressed: () {
            AudioService.instance?.playSfx('ui_back');
            Navigator.of(context).pop();
          },
        ),
      ),
      // Tablet clamp (v0.26.0): content caps at kMaxContentWidth.
      body: ContentClamp(
        child: SafeArea(
          child: ScrollComfort(
            child: ListView(
              padding: const EdgeInsets.all(Space.l),
              children: [
                const Text('AUDIO', style: EmberText.micro),
                const SizedBox(height: Space.s),
                Panel(
                  child: Column(
                    children: [
                      _volumeRow(
                        icon: Icons.music_note,
                        label: 'Music',
                        value: _s.musicVolume,
                        muted: _s.musicMuted,
                        // Live volume preview while dragging; persist once on release.
                        onVolume: (v) {
                          _s.musicVolume = v;
                          _changed(persist: false);
                        },
                        onVolumeEnd: (v) {
                          _s.musicVolume = v;
                          _changed();
                        },
                        onMute: (m) {
                          _s.musicMuted = !m;
                          _changed();
                        },
                      ),
                      const Divider(color: EmberColors.line, height: Space.xl),
                      _volumeRow(
                        icon: Icons.graphic_eq,
                        label: 'Sound effects',
                        value: _s.sfxVolume,
                        muted: _s.sfxMuted,
                        // No SFX per drag tick; single confirm tap + save on release.
                        onVolume: (v) {
                          _s.sfxVolume = v;
                          _changed(persist: false);
                        },
                        onVolumeEnd: (v) {
                          _s.sfxVolume = v;
                          _changed(preview: true);
                        },
                        onMute: (m) {
                          _s.sfxMuted = !m;
                          _changed(preview: true);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.xl),
                // COMFORT (v0.16.0, was FEEDBACK): body-facing settings —
                // vibration and motion. Renamed when reduce-motion joined.
                const Text('COMFORT', style: EmberText.micro),
                const SizedBox(height: Space.s),
                Panel(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.vibration,
                            color: EmberColors.textDim,
                            size: 20,
                          ),
                          const SizedBox(width: Space.m),
                          const Expanded(
                            child: Text('Haptics', style: EmberText.body),
                          ),
                          _EmberToggle(
                            semanticLabel: 'Haptics',
                            value: _s.haptics,
                            onChanged: (v) {
                              _s.haptics = v;
                              _changed(preview: true);
                              // Answer "ON" with a buzz you can feel — instant
                              // on-device confirmation that haptics actually work.
                              if (v) Haptics.preview();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.l),
                      // Reduce motion (v0.16.0 The Still Flame): no screen
                      // shake, no drifting embers, damage numbers hold still.
                      // 'System' follows the OS accessibility setting.
                      const Row(
                        children: [
                          Icon(
                            Icons.waves,
                            color: EmberColors.textDim,
                            size: 20,
                          ),
                          SizedBox(width: Space.m),
                          Expanded(
                            child: Text('Reduce motion', style: EmberText.body),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.s),
                      Container(
                        key: const ValueKey('reduce-motion'),
                        decoration: BoxDecoration(
                          color: EmberColors.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: EmberColors.line),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Row(
                          children: [
                            for (final (id, label) in const [
                              ('system', 'SYSTEM'),
                              ('on', 'REDUCED'),
                              ('off', 'FULL'),
                            ])
                              Expanded(
                                child: GestureDetector(
                                  key: ValueKey('reduce-motion-$id'),
                                  onTap: () {
                                    _s.reduceMotion = id;
                                    Motion.instance.update(setting: id);
                                    _changed(preview: true);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: Space.s,
                                    ),
                                    decoration: BoxDecoration(
                                      color: id == _s.reduceMotion
                                          ? EmberColors.raised
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: id == _s.reduceMotion
                                            ? EmberColors.ember
                                            : Colors.transparent,
                                      ),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        label,
                                        textAlign: TextAlign.center,
                                        style: EmberText.micro.copyWith(
                                          color: id == _s.reduceMotion
                                              ? EmberColors.textPrimary
                                              : EmberColors.textDim,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Space.xs),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Steadies the screen: no shake, no drifting embers.',
                          style: EmberText.micro.copyWith(
                            color: EmberColors.textDim,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.xl),
                const Text('PRIVACY', style: EmberText.micro),
                const SizedBox(height: Space.s),
                Panel(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.insights,
                        color: EmberColors.textDim,
                        size: 20,
                      ),
                      const SizedBox(width: Space.m),
                      const Expanded(
                        child: Text(
                          'Gameplay analytics',
                          style: EmberText.body,
                        ),
                      ),
                      _EmberToggle(
                        semanticLabel: 'Gameplay analytics',
                        value: TelemetryService.instance.analyticsConsented,
                        onChanged: (v) {
                          TelemetryService.instance.logEvent(
                            'settings_changed',
                            {'setting': 'analytics_consent', 'value': '$v'},
                          );
                          TelemetryService.instance.setAnalyticsConsent(v);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
                // Daily Delve reminder (v0.6.0): opt-in, neutral-fact copy, one
                // notification a day at most, quietly stops after a week away.
                // Hidden entirely on builds without the platform backends.
                if (ReminderService.instance.available) ...[
                  const SizedBox(height: Space.xl),
                  const Text('NOTIFICATIONS', style: EmberText.micro),
                  const SizedBox(height: Space.s),
                  AnimatedBuilder(
                    animation: ReminderService.instance.tick,
                    builder: (context, _) {
                      final rem = ReminderService.instance;
                      return Panel(
                        child: Row(
                          children: [
                            Icon(
                              Icons.notifications_none,
                              color: rem.enabled
                                  ? EmberColors.ember
                                  : EmberColors.textDim,
                              size: 20,
                            ),
                            const SizedBox(width: Space.m),
                            const Expanded(
                              child: Text(
                                'Daily Delve reminder',
                                style: EmberText.body,
                              ),
                            ),
                            _EmberToggle(
                              semanticLabel: 'Daily Delve reminder',
                              key: const ValueKey('daily-reminder'),
                              value: rem.enabled,
                              onChanged: (v) async {
                                AudioService.instance?.playSfx('ui_tap');
                                if (v) {
                                  await rem.enable();
                                } else {
                                  await rem.disable();
                                }
                                if (mounted) setState(() {});
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
                // The Watchtower (v0.21.0): update awareness for GitHub-only
                // builds. Manual check + opt-in launch check; §Ethics: neutral
                // facts, never a nag, nothing auto-downloads. Hidden entirely
                // when no fetcher is wired (tests, non-Android).
                if (UpdateService.instance.available) ...[
                  const SizedBox(height: Space.xl),
                  const Text('UPDATES', style: EmberText.micro),
                  const SizedBox(height: Space.s),
                  AnimatedBuilder(
                    animation: UpdateService.instance.tick,
                    builder: (context, _) {
                      final up = UpdateService.instance;
                      final newer = up.status == UpdateStatus.newer;
                      return Column(
                        children: [
                          Panel(
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.new_releases_outlined,
                                      color: newer
                                          ? EmberColors.ember
                                          : EmberColors.textDim,
                                      size: 20,
                                    ),
                                    const SizedBox(width: Space.m),
                                    Expanded(
                                      child: Text(
                                        _updateLine(up),
                                        style: EmberText.body,
                                      ),
                                    ),
                                    EmberButton(
                                      'Check',
                                      key: const ValueKey('update-check-now'),
                                      dense: true,
                                      onTap: up.status == UpdateStatus.checking
                                          ? null
                                          : () async {
                                              await up.check();
                                              if (mounted) setState(() {});
                                            },
                                    ),
                                  ],
                                ),
                                if (newer) ...[
                                  const SizedBox(height: Space.s),
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'New releases live on the GitHub '
                                          'releases page.',
                                          style: EmberText.bodyDim,
                                        ),
                                      ),
                                      EmberButton(
                                        _linkCopied ? 'Copied' : 'Copy link',
                                        key: const ValueKey('update-copy-link'),
                                        dense: true,
                                        onTap: () async {
                                          await Clipboard.setData(
                                            const ClipboardData(
                                              text:
                                                  UpdateService.releasesPageUrl,
                                            ),
                                          );
                                          if (mounted) {
                                            setState(() => _linkCopied = true);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: Space.s),
                          Panel(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.update,
                                  color: up.enabled
                                      ? EmberColors.ember
                                      : EmberColors.textDim,
                                  size: 20,
                                ),
                                const SizedBox(width: Space.m),
                                const Expanded(
                                  child: Text(
                                    'Check once at launch',
                                    style: EmberText.body,
                                  ),
                                ),
                                _EmberToggle(
                                  semanticLabel: 'Check for updates at launch',
                                  key: const ValueKey('update-launch-check'),
                                  value: up.enabled,
                                  onChanged: (v) async {
                                    AudioService.instance?.playSfx('ui_tap');
                                    await up.setEnabled(v);
                                    if (mounted) setState(() {});
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
                // Play Games (v0.5.0, P4+P5): opt-in connect. Hidden entirely on
                // builds without the platform backends (tests, web, desktop).
                if (PlayGamesService.instance.available) ...[
                  const SizedBox(height: Space.xl),
                  const Text('PLAY GAMES', style: EmberText.micro),
                  const SizedBox(height: Space.s),
                  AnimatedBuilder(
                    animation: PlayGamesService.instance.tick,
                    builder: (context, _) {
                      final pgs = PlayGamesService.instance;
                      final on = pgs.connected;
                      return Column(
                        children: [
                          Panel(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.cloud_done,
                                  color: on
                                      ? EmberColors.ember
                                      : EmberColors.textDim,
                                  size: 20,
                                ),
                                const SizedBox(width: Space.m),
                                Expanded(
                                  child: Text(
                                    on
                                        ? 'Connected — progress backed up, '
                                              'Delve leaderboards on.'
                                        : 'Back up progress and join the '
                                              'Delve leaderboards.',
                                    style: EmberText.body,
                                  ),
                                ),
                                EmberButton(
                                  on ? 'Disconnect' : 'Connect',
                                  key: const ValueKey('pgs-connect'),
                                  dense: true,
                                  onTap: () async {
                                    AudioService.instance?.playSfx('ui_tap');
                                    if (on) {
                                      await pgs.disconnect();
                                    } else {
                                      await pgs.connect();
                                    }
                                    if (mounted) setState(() {});
                                  },
                                ),
                              ],
                            ),
                          ),
                          if (on) ...[
                            const SizedBox(height: Space.s),
                            Panel(
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.leaderboard,
                                    color: EmberColors.textDim,
                                    size: 20,
                                  ),
                                  const SizedBox(width: Space.m),
                                  const Expanded(
                                    child: Text(
                                      'Daily & Weekly Delve boards',
                                      style: EmberText.body,
                                    ),
                                  ),
                                  EmberButton(
                                    'View',
                                    key: const ValueKey('pgs-leaderboards'),
                                    dense: true,
                                    onTap: () {
                                      AudioService.instance?.playSfx('ui_tap');
                                      pgs.showLeaderboards();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
                const SizedBox(height: Space.xl),
                // The Carried Ember (v0.24.0): sideloaded installs have no
                // guaranteed cloud save — the whole ledger travels as one
                // pasteable code instead. Import merges (never replaces); the
                // Forge purchase deliberately does not ride in the code.
                const Text('CARRY YOUR EMBER', style: EmberText.micro),
                const SizedBox(height: Space.s),
                Panel(
                  key: const ValueKey('carry-ember-panel'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.outbox,
                            color: EmberColors.textDim,
                            size: 20,
                          ),
                          const SizedBox(width: Space.m),
                          const Expanded(
                            child: Text(
                              'Copy a save code that holds your progress.',
                              style: EmberText.body,
                            ),
                          ),
                          EmberButton(
                            'Copy',
                            key: const ValueKey('copy-save-code'),
                            dense: true,
                            onTap: _copySaveCode,
                          ),
                        ],
                      ),
                      const Divider(color: EmberColors.line, height: Space.xl),
                      Row(
                        children: [
                          const Icon(
                            Icons.move_to_inbox,
                            color: EmberColors.textDim,
                            size: 20,
                          ),
                          const SizedBox(width: Space.m),
                          const Expanded(
                            child: Text(
                              'Paste a code from another device to merge '
                              'it here.',
                              style: EmberText.body,
                            ),
                          ),
                          EmberButton(
                            'Paste',
                            key: const ValueKey('paste-save-code'),
                            dense: true,
                            onTap: _pasteSaveCode,
                          ),
                        ],
                      ),
                      const Divider(color: EmberColors.line, height: Space.xl),
                      // v0.8.0 Guided Delve: replay the anchored tour anytime.
                      Row(
                        children: [
                          const Icon(
                            Icons.tour,
                            color: EmberColors.textDim,
                            size: 20,
                          ),
                          const SizedBox(width: Space.m),
                          const Expanded(
                            child: Text(
                              'Replay the guided tour in your next fight.',
                              style: EmberText.body,
                            ),
                          ),
                          EmberButton(
                            _tourQueued ? 'Queued' : 'Replay',
                            key: const ValueKey('replay-tour'),
                            dense: true,
                            onTap: _tourQueued
                                ? null
                                : () => setState(
                                    () => _tourQueued =
                                        TourDirector.replayRequested = true,
                                  ),
                          ),
                        ],
                      ),
                      const Divider(color: EmberColors.line, height: Space.xl),
                      // Offline unlock codes (UNLOCK-CODES-SPEC): a signed code
                      // lights the Forge on builds without Play billing. Reads
                      // the clipboard like the save-code row — one gesture, no
                      // typing a 100-char code on a phone keyboard.
                      Row(
                        children: [
                          const Icon(
                            Icons.vpn_key,
                            color: EmberColors.textDim,
                            size: 20,
                          ),
                          const SizedBox(width: Space.m),
                          const Expanded(
                            child: Text(
                              'Have an unlock code? Copy it, then redeem '
                              'it here.',
                              style: EmberText.body,
                            ),
                          ),
                          EmberButton(
                            'Redeem',
                            key: const ValueKey('redeem-unlock-code'),
                            dense: true,
                            onTap: _redeemUnlockCode,
                          ),
                        ],
                      ),
                      if (_redeemLine != null) ...[
                        const SizedBox(height: Space.m),
                        Text(
                          _redeemLine!,
                          key: const ValueKey('redeem-line'),
                          style: EmberText.micro.copyWith(
                            color: EmberColors.textDim,
                          ),
                        ),
                      ],
                      if (_transferLine != null) ...[
                        const SizedBox(height: Space.m),
                        Text(
                          _transferLine!,
                          key: const ValueKey('transfer-line'),
                          style: EmberText.micro.copyWith(
                            color: EmberColors.textDim,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: Space.s),
                Text(
                  'The Ember Forge purchase moves with your Play account, '
                  'not with the code.',
                  style: EmberText.micro.copyWith(color: EmberColors.textDim),
                ),
                const SizedBox(height: Space.xl),
                // Ember Forge (v0.4.0, spec R8): the restore path lives here too —
                // a player on a new device must never have to hunt for it.
                const Text('THE EMBER FORGE', style: EmberText.micro),
                const SizedBox(height: Space.s),
                if (StoreService.instance != null)
                  AnimatedBuilder(
                    animation: StoreService.instance!.tick,
                    builder: (context, _) {
                      final store = StoreService.instance!;
                      final owned = store.state == ForgeStoreState.owned;
                      return Panel(
                        child: Row(
                          children: [
                            Icon(
                              Icons.local_fire_department,
                              color: owned
                                  ? EmberColors.ember
                                  : EmberColors.textDim,
                              size: 20,
                            ),
                            const SizedBox(width: Space.m),
                            Expanded(
                              child: Text(
                                owned
                                    ? 'The Forge is open on this profile.'
                                    : 'Bought the Forge before? Bring it here.',
                                style: EmberText.body,
                              ),
                            ),
                            if (!owned)
                              EmberButton(
                                'Restore',
                                key: const ValueKey('settings-restore'),
                                dense: true,
                                onTap: () {
                                  AudioService.instance?.playSfx('ui_tap');
                                  store.restore();
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  )
                else
                  const Panel(
                    child: Text(
                      'Purchases are unavailable in this build.',
                      style: EmberText.bodyDim,
                    ),
                  ),
                const SizedBox(height: Space.xl),
                const Text('ABOUT', style: EmberText.micro),
                const SizedBox(height: Space.s),
                Panel(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.menu_book,
                        color: EmberColors.textDim,
                        size: 20,
                      ),
                      const SizedBox(width: Space.m),
                      const Expanded(
                        child: Text(
                          'Credits & Licenses',
                          style: EmberText.body,
                        ),
                      ),
                      EmberButton(
                        'View',
                        onTap: () {
                          AudioService.instance?.playSfx('ui_tap');
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CreditsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.s),
                // Past posts (v0.15.0): the Hearthside Post archive — every
                // release note, re-readable forever. No unread state (§Ethics).
                Panel(
                  key: const ValueKey('past-posts-tile'),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.history_edu,
                        color: EmberColors.textDim,
                        size: 20,
                      ),
                      const SizedBox(width: Space.m),
                      const Expanded(
                        child: Text('Past posts', style: EmberText.body),
                      ),
                      EmberButton(
                        'Read',
                        onTap: () {
                          AudioService.instance?.playSfx('ui_tap');
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const NewsArchiveScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copySaveCode() async {
    AudioService.instance?.playSfx('ui_tap');
    final load = SaveTransfer.loadLocalHook;
    if (load == null) return;
    final code = encodeSaveCode(await load());
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      setState(
        () =>
            _transferLine = 'Save code copied — paste it on your other device.',
      );
    }
  }

  Future<void> _pasteSaveCode() async {
    AudioService.instance?.playSfx('ui_tap');
    final load = SaveTransfer.loadLocalHook;
    final adopt = SaveTransfer.adoptMergedHook;
    if (load == null || adopt == null) return;
    final clip = await Clipboard.getData('text/plain');
    final decoded = decodeSaveCode(clip?.text ?? '');
    if (!mounted) return;
    if (decoded == null) {
      // Neutral fact, no blame — garbage on the clipboard is normal.
      setState(
        () => _transferLine = 'The clipboard does not hold a save code.',
      );
      return;
    }
    final merge = await _confirmCarry(decoded);
    if (merge != true) return;
    final merged = mergeMetaStates(await load(), decoded);
    await adopt(merged);
    if (mounted) {
      setState(() => _transferLine = 'Ember carried — progress merged.');
    }
  }

  Future<void> _redeemUnlockCode() async {
    AudioService.instance?.playSfx('ui_tap');
    final redeem = UnlockRedeem.redeemHook;
    if (redeem == null) return;
    final clip = await Clipboard.getData('text/plain');
    final result = await redeem(clip?.text ?? '');
    if (!mounted) return;
    setState(
      () => _redeemLine = switch (result) {
        // Neutral facts, no blame (§Ethics) — same voice as the save-code row.
        UnlockRedeemResult.invalid =>
          'The clipboard does not hold a valid unlock code.',
        UnlockRedeemResult.blocked =>
          'That code is the published example — it cannot unlock.',
        UnlockRedeemResult.alreadyOwned =>
          'The Ember Forge is already lit on this profile.',
        UnlockRedeemResult.granted => 'The Ember Forge is lit. Enjoy.',
      },
    );
  }

  /// States what the code holds and what merging does, then asks. Facts
  /// only (§Ethics): merging keeps the best of both sides.
  Future<bool?> _confirmCarry(MetaState decoded) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Panel(
          padding: const EdgeInsets.all(Space.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('CARRY THE EMBER', style: EmberText.h2),
              const SizedBox(height: Space.m),
              Text(
                'This code holds ${saveCodeSummary(decoded)}.',
                key: const ValueKey('carry-summary'),
                textAlign: TextAlign.center,
                style: EmberText.body,
              ),
              const SizedBox(height: Space.s),
              Text(
                'Merging keeps the best of both — nothing on this '
                'device is lost.',
                textAlign: TextAlign.center,
                style: EmberText.micro.copyWith(color: EmberColors.textDim),
              ),
              const SizedBox(height: Space.l),
              SizedBox(
                width: double.infinity,
                child: EmberButton(
                  'Merge progress',
                  key: const ValueKey('carry-merge'),
                  primary: true,
                  icon: Icons.merge,
                  onTap: () => Navigator.of(ctx).pop(true),
                ),
              ),
              const SizedBox(height: Space.m),
              SizedBox(
                width: double.infinity,
                child: EmberButton(
                  'Keep as is',
                  ghost: true,
                  onTap: () => Navigator.of(ctx).pop(false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _volumeRow({
    required IconData icon,
    required String label,
    required double value,
    required bool muted,
    required ValueChanged<double> onVolume,
    required ValueChanged<double> onVolumeEnd,
    required ValueChanged<bool> onMute,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: EmberColors.textDim),
            const SizedBox(width: Space.m),
            Expanded(child: Text(label, style: EmberText.body)),
            _EmberToggle(
              semanticLabel: label,
              value: !muted,
              onChanged: onMute,
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 8,
            activeTrackColor: EmberColors.ember,
            inactiveTrackColor: const Color(0xFF171021),
            thumbShape: const _EmberThumb(),
            overlayShape: SliderComponentShape.noOverlay,
            trackShape: const RoundedRectSliderTrackShape(),
          ),
          child: Slider(
            value: value,
            onChanged: muted ? null : onVolume,
            onChangeEnd: muted ? null : onVolumeEnd,
          ),
        ),
      ],
    );
  }
}

/// Skinned slider thumb: a glowing ember bead with a charcoal rim (no stock
/// Material thumb/overlay).
class _EmberThumb extends SliderComponentShape {
  const _EmberThumb();
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(22, 22);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final enabled = enableAnimation.value > 0.5;
    if (enabled) {
      canvas.drawCircle(
        center,
        10,
        Paint()
          ..color = EmberColors.ember.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFD98A),
            enabled ? EmberColors.ember : EmberColors.textDisabled,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: 8)),
    );
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF17110A),
    );
  }
}

/// Drawn on/off toggle: an ember coal that lights when on (replaces the stock
/// Material Switch).
class _EmberToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  /// What TalkBack speaks for this coal. The drawn toggle has no text of its
  /// own, so without this a screen reader announces a bare "double tap to
  /// activate" (caught by test/semantics_probe_test.dart, v0.19.0).
  final String semanticLabel;
  const _EmberToggle({
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      toggled: value,
      container: true,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 46,
          height: 26,
          padding: const EdgeInsets.all(3),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: const Color(0xFF171021),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: value ? EmberColors.ember : EmberColors.line,
              width: 1.4,
            ),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  value ? const Color(0xFFFFD98A) : EmberColors.textDisabled,
                  value ? EmberColors.ember : const Color(0xFF3A3148),
                ],
              ),
              boxShadow: value
                  ? [
                      BoxShadow(
                        color: EmberColors.ember.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

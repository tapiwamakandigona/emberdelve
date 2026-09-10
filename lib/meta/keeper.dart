// Local, optional supporter recognition. Never part of MetaState: that model
// travels via cloud saves and shareable save codes. This file is not in the
// Android backup/transfer include lists either. No analytics or network.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

class KeeperProfile {
  const KeeperProfile({
    this.invitationSeen = false,
    this.name = '',
    this.showName = false,
    this.showCrest = false,
  });

  final bool invitationSeen;
  final String name;
  final bool showName;
  final bool showCrest;

  static const maxNameLength = 24;

  static String sanitizeName(String raw) => raw
      .replaceAll(
        RegExp(r'[\x00-\x1f\x7f-\x9f\u202a-\u202e\u2066-\u2069]'),
        ' ',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .characters
      .take(maxNameLength)
      .toString()
      .trim();

  factory KeeperProfile.fromJson(Map<String, dynamic> json) => KeeperProfile(
    invitationSeen: json['invitationSeen'] == true,
    name: sanitizeName(json['name'] is String ? json['name'] as String : ''),
    showName: json['showName'] == true,
    showCrest: json['showCrest'] == true,
  );

  Map<String, Object> toJson() => {
    'invitationSeen': invitationSeen,
    'name': name,
    'showName': showName,
    'showCrest': showCrest,
  };
}

class KeeperService extends ChangeNotifier {
  KeeperService({
    required this.alreadyOwned,
    this.entitlementChanges,
    Future<Map<String, dynamic>> Function()? loadData,
    Future<void> Function(Map<String, Object>)? saveData,
  }) : _loadData = loadData ?? _readLocal,
       _saveData = saveData ?? _writeLocal {
    entitlementChanges?.addListener(_entitlementChanged);
  }

  /// Wired in main, after the real profile is loaded; null in older harnesses.
  static KeeperService? instance;
  static const fileName = 'emberdelve_keeper.json';
  final bool Function() alreadyOwned;
  final Listenable? entitlementChanges;
  final Future<Map<String, dynamic>> Function() _loadData;
  final Future<void> Function(Map<String, Object>) _saveData;

  KeeperProfile _profile = const KeeperProfile();
  KeeperProfile get profile => _profile;
  bool get entitled => alreadyOwned();
  bool get needsInvitation => loaded && entitled && !_profile.invitationSeen;
  bool loaded = false;
  bool _disposed = false;
  Future<void>? _loadFuture;
  Future<void> _writes = Future.value();

  void _entitlementChanged() {
    if (!_disposed) notifyListeners();
  }

  /// Called after the first frame, never awaited by app startup.
  Future<void> load() => _loadFuture ??= _load();

  Future<void> _load() async {
    try {
      _profile = KeeperProfile.fromJson(await _loadData());
    } catch (_) {
      // Missing/corrupt local decoration cannot revoke an actual purchase.
      _profile = const KeeperProfile();
    }
    loaded = true;
    _entitlementChanged();
  }

  /// Stamp before showing an invitation again; failures never log names.
  /// In-memory state remains useful if the device temporarily cannot save.
  Future<bool> markInvited() => _set(
    KeeperProfile(
      invitationSeen: true,
      name: _profile.name,
      showName: _profile.showName,
      showCrest: _profile.showCrest,
    ),
  );

  Future<bool> personalise({
    required String name,
    required bool showName,
    required bool showCrest,
  }) {
    if (!entitled || !loaded) return Future.value(false);
    final clean = KeeperProfile.sanitizeName(name);
    return _set(
      KeeperProfile(
        invitationSeen: true,
        name: clean,
        showName: showName && clean.isNotEmpty,
        showCrest: showCrest,
      ),
    );
  }

  Future<bool> skip() =>
      personalise(name: '', showName: false, showCrest: false);

  Future<bool> removeName() =>
      personalise(name: '', showName: false, showCrest: _profile.showCrest);

  Future<bool> _set(KeeperProfile value) {
    if (!loaded || !entitled) return Future.value(false);
    _profile = value;
    _entitlementChanged();
    final snapshot = value.toJson();
    var saved = true;
    final write = _writes.then((_) async {
      try {
        await _saveData(snapshot);
      } catch (_) {
        saved = false;
      }
    });
    _writes = write;
    return write.then((_) => saved);
  }

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$fileName');
  }

  static Future<Map<String, dynamic>> _readLocal() async {
    final file = await _file();
    if (!await file.exists() || await file.length() > 4096) return {};
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  static Future<void> _writeLocal(Map<String, Object> data) async {
    final file = await _file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(data), flush: true);
    await temp.rename(file.path);
  }

  @override
  void dispose() {
    _disposed = true;
    entitlementChanges?.removeListener(_entitlementChanged);
    super.dispose();
  }
}

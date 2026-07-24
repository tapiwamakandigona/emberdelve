// lib/telemetry/feedback_share.dart — "Send feedback" glue: the `feedback`
// package captures an annotated screenshot + note in-app, then the system
// share sheet (share_plus) sends it wherever the tester likes (email,
// Discord, ...). No backend, no extra data collection — nothing leaves the
// device except through the tester's own share action.
import 'dart:io';
import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the feedback overlay; on submit, writes the screenshot to a temp
/// file and hands screenshot + text to the share sheet.
void showFeedbackAndShare(BuildContext context) {
  BetterFeedback.of(context).show((UserFeedback feedback) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/emberdelve_feedback_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(feedback.screenshot);
      await SharePlus.instance.share(ShareParams(
        text: 'Emberdelve beta feedback:\n${feedback.text}',
        subject: 'Emberdelve beta feedback',
        files: [XFile(file.path, mimeType: 'image/png')],
      ));
    } catch (_) {
      // Best-effort: a failed share must never crash the game.
    }
  });
}

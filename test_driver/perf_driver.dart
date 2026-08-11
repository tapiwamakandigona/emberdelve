// test_driver/perf_driver.dart — host-side driver for the frame trace.
// Summarizes every timeline the integration test reports into
// build/frame_trace/<scenario>.timeline_summary.json (frame build/raster
// averages, 90th/99th percentiles, worst frame, missed-frame counts).
import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() {
  return integrationDriver(
    responseDataCallback: (Map<String, dynamic>? data) async {
      if (data == null) {
        // ignore: avoid_print
        print('FRAME_TRACE: no report data — did traceAction run?');
        return;
      }
      for (final entry in data.entries) {
        if (entry.value is! Map<String, dynamic>) continue;
        final timeline = driver.Timeline.fromJson(
          entry.value as Map<String, dynamic>,
        );
        final summary = driver.TimelineSummary.summarize(timeline);
        await summary.writeTimelineToFile(
          entry.key,
          pretty: true,
          includeSummary: true,
          destinationDirectory: 'build/frame_trace',
        );
        // ignore: avoid_print
        print('FRAME_TRACE: wrote build/frame_trace/${entry.key}.*');
      }
    },
  );
}

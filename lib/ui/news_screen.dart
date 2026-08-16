// lib/ui/news_screen.dart — "Past posts": the Hearthside Post archive
// (v0.15.0). Every release note ever shipped, newest first, re-readable
// forever. Deliberately stateless — no unread markers, no badges (§Ethics);
// the archive is a bookshelf, not an inbox. Content: lib/data/news.dart.
import 'package:flutter/material.dart';
import '../audio/audio_service.dart';
import '../data/news.dart';
import 'theme.dart';
import 'widgets.dart';

class NewsArchiveScreen extends StatelessWidget {
  const NewsArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Past posts', style: EmberText.h2),
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
          child: ListView.separated(
            padding: const EdgeInsets.all(Space.l),
            itemCount: newsEntries.length,
            separatorBuilder: (_, _) => const SizedBox(height: Space.m),
            itemBuilder: (context, i) {
              final e = newsEntries[i];
              return Panel(
                key: ValueKey('news-archive-${e.version}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('v${e.version}', style: EmberText.micro),
                    const SizedBox(height: Space.xs),
                    Text(e.title, style: EmberText.body),
                    const SizedBox(height: Space.s),
                    for (final line in e.lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.xs),
                        child: Text(line, style: EmberText.bodyDim),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

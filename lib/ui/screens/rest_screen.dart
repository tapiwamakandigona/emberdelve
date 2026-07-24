// lib/ui/screens/rest_screen.dart — part of screens.dart (see library header there).
part of '../screens.dart';

class RestScreen extends StatelessWidget {
  final GameController c;
  const RestScreen(this.c, {super.key});
  @override
  Widget build(BuildContext context) {
    final player = c.state!['player'] as Map;
    final dice0 = (player['dice'] as List).cast<String>();
    final forgeable = <int>[];
    for (var i = 0; i < dice0.length; i++) {
      if (dieDef(dice0[i]).forgeTo.isNotEmpty) forgeable.add(i);
    }
    // v0.3.1 F9: never offer a heal that heals nothing.
    final fullHp = (player['hp'] as int) >= (player['max_hp'] as int);
    return Stack(fit: StackFit.expand, children: [
      const EmberDrift(count: 16, opacity: 0.6),
      Column(children: [
      _TopBar(c),
      const SizedBox(height: Space.xl),
      Text('A warm hollow', style: EmberText.h1),
      const SizedBox(height: Space.xs),
      Text('Rest to heal, or forge a die into something stronger. One only.',
          style: EmberText.bodyDim, textAlign: TextAlign.center),
      const Spacer(),
      Padding(
        padding: const EdgeInsets.all(Space.l),
        child: SizedBox(
          width: double.infinity,
          child: EmberButton(
              // At full HP this is the ONLY exit when nothing is forgeable —
              // a disabled button here soft-locked the run (found in play
              // session 2026-07-24). The sim's `rest` command is safe at full
              // HP: it heals 0 and moves to the map.
              fullHp ? 'Move on — fully rested' : 'Rest — heal 30%',
              primary: !fullHp,
              icon: fullHp
                  ? Icons.arrow_forward
                  : Icons.local_fire_department,
              onTap: () => c.apply({'type': 'rest'})),
        ),
      ),
      if (forgeable.isNotEmpty)
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: Space.l),
            children: [
              Text('FORGE', style: EmberText.micro),
              const SizedBox(height: Space.s),
              for (final i in forgeable)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.s),
                  child: _forgeRow(dice0[i], i + 1),
                ),
            ],
          ),
        )
      else
        const Spacer(),
      ]),
    ]);
  }

  Widget _forgeRow(String id, int index) {
    final def = dieDef(id);
    final into = def.forgeTo.first;
    // Compact chips + dense button: the full-size row overflowed 320dp
    // phones by ~9px (many-dice layout sweep 2026-07-24).
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _chip(id),
          const Icon(Icons.arrow_forward, size: 16, color: EmberColors.ember),
          _chip(into),
          const Spacer(),
          EmberButton('Forge',
              dense: true,
              onTap: () =>
                  c.apply({'type': 'forge', 'die': index, 'into': into})),
        ]),
        const SizedBox(height: Space.xs),
        // Full-width caption line: squeezed beside the button it wrapped
        // mid-word on 320dp phones.
        Text('${def.name} → ${dieDef(into).name}',
            maxLines: 1, overflow: TextOverflow.ellipsis, style: EmberText.label),
      ]),
    );
  }

  Widget _chip(String id) => SizedBox(
        width: 48,
        height: 60,
        child: FittedBox(fit: BoxFit.contain, child: DieChip(id)),
      );
}

// ---------------------------------------------------------------------------
// Shop
// ---------------------------------------------------------------------------

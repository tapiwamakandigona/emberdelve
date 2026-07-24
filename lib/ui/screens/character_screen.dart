// lib/ui/screens/character_screen.dart — part of screens.dart (see library header there).
part of '../screens.dart';

class CharacterScreen extends StatefulWidget {
  final GameController c;
  const CharacterScreen(this.c, {super.key});
  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  int ascension = 0;
  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final m = c.meta;
    final maxAsc = m.bestAscension.clamp(0, 20);
    return Scaffold(
      appBar: AppBar(
          title: Text('Choose a delver', style: EmberText.h2),
          backgroundColor: EmberColors.bg,
          leading: BackButton(onPressed: () {
            AudioService.instance?.playSfx('ui_back');
            Navigator.of(context).pop();
          })),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(Space.l), children: [
          _nextUnlockBar(m),
          const SizedBox(height: Space.l),
          for (final id in charactersOrder) _charCard(context, id),
          const SizedBox(height: Space.l),
          Text('ASCENSION', style: EmberText.micro),
          const SizedBox(height: Space.s),
          Text('Higher rungs make every enemy hit harder. Unlock the next by '
              'winning at the current one.', style: EmberText.bodyDim),
          const SizedBox(height: Space.s),
          Row(children: [
            IconButton(
                onPressed: ascension > 0
                    ? () => setState(() => ascension--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline)),
            Text('$ascension', style: EmberText.value),
            IconButton(
                onPressed: ascension < maxAsc
                    ? () => setState(() => ascension++)
                    : null,
                icon: const Icon(Icons.add_circle_outline)),
            const SizedBox(width: Space.s),
            Text('max unlocked: $maxAsc', style: EmberText.bodyDim),
          ]),
        ]),
      ),
    );
  }

  Widget _nextUnlockBar(m) {
    final target = m.nextUnlockTarget;
    if (target == null) {
      return Panel(child: Text('All delvers unlocked.', style: EmberText.body));
    }
    final frac = (m.embers / target.unlockEmbers).clamp(0.0, 1.0);
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('NEXT UNLOCK — ${target.name.toUpperCase()}',
            style: EmberText.micro),
        const SizedBox(height: Space.s),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(children: [
            Container(height: 12, color: EmberColors.raised),
            FractionallySizedBox(
                widthFactor: frac,
                child: Container(height: 12, color: EmberColors.ember)),
          ]),
        ),
        const SizedBox(height: Space.s),
        Text('${m.embers} / ${target.unlockEmbers} embers',
            style: EmberText.bodyDim),
      ]),
    );
  }

  Widget _charCard(BuildContext context, String id) {
    final c = widget.c;
    final def = characters[id]!;
    final unlocked = c.meta.isUnlocked(id);
    final canAfford = c.meta.embers >= def.unlockEmbers;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.m),
      child: Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            // Static portrait frame from the character sheet (idle frame 0);
            // animation stays reserved for the combat stage.
            Opacity(
              opacity: unlocked ? 1 : 0.45,
              child: SpriteView(id, height: 56, animate: false),
            ),
            const SizedBox(width: Space.m),
            Expanded(child: Text(def.name, style: EmberText.h2)),
            if (!unlocked)
              Row(children: [
                const Icon(Icons.lock, size: 14, color: EmberColors.textDim),
                const SizedBox(width: 4),
                Text('${def.unlockEmbers}', style: EmberText.label),
              ]),
          ]),
          const SizedBox(height: Space.xs),
          Text(def.text, style: EmberText.bodyDim),
          const SizedBox(height: Space.s),
          Text('${def.maxHp} HP · ${def.startDice.map((d) => dieDef(d).name).join(", ")}',
              style: EmberText.micro),
          const SizedBox(height: Space.m),
          SizedBox(
            width: double.infinity,
            child: unlocked
                ? EmberButton('Delve as ${def.name}',
                    primary: id == defaultCharacter,
                    onTap: () {
                      Navigator.of(context).pop();
                      c.startRun(
                          character: id, ascension: ascension, boons: true);
                    })
                : EmberButton(
                    canAfford ? 'Unlock (${def.unlockEmbers} embers)' : 'Locked',
                    onTap: canAfford
                        ? () {
                            c.unlock(id);
                            setState(() {});
                          }
                        : null),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Map
// ---------------------------------------------------------------------------

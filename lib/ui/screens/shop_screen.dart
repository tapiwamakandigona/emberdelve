// lib/ui/screens/shop_screen.dart — part of screens.dart (see library header there).
part of '../screens.dart';

class ShopScreen extends StatelessWidget {
  final GameController c;
  const ShopScreen(this.c, {super.key});
  @override
  Widget build(BuildContext context) {
    // After leave_shop the PhaseSwitcher cross-fade keeps this screen mounted
    // briefly while state['shop'] is already null — render nothing then.
    final shop = c.state?['shop'] as Map?;
    if (shop == null) return const SizedBox.shrink();
    final slots = (shop['slots'] as List).cast<Map>();
    final gold = (c.state!['run'] as Map)['gold'] as int;
    return Column(children: [
      _TopBar(c),
      const SizedBox(height: Space.l),
      Text('The Ashmonger', style: EmberText.h1),
      const SizedBox(height: Space.xs),
      Text('Spend your gold before the descent.', style: EmberText.bodyDim),
      const SizedBox(height: Space.l),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: Space.l),
          children: [
            for (var i = 0; i < slots.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.m),
                child: _slot(slots[i], i + 1, gold),
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(Space.l),
        child: SizedBox(
          width: double.infinity,
          child: EmberButton('Leave shop',
              primary: true, onTap: () => c.apply({'type': 'leave_shop'})),
        ),
      ),
    ]);
  }

  Widget _slot(Map slot, int index, int gold) {
    final kind = slot['kind'] as String;
    final id = slot['id'] as String;
    final price = slot['price'] as int;
    final sold = slot['sold'] == true;
    final afford = gold >= price;
    String title, desc;
    Widget lead;
    if (kind == 'die') {
      title = dieDef(id).name;
      desc = _dieDesc(dieDef(id));
      lead = DieChip(id);
    } else if (kind == 'relic') {
      title = relicDef(id).name;
      desc = relicDef(id).text;
      lead = Image.asset(Art.relicIcon(id),
          width: 44, height: 44, filterQuality: FilterQuality.medium);
    } else {
      title = 'Field Rations';
      desc = 'Heal ${slot['amount']} HP';
      lead = const Icon(Icons.healing, color: EmberColors.success, size: 40);
    }
    return Opacity(
      opacity: sold ? 0.4 : 1,
      child: Panel(
        child: Row(children: [
          SizedBox(width: 64, child: Center(child: lead)),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: EmberText.h2),
              const SizedBox(height: Space.xs),
              Text(desc, style: EmberText.bodyDim),
            ]),
          ),
          const SizedBox(width: Space.s),
          sold
              ? Text('SOLD', style: EmberText.micro)
              : EmberButton('$price',
                  icon: Icons.circle,
                  onTap: afford
                      ? () => c.apply({'type': 'buy', 'slot': index})
                      : null),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Event
// ---------------------------------------------------------------------------

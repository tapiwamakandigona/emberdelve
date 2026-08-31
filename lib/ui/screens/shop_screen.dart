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
    return Column(
      children: [
        _TopBar(c),
        // Tablet clamp (v0.26.0): content column caps at kMaxContentWidth.
        Expanded(
          child: ContentClamp(
            child: Column(
              children: [
                const SizedBox(height: Space.l),
                const Text('The Ashmonger', style: EmberText.h1),
                const SizedBox(height: Space.xs),
                const Text(
                  'Spend your gold before the descent.',
                  style: EmberText.bodyDim,
                ),
                const SizedBox(height: Space.l),
                Expanded(
                  child: ScrollComfort(
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
                ),
                Padding(
                  padding: const EdgeInsets.all(Space.l),
                  child: SizedBox(
                    width: double.infinity,
                    child: EmberButton(
                      'Leave shop',
                      primary: true,
                      onTap: () => c.apply({'type': 'leave_shop'}),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
      desc = dieFacts(dieDef(id));
      lead = DieChip(id, skin: c.activeRunSkin);
    } else if (kind == 'relic') {
      title = relicDef(id).name;
      desc = relicDef(id).text;
      lead = Image.asset(
        Art.relicIcon(id),
        width: 44,
        height: 44,
        filterQuality: FilterQuality.medium,
      );
    } else {
      title = 'Field Rations';
      // v0.90.0 The Counted Ration: unsold rations print the real heal —
      // the sim's own overheal cap — not the nominal amount. SOLD rows keep
      // the historic label; a bought ration must not relabel itself from
      // the player's new HP. NBSPs bind the paren group (v0.89 lesson).
      final amount = slot['amount'] as int;
      final live = !sold && c.sim != null;
      final heal = live ? healPreview(c.sim!, amount) : amount;
      if (!live) {
        desc = 'Heal $amount HP';
      } else if (heal == 0) {
        desc = 'Fully rested — heals nothing';
      } else {
        final hp = c.sim!.player['hp'] as int;
        desc = 'Heal $heal HP ($hp\u00A0to\u00A0${hp + heal})';
      }
      lead = const Icon(Icons.healing, color: EmberColors.success, size: 40);
    }
    // v0.91.0 The Legible Stall: the old single-row layout squeezed title
    // and description into ~40% of the panel — titles broke mid-word at
    // 320px ('FIELD RATION / S') and relic texts wrapped every two words.
    // Now the top row carries lead · title · price and the description
    // spans the full panel width below. FittedBox keeps a title one line,
    // scaling down instead of ever breaking a name (StatBar precedent).
    return Opacity(
      opacity: sold ? 0.4 : 1,
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(width: 64, child: Center(child: lead)),
                const SizedBox(width: Space.m),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(title, style: EmberText.h2),
                  ),
                ),
                const SizedBox(width: Space.s),
                sold
                    ? const Text('SOLD', style: EmberText.micro)
                    : EmberButton(
                        '$price',
                        // A coin, not an abstract dot (wordiness 2026-07-24).
                        icon: Icons.paid,
                        // v0.122.0 The Spoken Delve: the drawn button is a
                        // bare number beside a legible panel — name the
                        // deed, the price, and a shortfall for TalkBack.
                        semanticLabel: afford
                            ? 'Buy $title for $price gold'
                            : '$title, $price gold, not enough gold',
                        onTap: afford
                            ? () => c.apply({'type': 'buy', 'slot': index})
                            : null,
                      ),
              ],
            ),
            const SizedBox(height: Space.s),
            Text(desc, style: EmberText.bodyDim),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Event
// ---------------------------------------------------------------------------

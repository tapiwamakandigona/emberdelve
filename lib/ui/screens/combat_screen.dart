// Combat screen: enemy panel (intent always visible), player panel, dice
// assignment flow, and the reward overlay (phase 'reward' renders here so a
// resumed reward save lands on a sensible screen — m1-contract §9).
//
// Interaction: Roll -> tap a die chip -> Attack / Block (gated by the die's
// attack_only/block_only mods) -> End Turn. All state comes from
// session.state + session.lastEvents; the sim validates everything.
import 'package:flutter/material.dart';

import '../../data/dice.dart';
import '../../services/session.dart';
import '../theme.dart';
import '../widgets/common.dart';

class CombatScreen extends StatefulWidget {
  const CombatScreen({super.key, required this.session});

  final GameSession session;

  @override
  State<CombatScreen> createState() => _CombatScreenState();
}

class _CombatScreenState extends State<CombatScreen> {
  int? _selectedDie; // 1-based index into player.rolled

  GameSession get session => widget.session;

  Future<void> _assign(String action) async {
    final die = _selectedDie;
    if (die == null) return;
    setState(() => _selectedDie = null);
    await session.apply({'type': 'assign', 'die': die, 'action': action});
  }

  @override
  Widget build(BuildContext context) {
    final st = session.state;
    final player = st['player'] as Map<String, dynamic>;
    final enemy = st['enemy'] as Map<String, dynamic>?;
    final run = (st['run'] as Map?) ?? const {};
    final isReward = session.phase == 'reward';
    final isBoss = enemy?['boss'] == true;

    return Scaffold(
      body: SafeArea(
        child: Stack(children: [
          Column(children: [
            RunHeader(player: player, run: run),
            if (isBoss) const _BossBanner(),
            const SizedBox(height: 6),
            if (enemy != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _EnemyPanel(enemy: enemy, isBoss: isBoss),
              ),
            const Spacer(),
            _EventLog(events: session.lastEvents),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _PlayerPanel(
                player: player,
                selectedDie: _selectedDie,
                onSelectDie: (i) => setState(
                    () => _selectedDie = _selectedDie == i ? null : i),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: _ActionBar(
                player: player,
                selectedDie: _selectedDie,
                onRoll: () => session.apply({'type': 'roll'}),
                onAssign: _assign,
                onEndTurn: () {
                  setState(() => _selectedDie = null);
                  session.apply({'type': 'end_turn'});
                },
              ),
            ),
          ]),
          if (isReward)
            RewardOverlay(
              offers: ((st['offers'] as List?) ?? const []).cast<String>(),
              onChoose: (index) =>
                  session.apply({'type': 'choose_reward', 'index': index}),
            ),
        ]),
      ),
    );
  }
}

class _BossBanner extends StatelessWidget {
  const _BossBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: EmberRadius.chip,
        gradient: LinearGradient(colors: [
          Ember.bossPurple.withValues(alpha: 0.0),
          Ember.bossPurple.withValues(alpha: 0.35),
          Ember.bossPurple.withValues(alpha: 0.0),
        ]),
      ),
      child: const Text(
        '⚠ BOSS ⚠',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Ember.bossPurple,
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
        ),
      ),
    );
  }
}

class _EnemyPanel extends StatelessWidget {
  const _EnemyPanel({required this.enemy, required this.isBoss});

  final Map<String, dynamic> enemy;
  final bool isBoss;

  @override
  Widget build(BuildContext context) {
    final hp = enemy['hp'] as int;
    final maxHp = enemy['max_hp'] as int? ?? hp;
    final block = enemy['block'] as int? ?? 0;
    final intent = enemy['intent'] as Map?;
    final accent = isBoss
        ? Ember.bossPurple
        : enemy['elite'] == true
            ? Ember.eliteGold
            : Ember.danger;

    return EmberPanel(
      borderColor: accent.withValues(alpha: 0.6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              '${enemy['name'] ?? enemy['id']}',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium!
                  .copyWith(fontSize: 18),
            ),
          ),
          if (block > 0)
            StatBadge(
              icon: Icons.shield_rounded,
              value: '$block',
              color: Ember.block,
            ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: StatBar(value: hp, max: maxHp, color: accent, height: 10)),
          const SizedBox(width: 8),
          Text('$hp/$maxHp',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Ember.textDim)),
        ]),
        if (intent != null) ...[
          const SizedBox(height: 10),
          _IntentRow(intent: intent),
        ],
      ]),
    );
  }
}

/// Enemy intent — always visible before the player commits (design pillar).
class _IntentRow extends StatelessWidget {
  const _IntentRow({required this.intent});

  final Map intent;

  @override
  Widget build(BuildContext context) {
    final kind = intent['kind'] as String;
    final amount = intent['amount'];
    final blockAmt = intent['block'];
    final parts = <Widget>[
      const Text('INTENT:',
          style: TextStyle(
              color: Ember.textDim,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5)),
      const SizedBox(width: 8),
    ];
    if (kind == 'attack' || kind == 'attack_block') {
      parts.add(StatBadge(
          icon: Icons.flash_on_rounded,
          value: '$amount',
          color: Ember.danger));
    }
    if (kind == 'block') {
      parts.add(StatBadge(
          icon: Icons.shield_rounded, value: '$amount', color: Ember.block));
    }
    if (kind == 'attack_block' && blockAmt != null) {
      parts.add(const SizedBox(width: 6));
      parts.add(StatBadge(
          icon: Icons.shield_rounded, value: '$blockAmt', color: Ember.block));
    }
    return Row(children: parts);
  }
}

class _PlayerPanel extends StatelessWidget {
  const _PlayerPanel({
    required this.player,
    required this.selectedDie,
    required this.onSelectDie,
  });

  final Map<String, dynamic> player;
  final int? selectedDie;
  final ValueChanged<int> onSelectDie;

  @override
  Widget build(BuildContext context) {
    final rolled = (player['rolled'] as List?)?.cast<int>();
    final dice = (player['dice'] as List).cast<String>();
    final assigned = (player['assigned'] as Map?) ?? const {};
    final block = player['block'] as int? ?? 0;

    return EmberPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('YOUR DICE',
              style: TextStyle(
                  color: Ember.textDim,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5)),
          const Spacer(),
          StatBadge(
              icon: Icons.shield_rounded, value: '$block', color: Ember.block),
        ]),
        const SizedBox(height: 10),
        if (rolled == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('Roll to begin your turn.',
                style: TextStyle(color: Ember.textDim)),
          )
        else
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Wrap(
              key: ValueKey(rolled.join(',')),
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 1; i <= rolled.length; i++)
                  DieChip(
                    index: i,
                    dieId: dice[i - 1],
                    value: rolled[i - 1],
                    assignedAction: assigned[i] as String?,
                    selected: selectedDie == i,
                    onTap: assigned.containsKey(i)
                        ? null
                        : () => onSelectDie(i),
                  ),
              ],
            ),
          ),
      ]),
    );
  }
}

/// One rolled die: face value, die name, assignment state.
class DieChip extends StatelessWidget {
  const DieChip({
    super.key,
    required this.index,
    required this.dieId,
    required this.value,
    required this.assignedAction,
    required this.selected,
    this.onTap,
  });

  final int index;
  final String dieId;
  final int value;
  final String? assignedAction;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final def = diceData[dieId];
    final name = def?['name'] as String? ?? dieId;
    final spent = assignedAction != null;
    final accent = assignedAction == 'attack'
        ? Ember.danger
        : assignedAction == 'block'
            ? Ember.block
            : Ember.primary;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: spent ? 0.45 : 1,
      child: Material(
        color: selected ? Ember.glow : Ember.surfaceHigh,
        borderRadius: EmberRadius.chip,
        child: InkWell(
          borderRadius: EmberRadius.chip,
          onTap: onTap,
          child: Container(
            width: 68,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: EmberRadius.chip,
              border: Border.all(
                color: selected ? Ember.primary : accent.withValues(alpha: 0.5),
                width: selected ? 2.5 : 1.5,
              ),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$value',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: spent ? Ember.textDim : Ember.text)),
              const SizedBox(height: 2),
              Text(name.split(' ').first,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 10, color: Ember.textDim)),
              if (spent)
                Icon(
                  assignedAction == 'attack'
                      ? Icons.flash_on_rounded
                      : Icons.shield_rounded,
                  size: 14,
                  color: accent,
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Roll / Attack / Block / End Turn. Attack/Block appear once a die is
/// selected and are gated by that die's attack_only/block_only mods.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.player,
    required this.selectedDie,
    required this.onRoll,
    required this.onAssign,
    required this.onEndTurn,
  });

  final Map<String, dynamic> player;
  final int? selectedDie;
  final VoidCallback onRoll;
  final void Function(String action) onAssign;
  final VoidCallback onEndTurn;

  @override
  Widget build(BuildContext context) {
    final rolled = player['rolled'];
    if (rolled == null) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onRoll,
          icon: const Icon(Icons.casino_rounded),
          label: const Text('ROLL'),
        ),
      );
    }

    Map<String, dynamic> mods = const {};
    if (selectedDie != null) {
      final dice = (player['dice'] as List).cast<String>();
      mods = (diceData[dice[selectedDie! - 1]]?['mods']
              as Map<String, dynamic>?) ??
          const {};
    }
    final canAttack = selectedDie != null && mods['block_only'] != true;
    final canBlock = selectedDie != null && mods['attack_only'] != true;

    return Row(children: [
      Expanded(
        child: FilledButton.icon(
          onPressed: canAttack ? () => onAssign('attack') : null,
          icon: const Icon(Icons.flash_on_rounded, size: 20),
          label: const Text('ATTACK'),
          style: FilledButton.styleFrom(
            backgroundColor: Ember.danger,
            disabledBackgroundColor: Ember.surfaceHigh,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: FilledButton.icon(
          onPressed: canBlock ? () => onAssign('block') : null,
          icon: const Icon(Icons.shield_rounded, size: 20),
          label: const Text('BLOCK'),
          style: FilledButton.styleFrom(
            backgroundColor: Ember.block,
            disabledBackgroundColor: Ember.surfaceHigh,
          ),
        ),
      ),
      const SizedBox(width: 10),
      OutlinedButton(
        onPressed: onEndTurn,
        child: const Text('END'),
      ),
    ]);
  }
}

/// Compact scrolling log of the latest sim events.
class _EventLog extends StatelessWidget {
  const _EventLog({required this.events});

  final List<Map<String, dynamic>> events;

  @override
  Widget build(BuildContext context) {
    final lines = events
        .map(describeEvent)
        .whereType<String>()
        .toList()
        .reversed
        .take(3)
        .toList();
    if (lines.isEmpty) return const SizedBox(height: 44);
    return SizedBox(
      height: 56,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (var i = lines.length - 1; i >= 0; i--)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: i == 0 ? 1 : 0.55,
              child: Text(lines[i],
                  style: const TextStyle(fontSize: 12, color: Ember.textDim)),
            ),
        ],
      ),
    );
  }
}

/// Reward pick — shown over the combat screen after a won fight/elite.
class RewardOverlay extends StatelessWidget {
  const RewardOverlay({
    super.key,
    required this.offers,
    required this.onChoose,
  });

  final List<String> offers;
  final void Function(int index) onChoose; // 1-based; 0 = skip

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Ember.bg.withValues(alpha: 0.88),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: EmberPanel(
        borderColor: Ember.primary.withValues(alpha: 0.6),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.auto_awesome_rounded,
              color: Ember.eliteGold, size: 32),
          const SizedBox(height: 8),
          Text('CLAIM A DIE',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium!
                  .copyWith(fontSize: 20, letterSpacing: 2)),
          const SizedBox(height: 16),
          for (var i = 1; i <= offers.length; i++) ...[
            _RewardCard(dieId: offers[i - 1], onTap: () => onChoose(i)),
            const SizedBox(height: 10),
          ],
          TextButton(
            onPressed: () => onChoose(0),
            child: const Text('SKIP',
                style: TextStyle(
                    color: Ember.textDim, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.dieId, required this.onTap});

  final String dieId;
  final VoidCallback onTap;

  static String _describeMods(Map<String, dynamic> mods) {
    final parts = <String>[];
    mods.forEach((k, v) {
      parts.add(switch (k) {
        'attack_bonus' => '+$v attack',
        'block_bonus' => '+$v block',
        'min_value' => 'min roll $v',
        'on_max_bonus' => '+$v on max roll',
        'attack_only' => 'attack only',
        'block_only' => 'block only',
        _ => '$k $v',
      });
    });
    return parts.isEmpty ? 'No modifiers' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final def = diceData[dieId] ?? const {};
    final mods = (def['mods'] as Map<String, dynamic>?) ?? const {};
    return Material(
      color: Ember.surfaceHigh,
      borderRadius: EmberRadius.chip,
      child: InkWell(
        borderRadius: EmberRadius.chip,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: EmberRadius.chip,
            border:
                Border.all(color: Ember.primary.withValues(alpha: 0.45)),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Ember.glow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('d${def['size'] ?? '?'}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, color: Ember.primary)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${def['name'] ?? dieId}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(_describeMods(mods),
                      style: const TextStyle(
                          fontSize: 12, color: Ember.textDim)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Ember.textDim),
          ]),
        ),
      ),
    );
  }
}

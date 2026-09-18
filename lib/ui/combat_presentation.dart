// A short-lived presentation ledger, never simulation state or save data.
//
// The sim resolves synchronously at the tap. Its event payloads then advance
// these copied display fields at the contact/burn/riposte beats. Keeping the
// event's absolute HP also handles lethal hits after sim.enemy becomes null.
class CombatPresentation {
  final Map<String, Object?> _player;
  final Map<String, Object?> enemy;
  final int turn;

  CombatPresentation({
    required Map player,
    required Map enemy,
    required this.turn,
  }) : _player = {
         'hp': player['hp'],
         'max_hp': player['max_hp'],
         'block': player['block'],
       },
       enemy = {
         ...Map<String, Object?>.from(enemy),
         if (enemy['intent'] is Map)
           'intent': Map<String, Object?>.from(enemy['intent'] as Map),
       };

  // Dice and input data stay live. Only displayed vitals are deferred.
  Map playerView(Map live) => {...live, ..._player};

  void apply(Map<String, Object?> event) {
    final type = event['type'];
    switch (type) {
      case 'damage_dealt':
        enemy['hp'] = event['enemy_hp'];
        enemy['block'] = _remaining(enemy['block'], event['blocked']);
      case 'enemy_attacked':
      case 'counter_struck':
        _player['hp'] = event['player_hp'];
        _player['block'] = _remaining(_player['block'], event['blocked']);
        if (type == 'enemy_attacked') {
          // Previous-turn enemy block expires as its action lands;
          // attack+block supplies its new amount on the same event.
          enemy['block'] = event['block'] ?? 0;
        }
      case 'enemy_blocked':
        enemy['block'] = event['enemy_block'];
      case 'thorns_dealt':
        enemy['hp'] = event['enemy_hp'];
      case 'burn_tick':
        enemy['hp'] = event['enemy_hp'];
        enemy['burn'] = event['stacks_left'];
      case 'player_healed':
        _player['hp'] = event['hp'];
      case 'charge_broken':
        enemy['intent'] = <String, Object?>{'kind': 'stagger', 'amount': 0};
    }
  }

  static int _remaining(Object? before, Object? spent) =>
      ((before as int? ?? 0) - (spent as int? ?? 0)).clamp(0, 1 << 30);
}

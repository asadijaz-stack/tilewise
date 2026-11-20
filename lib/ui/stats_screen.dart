/// Stats page: totals, vs-computer breakdown and full game history.
library;

import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/stats_store.dart';
import 'widgets.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<GameRecord>? _records;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await StatsStore.load();
    if (!mounted) return;
    setState(() => _records = records);
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E4D2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear all stats?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This deletes the history of every game you have played. '
          'It cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                const Text('Clear', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await StatsStore.clear();
      if (mounted) setState(() => _records = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F3D1F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Your Stats',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    final records = _records;
    if (records == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.amber),
      );
    }
    if (records.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart,
                  size: 84, color: Colors.white.withValues(alpha: 0.35)),
              const SizedBox(height: 18),
              const Text(
                'No finished games yet',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Finish a game and your results, best words and '
                'win history will appear here.',
                style: TextStyle(color: Colors.white60, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    final s = summarize(records);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      children: [
        // Summary cards.
        Row(
          children: [
            _statCard(Icons.sports_esports, 'Games played', '${s.totalGames}',
                Colors.lightBlue),
            const SizedBox(width: 12),
            _statCard(
              Icons.emoji_events,
              'Wins vs Computer',
              s.vsComputerGames == 0
                  ? '—'
                  : '${s.humanWinsVsComputer} of ${s.vsComputerGames} '
                      '(${(s.winRateVsComputer * 100).round()}%)',
              Colors.amber,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _statCard(Icons.star, 'Highest score', '${s.highestScore}',
                Colors.orange),
            const SizedBox(width: 12),
            _statCard(
              Icons.abc,
              'Best word',
              s.bestWord == null
                  ? '—'
                  : '${s.bestWord} · ${s.bestWordScore} pts',
              Colors.greenAccent,
            ),
          ],
        ),
        if (s.byDifficulty.isNotEmpty) ...[
          const SizedBox(height: 22),
          _sectionTitle('Vs Computer — by difficulty'),
          for (final d in Difficulty.values)
            if (s.byDifficulty.containsKey(d))
              _difficultyRow(d, s.byDifficulty[d]!),
        ],
        if (s.passPlayGames > 0) ...[
          const SizedBox(height: 14),
          _infoRow(Icons.group, 'Pass & Play games: ${s.passPlayGames}'),
        ],
        const SizedBox(height: 22),
        _sectionTitle('Game history'),
        for (var i = 0; i < records.length; i++)
          StaggeredIn(index: i.clamp(0, 6), child: _historyCard(records[i])),
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            onPressed: _confirmClear,
            icon: const Icon(Icons.delete_outline,
                color: Colors.white38, size: 18),
            label: const Text('Clear all stats',
                style: TextStyle(color: Colors.white38)),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF1E4D2B),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 6),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 9),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _difficultyRow(Difficulty d, (int, int) playedWon) {
    final (played, won) = playedWon;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            d == Difficulty.easy
                ? Icons.sentiment_satisfied
                : d == Difficulty.medium
                    ? Icons.psychology
                    : Icons.bolt,
            color: Colors.white70,
            size: 21,
          ),
          const SizedBox(width: 11),
          Text(
            d.label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const Spacer(),
          Text(
            'Won $won of $played',
            style: const TextStyle(color: Colors.white70, fontSize: 13.5),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 21),
          const SizedBox(width: 11),
          Text(
            text,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _historyCard(GameRecord r) {
    final scores = r.players.map((p) => '${p.name} ${p.score}').join('  ·  ');
    // Best human word of this game, if any.
    PlayerResult? best;
    for (final p in r.players) {
      if (p.isAI || p.bestWord == null) continue;
      if (best == null || p.bestWordScore > best.bestWordScore) best = p;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E4D2B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: r.vsComputer
                      ? Colors.blueGrey.shade700
                      : Colors.brown.shade700,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      r.vsComputer ? Icons.smart_toy : Icons.group,
                      color: Colors.white,
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      r.vsComputer
                          ? 'vs Computer · ${r.difficulty?.label ?? ''}'
                          : 'Pass & Play',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(r.date),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            '🏆 ${r.winner.name} won',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            scores,
            style: const TextStyle(color: Colors.white70, fontSize: 13.5),
          ),
          if (best != null) ...[
            const SizedBox(height: 3),
            Text(
              'Best word: ${best.bestWord} (+${best.bestWordScore}) '
              'by ${best.name}',
              style: const TextStyle(color: Colors.amber, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatDate(DateTime d) {
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${_months[d.month - 1]} ${d.year} · $hour12:$mm $ampm';
  }
}

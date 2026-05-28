import 'dart:math';

class LudoEngine {
  static const List<int> safeZones = [0, 8, 13, 21, 26, 34, 39, 47];
  
  static const Map<String, int> startCells = {
    'Red': 0,
    'Green': 13,
    'Yellow': 26,
    'Blue': 39
  };

  static int? getGeneralTrackIndex(String color, int stepCount) {
    if (stepCount < 1 || stepCount > 51) return null;
    final startCell = startCells[color]!;
    return (startCell + stepCount - 1) % 52;
  }

  static List<Map<String, dynamic>> getPossibleMoves(List<int> pawns, int rollValue) {
    final List<Map<String, dynamic>> moves = [];

    for (int i = 0; i < 4; i++) {
      final step = pawns[i];
      if (step == 0) {
        if (rollValue == 6) {
          moves.add({'pawnId': i, 'type': 'unlock', 'from': 0, 'to': 1});
        }
      } else if (step > 0 && step < 57) {
        final next = step + rollValue;
        if (next <= 57) {
          moves.add({
            'pawnId': i,
            'type': next == 57 ? 'goal' : 'move',
            'from': step,
            'to': next
          });
        }
      }
    }
    return moves;
  }

  /// AI Bot move selection (Mirrors backend logic)
  static int selectBotMove(Map<String, List<int>> allPawns, String botColor, List<Map<String, dynamic>> possibleMoves, String difficulty) {
    if (possibleMoves.isEmpty) return -1;
    if (possibleMoves.length == 1) return possibleMoves[0]['pawnId'];

    if (difficulty == 'easy') {
      return possibleMoves[Random().nextInt(possibleMoves.length)]['pawnId'];
    }

    // Medium priority: Goal, Unlock, Furthest
    if (difficulty == 'medium') {
      final goal = possibleMoves.firstWhere((m) => m['type'] == 'goal', orElse: () => <String, dynamic>{});
      if (goal.isNotEmpty) return goal['pawnId'];

      final unlock = possibleMoves.firstWhere((m) => m['type'] == 'unlock', orElse: () => <String, dynamic>{});
      if (unlock.isNotEmpty) return unlock['pawnId'];

      // Furthest pawn
      possibleMoves.sort((a, b) => b['from'].compareTo(a['from']));
      return possibleMoves[0]['pawnId'];
    }

    // Hard heuristic priority
    if (difficulty == 'hard') {
      final goal = possibleMoves.firstWhere((m) => m['type'] == 'goal', orElse: () => <String, dynamic>{});
      if (goal.isNotEmpty) return goal['pawnId'];

      // Score moves
      final List<Map<String, dynamic>> scoredMoves = possibleMoves.map((move) {
        double score = 0;
        final targetStep = move['to'] as int;
        final currentStep = move['from'] as int;
        
        final targetTrack = getGeneralTrackIndex(botColor, targetStep);
        final currentTrack = getGeneralTrackIndex(botColor, currentStep);

        // A. Is it a kill?
        bool isKill = false;
        if (targetTrack != null && !safeZones.contains(targetTrack)) {
          allPawns.forEach((oppColor, oppPawns) {
            if (oppColor == botColor) return;
            for (final oppStep in oppPawns) {
              if (getGeneralTrackIndex(oppColor, oppStep) == targetTrack) {
                isKill = true;
              }
            }
          });
        }
        if (isKill) score += 1000;

        // B. Evade threat
        if (currentTrack != null && !safeZones.contains(currentTrack)) {
          bool underThreat = false;
          allPawns.forEach((oppColor, oppPawns) {
            if (oppColor == botColor) return;
            for (final oppStep in oppPawns) {
              final oppTrack = getGeneralTrackIndex(oppColor, oppStep);
              if (oppTrack != null) {
                final dist = (currentTrack - oppTrack + 52) % 52;
                if (dist > 0 && dist <= 6) underThreat = true;
              }
            }
          });
          if (underThreat) score += 300;
        }

        // C. Safe landing
        if (targetTrack != null && safeZones.contains(targetTrack)) {
          score += 150;
        }

        // D. Unlock move
        if (move['type'] == 'unlock') {
          score += 200;
        }

        // E. Rush furthest
        score += currentStep * 2;

        return {'pawnId': move['pawnId'], 'score': score};
      }).toList();

      scoredMoves.sort((a, b) => b['score'].compareTo(a['score']));
      return scoredMoves[0]['pawnId'];
    }

    return possibleMoves[0]['pawnId'];
  }
}

class BoardCell {
  final int x;
  final int y;
  const BoardCell(this.x, this.y);
}

class LudoCoordinates {
  // Yard positions (Home bases)
  static const Map<String, List<BoardCell>> yardCoordinates = {
    'Red': [
      BoardCell(2, 2),
      BoardCell(3, 2),
      BoardCell(2, 3),
      BoardCell(3, 3),
    ],
    'Green': [
      BoardCell(11, 2),
      BoardCell(12, 2),
      BoardCell(11, 3),
      BoardCell(12, 3),
    ],
    'Yellow': [
      BoardCell(11, 11),
      BoardCell(12, 11),
      BoardCell(11, 12),
      BoardCell(12, 12),
    ],
    'Blue': [
      BoardCell(2, 11),
      BoardCell(3, 11),
      BoardCell(2, 12),
      BoardCell(3, 12),
    ],
  };

  // Safe zones (on the general board perimeter)
  // Maps track step index to safety
  static const List<BoardCell> safeZoneCells = [
    BoardCell(1, 6),   // Red starting point
    BoardCell(8, 2),   // Green starting point
    BoardCell(13, 8),  // Yellow starting point
    BoardCell(6, 12),  // Blue starting point
    BoardCell(8, 6),   // Star
    BoardCell(8, 8),   // Star
    BoardCell(6, 6),   // Star
    BoardCell(6, 8),   // Star
  ];

  // The 52 general track cell sequence starting at Red start cell (1, 6)
  static const List<BoardCell> generalTrack = [
    BoardCell(1, 6), BoardCell(2, 6), BoardCell(3, 6), BoardCell(4, 6), BoardCell(5, 6), // Left to right
    BoardCell(6, 5), BoardCell(6, 4), BoardCell(6, 3), BoardCell(6, 2), BoardCell(6, 1), BoardCell(6, 0), // Bottom to top
    BoardCell(7, 0), // Top junction
    BoardCell(8, 0), BoardCell(8, 1), BoardCell(8, 2), BoardCell(8, 3), BoardCell(8, 4), BoardCell(8, 5), // Top to bottom
    BoardCell(9, 6), BoardCell(10, 6), BoardCell(11, 6), BoardCell(12, 6), BoardCell(13, 6), BoardCell(14, 6), // Left to right
    BoardCell(14, 7), // Right junction
    BoardCell(14, 8), BoardCell(13, 8), BoardCell(12, 8), BoardCell(11, 8), BoardCell(10, 8), BoardCell(9, 8), // Right to left
    BoardCell(8, 9), BoardCell(8, 10), BoardCell(8, 11), BoardCell(8, 12), BoardCell(8, 13), BoardCell(8, 14), // Top to bottom
    BoardCell(7, 14), // Bottom junction
    BoardCell(6, 14), BoardCell(6, 13), BoardCell(6, 12), BoardCell(6, 11), BoardCell(6, 10), BoardCell(6, 9), // Bottom to top
    BoardCell(5, 8), BoardCell(4, 8), BoardCell(3, 8), BoardCell(2, 8), BoardCell(1, 8), BoardCell(0, 8), // Right to left
    BoardCell(0, 7), // Left junction
    BoardCell(0, 6), // Top-left cell
  ];

  // Generates complete 58-step path for a given color
  static List<BoardCell> getPathForColor(String color) {
    final List<BoardCell> path = [];
    
    // Step 0: Represented by Yard (handled separately)
    path.add(const BoardCell(-1, -1));

    // Get offset index on the general track loop for the starting point
    int startIndex = 0;
    if (color == 'Red') startIndex = 0;
    else if (color == 'Green') startIndex = 13;
    else if (color == 'Yellow') startIndex = 26;
    else if (color == 'Blue') startIndex = 39;

    // Steps 1 to 51: general track traversal
    for (int i = 0; i < 51; i++) {
      final cellIdx = (startIndex + i) % 52;
      path.add(generalTrack[cellIdx]);
    }

    // Steps 52 to 56: Home stretch path
    for (int i = 1; i <= 5; i++) {
      if (color == 'Red') {
        path.add(BoardCell(i, 7));
      } else if (color == 'Green') {
        path.add(BoardCell(7, i));
      } else if (color == 'Yellow') {
        path.add(BoardCell(14 - i, 7));
      } else if (color == 'Blue') {
        path.add(BoardCell(7, 14 - i));
      }
    }

    // Step 57: Goal (Center cell 7, 7)
    path.add(const BoardCell(7, 7));

    return path;
  }
}

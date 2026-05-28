import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/ludo_coordinates.dart';

class LudoBoard extends StatelessWidget {
  final Map<String, List<int>> pawns;
  final String activeColor;
  final List<int> highlightPawnIds;
  final Function(String color, int pawnId)? onPawnTap;

  const LudoBoard({
    super.key,
    required this.pawns,
    required this.activeColor,
    required this.highlightPawnIds,
    this.onPawnTap,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double cellSize = constraints.maxWidth / 15;
          
          return Stack(
            children: [
              // 1. Static Board background cells
              _buildStaticBoard(cellSize),

              // 2. Safe zone indicators (stars)
              ..._buildSafeZoneStars(cellSize),

              // 3. Pawns layer (Dynamic & Overlay Stacked)
              ..._buildPawns(cellSize),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStaticBoard(double cellSize) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 15,
      ),
      itemCount: 225,
      itemBuilder: (context, index) {
        final x = index % 15;
        final y = index ~/ 15;

        // Check if inside Yard (cages)
        if (x < 6 && y < 6) return _buildYardCell(AppColors.ludoRed);
        if (x >= 9 && y < 6) return _buildYardCell(AppColors.ludoGreen);
        if (x >= 9 && y >= 9) return _buildYardCell(AppColors.ludoYellow);
        if (x < 6 && y >= 9) return _buildYardCell(AppColors.ludoBlue);

        // Check if inside Goal (center)
        if (x >= 6 && x <= 8 && y >= 6 && y <= 8) {
          return _buildGoalCell(x, y);
        }

        // Check if inside Home Stretch path
        if (y == 7 && x >= 1 && x <= 5) return _buildPathCell(AppColors.ludoRed);
        if (x == 7 && y >= 1 && y <= 5) return _buildPathCell(AppColors.ludoGreen);
        if (y == 7 && x >= 9 && x <= 13) return _buildPathCell(AppColors.ludoYellow);
        if (x == 7 && y >= 9 && y <= 13) return _buildPathCell(AppColors.ludoBlue);

        // Starting points
        if (x == 1 && y == 6) return _buildPathCell(AppColors.ludoRed, isStartingPoint: true);
        if (x == 8 && y == 2) return _buildPathCell(AppColors.ludoGreen, isStartingPoint: true);
        if (x == 13 && y == 8) return _buildPathCell(AppColors.ludoYellow, isStartingPoint: true);
        if (x == 6 && y == 12) return _buildPathCell(AppColors.ludoBlue, isStartingPoint: true);

        // Normal path cells
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            border: Border.all(color: const Color(0xFF334155), width: 0.5),
          ),
        );
      },
    );
  }

  Widget _buildYardCell(Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.95),
        border: Border.all(color: Colors.black45, width: 1.5),
      ),
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildPathCell(Color color, {bool isStartingPoint = false}) {
    return Container(
      decoration: BoxDecoration(
        color: isStartingPoint ? color : color.withOpacity(0.2),
        border: Border.all(color: const Color(0xFF334155), width: 0.5),
      ),
    );
  }

  Widget _buildGoalCell(int x, int y) {
    // We can color triangles pointing to the center (7, 7)
    Color cellColor = AppColors.surface;
    if (x < 7 && y == 7) cellColor = AppColors.ludoRed;
    if (x == 7 && y < 7) cellColor = AppColors.ludoGreen;
    if (x > 7 && y == 7) cellColor = AppColors.ludoYellow;
    if (x == 7 && y > 7) cellColor = AppColors.ludoBlue;

    return Container(
      decoration: BoxDecoration(
        color: cellColor,
        border: Border.all(color: Colors.black26, width: 0.5),
      ),
    );
  }

  List<Widget> _buildSafeZoneStars(double cellSize) {
    return LudoCoordinates.safeZoneCells.map((cell) {
      return Positioned(
        left: cell.x * cellSize,
        top: cell.y * cellSize,
        width: cellSize,
        height: cellSize,
        child: const Center(
          child: Icon(Icons.star, color: AppColors.gold, size: 16),
        ),
      );
    }).toList();
  }

  List<Widget> _buildPawns(double cellSize) {
    final List<Widget> widgets = [];
    
    // Group pawns by their visual coordinate (x, y)
    final Map<String, List<Map<String, dynamic>>> groups = {};

    pawns.forEach((color, steps) {
      final path = LudoCoordinates.getPathForColor(color);
      for (int i = 0; i < 4; i++) {
        final step = steps[i];
        
        // Skip goal pawns from showing on board (or center them)
        if (step == 57) continue;

        BoardCell cell;
        if (step == 0) {
          cell = LudoCoordinates.yardCoordinates[color]![i];
        } else {
          cell = path[step];
        }

        final key = '${cell.x}_${cell.y}';
        groups.putIfAbsent(key, () => []);
        groups[key]!.add({
          'color': color,
          'pawnId': i,
          'highlight': (color == activeColor && highlightPawnIds.contains(i)),
        });
      }
    });

    // Render grouped pawns with adjustments
    groups.forEach((key, list) {
      final parts = key.split('_');
      final x = int.parse(parts[0]);
      final y = int.parse(parts[1]);

      final count = list.length;
      final double subSize = count == 1 ? cellSize * 0.75 : cellSize * 0.5;

      for (int index = 0; index < count; index++) {
        final item = list[index];
        final String color = item['color'];
        final int pawnId = item['pawnId'];
        final bool highlight = item['highlight'];

        // Calculate offsets if multiple pawns share cell
        double dx = 0;
        double dy = 0;
        if (count > 1) {
          final double offsetVal = cellSize * 0.22;
          if (count == 2) {
            dx = index == 0 ? -offsetVal : offsetVal;
          } else if (count == 3) {
            if (index == 0) { dy = -offsetVal; }
            else if (index == 1) { dx = -offsetVal; dy = offsetVal; }
            else { dx = offsetVal; dy = offsetVal; }
          } else {
            dx = (index == 0 || index == 2) ? -offsetVal : offsetVal;
            dy = (index == 0 || index == 1) ? -offsetVal : offsetVal;
          }
        }

        widgets.add(
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: (x * cellSize) + (cellSize - subSize) / 2 + dx,
            top: (y * cellSize) + (cellSize - subSize) / 2 + dy,
            width: subSize,
            height: subSize,
            child: GestureDetector(
              onTap: () => onPawnTap?.call(color, pawnId),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color == 'Red'
                      ? AppColors.ludoRed
                      : color == 'Green'
                          ? AppColors.ludoGreen
                          : color == 'Yellow'
                              ? AppColors.ludoYellow
                              : AppColors.ludoBlue,
                  border: Border.all(
                    color: highlight ? Colors.white : Colors.black87,
                    width: highlight ? 2.5 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: highlight ? 8 : 4,
                      offset: const Offset(0, 2),
                    ),
                    if (highlight)
                      BoxShadow(
                        color: Colors.white.withOpacity(0.8),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${pawnId + 1}',
                    style: TextStyle(
                      fontSize: count == 1 ? 12 : 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    });

    return widgets;
  }
}

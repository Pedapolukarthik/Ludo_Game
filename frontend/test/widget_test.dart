import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_frontend/features/game/domain/ludo_coordinates.dart';

void main() {
  test('Ludo coordinates path generation test', () {
    final path = LudoCoordinates.getPathForColor('Red');
    
    // Step list must contain 58 elements (0 to 57)
    expect(path.length, 58);
    
    // Step 0 is yard (-1, -1)
    expect(path[0].x, -1);
    expect(path[0].y, -1);
    
    // Step 57 is Goal (7, 7)
    expect(path[57].x, 7);
    expect(path[57].y, 7);
  });
}

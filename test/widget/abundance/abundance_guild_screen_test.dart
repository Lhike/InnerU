import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_guild_screen.dart';
import 'package:selfcare_projects/src/features/authentication/screen/leaderboard/leaderboard_screen.dart';

void main() {
  test('Guild delegates to InnerU leaderboard with its A12 scoring mode', () {
    const screen = AbundanceGuildScreen();
    expect(screen.buildLeaderboard(), isA<Leaderboard>());
  });
}

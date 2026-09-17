import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_mission_presentation.dart';
import 'package:selfcare_projects/src/features/authentication/screen/todo_list.dart';

void main() {
  test('mission tags expose the same label and icon used across A12', () {
    expect(TaskTag.none.abundanceMissionLabel, 'Meditation');
    expect(TaskTag.none.abundanceMissionIcon, Icons.self_improvement);
    expect(TaskTag.personal.abundanceMissionLabel, 'Exercise / movements');
    expect(TaskTag.personal.abundanceMissionIcon, Icons.directions_run);
    expect(TaskTag.professional.abundanceMissionLabel, 'Learning');
    expect(TaskTag.professional.abundanceMissionIcon, Icons.menu_book_outlined);
    expect(TaskTag.contribution.abundanceMissionLabel, 'Coaching call');
    expect(TaskTag.contribution.abundanceMissionIcon,
        Icons.phone_in_talk_outlined);
  });
}

import 'package:flutter/material.dart';

import 'package:selfcare_projects/src/features/authentication/screen/todo_list.dart'
    as todo;

/// The four mission choices in Abundance are backed by the existing task tag
/// enum. Keeping their label and icon together prevents the selector and Home
/// tile from drifting apart when a task title is custom text.
extension AbundanceMissionTagPresentation on todo.TaskTag {
  String get abundanceMissionLabel {
    switch (this) {
      case todo.TaskTag.none:
        return 'Meditation';
      case todo.TaskTag.personal:
        return 'Exercise / movements';
      case todo.TaskTag.professional:
        return 'Learning';
      case todo.TaskTag.contribution:
        return 'Coaching call';
    }
  }

  IconData get abundanceMissionIcon {
    switch (this) {
      case todo.TaskTag.none:
        return Icons.self_improvement;
      case todo.TaskTag.personal:
        return Icons.directions_run;
      case todo.TaskTag.professional:
        return Icons.menu_book_outlined;
      case todo.TaskTag.contribution:
        return Icons.phone_in_talk_outlined;
    }
  }
}

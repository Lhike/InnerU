import 'package:flutter/material.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_assets.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_card.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_status_view.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_header_profile_button.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_api_transport.dart';
import 'package:selfcare_projects/src/features/abundance/services/goals_service.dart';
import 'package:selfcare_projects/src/services/coach_api_service.dart';

class AbundanceCoachStudentFileScreen extends StatefulWidget {
  const AbundanceCoachStudentFileScreen(
      {super.key,
      required this.student,
      this.loader,
      this.goalsService,
      this.onTabSelected});
  final Map<String, dynamic> student;
  final Future<List<Map<String, dynamic>>> Function(String studentId)? loader;
  final GoalsService? goalsService;
  final ValueChanged<int>? onTabSelected;
  @override
  State<AbundanceCoachStudentFileScreen> createState() =>
      _AbundanceCoachStudentFileScreenState();
}

class _AbundanceCoachStudentFileScreenState
    extends State<AbundanceCoachStudentFileScreen> {
  late Future<Map<String, dynamic>> _future;
  late DateTime _calendarMonth;
  String? _selectedMissionDate;
  bool _savingNote = false;
  bool _savingAction = false;
  final _note = TextEditingController(),
      _action = TextEditingController(),
      _due = TextEditingController();
  String get _id => (widget.student['menteeId'] ??
          widget.student['id'] ??
          widget.student['userId'] ??
          '')
      .toString();
  String get _name => (widget.student['menteeName'] ??
          widget.student['name'] ??
          widget.student['fullName'] ??
          'Student')
      .toString();
  String get _level => (widget.student['levelName'] ??
          widget.student['groupName'] ??
          'Abundance')
      .toString();
  String get _headline => (widget.student['headline'] ??
          widget.student['menteeEmail'] ??
          'Abundance student')
      .toString();
  String get _email =>
      (widget.student['menteeEmail'] ?? widget.student['email'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calendarMonth = DateTime(now.year, now.month);
    _selectedMissionDate = _dateKey(now);
    _future = _load();
  }

  @override
  void dispose() {
    _note.dispose();
    _action.dispose();
    _due.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    final api = CoachApiService.instance;
    final a12Student = widget.loader == null ? await _loadA12Student() : null;
    final goals = widget.loader != null
        ? await widget.loader!(_id)
        : _mapRecords(a12Student?['goals']);
    List<Map<String, dynamic>> tasks = const [];
    final a12Missions = a12Student?['missions'];
    if (a12Missions is List) {
      tasks = a12Missions.whereType<Map>().map((mission) {
        return <String, dynamic>{
          ...Map<String, dynamic>.from(mission),
          'title': mission['name'] ?? mission['title'] ?? 'Mission',
          'isCompleted': mission['completed'] == true,
        };
      }).toList();
    }
    List<Map<String, dynamic>> notes = const [];
    List<Map<String, dynamic>> actions = const [];
    if (widget.loader == null) {
      try {
        notes = await api.fetchAbundanceNotes(_id);
        actions = await api.fetchAbundanceActionItems(_id);
      } catch (_) {
        // Coaching records are optional to the read-only student file. A
        // missing/unmigrated coaching-record table must not hide real goals
        // and check-ins from the coach.
      }
    }
    return {
      'goals': goals,
      'tasks': tasks,
      'missionCalendar': a12Student?['missionCalendar'],
      'notes': notes,
      'actions': actions,
    };
  }

  Future<Map<String, dynamic>?> _loadA12Student() async {
    // Abundance quests are owned by the A12 mobile account. InnerU and A12
    // link the same person by canonical email, but their numeric ids differ.
    // Read the existing A12 coach roster (already scoped to this coach) and
    // reconcile the selected student by email. The returned record is the
    // single source for both quests and today's missions.
    try {
      final a12Roster =
          await (widget.goalsService ?? GoalsService(null, A12ApiTransport()))
              .fetchA12CoachRoster();
      return a12Roster.where((item) {
        final a12Id = (item['id'] ?? '').toString();
        final a12Email = (item['email'] ?? '').toString().trim().toLowerCase();
        return (_id.isNotEmpty && a12Id == _id) ||
            (_email.isNotEmpty && a12Email == _email);
      }).firstOrNull;
    } catch (_) {
      // Keep the InnerU compatibility source when the A12 bridge is
      // temporarily unavailable.
      return null;
    }
  }

  List<Map<String, dynamic>> _mapRecords(Object? raw) => raw is List
      ? raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
      : const <Map<String, dynamic>>[];

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  List<DateTime> _calendarDays() {
    final first = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final offset = first.weekday - DateTime.monday;
    final start = first.subtract(Duration(days: offset));
    final days = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0).day;
    final count = ((offset + days + 6) ~/ 7) * 7;
    return List.generate(count, (index) => start.add(Duration(days: index)));
  }

  Widget _missionCalendar(Object? raw, List<Map> fallbackToday) {
    final missions = _mapRecords(raw);
    final byDate = <String, List<Map<String, dynamic>>>{};
    for (final mission in missions) {
      final date = mission['date']?.toString();
      if (date != null && date.isNotEmpty) {
        byDate.putIfAbsent(date, () => <Map<String, dynamic>>[]).add(mission);
      }
    }
    if (missions.isEmpty && fallbackToday.isNotEmpty) {
      byDate[_selectedMissionDate ?? _dateKey(DateTime.now())] = fallbackToday
          .map((item) => <String, dynamic>{
                ...Map<String, dynamic>.from(item),
                'completed': item['isCompleted'] == true,
              })
          .toList();
    }
    final selected =
        byDate[_selectedMissionDate] ?? const <Map<String, dynamic>>[];
    final weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final days = _calendarDays();
    return Column(
      children: [
        AbundanceCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => setState(() => _calendarMonth = DateTime(
                        _calendarMonth.year, _calendarMonth.month - 1)),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                      '${_monthName(_calendarMonth.month)} ${_calendarMonth.year}',
                      style: AbundanceTypography.title),
                  IconButton(
                    onPressed: () => setState(() => _calendarMonth = DateTime(
                        _calendarMonth.year, _calendarMonth.month + 1)),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              Row(
                children: weekdayLabels
                    .map((day) => Expanded(
                          child: Center(
                            child:
                                Text(day, style: AbundanceTypography.eyebrow),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 6),
              GridView.builder(
                itemCount: days.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7, childAspectRatio: 1.15),
                itemBuilder: (context, index) {
                  final day = days[index];
                  final key = _dateKey(day);
                  final items = byDate[key] ?? const <Map<String, dynamic>>[];
                  final completedCount =
                      items.where((item) => item['completed'] == true).length;
                  final completed =
                      items.isNotEmpty && completedCount == items.length;
                  final progress =
                      items.isEmpty ? 0.0 : completedCount / items.length;
                  final selectedDay = key == _selectedMissionDate;
                  return Semantics(
                    button: true,
                    selected: selectedDay,
                    label:
                        'Mission date ${_monthName(day.month)} ${day.day}, ${day.year}. ${items.length} missions.',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() => _selectedMissionDate = key),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: selectedDay
                                ? AbundanceColors.primaryGold
                                    .withValues(alpha: .25)
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            border: selectedDay
                                ? Border.all(color: AbundanceColors.primaryGold)
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${day.day}',
                                  style: AbundanceTypography.body.copyWith(
                                      color: day.month == _calendarMonth.month
                                          ? AbundanceColors.foreground
                                          : AbundanceColors.muted)),
                              if (items.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 3,
                                  backgroundColor:
                                      AbundanceColors.surfaceSunken,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    completed
                                        ? AbundanceColors.accentCyan
                                        : AbundanceColors.primaryGold,
                                  ),
                                ),
                                Text('$completedCount/${items.length}',
                                    style: const TextStyle(
                                        color: AbundanceColors.muted,
                                        fontSize: 8)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (selected.isEmpty)
          const Text('No missions on this date.',
              style: AbundanceTypography.body),
        ...selected.map((mission) => _card(
            (mission['name'] ?? mission['title'] ?? 'Mission').toString(),
            mission['completed'] == true ? 'Completed' : 'Not completed yet')),
      ],
    );
  }

  String _monthName(int month) => const [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
      ][month - 1];

  void _openQuestDetail(Map quest) {
    final category = quest['category'];
    final categoryLabel = category is Map
        ? (category['name'] ?? category['key'] ?? 'Quest')
        : (category ?? 'Quest');
    final progress =
        ((quest['progress'] as num?)?.toDouble() ?? 0).clamp(0.0, 100.0);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AbundanceColors.surfaceRaised,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text((quest['title'] ?? 'Quest').toString(),
                style: AbundanceTypography.display),
            const SizedBox(height: 8),
            Text(categoryLabel.toString().toUpperCase(),
                style: AbundanceTypography.eyebrow),
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: progress / 100,
              minHeight: 10,
              borderRadius: BorderRadius.circular(999),
              backgroundColor: AbundanceColors.border,
              valueColor:
                  const AlwaysStoppedAnimation(AbundanceColors.accentCyan),
            ),
            const SizedBox(height: 8),
            Text('${progress.round()}% · ${(quest['status'] ?? 'IN PROGRESS')}',
                style: AbundanceTypography.body
                    .copyWith(color: AbundanceColors.accentCyan)),
            if ((quest['statement'] ?? quest['description']) != null) ...[
              const SizedBox(height: 20),
              Text((quest['statement'] ?? quest['description']).toString(),
                  style: AbundanceTypography.body),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _saveNote() async {
    final body = _note.text.trim();
    if (body.isEmpty || _savingNote) return;
    setState(() => _savingNote = true);
    try {
      await CoachApiService.instance
          .createAbundanceNote(menteeId: _id, body: body);
      _note.clear();
      if (mounted) setState(() => _future = _load());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save coaching note.')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
  }

  Future<void> _saveAction() async {
    final title = _action.text.trim();
    if (title.isEmpty || _savingAction) return;
    setState(() => _savingAction = true);
    try {
      await CoachApiService.instance.createAbundanceActionItem(
          menteeId: _id,
          title: title,
          dueDate: _due.text.trim().isEmpty ? null : _due.text.trim());
      _action.clear();
      _due.clear();
      if (mounted) setState(() => _future = _load());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save action item.')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingAction = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AbundanceColors.background,
        appBar: const AbundanceHeaderBar(),
        bottomNavigationBar: _StudentFileBottomNavigationBar(
          onTap: (index) {
            Navigator.of(context).pop();
            widget.onTabSelected?.call(index);
          },
        ),
        body: Stack(children: [
          Positioned.fill(
              child: Opacity(
                  opacity: .1,
                  child:
                      Image.asset(abundanceBackdropAsset, fit: BoxFit.cover))),
          FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AbundanceStatusView.loading();
                }
                if (snapshot.hasError) {
                  return AbundanceStatusView.error(
                      message: 'This student file could not be loaded.',
                      onRetry: () => setState(() => _future = _load()));
                }
                final data = snapshot.data ?? {};
                final goals = (data['goals'] as List? ?? const [])
                    .whereType<Map>()
                    .toList();
                final tasks = (data['tasks'] as List? ?? const [])
                    .whereType<Map>()
                    .toList();
                final notes = (data['notes'] as List? ?? const [])
                    .whereType<Map>()
                    .toList();
                final actions = (data['actions'] as List? ?? const [])
                    .whereType<Map>()
                    .toList();
                return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
                    children: [
                      Text('COACHING · $_level',
                          style: AbundanceTypography.eyebrow),
                      const SizedBox(height: 6),
                      Text(_name, style: AbundanceTypography.display),
                      Text(_headline,
                          style: AbundanceTypography.body
                              .copyWith(color: AbundanceColors.muted)),
                      _heading('Quest progress'),
                      _questContainer(goals),
                      _heading('Mission'),
                      _missionCalendar(data['missionCalendar'], tasks),
                      _heading('Private coaching notes'),
                      const Text('ADD A NOTE',
                          style: AbundanceTypography.eyebrow),
                      _field(_note, 'Record a private coaching note', 4),
                      FilledButton(
                          onPressed: _savingNote ? null : _saveNote,
                          child: Text(_savingNote ? 'Saving…' : 'Save note')),
                      ...notes.map((n) => _card((n['body'] ?? '').toString(),
                          (n['createdAt'] ?? '').toString())),
                      _heading('Action items'),
                      const Text('ACTION ITEM',
                          style: AbundanceTypography.eyebrow),
                      _field(_action, 'Next step', 1),
                      const Text('DUE DATE (OPTIONAL)',
                          style: AbundanceTypography.eyebrow),
                      _field(_due, 'YYYY-MM-DD', 1),
                      FilledButton(
                          onPressed: _savingAction ? null : _saveAction,
                          child: Text(
                              _savingAction ? 'Saving…' : 'Add action item')),
                      ...actions.map((a) => _card(
                          (a['title'] ?? '').toString(), _actionStatus(a))),
                    ]);
              }),
        ]),
      );
  String _progress(Map g) =>
      '${g['progress'] ?? 0}% · ${g['status'] ?? 'IN PROGRESS'}';
  String _actionStatus(Map a) =>
      '${a['dueDate'] ?? 'No due date'} · ${a['status'] ?? 'OPEN'}';
  Widget _questContainer(List<Map> goals) => AbundanceCard(
        margin: const EdgeInsets.only(bottom: 2),
        child: goals.isEmpty
            ? const Text('No quests added yet.',
                style: AbundanceTypography.body)
            : Column(
                children: [
                  for (var index = 0; index < goals.length; index++) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () => _openQuestDetail(goals[index]),
                      title: Text((goals[index]['title'] ?? 'Quest').toString(),
                          style: AbundanceTypography.title),
                      subtitle: Text(_progress(goals[index]),
                          style: AbundanceTypography.body
                              .copyWith(color: AbundanceColors.accentCyan)),
                      trailing: SizedBox(
                        width: 84,
                        child: LinearProgressIndicator(
                          value: (((goals[index]['progress'] as num?)
                                          ?.toDouble() ??
                                      0) /
                                  100)
                              .clamp(0.0, 1.0),
                          minHeight: 7,
                          borderRadius: BorderRadius.circular(8),
                          backgroundColor: AbundanceColors.border,
                          valueColor: const AlwaysStoppedAnimation(
                              AbundanceColors.accentCyan),
                        ),
                      ),
                    ),
                    if (index < goals.length - 1)
                      const Divider(color: AbundanceColors.border),
                  ],
                ],
              ),
      );
  Widget _heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Text(text,
          style: AbundanceTypography.title
              .copyWith(color: AbundanceColors.primaryGold)));
  Widget _card(String title, String subtitle) => AbundanceCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title, style: AbundanceTypography.title),
          subtitle: Text(subtitle,
              style: AbundanceTypography.body
                  .copyWith(color: AbundanceColors.accentCyan))));
  Widget _field(TextEditingController c, String hint, int lines) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
          controller: c,
          maxLines: lines,
          style: const TextStyle(color: AbundanceColors.foreground),
          decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AbundanceColors.muted),
              filled: true,
              fillColor: AbundanceColors.surfaceRaised,
              border: const OutlineInputBorder())));
}

class _StudentFileBottomNavigationBar extends StatelessWidget {
  const _StudentFileBottomNavigationBar({required this.onTap});

  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AbundanceColors.surfaceRaised,
        selectedItemColor: AbundanceColors.primaryGold,
        unselectedItemColor: AbundanceColors.muted,
        showUnselectedLabels: true,
        currentIndex: 4,
        onTap: onTap,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined), label: 'Mission'),
          BottomNavigationBarItem(
              icon: Icon(Icons.flag_outlined), label: 'Quests'),
          BottomNavigationBarItem(
              icon: Icon(Icons.workspace_premium_outlined), label: 'Awards'),
          BottomNavigationBarItem(
              icon: Icon(Icons.groups_outlined), label: 'Guild'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_circle_outlined), label: 'Profile'),
        ],
      );
}

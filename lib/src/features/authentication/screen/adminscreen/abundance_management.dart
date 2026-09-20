import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:selfcare_projects/src/services/abundance_admin_api_service.dart';

class AbundanceManagementScreen extends StatefulWidget {
  const AbundanceManagementScreen({super.key, this.service});

  final AbundanceAdminApiService? service;

  @override
  State<AbundanceManagementScreen> createState() =>
      _AbundanceManagementScreenState();
}

class _AbundanceManagementScreenState extends State<AbundanceManagementScreen> {
  late Future<AbundanceAdminSnapshot> _future;
  final _search = TextEditingController();

  AbundanceAdminApiService get _service =>
      widget.service ?? AbundanceAdminApiService.instance;

  @override
  void initState() {
    super.initState();
    _future = _service.fetch();
  }

  void _refresh() {
    setState(() {
      _future = _service.fetch();
    });
  }

  Future<void> _assign(
      AbundanceAdminCoach coach, AbundanceAdminStudent student) async {
    await _service.assign(coach.id, student.id);
    if (!mounted) return;
    Navigator.pop(context);
    _refresh();
  }

  Future<void> _chooseStudent(
      AbundanceAdminCoach coach, List<AbundanceAdminStudent> students) async {
    final selected = await showModalBottomSheet<AbundanceAdminStudent>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Add student to ${coach.name}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ...students.map((student) => ListTile(
                  leading: const Icon(CupertinoIcons.person),
                  title: Text(student.name),
                  subtitle: Text(student.email),
                  onTap: () => Navigator.pop(context, student),
                )),
          ],
        ),
      ),
    );
    if (selected != null) await _assign(coach, selected);
  }

  Future<void> _remove(AbundanceAdminStudent student) async {
    await _service.remove(student.id);
    _refresh();
  }

  Future<void> _makeCoach(AbundanceAdminStudent student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Make ${student.name} a coach?'),
        content: const Text('This gives the user Abundance Coach access.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Make coach'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.makeCoach(student);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Unable to make ${student.name} a coach: $error')),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${student.name} is now an Abundance coach.')),
    );
    _refresh();
  }

  Future<void> _manageStudent(AbundanceAdminStudent student) async {
    final title = TextEditingController();
    final quest = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(student.name),
        content: SizedBox(
          width: 420,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(student.email),
              const SizedBox(height: 12),
              const Text('Goals / Quests',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              ...student.goals.map((goal) => ListTile(
                    title: Text('${goal['title'] ?? ''}'),
                    subtitle: Text(
                        '${goal['progress'] ?? 0}% · ${goal['status'] ?? ''}'),
                  )),
              TextField(
                  controller: title,
                  decoration:
                      const InputDecoration(labelText: 'Edit goal title')),
              TextField(
                  controller: quest,
                  decoration: const InputDecoration(
                      labelText: 'Add quest to first goal')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (student.goals.isNotEmpty && title.text.trim().isNotEmpty) {
                await _service.updateGoal(student.goals.first['id'].toString(),
                    {'title': title.text.trim()});
              }
              if (student.goals.isNotEmpty && quest.text.trim().isNotEmpty) {
                await _service.addQuest(
                    student.goals.first['id'].toString(), quest.text.trim());
              }
              if (context.mounted) Navigator.pop(context);
              _refresh();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    title.dispose();
    quest.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Abundance Management'), actions: [
        IconButton(
            onPressed: _refresh, icon: const Icon(CupertinoIcons.refresh))
      ]),
      body: FutureBuilder<AbundanceAdminSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text(
                    'Unable to load Abundance management.\n${snapshot.error}'));
          }
          final data = snapshot.data!;
          final term = _search.text.trim().toLowerCase();
          final students = data.students
              .where((s) =>
                  term.isEmpty ||
                  '${s.name} ${s.email} ${s.username}'
                      .toLowerCase()
                      .contains(term))
              .toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                      prefixIcon: Icon(CupertinoIcons.search),
                      labelText: 'Search students')),
              const SizedBox(height: 18),
              const Text('Coaches',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ...data.coaches.map((coach) => Card(
                    child: ExpansionTile(
                      leading: const Icon(CupertinoIcons.person_2_fill),
                      title: Text(coach.name),
                      subtitle:
                          Text('${coach.students.length} assigned student(s)'),
                      trailing: IconButton(
                          icon: const Icon(CupertinoIcons.person_add),
                          onPressed: () => _chooseStudent(
                              coach,
                              students
                                  .where((s) => s.coachId != coach.id)
                                  .toList())),
                      children: coach.students
                          .map((student) => ListTile(
                              title: Text(student.name),
                              subtitle: Text(student.email),
                              onTap: () => _manageStudent(student),
                              trailing: IconButton(
                                  icon: const Icon(CupertinoIcons.minus_circle),
                                  onPressed: () => _remove(student))))
                          .toList(),
                    ),
                  )),
              const SizedBox(height: 18),
              const Text('Unassigned students',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ...students.where((s) => s.coachId == null).map((s) => ListTile(
                    leading: const Icon(CupertinoIcons.person),
                    title: Text(s.name),
                    subtitle: Text(s.email),
                    trailing: _service.isA12AbundanceManagement
                        ? TextButton.icon(
                            onPressed: () => _makeCoach(s),
                            icon: const Icon(CupertinoIcons.person_badge_plus),
                            label: const Text('Make coach'),
                          )
                        : null,
                  )),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }
}

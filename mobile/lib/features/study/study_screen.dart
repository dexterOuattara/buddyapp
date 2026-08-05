import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/app_database.dart';
import '../../providers.dart';

/// Browse synced summaries, exercises, and quizzes per chapter. Content that
/// has been synced is readable offline.
class StudyScreen extends ConsumerWidget {
  const StudyScreen({super.key, this.focusChapterClientUuid});

  final String? focusChapterClientUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    return FutureBuilder<List<Chapter>>(
      future: (db.select(db.chapters)..where((c) => c.deleted.equals(false)))
          .get(),
      builder: (context, snapshot) {
        final chapters = snapshot.data ?? const [];
        if (chapters.isEmpty) {
          return const Center(child: Text('No chapters yet.'));
        }

        // If navigated from a chapter, jump straight to it.
        if (focusChapterClientUuid != null) {
          final chapter = chapters.firstWhere(
            (c) => c.clientUuid == focusChapterClientUuid,
            orElse: () => chapters.first,
          );
          return ChapterStudyView(chapter: chapter);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: chapters.length,
          itemBuilder: (context, i) => Card(
            child: ListTile(
              leading: const Icon(Icons.auto_stories),
              title: Text(chapters[i].title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChapterStudyView(chapter: chapters[i]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ChapterStudyView extends ConsumerWidget {
  const ChapterStudyView({super.key, required this.chapter});
  final Chapter chapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(chapter.title),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.summarize), text: 'Summary'),
              Tab(icon: Icon(Icons.edit_note), text: 'Exercises'),
              Tab(icon: Icon(Icons.quiz), text: 'Quiz'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SummaryTab(db: db, chapterUuid: chapter.clientUuid),
            _ExercisesTab(db: db, chapterUuid: chapter.clientUuid),
            _QuizTab(db: db, chapterUuid: chapter.clientUuid),
          ],
        ),
      ),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({required this.db, required this.chapterUuid});
  final AppDatabase db;
  final String chapterUuid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Summary>>(
      stream: (db.select(db.summaries)
            ..where((s) => s.chapterClientUuid.equals(chapterUuid)))
          .watch(),
      builder: (context, snapshot) {
        final summaries = snapshot.data ?? const [];
        if (summaries.isEmpty) return const _PendingMaterial();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SelectableText(
              summaries.first.contentMd,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ],
        );
      },
    );
  }
}

class _ExercisesTab extends StatelessWidget {
  const _ExercisesTab({required this.db, required this.chapterUuid});
  final AppDatabase db;
  final String chapterUuid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Exercise>>(
      stream: (db.select(db.exercises)
            ..where((e) => e.chapterClientUuid.equals(chapterUuid)))
          .watch(),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const [];
        if (rows.isEmpty) return const _PendingMaterial();
        final items =
            (jsonDecode(rows.first.itemsJson) as List).cast<Map<String, dynamic>>();
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, i) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Exercise ${i + 1}',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Text(items[i]['prompt'] as String? ?? ''),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QuizTab extends StatelessWidget {
  const _QuizTab({required this.db, required this.chapterUuid});
  final AppDatabase db;
  final String chapterUuid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Quizze>>(
      stream: (db.select(db.quizzes)
            ..where((q) => q.chapterClientUuid.equals(chapterUuid)))
          .watch(),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const [];
        if (rows.isEmpty) return const _PendingMaterial();
        final questions =
            (jsonDecode(rows.first.questionsJson) as List).cast<Map<String, dynamic>>();
        return _QuizRunner(questions: questions);
      },
    );
  }
}

class _QuizRunner extends StatefulWidget {
  const _QuizRunner({required this.questions});
  final List<Map<String, dynamic>> questions;

  @override
  State<_QuizRunner> createState() => _QuizRunnerState();
}

class _QuizRunnerState extends State<_QuizRunner> {
  int _index = 0;
  int _score = 0;
  int? _selected;
  bool _answered = false;
  bool _finished = false;

  void _select(int choice) {
    if (_answered) return;
    final correct = widget.questions[_index]['correct_index'] as int? ?? 0;
    setState(() {
      _selected = choice;
      _answered = true;
      if (choice == correct) _score++;
    });
  }

  void _next() {
    setState(() {
      if (_index + 1 >= widget.questions.length) {
        _finished = true;
      } else {
        _index++;
        _selected = null;
        _answered = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 48, color: Colors.amber),
            const SizedBox(height: 12),
            Text('You scored $_score / ${widget.questions.length}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => setState(() {
                _finished = false;
                _index = 0;
                _score = 0;
                _selected = null;
                _answered = false;
              }),
              child: const Text('Retake quiz'),
            ),
          ],
        ),
      );
    }

    final q = widget.questions[_index];
    final choices = (q['choices'] as List).cast<String>();
    final correct = q['correct_index'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Question ${_index + 1} of ${widget.questions.length}',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(q['prompt'] as String? ?? '',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          for (var i = 0; i < choices.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: !_answered
                      ? null
                      : i == correct
                          ? Colors.green.shade50
                          : i == _selected
                              ? Colors.red.shade50
                              : null,
                  padding: const EdgeInsets.all(14),
                  alignment: Alignment.centerLeft,
                ),
                onPressed: () => _select(i),
                child: Text(choices[i]),
              ),
            ),
          if (_answered) ...[
            if ((q['explanation'] as String?)?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(q['explanation'] as String,
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _next, child: const Text('Next')),
          ],
        ],
      ),
    );
  }
}

class _PendingMaterial extends StatelessWidget {
  const _PendingMaterial();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_empty, size: 40, color: Colors.grey),
            SizedBox(height: 12),
            Text('Not ready yet', textAlign: TextAlign.center),
            SizedBox(height: 4),
            Text(
              'Record the lesson and go online — your summary, exercises, '
              'and quiz will appear here automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

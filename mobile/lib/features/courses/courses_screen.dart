import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../db/app_database.dart';
import '../../providers.dart';
import '../recording/recorder_service.dart';
import '../study/study_screen.dart';

/// Course → lesson → chapter hierarchy. All navigation works offline.
class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = (ref.watch(coursesStreamProvider).value ?? const [])
        .where((c) => !c.deleted)
        .toList();

    return Column(
      children: [
        Expanded(
          child: courses.isEmpty
              ? const _EmptyCourses()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: courses.length,
                  itemBuilder: (context, i) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.indigo,
                        child: Icon(Icons.school, color: Colors.white),
                      ),
                      title: Text(courses[i].title),
                      subtitle: courses[i].description != null
                          ? Text(courses[i].description!,
                              maxLines: 1, overflow: TextOverflow.ellipsis)
                          : null,
                      trailing: courses[i].pendingSync
                          ? const Icon(Icons.cloud_upload,
                              size: 18, color: Colors.orange)
                          : const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              CourseDetailScreen(course: courses[i]),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () => _addCourse(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add course'),
          ),
        ),
      ],
    );
  }

  Future<void> _addCourse(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final description = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New course'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: description,
              decoration:
                  const InputDecoration(labelText: 'Description (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (saved != true || title.text.trim().isEmpty) return;

    final db = ref.read(databaseProvider);
    await db.into(db.courses).insert(CoursesCompanion.insert(
      clientUuid: const Uuid().v4(),
      title: title.text.trim(),
      description: Value(description.text.trim().isEmpty
          ? null
          : description.text.trim()),
    ));
  }
}

class CourseDetailScreen extends ConsumerWidget {
  const CourseDetailScreen({super.key, required this.course});
  final Course course;

  /// Live lesson+chapter feed for this course (offline, from drift).
  Stream<List<_ChapterEntry>> _entries(AppDatabase db) {
    final lessonsStream = (db.select(db.lessons)
          ..where((l) =>
              l.courseClientUuid.equals(course.clientUuid) &
              l.deleted.equals(false)))
        .watch();
    final chaptersStream = (db.select(db.chapters)
          ..where((c) => c.deleted.equals(false)))
        .watch();

    List<Lesson> lessons = [];
    List<Chapter> chapters = [];
    List<_ChapterEntry> build() => [
          for (final lesson in lessons)
            for (final chapter in chapters
                .where((c) => c.lessonClientUuid == lesson.clientUuid))
              _ChapterEntry(lesson: lesson, chapter: chapter),
        ];

    final controller = StreamController<List<_ChapterEntry>>();
    final lessonsSub = lessonsStream.listen((rows) {
      lessons = rows;
      controller.add(build());
    });
    final chaptersSub = chaptersStream.listen((rows) {
      chapters = rows;
      controller.add(build());
    });
    controller.onCancel = () {
      lessonsSub.cancel();
      chaptersSub.cancel();
    };
    return controller.stream;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(title: Text(course.title)),
      body: StreamBuilder<List<_ChapterEntry>>(
        stream: _entries(db),
        builder: (context, snapshot) {
          final entries = snapshot.data ?? const <_ChapterEntry>[];
          if (entries.isEmpty) {
            return const Center(
                child: Text('No lessons yet — add one below.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final entry = entries[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.book),
                  title: Text(entry.chapter.title),
                  subtitle: Text(entry.lesson.title),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ChapterDetailScreen(chapter: entry.chapter),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addLessonAndChapter(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add lesson / chapter'),
      ),
    );
  }

  Future<void> _addLessonAndChapter(BuildContext context, WidgetRef ref) async {
    final lessonTitle = TextEditingController();
    final chapterTitle = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New lesson & chapter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: lessonTitle,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Lesson title'),
            ),
            TextField(
              controller: chapterTitle,
              decoration: const InputDecoration(labelText: 'First chapter title'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (saved != true || lessonTitle.text.trim().isEmpty) return;

    final db = ref.read(databaseProvider);
    final lessonUuid = const Uuid().v4();
    await db.into(db.lessons).insert(LessonsCompanion.insert(
      clientUuid: lessonUuid,
      courseClientUuid: course.clientUuid,
      title: lessonTitle.text.trim(),
    ));
    if (chapterTitle.text.trim().isNotEmpty) {
      await db.into(db.chapters).insert(ChaptersCompanion.insert(
        clientUuid: const Uuid().v4(),
        lessonClientUuid: lessonUuid,
        title: chapterTitle.text.trim(),
      ));
    }
  }
}

class _ChapterEntry {
  _ChapterEntry({required this.lesson, required this.chapter});
  final Lesson lesson;
  final Chapter chapter;
}

/// A chapter is where recording starts and study material lives.
class ChapterDetailScreen extends ConsumerStatefulWidget {
  const ChapterDetailScreen({super.key, required this.chapter});
  final Chapter chapter;

  @override
  ConsumerState<ChapterDetailScreen> createState() =>
      _ChapterDetailScreenState();
}

class _ChapterDetailScreenState extends ConsumerState<ChapterDetailScreen> {
  bool _recording = false;

  Future<void> _toggleRecording() async {
    final recorder = ref.read(recorderServiceProvider);
    if (_recording) {
      await recorder.stop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Recording saved. Go online to generate your summary.'),
          ),
        );
      }
    } else {
      if (!await recorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission needed.')),
          );
        }
        return;
      }
      await recorder.start(chapterClientUuid: widget.chapter.clientUuid);
    }
    if (mounted) setState(() => _recording = !_recording);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.chapter.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Record this lesson',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                    'Recording works fully offline. When you reconnect, the '
                    'audio is uploaded and your summary, exercises, and quiz '
                    'are generated automatically.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          _recording ? Colors.red : Colors.indigo,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _toggleRecording,
                    icon: Icon(_recording ? Icons.stop : Icons.mic),
                    label: Text(_recording ? 'Stop recording' : 'Start recording'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StudyScreen(
                  focusChapterClientUuid: widget.chapter.clientUuid,
                ),
              ),
            ),
            icon: const Icon(Icons.auto_stories),
            label: const Text('Open study material'),
          ),
        ],
      ),
    );
  }
}

class _EmptyCourses extends StatelessWidget {
  const _EmptyCourses();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.school_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text('No courses yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('Add your first course to get started.',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

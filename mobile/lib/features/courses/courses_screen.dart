import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_theme.dart';
import '../../db/app_database.dart';
import '../../providers.dart';
import '../recording/recording_player_screen.dart';
import '../study/study_screen.dart';
import 'course_progress.dart';
import 'course_recording_screen.dart';

enum _CourseFilter { all, active, completed }

class CoursesScreen extends ConsumerStatefulWidget {
  const CoursesScreen({super.key});

  @override
  ConsumerState<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends ConsumerState<CoursesScreen> {
  final _search = TextEditingController();
  _CourseFilter _filter = _CourseFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(courseCatalogProvider);
    return catalog.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _CourseLoadError(
        onRetry: () => ref.invalidate(courseCatalogProvider),
      ),
      data: (snapshot) {
        final query = _search.text.trim().toLowerCase();
        final courses = snapshot.courses.where((course) {
          final matchesQuery =
              query.isEmpty ||
              course.course.title.toLowerCase().contains(query) ||
              (course.course.description?.toLowerCase().contains(query) ??
                  false);
          final matchesFilter = switch (_filter) {
            _CourseFilter.all => true,
            _CourseFilter.active => !course.isCompleted,
            _CourseFilter.completed => course.isCompleted,
          };
          return matchesQuery && matchesFilter;
        }).toList();

        return Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Rechercher un cours',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _search.text.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      _search.clear();
                                      setState(() {});
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _FilterChip(
                                label: 'Tous',
                                selected: _filter == _CourseFilter.all,
                                onTap: () =>
                                    setState(() => _filter = _CourseFilter.all),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'En cours',
                                selected: _filter == _CourseFilter.active,
                                onTap: () => setState(
                                  () => _filter = _CourseFilter.active,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Terminés',
                                selected: _filter == _CourseFilter.completed,
                                onTap: () => setState(
                                  () => _filter = _CourseFilter.completed,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
                if (courses.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyCourses(filtered: snapshot.courses.isNotEmpty),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList.separated(
                      itemCount: courses.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _CourseCard(
                        progress: courses[index],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CourseDetailScreen(
                              course: courses[index].course,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Positioned(
              right: 18,
              bottom: 18,
              child: FloatingActionButton(
                heroTag: 'add-course',
                tooltip: 'Ajouter un cours',
                onPressed: () => _addCourse(context, ref),
                child: const Icon(Icons.add_rounded, size: 30),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addCourse(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final description = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nouveau cours'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nom du cours'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: description,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description (facultatif)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (saved != true || title.text.trim().isEmpty) return;

    final db = ref.read(databaseProvider);
    await db
        .into(db.courses)
        .insert(
          CoursesCompanion.insert(
            clientUuid: const Uuid().v4(),
            title: title.text.trim(),
            description: Value(
              description.text.trim().isEmpty ? null : description.text.trim(),
            ),
          ),
        );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.progress, required this.onTap});
  final CourseProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = _courseVisual(progress.course.title);
    final percent = (progress.progress * 100).round();
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _CourseIcon(visual: visual, size: 58),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progress.course.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${progress.chapters.length} chapitre${progress.chapters.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text(
                          'Progression',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: progress.progress,
                            minHeight: 5,
                            borderRadius: BorderRadius.circular(10),
                            color: AppColors.secondary,
                            backgroundColor: AppColors.outline,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$percent %',
                          style: const TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (progress.course.pendingSync)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.cloud_upload_outlined,
                    color: AppColors.warning,
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CourseDetailScreen extends ConsumerWidget {
  const CourseDetailScreen({super.key, required this.course});
  final Course course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(courseCatalogProvider);
    final progress = catalog.valueOrNull?.courses
        .where((item) => item.course.clientUuid == course.clientUuid)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(course.title),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'add') _addLessonAndChapter(context, ref);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'add',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.add_rounded),
                  title: Text('Ajouter un chapitre'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: progress == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                _CourseOverviewCard(progress: progress),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => _recordCurrent(context, progress),
                  icon: const Icon(Icons.mic_rounded),
                  label: const Text('Enregistrer un cours'),
                ),
                const SizedBox(height: 22),
                if (progress.currentChapter case final current?) ...[
                  Text(
                    'Continuer à étudier',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ContinueCard(
                    chapter: current,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChapterDetailScreen(
                          chapter: current.chapter,
                          courseTitle: course.title,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Chapitres',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      '${progress.completedCount}/${progress.chapters.length} terminés',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (progress.chapters.isEmpty)
                  _NoChapters(onAdd: () => _addLessonAndChapter(context, ref))
                else
                  Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < progress.chapters.length; i++) ...[
                          _ChapterRow(
                            number: i + 1,
                            progress: progress.chapters[i],
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChapterDetailScreen(
                                  chapter: progress.chapters[i].chapter,
                                  courseTitle: course.title,
                                ),
                              ),
                            ),
                          ),
                          if (i < progress.chapters.length - 1)
                            const Divider(height: 1, indent: 14, endIndent: 14),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  void _recordCurrent(BuildContext context, CourseProgress progress) {
    final current = progress.currentChapter;
    if (current == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez d’abord un chapitre.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CourseRecordingScreen(
          chapter: current.chapter,
          courseTitle: course.title,
        ),
      ),
    );
  }

  Future<void> _addLessonAndChapter(BuildContext context, WidgetRef ref) async {
    final lessonTitle = TextEditingController(text: 'Cours principal');
    final chapterTitle = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nouveau chapitre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: lessonTitle,
              decoration: const InputDecoration(labelText: 'Module'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: chapterTitle,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Chapitre'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (saved != true || chapterTitle.text.trim().isEmpty) return;

    final db = ref.read(databaseProvider);
    final existingLessons =
        await (db.select(db.lessons)
              ..where(
                (l) =>
                    l.courseClientUuid.equals(course.clientUuid) &
                    l.title.equals(lessonTitle.text.trim()) &
                    l.deleted.equals(false),
              )
              ..limit(1))
            .get();
    final lessonUuid = existingLessons.isEmpty
        ? const Uuid().v4()
        : existingLessons.first.clientUuid;
    if (existingLessons.isEmpty) {
      await db
          .into(db.lessons)
          .insert(
            LessonsCompanion.insert(
              clientUuid: lessonUuid,
              courseClientUuid: course.clientUuid,
              title: lessonTitle.text.trim().isEmpty
                  ? 'Cours principal'
                  : lessonTitle.text.trim(),
            ),
          );
    }
    final count = await (db.select(
      db.chapters,
    )..where((c) => c.lessonClientUuid.equals(lessonUuid))).get();
    await db
        .into(db.chapters)
        .insert(
          ChaptersCompanion.insert(
            clientUuid: const Uuid().v4(),
            lessonClientUuid: lessonUuid,
            title: chapterTitle.text.trim(),
            position: Value(count.length),
          ),
        );
  }
}

class ChapterDetailScreen extends ConsumerWidget {
  const ChapterDetailScreen({
    super.key,
    required this.chapter,
    this.courseTitle = 'Cours',
  });

  final Chapter chapter;
  final String courseTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(courseCatalogProvider).valueOrNull;
    final progress = catalog?.chapter(chapter.clientUuid);
    return Scaffold(
      appBar: AppBar(
        title: Text(chapter.title),
        actions: [
          IconButton(
            tooltip: 'Plus d’options',
            onPressed: () {},
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
      body: progress == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              children: [
                Text(
                  '$courseTitle  ·  ${progress.lesson.title}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      '${progress.mastery} % maîtrisé',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: progress.mastery / 100,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.secondary,
                        backgroundColor: AppColors.outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.22,
                  children: [
                    _ResourceTile(
                      icon: Icons.description_outlined,
                      color: AppColors.primary,
                      title: 'Résumé intelligent',
                      subtitle: progress.summary == null
                          ? 'En attente'
                          : '${_readingMinutes(progress.summary!.contentMd)} min de lecture',
                      enabled: progress.summary != null,
                      onTap: () => _openStudy(context, 0),
                    ),
                    _ResourceTile(
                      icon: Icons.style_outlined,
                      color: AppColors.secondary,
                      title: 'Fiches de révision',
                      subtitle: '${progress.flashcardCount} fiches',
                      enabled: progress.summary != null,
                      onTap: () => _openStudy(context, 1),
                    ),
                    _ResourceTile(
                      icon: Icons.edit_outlined,
                      color: AppColors.success,
                      title: 'Exercices',
                      subtitle: '${progress.exerciseCount} exercices',
                      enabled: progress.exercise != null,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChapterExercisesScreen(
                            chapter: chapter,
                            courseTitle: courseTitle,
                          ),
                        ),
                      ),
                    ),
                    _ResourceTile(
                      icon: Icons.quiz_outlined,
                      color: AppColors.warning,
                      title: 'Quiz',
                      subtitle: '${progress.quizCount} questions',
                      enabled: progress.quiz != null,
                      onTap: () => _openStudy(context, 2),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'Enregistrements',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (progress.recordings.isEmpty)
                  const _NoRecordings()
                else
                  for (final recording in progress.recordings) ...[
                    _ChapterRecordingCard(
                      recording: recording,
                      transcript: progress.transcriptFor(recording),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CourseProcessingScreen(
                            recordingId: recording.id,
                            chapter: chapter,
                            courseTitle: courseTitle,
                          ),
                        ),
                      ),
                      onPlay: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RecordingPlayerScreen(
                            recording: recording,
                            chapterTitle: chapter.title,
                            courseTitle: courseTitle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CourseRecordingScreen(
                        chapter: chapter,
                        courseTitle: courseTitle,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.mic_rounded),
                  label: const Text('Nouvel enregistrement'),
                ),
              ],
            ),
    );
  }

  void _openStudy(BuildContext context, int tab) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChapterStudyView(
          chapter: chapter,
          courseTitle: courseTitle,
          initialTab: tab,
        ),
      ),
    );
  }
}

class _CourseOverviewCard extends StatelessWidget {
  const _CourseOverviewCard({required this.progress});
  final CourseProgress progress;

  @override
  Widget build(BuildContext context) {
    final visual = _courseVisual(progress.course.title);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _CourseIcon(visual: visual, size: 54),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    progress.course.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${progress.chapters.length} chapitre${progress.chapters.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            _ProgressRing(value: progress.progress, size: 58),
          ],
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.chapter, required this.onTap});
  final ChapterProgress chapter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chapter.chapter.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text(
                    'Maîtrise',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: chapter.mastery / 100,
                      minHeight: 5,
                      borderRadius: BorderRadius.circular(10),
                      color: AppColors.secondary,
                      backgroundColor: AppColors.outline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${chapter.mastery} %',
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onTap,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: const Text('Reprendre'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({
    required this.number,
    required this.progress,
    required this.onTap,
  });

  final int number;
  final ChapterProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (progress.status) {
      ChapterLearningStatus.completed => (
        'Terminé',
        Icons.check_circle_rounded,
        AppColors.success,
      ),
      ChapterLearningStatus.review => (
        'À revoir',
        Icons.schedule_rounded,
        AppColors.warning,
      ),
      ChapterLearningStatus.inProgress => (
        'En cours',
        Icons.timelapse_rounded,
        AppColors.secondary,
      ),
      ChapterLearningStatus.notStarted => (
        'À commencer',
        Icons.circle_outlined,
        AppColors.muted,
      ),
    };
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        child: Row(
          children: [
            Text(
              '$number ·',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                progress.chapter.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight:
                      progress.status == ChapterLearningStatus.inProgress
                      ? FontWeight.w800
                      : FontWeight.w600,
                  color: progress.status == ChapterLearningStatus.inProgress
                      ? AppColors.secondary
                      : AppColors.ink,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: enabled ? color : AppColors.muted, size: 34),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.muted, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChapterRecordingCard extends StatelessWidget {
  const _ChapterRecordingCard({
    required this.recording,
    required this.transcript,
    required this.onTap,
    required this.onPlay,
  });
  final Recording recording;
  final Transcript? transcript;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (recording.status) {
      'ready' => ('Prêt', AppColors.success, Icons.check_circle_rounded),
      'processing' => ('Traitement', AppColors.secondary, Icons.auto_awesome),
      'synced' => ('Synchronisé', AppColors.success, Icons.cloud_done_outlined),
      'failed' => ('Erreur', AppColors.error, Icons.error_outline_rounded),
      _ => ('En attente', AppColors.warning, Icons.schedule_rounded),
    };
    final transcriptAvailable = transcriptIsAvailable(transcript);
    final transcriptProcessing = recording.status == 'processing';
    final transcriptLabel = transcriptAvailable
        ? 'Transcription disponible'
        : transcriptProcessing
        ? 'Transcription en cours…'
        : 'Transcription pas disponible';
    final transcriptColor = transcriptAvailable
        ? AppColors.success
        : transcriptProcessing
        ? AppColors.secondary
        : AppColors.muted;
    final transcriptIcon = transcriptAvailable
        ? Icons.subtitles_rounded
        : transcriptProcessing
        ? Icons.hourglass_top_rounded
        : Icons.subtitles_off_rounded;
    return Card(
      child: ListTile(
        isThreeLine: true,
        onTap: onTap,
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.graphic_eq_rounded,
            color: AppColors.secondary,
          ),
        ),
        title: Text(
          'Cours du ${DateFormat('d MMM', 'fr').format(recording.createdAt)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(_duration(recording.durationSecs ?? 0)),
                const SizedBox(width: 8),
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(transcriptIcon, size: 14, color: transcriptColor),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    transcriptLabel,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: transcriptColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          tooltip: 'Réécouter',
          onPressed: onPlay,
          icon: const Icon(
            Icons.play_circle_fill_rounded,
            color: AppColors.primary,
            size: 34,
          ),
        ),
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.value, this.size = 54});
  final double value;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 4,
              color: AppColors.secondary,
              backgroundColor: AppColors.outline,
            ),
          ),
          Text(
            '${(value * 100).round()} %',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.ink,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _CourseIcon extends StatelessWidget {
  const _CourseIcon({required this.visual, required this.size});
  final _CourseVisual visual;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [visual.color.withValues(alpha: 0.72), visual.color],
        ),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(visual.icon, color: Colors.white, size: size * 0.52),
    );
  }
}

class _EmptyCourses extends StatelessWidget {
  const _EmptyCourses({required this.filtered});
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.menu_book_outlined,
              size: 52,
              color: AppColors.muted,
            ),
            const SizedBox(height: 14),
            Text(
              filtered ? 'Aucun résultat' : 'Aucun cours pour le moment',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              filtered
                  ? 'Modifiez la recherche ou le filtre.'
                  : 'Ajoutez votre premier cours pour commencer.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseLoadError extends StatelessWidget {
  const _CourseLoadError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 42,
            ),
            const SizedBox(height: 12),
            const Text('Impossible de charger les cours.'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

class _NoChapters extends StatelessWidget {
  const _NoChapters({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Text(
              'Ce cours ne contient pas encore de chapitre.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter un chapitre'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoRecordings extends StatelessWidget {
  const _NoRecordings();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.graphic_eq_rounded, color: AppColors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Aucun enregistrement pour ce chapitre.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseVisual {
  const _CourseVisual(this.icon, this.color);
  final IconData icon;
  final Color color;
}

_CourseVisual _courseVisual(String title) {
  const visuals = [
    _CourseVisual(Icons.functions_rounded, AppColors.primary),
    _CourseVisual(Icons.eco_rounded, AppColors.success),
    _CourseVisual(Icons.bar_chart_rounded, AppColors.warning),
    _CourseVisual(Icons.science_outlined, AppColors.secondary),
    _CourseVisual(Icons.translate_rounded, AppColors.primary),
  ];
  return visuals[title.hashCode.abs() % visuals.length];
}

int _readingMinutes(String text) {
  final words = text.trim().split(RegExp(r'\s+')).length;
  return (words / 180).ceil().clamp(1, 99);
}

String _duration(int seconds) {
  final minutes = seconds ~/ 60;
  final remaining = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
}

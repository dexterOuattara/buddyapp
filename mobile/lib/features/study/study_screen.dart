import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_theme.dart';
import '../../db/app_database.dart';
import '../../providers.dart';
import '../../sync/sync_engine.dart';
import '../courses/course_progress.dart';

/// Home study feed. Every item is built from the local database and remains
/// available without connectivity.
class StudyScreen extends ConsumerWidget {
  const StudyScreen({super.key, this.focusChapterClientUuid});

  final String? focusChapterClientUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(courseCatalogProvider);
    return catalog.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          const Center(child: Text('Impossible de charger vos contenus.')),
      data: (snapshot) {
        final entries = [
          for (final course in snapshot.courses)
            for (final chapter in course.chapters) (course, chapter),
        ];
        if (entries.isEmpty) {
          return const _PendingMaterial(
            message: 'Créez un cours et un chapitre pour commencer.',
          );
        }

        if (focusChapterClientUuid != null) {
          final match = entries
              .where(
                (entry) =>
                    entry.$2.chapter.clientUuid == focusChapterClientUuid,
              )
              .firstOrNull;
          if (match != null) {
            return ChapterStudyView(
              chapter: match.$2.chapter,
              courseTitle: match.$1.course.title,
            );
          }
        }

        final active = entries.where(
          (entry) =>
              entry.$2.status != ChapterLearningStatus.notStarted ||
              entry.$2.hasMaterial,
        );
        final visible = active.isEmpty ? entries : active.toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            Text(
              'À continuer',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            for (final entry in visible) ...[
              _HomeStudyCard(
                courseTitle: entry.$1.course.title,
                chapter: entry.$2,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChapterStudyView(
                      chapter: entry.$2.chapter,
                      courseTitle: entry.$1.course.title,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class ChapterStudyView extends ConsumerStatefulWidget {
  const ChapterStudyView({
    super.key,
    required this.chapter,
    this.courseTitle = 'Cours',
    this.initialTab = 0,
  });

  final Chapter chapter;
  final String courseTitle;
  final int initialTab;

  @override
  ConsumerState<ChapterStudyView> createState() => _ChapterStudyViewState();
}

class _ChapterStudyViewState extends ConsumerState<ChapterStudyView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final phase = ref.watch(syncPhaseProvider).value ?? SyncPhase.idle;
    final chapterProgress = ref
        .watch(courseCatalogProvider)
        .valueOrNull
        ?.chapter(widget.chapter.clientUuid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Résumé intelligent'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _AvailabilityBadge(offline: phase == SyncPhase.offline),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.courseTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.chapter.title,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.outline.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabs,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.ink,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    tabs: const [
                      Tab(text: 'Résumé'),
                      Tab(text: 'Fiches'),
                      Tab(text: 'Quiz'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _SummaryTab(
                  db: db,
                  chapterUuid: widget.chapter.clientUuid,
                  mastery: chapterProgress?.mastery ?? 0,
                  onStartQuiz: () => _tabs.animateTo(2),
                ),
                _FlashcardsTab(db: db, chapterUuid: widget.chapter.clientUuid),
                _QuizTab(
                  db: db,
                  chapter: widget.chapter,
                  courseTitle: widget.courseTitle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChapterExercisesScreen extends ConsumerWidget {
  const ChapterExercisesScreen({
    super.key,
    required this.chapter,
    this.courseTitle = 'Cours',
  });

  final Chapter chapter;
  final String courseTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Exercices')),
      body: StreamBuilder<List<Exercise>>(
        stream:
            (db.select(
                  db.exercises,
                )..where((e) => e.chapterClientUuid.equals(chapter.clientUuid)))
                .watch(),
        builder: (context, snapshot) {
          final row = _latestByVersion(snapshot.data ?? const <Exercise>[]);
          if (row == null) return const _PendingMaterial();
          final items = _decodeList(row.itemsJson);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Text(courseTitle, style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 3),
              Text(
                chapter.title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              for (var index = 0; index < items.length; index++) ...[
                _ExerciseCard(index: index, item: items[index]),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({
    required this.db,
    required this.chapterUuid,
    required this.mastery,
    required this.onStartQuiz,
  });

  final AppDatabase db;
  final String chapterUuid;
  final int mastery;
  final VoidCallback onStartQuiz;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Summary>>(
      stream: (db.select(
        db.summaries,
      )..where((s) => s.chapterClientUuid.equals(chapterUuid))).watch(),
      builder: (context, snapshot) {
        final summary = _latestByVersion(snapshot.data ?? const <Summary>[]);
        if (summary == null) return const _PendingMaterial();
        final content = _StudyContent.fromSummary(summary);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            _SummarySection(
              icon: Icons.fact_check_outlined,
              iconColor: AppColors.primary,
              title: 'Points essentiels',
              child: Column(
                children: [
                  for (final point in content.keyPoints)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 7),
                            child: CircleAvatar(
                              radius: 2.5,
                              backgroundColor: AppColors.ink,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              point,
                              style: const TextStyle(height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _SummarySection(
              icon: Icons.lightbulb_outline_rounded,
              iconColor: AppColors.warning,
              title: 'À retenir',
              child: Text(
                content.takeaway,
                style: const TextStyle(height: 1.45),
              ),
            ),
            const SizedBox(height: 10),
            if (content.body.isNotEmpty)
              _SummarySection(
                icon: Icons.notes_rounded,
                iconColor: AppColors.secondary,
                title: 'Résumé détaillé',
                child: Text(content.body, style: const TextStyle(height: 1.5)),
              ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    _MasteryRing(value: mastery),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Maîtrise du chapitre',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: mastery / 100,
                            minHeight: 5,
                            borderRadius: BorderRadius.circular(10),
                            color: AppColors.secondary,
                            backgroundColor: AppColors.outline,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onStartQuiz,
              icon: const Icon(Icons.rocket_launch_outlined),
              label: const Text('Commencer le quiz'),
            ),
          ],
        );
      },
    );
  }
}

class _FlashcardsTab extends StatelessWidget {
  const _FlashcardsTab({required this.db, required this.chapterUuid});
  final AppDatabase db;
  final String chapterUuid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Summary>>(
      stream: (db.select(
        db.summaries,
      )..where((s) => s.chapterClientUuid.equals(chapterUuid))).watch(),
      builder: (context, snapshot) {
        final summary = _latestByVersion(snapshot.data ?? const <Summary>[]);
        if (summary == null) return const _PendingMaterial();
        final content = _StudyContent.fromSummary(summary);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
              '${content.flashcards.length} fiches de révision',
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < content.flashcards.length; i++) ...[
              _FlashcardTile(index: i, card: content.flashcards[i]),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _QuizTab extends StatelessWidget {
  const _QuizTab({
    required this.db,
    required this.chapter,
    required this.courseTitle,
  });

  final AppDatabase db;
  final Chapter chapter;
  final String courseTitle;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Quizze>>(
      stream: (db.select(
        db.quizzes,
      )..where((q) => q.chapterClientUuid.equals(chapter.clientUuid))).watch(),
      builder: (context, snapshot) {
        final quiz = _latestByVersion(snapshot.data ?? const <Quizze>[]);
        if (quiz == null) return const _PendingMaterial();
        final questions = _decodeList(quiz.questionsJson);
        return StreamBuilder<List<QuizAttempt>>(
          stream:
              (db.select(db.quizAttempts)
                    ..where(
                      (a) => a.chapterClientUuid.equals(chapter.clientUuid),
                    )
                    ..orderBy([(a) => OrderingTerm.desc(a.takenAt)]))
                  .watch(),
          builder: (context, attemptSnapshot) {
            final attempts = attemptSnapshot.data ?? const <QuizAttempt>[];
            final latest = attempts.firstOrNull;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.quiz_outlined,
                            color: AppColors.warning,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '${questions.length} questions',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Testez votre compréhension et identifiez les notions à revoir.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
                if (latest != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: _MasteryRing(
                        value: latest.total == 0
                            ? 0
                            : ((latest.score / latest.total) * 100).round(),
                        size: 48,
                      ),
                      title: const Text(
                        'Dernier résultat',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text('${latest.score} / ${latest.total}'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => QuizResultScreen(
                            chapter: chapter,
                            courseTitle: courseTitle,
                            attempt: latest,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: questions.isEmpty
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => QuizRunnerScreen(
                              chapter: chapter,
                              courseTitle: courseTitle,
                              quiz: quiz,
                              questions: questions,
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    latest == null ? 'Commencer le quiz' : 'Refaire le quiz',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class QuizRunnerScreen extends ConsumerStatefulWidget {
  const QuizRunnerScreen({
    super.key,
    required this.chapter,
    required this.courseTitle,
    required this.quiz,
    required this.questions,
  });

  final Chapter chapter;
  final String courseTitle;
  final Quizze quiz;
  final List<Map<String, dynamic>> questions;

  @override
  ConsumerState<QuizRunnerScreen> createState() => _QuizRunnerScreenState();
}

class _QuizRunnerScreenState extends ConsumerState<QuizRunnerScreen> {
  int _index = 0;
  int? _selected;
  final List<Map<String, dynamic>> _answers = [];

  Future<void> _next() async {
    if (_selected == null) return;
    final question = widget.questions[_index];
    final correctIndex = _asInt(question['correct_index']);
    _answers.add({
      'question_index': _index,
      'choice': _selected,
      'correct': _selected == correctIndex,
      'correct_index': correctIndex,
      'prompt': question['prompt']?.toString() ?? '',
      'choices': question['choices'] ?? const [],
      'explanation': question['explanation'],
      'topic': question['topic']?.toString().trim().isNotEmpty == true
          ? question['topic'].toString()
          : _fallbackTopic(question['prompt']?.toString() ?? ''),
    });
    if (_index + 1 < widget.questions.length) {
      setState(() {
        _index++;
        _selected = null;
      });
      return;
    }

    final score = _answers.where((answer) => answer['correct'] == true).length;
    final db = ref.read(databaseProvider);
    final clientUuid = const Uuid().v4();
    await db
        .into(db.quizAttempts)
        .insert(
          QuizAttemptsCompanion.insert(
            clientUuid: clientUuid,
            quizServerId: widget.quiz.serverId ?? '',
            chapterClientUuid: widget.chapter.clientUuid,
            score: score,
            total: widget.questions.length,
            answersJson: jsonEncode(_answers),
          ),
        );
    final attempt = await (db.select(
      db.quizAttempts,
    )..where((a) => a.clientUuid.equals(clientUuid))).getSingle();
    unawaited(ref.read(syncEngineProvider).sync());
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => QuizResultScreen(
          chapter: widget.chapter,
          courseTitle: widget.courseTitle,
          attempt: attempt,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[_index];
    final choices = (question['choices'] as List? ?? const [])
        .map((choice) => choice.toString())
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Question ${_index + 1} sur ${widget.questions.length}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(((_index + 1) / widget.questions.length) * 100).round()} %',
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (_index + 1) / widget.questions.length,
                minHeight: 6,
                borderRadius: BorderRadius.circular(10),
                color: AppColors.secondary,
                backgroundColor: AppColors.outline,
              ),
              const SizedBox(height: 30),
              Text(
                question['prompt']?.toString() ?? '',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 22),
              for (var i = 0; i < choices.length; i++) ...[
                _QuizChoice(
                  index: i,
                  text: choices[i],
                  selected: _selected == i,
                  onTap: () => setState(() => _selected = i),
                ),
                const SizedBox(height: 10),
              ],
              const Spacer(),
              FilledButton(
                onPressed: _selected == null ? null : _next,
                child: Text(
                  _index + 1 == widget.questions.length
                      ? 'Voir mon résultat'
                      : 'Question suivante',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuizResultScreen extends StatelessWidget {
  const QuizResultScreen({
    super.key,
    required this.chapter,
    required this.courseTitle,
    required this.attempt,
  });

  final Chapter chapter;
  final String courseTitle;
  final QuizAttempt attempt;

  @override
  Widget build(BuildContext context) {
    final answers = _decodeList(attempt.answersJson);
    final percent = attempt.total == 0
        ? 0
        : ((attempt.score / attempt.total) * 100).round();
    final topics = _topicScores(answers);
    final mistakes = answers.where((a) => a['correct'] != true).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Résultat du quiz')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: AppColors.warning,
            size: 82,
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${attempt.score}',
                  style: const TextStyle(color: AppColors.primary),
                ),
                TextSpan(text: ' / ${attempt.total}'),
              ],
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            percent >= 80
                ? 'Très bon travail !'
                : percent >= 70
                ? 'Chapitre maîtrisé !'
                : 'Encore un petit effort !',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MasteryRing(value: percent, size: 62),
              const SizedBox(width: 12),
              const Text(
                'Score global',
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Détail par sujet',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < topics.length; i++) ...[
                  _TopicResultRow(topic: topics[i]),
                  if (i < topics.length - 1)
                    const Divider(height: 1, indent: 14, endIndent: 14),
                ],
              ],
            ),
          ),
          if (mistakes.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.statusColors.warningContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.star_outline_rounded,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Révisez ${topics.where((t) => !t.mastered).map((t) => t.label.toLowerCase()).join(', ')} avant de continuer.',
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: mistakes.isEmpty
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _QuizReviewScreen(mistakes: mistakes),
                    ),
                  ),
            child: const Text('Revoir mes erreurs'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Retour au chapitre'),
          ),
        ],
      ),
    );
  }
}

class _QuizReviewScreen extends StatelessWidget {
  const _QuizReviewScreen({required this.mistakes});
  final List<Map<String, dynamic>> mistakes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes erreurs')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: mistakes.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final answer = mistakes[index];
          final choices = (answer['choices'] as List? ?? const [])
              .map((e) => e.toString())
              .toList();
          final chosen = _asInt(answer['choice']);
          final correct = _asInt(answer['correct_index']);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    answer['prompt']?.toString() ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Votre réponse : ${chosen < choices.length ? choices[chosen] : '—'}',
                    style: const TextStyle(color: AppColors.error),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Bonne réponse : ${correct < choices.length ? choices[correct] : '—'}',
                    style: const TextStyle(color: AppColors.success),
                  ),
                  if (answer['explanation']?.toString().isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    Text(
                      answer['explanation'].toString(),
                      style: const TextStyle(
                        color: AppColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HomeStudyCard extends StatelessWidget {
  const _HomeStudyCard({
    required this.courseTitle,
    required this.chapter,
    required this.onTap,
  });

  final String courseTitle;
  final ChapterProgress chapter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.auto_stories_rounded,
            color: AppColors.secondary,
          ),
        ),
        title: Text(
          chapter.chapter.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('$courseTitle · ${chapter.mastery} % maîtrisé'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 21),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _FlashcardTile extends StatefulWidget {
  const _FlashcardTile({required this.index, required this.card});
  final int index;
  final _Flashcard card;

  @override
  State<_FlashcardTile> createState() => _FlashcardTileState();
}

class _FlashcardTileState extends State<_FlashcardTile> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => setState(() => _revealed = !_revealed),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FICHE ${widget.index + 1}',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  widget.card.front,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                if (_revealed)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      widget.card.back,
                      style: const TextStyle(height: 1.4),
                    ),
                  )
                else
                  const Row(
                    children: [
                      Icon(
                        Icons.touch_app_outlined,
                        color: AppColors.muted,
                        size: 17,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Touchez pour révéler la réponse',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatefulWidget {
  const _ExerciseCard({required this.index, required this.item});
  final int index;
  final Map<String, dynamic> item;

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  bool _showGuidance = false;

  @override
  Widget build(BuildContext context) {
    final guidance = widget.item['guidance']?.toString();
    final answer = widget.item['answer']?.toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EXERCICE ${widget.index + 1}',
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              widget.item['prompt']?.toString() ?? '',
              style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4),
            ),
            if ((guidance?.isNotEmpty ?? false) ||
                (answer?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => setState(() => _showGuidance = !_showGuidance),
                icon: Icon(
                  _showGuidance
                      ? Icons.visibility_off_outlined
                      : Icons.lightbulb_outline,
                ),
                label: Text(
                  _showGuidance ? 'Masquer l’aide' : 'Voir un indice',
                ),
              ),
              if (_showGuidance)
                Text(
                  guidance?.isNotEmpty == true ? guidance! : answer!,
                  style: const TextStyle(color: AppColors.muted, height: 1.4),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuizChoice extends StatelessWidget {
  const _QuizChoice({
    required this.index,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.secondary.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.secondary : AppColors.outline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? AppColors.secondary : AppColors.canvas,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.secondary : AppColors.outline,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                String.fromCharCode(65 + index),
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
          ],
        ),
      ),
    );
  }
}

class _TopicResultRow extends StatelessWidget {
  const _TopicResultRow({required this.topic});
  final _TopicScore topic;

  @override
  Widget build(BuildContext context) {
    final color = topic.mastered ? AppColors.success : AppColors.warning;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      child: Row(
        children: [
          Expanded(
            child: Text(
              topic.label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Icon(
            topic.mastered
                ? Icons.check_circle_rounded
                : Icons.schedule_rounded,
            color: color,
            size: 17,
          ),
          const SizedBox(width: 5),
          Text(
            topic.mastered ? 'Maîtrisé' : 'À revoir',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MasteryRing extends StatelessWidget {
  const _MasteryRing({required this.value, this.size = 58});
  final int value;
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
              value: value / 100,
              strokeWidth: 4,
              color: AppColors.secondary,
              backgroundColor: AppColors.outline,
            ),
          ),
          Text(
            '$value %',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: size * 0.19,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  const _AvailabilityBadge({required this.offline});
  final bool offline;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          offline ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
          size: 17,
          color: offline ? AppColors.warning : AppColors.success,
        ),
        const SizedBox(width: 5),
        Text(
          offline ? 'Hors ligne' : 'Disponible hors ligne',
          style: TextStyle(
            color: offline ? AppColors.warning : AppColors.success,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PendingMaterial extends StatelessWidget {
  const _PendingMaterial({
    this.message =
        'Enregistrez le cours puis connectez-vous : vos contenus apparaîtront automatiquement.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.hourglass_empty_rounded,
              size: 42,
              color: AppColors.muted,
            ),
            const SizedBox(height: 12),
            const Text(
              'Contenu en attente',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _Flashcard {
  const _Flashcard(this.front, this.back);
  final String front;
  final String back;
}

class _StudyContent {
  const _StudyContent({
    required this.keyPoints,
    required this.takeaway,
    required this.flashcards,
    required this.body,
  });

  final List<String> keyPoints;
  final String takeaway;
  final List<_Flashcard> flashcards;
  final String body;

  factory _StudyContent.fromSummary(Summary summary) {
    Map<String, dynamic> structured = const {};
    try {
      final decoded = jsonDecode(summary.structuredJson ?? '{}');
      if (decoded is Map<String, dynamic>) structured = decoded;
    } catch (_) {}

    var points = (structured['key_points'] as List? ?? const [])
        .map((point) => point.toString().trim())
        .where((point) => point.isNotEmpty)
        .toList();
    if (points.isEmpty) {
      points = summary.contentMd
          .split('\n')
          .map((line) => line.trim())
          .where(
            (line) =>
                line.startsWith('- ') || RegExp(r'^\d+\. ').hasMatch(line),
          )
          .map((line) => line.replaceFirst(RegExp(r'^(?:- |\d+\. )'), ''))
          .map(_stripMarkdown)
          .where((line) => line.isNotEmpty)
          .take(5)
          .toList();
    }
    if (points.isEmpty) {
      final plain = _plainParagraphs(summary.contentMd);
      points = plain.take(3).toList();
    }

    var cards = (structured['flashcards'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (card) => _Flashcard(
            card['front']?.toString() ?? '',
            card['back']?.toString() ?? '',
          ),
        )
        .where((card) => card.front.isNotEmpty && card.back.isNotEmpty)
        .toList();
    if (cards.isEmpty) {
      cards = [
        for (final point in points) _Flashcard('Que faut-il retenir ?', point),
      ];
    }

    final plain = _plainParagraphs(summary.contentMd);
    final takeaway = structured['takeaway']?.toString().trim();
    return _StudyContent(
      keyPoints: points,
      takeaway: takeaway?.isNotEmpty == true
          ? takeaway!
          : (plain.isEmpty ? 'Révisez régulièrement ce chapitre.' : plain.last),
      flashcards: cards,
      body: plain.take(6).join('\n\n'),
    );
  }
}

class _TopicScore {
  const _TopicScore(this.label, this.correct, this.total);
  final String label;
  final int correct;
  final int total;
  bool get mastered => total > 0 && correct / total >= 0.7;
}

List<_TopicScore> _topicScores(List<Map<String, dynamic>> answers) {
  final totals = <String, (int, int)>{};
  for (final answer in answers) {
    final topic = answer['topic']?.toString().trim().isNotEmpty == true
        ? answer['topic'].toString()
        : 'Connaissances clés';
    final current = totals[topic] ?? (0, 0);
    totals[topic] = (
      current.$1 + (answer['correct'] == true ? 1 : 0),
      current.$2 + 1,
    );
  }
  return [
    for (final entry in totals.entries)
      _TopicScore(entry.key, entry.value.$1, entry.value.$2),
  ];
}

T? _latestByVersion<T>(List<T> rows) {
  if (rows.isEmpty) return null;
  int version(T row) => switch (row) {
    Summary value => value.syncVersion,
    Exercise value => value.syncVersion,
    Quizze value => value.syncVersion,
    _ => 0,
  };
  rows.sort((a, b) => version(b).compareTo(version(a)));
  return rows.first;
}

List<Map<String, dynamic>> _decodeList(String value) {
  try {
    final decoded = jsonDecode(value);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  } catch (_) {
    return const [];
  }
}

List<String> _plainParagraphs(String markdown) {
  return markdown
      .split(RegExp(r'\n\s*\n'))
      .map(
        (part) => part.replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), ''),
      )
      .map(
        (part) =>
            part.replaceAll(RegExp(r'^(?:- |\d+\. )', multiLine: true), ''),
      )
      .map(_stripMarkdown)
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty && !part.startsWith('Generated by'))
      .toList();
}

String _stripMarkdown(String value) => value
    .replaceAll(RegExp(r'[`*_>]'), '')
    .replaceAll(RegExp(r'\[(.*?)\]\(.*?\)'), r'$1')
    .trim();

String _fallbackTopic(String prompt) {
  final words = prompt
      .replaceAll(RegExp(r'[^A-Za-zÀ-ÿ0-9 ]'), '')
      .split(RegExp(r'\s+'))
      .where((word) => word.length > 3)
      .take(3)
      .toList();
  return words.isEmpty ? 'Connaissances clés' : words.join(' ');
}

int _asInt(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;

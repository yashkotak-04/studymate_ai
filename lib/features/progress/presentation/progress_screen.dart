import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/text_styles.dart';
import '../../../shared/widgets/screen_header.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/models/subject.dart';
import '../../profile/data/user_repository.dart';
import '../../practice/data/quiz_repository.dart';
import '../data/progress_repository.dart';
import '../../../shared/models/quiz_model.dart';

enum TimeFilter { week, month, allTime }

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  TimeFilter _selectedFilter = TimeFilter.week;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final userProfile = ref.watch(currentUserProfileProvider).value;
    final dailyStatsAsync = ref.watch(dailyStatsProvider);
    final subjectProgressAsync = ref.watch(subjectProgressProvider);
    final quizHistoryAsync = ref.watch(userQuizHistoryProvider);
    final allTimeAggAsync = ref.watch(allTimeAggregatesProvider);
    final allDailyStatsAsync = ref.watch(allDailyStatsProvider);

    final quizzes = quizHistoryAsync.value ?? [];
    final now = DateTime.now();

    // Filter quizzes based on selected time window
    final filteredQuizzes = quizzes.where((q) {
      if (_selectedFilter == TimeFilter.week) {
        return now.difference(q.endTime).inDays <= 7;
      } else if (_selectedFilter == TimeFilter.month) {
        return now.difference(q.endTime).inDays <= 30;
      }
      return true;
    }).toList();

    // Chronological order for trend visualization
    final chronologicalQuizzes = List<QuizSession>.from(filteredQuizzes)
      ..sort((a, b) => a.endTime.compareTo(b.endTime));

    // Compute Metrics safely
    int totalQuizzes = filteredQuizzes.length;
    int totalQuestions = 0;
    int totalCorrect = 0;

    for (final q in filteredQuizzes) {
      totalQuestions += q.totalQuestions;
      totalCorrect += q.score;
    }

    double avgAccuracy = totalQuestions > 0
        ? (totalCorrect / totalQuestions) * 100.0
        : 0.0;

    if (_selectedFilter == TimeFilter.allTime) {
      final aggData = allTimeAggAsync.value ?? {};
      if (aggData.isNotEmpty && (aggData['totalQuizzes'] as num? ?? 0) > 0) {
        totalQuizzes =
            (aggData['totalQuizzes'] as num?)?.toInt() ?? totalQuizzes;
        avgAccuracy = (aggData['accuracy'] as num?)?.toDouble() ?? avgAccuracy;
      }
    }

    // Period-specific Study Time calculation
    final allDailyStats = allDailyStatsAsync.value ?? [];
    int studyTimeMinutes = 0;
    if (_selectedFilter == TimeFilter.week) {
      for (final ds in allDailyStats) {
        final dateStr = ds['date'] as String?;
        if (dateStr != null) {
          try {
            final dt = DateTime.parse(dateStr);
            if (now.difference(dt).inDays <= 7) {
              studyTimeMinutes += (ds['minutesStudied'] as num?)?.toInt() ?? 0;
            }
          } catch (_) {}
        }
      }
    } else if (_selectedFilter == TimeFilter.month) {
      for (final ds in allDailyStats) {
        final dateStr = ds['date'] as String?;
        if (dateStr != null) {
          try {
            final dt = DateTime.parse(dateStr);
            if (now.difference(dt).inDays <= 30) {
              studyTimeMinutes += (ds['minutesStudied'] as num?)?.toInt() ?? 0;
            }
          } catch (_) {}
        }
      }
    } else {
      final aggData = allTimeAggAsync.value ?? {};
      studyTimeMinutes = (aggData['totalMinutesStudied'] as num?)?.toInt() ?? 0;
      if (studyTimeMinutes == 0) {
        for (final ds in allDailyStats) {
          studyTimeMinutes += (ds['minutesStudied'] as num?)?.toInt() ?? 0;
        }
      }
    }

    // Find Strongest and Weakest Subjects for selected period
    String strongestSubjectName = 'N/A';
    String weakestSubjectName = 'N/A';

    if (_selectedFilter == TimeFilter.allTime) {
      final subjectProgressList = subjectProgressAsync.value ?? [];
      double highestAcc = -1.0;
      double lowestAcc = 101.0;
      for (final sp in subjectProgressList) {
        final acc = (sp['accuracy'] as num?)?.toDouble() ?? 0.0;
        final subId = sp['id'] as String? ?? '';
        final subObj = AppSubjects.getById(subId);
        if (subObj != null && (sp['totalQuestions'] as num? ?? 0) > 0) {
          if (acc > highestAcc) {
            highestAcc = acc;
            strongestSubjectName = subObj.name;
          }
          if (acc < lowestAcc) {
            lowestAcc = acc;
            weakestSubjectName = subObj.name;
          }
        }
      }
    } else {
      final Map<String, int> subCorrect = {};
      final Map<String, int> subTotal = {};
      for (final q in filteredQuizzes) {
        if (q.subjectId != 'summary_quiz' && q.subjectId.isNotEmpty) {
          subCorrect[q.subjectId] = (subCorrect[q.subjectId] ?? 0) + q.score;
          subTotal[q.subjectId] =
              (subTotal[q.subjectId] ?? 0) + q.totalQuestions;
        }
      }

      double highestAcc = -1.0;
      double lowestAcc = 101.0;
      for (final entry in subTotal.entries) {
        final totalQ = entry.value;
        if (totalQ > 0) {
          final correct = subCorrect[entry.key] ?? 0;
          final acc = (correct / totalQ) * 100.0;
          final subObj = AppSubjects.getById(entry.key);
          if (subObj != null) {
            if (acc > highestAcc) {
              highestAcc = acc;
              strongestSubjectName = subObj.name;
            }
            if (acc < lowestAcc) {
              lowestAcc = acc;
              weakestSubjectName = subObj.name;
            }
          }
        }
      }
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(title: 'Analytics & Progress'),

              // Time Filter Toggle (Week / Month / All Time)
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _buildFilterTab('Week', TimeFilter.week, isDark),
                    _buildFilterTab('Month', TimeFilter.month, isDark),
                    _buildFilterTab('All Time', TimeFilter.allTime, isDark),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Overview Grid: 4 Metric Cards
              Row(
                children: [
                  Expanded(
                    child: CustomCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                LucideIcons.listChecks,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Total Quizzes',
                                style: AppTextStyles.bodySecondary(
                                  context,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$totalQuizzes',
                            style: AppTextStyles.monoBold(
                              context,
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CustomCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                LucideIcons.target,
                                size: 16,
                                color: AppColors.accentTeal,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Avg Accuracy',
                                style: AppTextStyles.bodySecondary(
                                  context,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${avgAccuracy.toInt()}%',
                            style: AppTextStyles.monoBold(
                              context,
                              fontSize: 22,
                              color: AppColors.accentTeal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: CustomCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                LucideIcons.flame,
                                size: 16,
                                color: AppColors.accentAmber,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Current Streak',
                                style: AppTextStyles.bodySecondary(
                                  context,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${userProfile?.currentStreak ?? 0} days',
                            style: AppTextStyles.monoBold(
                              context,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CustomCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                LucideIcons.clock,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Study Time',
                                style: AppTextStyles.bodySecondary(
                                  context,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$studyTimeMinutes mins',
                            style: AppTextStyles.monoBold(
                              context,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Subject Insights: Strongest & Weakest
              CustomCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'STRONGEST',
                            style: AppTextStyles.body(
                              context,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            strongestSubjectName,
                            style: AppTextStyles.body(
                              context,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (highestAcc >= 0)
                            Text(
                              '${highestAcc.toInt()}% accuracy',
                              style: AppTextStyles.bodySecondary(
                                context,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NEEDS FOCUS',
                            style: AppTextStyles.body(
                              context,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            weakestSubjectName,
                            style: AppTextStyles.body(
                              context,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (lowestAcc <= 100)
                            Text(
                              '${lowestAcc.toInt()}% accuracy',
                              style: AppTextStyles.bodySecondary(
                                context,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Score Trend Line Chart
              Text(
                'Score Trend Over Time',
                style: AppTextStyles.displayBold(context, fontSize: 16),
              ),
              const SizedBox(height: 10),

              if (chronologicalQuizzes.isEmpty)
                const CustomCard(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                        'No quiz attempts in this period. Take a quiz to view your score trend!',
                      ),
                    ),
                  ),
                )
              else
                CustomCard(
                  child: SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: 100,
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final idx = spot.x.toInt();
                                if (idx >= 0 &&
                                    idx < chronologicalQuizzes.length) {
                                  final q = chronologicalQuizzes[idx];
                                  return LineTooltipItem(
                                    '${q.topic}\nScore: ${spot.y.toInt()}%',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  );
                                }
                                return null;
                              }).toList();
                            },
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (val) => FlLine(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                            strokeWidth: 0.8,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                if (value % 25 != 0) return const SizedBox();
                                return Text(
                                  '${value.toInt()}%',
                                  style: AppTextStyles.monoBold(
                                    context,
                                    fontSize: 10,
                                  ),
                                );
                              },
                              reservedSize: 34,
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx >= 0 &&
                                    idx < chronologicalQuizzes.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Text(
                                      'Q${idx + 1}',
                                      style: AppTextStyles.monoBold(
                                        context,
                                        fontSize: 10,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox();
                              },
                              reservedSize: 22,
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(
                              chronologicalQuizzes.length,
                              (i) => FlSpot(
                                i.toDouble(),
                                chronologicalQuizzes[i].accuracy,
                              ),
                            ),
                            isCurved: chronologicalQuizzes.length > 1,
                            color: AppColors.primary,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) =>
                                  FlDotCirclePainter(
                                    radius: 4,
                                    color: AppColors.primary,
                                    strokeWidth: 2,
                                    strokeColor: Colors.white,
                                  ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.primary.withValues(alpha: 0.12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // Subject Mastery Bar Chart
              Text(
                'Subject Mastery (%)',
                style: AppTextStyles.displayBold(context, fontSize: 16),
              ),
              const SizedBox(height: 10),

              subjectProgressAsync.when(
                data: (subjects) {
                  if (subjects.isEmpty) {
                    return const CustomCard(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text(
                            'Complete your first quiz to see subject mastery charts!',
                          ),
                        ),
                      ),
                    );
                  }

                  return CustomCard(
                    child: SizedBox(
                      height: 220,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: 100,
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                final sub = subjects[group.x.toInt()];
                                final subObj = AppSubjects.getById(
                                  sub['id'] as String,
                                );
                                return BarTooltipItem(
                                  '${subObj?.shortName ?? sub['id']}: ${rod.toY.toInt()}%',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget:
                                    (double value, TitleMeta meta) {
                                      if (value.toInt() >= subjects.length ||
                                          value.toInt() < 0)
                                        return const SizedBox();
                                      final subjectId =
                                          subjects[value.toInt()]['id']
                                              as String;
                                      final subObj = AppSubjects.getById(
                                        subjectId,
                                      );
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8.0,
                                        ),
                                        child: Text(
                                          subObj?.shortName ??
                                              subjectId.toUpperCase(),
                                          style: AppTextStyles.monoBold(
                                            context,
                                            fontSize: 11,
                                          ),
                                        ),
                                      );
                                    },
                                reservedSize: 28,
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  if (value % 25 != 0) return const SizedBox();
                                  return Text(
                                    '${value.toInt()}',
                                    style: AppTextStyles.monoBold(
                                      context,
                                      fontSize: 10,
                                    ),
                                  );
                                },
                                reservedSize: 28,
                              ),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                              strokeWidth: 0.8,
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: List.generate(subjects.length, (index) {
                            final data = subjects[index];
                            final accuracy =
                                (data['accuracy'] as num?)?.toDouble() ?? 0.0;
                            final subObj = AppSubjects.getById(
                              data['id'] as String,
                            );
                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: accuracy,
                                  color: subObj?.color ?? AppColors.primary,
                                  width: 18,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) =>
                    Center(child: Text('Error loading charts: $e')),
              ),
              const SizedBox(height: 20),

              // Recent Quiz History List
              Text(
                'Recent Quiz Sessions',
                style: AppTextStyles.displayBold(context, fontSize: 16),
              ),
              const SizedBox(height: 10),

              if (filteredQuizzes.isEmpty)
                CustomCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'No quiz activity in this time period.',
                        style: AppTextStyles.bodySecondary(context),
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredQuizzes.take(5).length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final quiz = filteredQuizzes[index];
                    final subObj = AppSubjects.getById(quiz.subjectId);
                    final isPass = quiz.accuracy >= 70;

                    return CustomCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isPass
                                  ? AppColors.success.withOpacity(0.15)
                                  : AppColors.warning.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              quiz.isMockTest
                                  ? LucideIcons.layers
                                  : LucideIcons.checkSquare,
                              size: 18,
                              color: isPass
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  quiz.isMockTest
                                      ? 'Mock Exam'
                                      : (subObj?.name ?? quiz.topic),
                                  style: AppTextStyles.body(
                                    context,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${quiz.score}/${quiz.totalQuestions} Correct • ${quiz.accuracy.toInt()}%',
                                  style: AppTextStyles.bodySecondary(
                                    context,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${quiz.durationMinutes}m',
                            style: AppTextStyles.monoBold(
                              context,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTab(String label, TimeFilter filter, bool isDark) {
    final isSelected = _selectedFilter == filter;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedFilter = filter),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.body(
              context,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: isSelected
                  ? Colors.white
                  : (isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

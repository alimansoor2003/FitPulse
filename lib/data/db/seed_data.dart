/// The training split, seeded into SQLite on first launch.
///
/// Day 4 is a rest day and therefore has no exercises.
class TrainingDay {
  const TrainingDay({
    required this.index,
    required this.titleEn,
    required this.titleAr,
    required this.subtitle,
    required this.isRest,
  });

  final int index;
  final String titleEn;
  final String titleAr;
  final String subtitle;
  final bool isRest;
}

const List<TrainingDay> kTrainingDays = <TrainingDay>[
  TrainingDay(
    index: 1,
    titleEn: 'Chest & Triceps',
    titleAr: 'الصدر والترايسبس',
    subtitle: 'Push - 5 exercises',
    isRest: false,
  ),
  TrainingDay(
    index: 2,
    titleEn: 'Back & Biceps',
    titleAr: 'الظهر والبايسبس',
    subtitle: 'Pull - 5 exercises',
    isRest: false,
  ),
  TrainingDay(
    index: 3,
    titleEn: 'Legs & Shoulders',
    titleAr: 'الأرجل والأكتاف',
    subtitle: 'Lower + delts - 6 exercises',
    isRest: false,
  ),
  TrainingDay(
    index: 4,
    titleEn: 'Rest Day',
    titleAr: 'يوم راحة',
    subtitle: 'Recover - no training',
    isRest: true,
  ),
];

TrainingDay trainingDay(int index) =>
    kTrainingDays.firstWhere((TrainingDay d) => d.index == index,
        orElse: () => kTrainingDays.last);

class SeedExercise {
  const SeedExercise({
    required this.dayIndex,
    required this.nameEn,
    required this.nameAr,
    required this.targetLabel,
    required this.defaultSets,
    required this.restSeconds,
    required this.orderIndex,
  });

  final int dayIndex;
  final String nameEn;
  final String nameAr;
  final String targetLabel;
  final int defaultSets;
  final int restSeconds;
  final int orderIndex;
}

const List<SeedExercise> kSeedExercises = <SeedExercise>[
  // ---- Day 1: Chest & Triceps ----
  SeedExercise(
    dayIndex: 1,
    nameEn: 'Incline Chest Press',
    nameAr: 'جهاز صدر علوي',
    targetLabel: '3 sets',
    defaultSets: 3,
    restSeconds: 120,
    orderIndex: 1,
  ),
  SeedExercise(
    dayIndex: 1,
    nameEn: 'Flat Chest Press',
    nameAr: 'صدر مستوي',
    targetLabel: '3 sets',
    defaultSets: 3,
    restSeconds: 120,
    orderIndex: 2,
  ),
  SeedExercise(
    dayIndex: 1,
    nameEn: 'Cable Chest Flyes',
    nameAr: 'صدر سحاب تفتيح',
    targetLabel: '2-3 sets',
    defaultSets: 3,
    restSeconds: 90,
    orderIndex: 3,
  ),
  SeedExercise(
    dayIndex: 1,
    nameEn: 'Triceps Cable Pushdown',
    nameAr: 'تراي كيبل',
    targetLabel: '3 sets',
    defaultSets: 3,
    restSeconds: 75,
    orderIndex: 4,
  ),
  SeedExercise(
    dayIndex: 1,
    nameEn: 'Overhead Triceps Extension',
    nameAr: 'تراي خلفي',
    targetLabel: '2-3 sets',
    defaultSets: 3,
    restSeconds: 75,
    orderIndex: 5,
  ),

  // ---- Day 2: Back & Biceps ----
  SeedExercise(
    dayIndex: 2,
    nameEn: 'Lat Pulldown',
    nameAr: 'سحب عالي',
    targetLabel: '3 sets',
    defaultSets: 3,
    restSeconds: 120,
    orderIndex: 1,
  ),
  SeedExercise(
    dayIndex: 2,
    nameEn: 'Seated Cable Row',
    nameAr: 'سحب أرضي أفقي',
    targetLabel: '3 sets',
    defaultSets: 3,
    restSeconds: 120,
    orderIndex: 2,
  ),
  SeedExercise(
    dayIndex: 2,
    nameEn: 'One-Arm Dumbbell Row',
    nameAr: 'سحب بالدمبل فردي',
    targetLabel: '2-3 sets',
    defaultSets: 3,
    restSeconds: 90,
    orderIndex: 3,
  ),
  SeedExercise(
    dayIndex: 2,
    nameEn: 'Biceps Barbell / Cable Curl',
    nameAr: 'بايسبس بالبار أو الكيبل',
    targetLabel: '3 sets',
    defaultSets: 3,
    restSeconds: 75,
    orderIndex: 4,
  ),
  SeedExercise(
    dayIndex: 2,
    nameEn: 'Hammer Curls',
    nameAr: 'بايسبس هامر',
    targetLabel: '2-3 sets',
    defaultSets: 3,
    restSeconds: 75,
    orderIndex: 5,
  ),

  // ---- Day 3: Legs & Shoulders ----
  SeedExercise(
    dayIndex: 3,
    nameEn: 'Leg Extension',
    nameAr: 'تراكيز أرجل أمامي',
    targetLabel: '3 sets',
    defaultSets: 3,
    restSeconds: 90,
    orderIndex: 1,
  ),
  SeedExercise(
    dayIndex: 3,
    nameEn: 'Leg Press',
    nameAr: 'مكبس أرجل',
    targetLabel: '3 sets',
    defaultSets: 3,
    restSeconds: 150,
    orderIndex: 2,
  ),
  SeedExercise(
    dayIndex: 3,
    nameEn: 'Leg Curl',
    nameAr: 'أرجل خلفي',
    targetLabel: '3 sets',
    defaultSets: 3,
    restSeconds: 90,
    orderIndex: 3,
  ),
  SeedExercise(
    dayIndex: 3,
    nameEn: 'Dumbbell Shoulder Press',
    nameAr: 'ضغط أكتاف',
    targetLabel: '3 sets',
    defaultSets: 3,
    restSeconds: 120,
    orderIndex: 4,
  ),
  SeedExercise(
    dayIndex: 3,
    nameEn: 'Lateral Raise',
    nameAr: 'رفرفة جانبي',
    targetLabel: '4 sets',
    defaultSets: 4,
    restSeconds: 60,
    orderIndex: 5,
  ),
  SeedExercise(
    dayIndex: 3,
    nameEn: 'Rear Delt Fly',
    nameAr: 'كتف خلفي',
    targetLabel: '3 sets',
    defaultSets: 3,
    restSeconds: 60,
    orderIndex: 6,
  ),
];

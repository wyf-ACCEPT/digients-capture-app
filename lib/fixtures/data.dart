import '../models/task.dart';

const fixtureCategories = <Category>[
  Category(id: 'household', title: 'Household', taskCount: 142, rewardPoints: 320, tall: true),
  Category(id: 'industrial', title: 'Industrial', taskCount: 87, rewardPoints: 580),
  Category(id: 'sports', title: 'Sports', taskCount: 64, rewardPoints: 450, tall: true),
  Category(id: 'daily', title: 'Daily Life', taskCount: 211, rewardPoints: 180),
  Category(id: 'cooking', title: 'Cooking', taskCount: 38, rewardPoints: 390, soon: true),
  Category(id: 'mobility', title: 'Mobility', taskCount: 0, soon: true),
];

const fixtureProfile = Profile(
  displayName: 'Maya Chen',
  uid: 'DGT-A47K3PX9',
  balancePoints: 4280,
  pendingPoints: 1500,
  hoursLogged: 47.5,
  submittedCount: 132,
  approvalRate: 0.94,
  capabilities: [0.85, 0.62, 0.40, 0.78, 0.70, 0.94],
);

const fixtureLeaderboard = <LeaderRow>[
  LeaderRow(rank: 1, name: 'Tomás A.', hours: 184.2, points: 18420),
  LeaderRow(rank: 2, name: 'Priya R.', hours: 162.8, points: 16210),
  LeaderRow(rank: 3, name: 'Aiko S.', hours: 158.4, points: 15730),
  LeaderRow(rank: 27, name: 'Maya Chen', hours: 47.5, points: 4280, isYou: true),
  LeaderRow(rank: 28, name: 'Carlos V.', hours: 46.0, points: 4100),
];

const fixtureTasks = <Task>[
  Task(
    id: 'h-towel',
    categoryId: 'household',
    tag: 'Folding',
    title: 'Fold a towel and stack it on the shelf',
    publisher: 'Verlet Robotics',
    rewardPoints: 320,
    duration: '~2 min',
    slots: '12 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Bright indoor',
    surface: 'Flat counter',
    steps: [
      'Lay the towel flat on a counter or table.',
      'Fold the towel in half horizontally.',
      'Fold it in half again vertically.',
      'Carry it to the shelf and place it neatly on top of the existing pile.',
    ],
  ),
  Task(
    id: 'h-table',
    categoryId: 'household',
    tag: 'Wiping',
    title: 'Wipe the dining table after a meal',
    publisher: 'Verlet Robotics',
    rewardPoints: 180,
    duration: '~3 min',
    slots: '4 / 30 slots',
    difficulty: 'Easy',
    lighting: 'Bright indoor',
    surface: 'Dining table',
    steps: [
      'Pick up a clean cloth and dampen it slightly with water.',
      'Wipe the table surface in long, deliberate strokes.',
      'Cover every region; pay attention to edges.',
      'Return the cloth to its place.',
    ],
  ),
  Task(
    id: 'h-counter',
    categoryId: 'household',
    tag: 'Cleaning',
    title: 'Clear and wipe the kitchen counter',
    publisher: 'Verlet Robotics',
    rewardPoints: 240,
    duration: '~4 min',
    slots: '8 / 40 slots',
    difficulty: 'Easy',
    lighting: 'Bright indoor',
    surface: 'Counter top',
    steps: [
      'Remove all items from the counter and place them aside.',
      'Wipe the counter with a damp cloth in long strokes.',
      'Return items to the counter in their original positions.',
    ],
  ),
  Task(
    id: 'h-laundry',
    categoryId: 'household',
    tag: 'Folding',
    title: 'Fold a t-shirt on a flat surface',
    publisher: 'Verlet Robotics',
    rewardPoints: 280,
    duration: '~3 min',
    slots: '15 / 60 slots',
    difficulty: 'Easy',
    lighting: 'Bright indoor',
    surface: 'Bed or table',
    steps: [
      'Lay the t-shirt face-down on a flat surface.',
      'Fold one sleeve across the back of the shirt.',
      'Repeat for the other sleeve.',
      'Fold the bottom of the shirt up to meet the collar.',
    ],
  ),
  Task(
    id: 'i-bottlecap',
    categoryId: 'industrial',
    tag: 'Assembly',
    title: 'Cap a plastic bottle and place it on the line',
    publisher: 'Verlet Industrial',
    rewardPoints: 580,
    duration: '~2 min',
    slots: '3 / 25 slots',
    difficulty: 'Medium',
    lighting: 'Even overhead',
    surface: 'Conveyor or workbench',
    steps: [
      'Pick up an uncapped bottle from the input bin.',
      'Pick up a cap and align it with the bottle threads.',
      'Twist the cap on until snug.',
      'Place the bottle on the output line.',
    ],
  ),
  Task(
    id: 'i-hex',
    categoryId: 'industrial',
    tag: 'Tooling',
    title: 'Tighten three hex bolts on a bracket',
    publisher: 'Verlet Industrial',
    rewardPoints: 720,
    duration: '~4 min',
    slots: '2 / 20 slots',
    difficulty: 'Medium',
    lighting: 'Even overhead',
    surface: 'Workbench',
    steps: [
      'Pick up the hex driver.',
      'Insert it into the first bolt and tighten clockwise.',
      'Repeat for bolts two and three.',
      'Place the driver back on the bench.',
    ],
  ),
];

List<Task> tasksForCategory(String categoryId) =>
    fixtureTasks.where((t) => t.categoryId == categoryId).toList();

Task? findTask(String id) {
  for (final t in fixtureTasks) {
    if (t.id == id) return t;
  }
  return null;
}

Category? findCategory(String id) {
  for (final c in fixtureCategories) {
    if (c.id == id) return c;
  }
  return null;
}

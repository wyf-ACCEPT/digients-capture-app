import '../models/recording.dart';
import '../models/task.dart';

// Categories follow the 5 scenes from the data collection guide.
// IDs use kebab-case slugs and are also the value baked into export
// filenames as `<categoryId>-<sessionId>`.
const fixtureCategories = <Category>[
  Category(id: 'living-room', title: 'Living Room', taskCount: 8, rewardPoints: 320, tall: true),
  Category(id: 'kitchen', title: 'Kitchen', taskCount: 8, rewardPoints: 380),
  Category(id: 'bedroom', title: 'Bedroom', taskCount: 4, rewardPoints: 280, tall: true),
  Category(id: 'convenience-store', title: 'Convenience Store', taskCount: 5, rewardPoints: 420),
  Category(id: 'bathroom', title: 'Bathroom', taskCount: 3, rewardPoints: 260),
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

// Durations and slot counts are kept consistent with the guide's
// time bounds (e.g. 10–20s short, 30–60s combo, 60–180s long).
const fixtureTasks = <Task>[
  // ──────────────── Living Room ────────────────
  Task(
    id: 'lr-pick-remote',
    categoryId: 'living-room',
    tag: 'Pick & Place',
    title: 'Pick up and place the remote control',
    publisher: 'Digients Tasks',
    rewardPoints: 220,
    duration: '10–20 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Bright indoor',
    surface: 'Coffee table',
    steps: [
      'Place the remote control on the living room table.',
      'Pick it up, move it to a different spot on the table, sofa, or chair, and pause for 1 second.',
      'Pick it up again and return it to its original spot, then pause for 1 second.',
      'Vary the destination spot across attempts; keep both hands in frame.',
    ],
  ),
  Task(
    id: 'lr-pick-phone',
    categoryId: 'living-room',
    tag: 'Pick & Place',
    title: 'Pick up and place a phone',
    publisher: 'Digients Tasks',
    rewardPoints: 220,
    duration: '10–20 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Bright indoor',
    surface: 'Coffee table',
    steps: [
      'Place the phone on the living room table.',
      'Pick it up, move it to a different spot on the table, sofa, or chair, and pause for 1 second.',
      'Pick it up again and return it to its original spot, then pause for 1 second.',
      'Vary the destination spot across attempts; keep both hands in frame.',
    ],
  ),
  Task(
    id: 'lr-pick-powerbank',
    categoryId: 'living-room',
    tag: 'Pick & Place',
    title: 'Pick up and place a power bank',
    publisher: 'Digients Tasks',
    rewardPoints: 220,
    duration: '10–20 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Bright indoor',
    surface: 'Coffee table',
    steps: [
      'Place the power bank on the living room table.',
      'Pick it up, move it to a different spot on the table, sofa, or chair, and pause for 1 second.',
      'Pick it up again and return it to its original spot, then pause for 1 second.',
      'Vary the destination spot across attempts; keep both hands in frame.',
    ],
  ),
  Task(
    id: 'lr-pick-combo',
    categoryId: 'living-room',
    tag: 'Pick & Place',
    title: 'Pick & place — remote + phone + power bank',
    publisher: 'Digients Tasks',
    rewardPoints: 320,
    duration: '30–60 s',
    slots: '0 / 40 slots',
    difficulty: 'Medium',
    lighting: 'Bright indoor',
    surface: 'Coffee table',
    steps: [
      'Place the remote control, phone, and power bank on the table together.',
      'Pick up the remote, move it to a new spot on the table / sofa / chair, pause 1 s, then return it.',
      'Repeat the same routine for the phone, then for the power bank.',
      'Vary destinations across items; keep the full motion in frame.',
    ],
  ),
  Task(
    id: 'lr-switch-light',
    categoryId: 'living-room',
    tag: 'Switch',
    title: 'Toggle a wall light switch',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '10–20 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Mixed',
    surface: 'Wall switch',
    steps: [
      'Walk up to the wall switch.',
      'Press it once to turn the light on; pause 2 s so the camera catches the light coming on.',
      'Press it again to turn the light off; pause 2 s so the camera catches it going off.',
      'Press fully each time — no half-presses; keep your hand visible.',
    ],
  ),
  Task(
    id: 'lr-switch-drawer',
    categoryId: 'living-room',
    tag: 'Switch',
    title: 'Open and close a drawer',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '10–20 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Bright indoor',
    surface: 'Living-room drawer',
    steps: [
      'Walk up to the drawer.',
      'Grip the handle and pull it fully open; pause 2 s.',
      'Push it fully closed; pause 2 s.',
      'Pull / push all the way each time — no half motions.',
    ],
  ),
  Task(
    id: 'lr-switch-curtain',
    categoryId: 'living-room',
    tag: 'Switch',
    title: 'Open and close a curtain',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '10–20 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Mixed',
    surface: 'Window',
    steps: [
      'Walk up to the curtain.',
      'Grab the cord or fabric and pull it fully open to let light in; pause 2 s.',
      'Pull it fully closed again; pause 2 s.',
      'Always go from end to end — no half motions.',
    ],
  ),
  Task(
    id: 'lr-switch-combo',
    categoryId: 'living-room',
    tag: 'Switch',
    title: 'Light + drawer + curtain combo',
    publisher: 'Digients Tasks',
    rewardPoints: 300,
    duration: '30–60 s',
    slots: '0 / 40 slots',
    difficulty: 'Medium',
    lighting: 'Mixed',
    surface: 'Living room',
    steps: [
      'Toggle the wall light on, pause 2 s, then off, pause 2 s.',
      'Pull the drawer fully open, pause 2 s, then push it fully closed, pause 2 s.',
      'Pull the curtain fully open, pause 2 s, then close it, pause 2 s.',
      'Run all three in sequence; keep your hand in frame the whole time.',
    ],
  ),

  // ──────────────── Bedroom ────────────────
  Task(
    id: 'br-fold-clothes-single',
    categoryId: 'bedroom',
    tag: 'Folding',
    title: 'Fold a single piece of clothing',
    publisher: 'Digients Tasks',
    rewardPoints: 240,
    duration: '30–60 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Bright indoor',
    surface: 'Bed',
    steps: [
      'Lay one clean t-shirt, shirt, or pair of trousers flat on the bed.',
      'Fold both sides toward the centre, then roll or fold up from the bottom.',
      'Place the folded item on the headboard or wardrobe shelf and pause 1 s.',
      'Keep both hands visible — do not hold the garment up in front of the camera.',
    ],
  ),
  Task(
    id: 'br-fold-clothes-multi',
    categoryId: 'bedroom',
    tag: 'Folding',
    title: 'Fold 2–3 pieces of clothing',
    publisher: 'Digients Tasks',
    rewardPoints: 380,
    duration: '60–180 s',
    slots: '0 / 30 slots',
    difficulty: 'Medium',
    lighting: 'Bright indoor',
    surface: 'Bed',
    steps: [
      'Lay 2–3 clean garments flat on the bed.',
      'Fold each one in turn — sides to centre, then bottom up — and stack on the shelf.',
      'Finish each garment fully before starting the next.',
      'Use a natural pace; keep hands in frame throughout.',
    ],
  ),
  Task(
    id: 'br-fold-towel-single',
    categoryId: 'bedroom',
    tag: 'Folding',
    title: 'Fold a single towel',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '15–30 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Bright indoor',
    surface: 'Bed',
    steps: [
      'Lay one clean towel (face / bath) flat on the bed.',
      'Fold it in half along the long edge, then in half along the short edge into a square.',
      'Place it on the wash counter or wardrobe shelf.',
      'Hands stay in frame; do not block the camera with the towel.',
    ],
  ),
  Task(
    id: 'br-fold-towel-multi',
    categoryId: 'bedroom',
    tag: 'Folding',
    title: 'Fold 2–3 towels',
    publisher: 'Digients Tasks',
    rewardPoints: 320,
    duration: '30–90 s',
    slots: '0 / 30 slots',
    difficulty: 'Medium',
    lighting: 'Bright indoor',
    surface: 'Bed',
    steps: [
      'Lay 2–3 clean towels flat on the bed.',
      'Fold each one — long edge in half, then short edge in half — and stack.',
      'Finish each towel before moving to the next.',
      'Natural pace; keep hands in frame.',
    ],
  ),

  // ──────────────── Kitchen ────────────────
  Task(
    id: 'kt-cut-fruit-single',
    categoryId: 'kitchen',
    tag: 'Cutting',
    title: 'Cut a single piece of fruit',
    publisher: 'Digients Tasks',
    rewardPoints: 280,
    duration: '30–60 s',
    slots: '0 / 40 slots',
    difficulty: 'Medium',
    lighting: 'Bright indoor',
    surface: 'Cutting board',
    steps: [
      'Wash one apple, orange, banana, or similar fruit.',
      'Place the fruit on the board and chop into pieces with the knife.',
      'Transfer the pieces to a plate.',
      'Mind the knife — do not raise it high enough that your hand leaves the frame.',
    ],
  ),
  Task(
    id: 'kt-cut-fruit-multi',
    categoryId: 'kitchen',
    tag: 'Cutting',
    title: 'Cut 2–3 different fruits',
    publisher: 'Digients Tasks',
    rewardPoints: 420,
    duration: '60–180 s',
    slots: '0 / 30 slots',
    difficulty: 'Medium',
    lighting: 'Bright indoor',
    surface: 'Cutting board',
    steps: [
      'Wash 2–3 different fruits (e.g. apple, orange, banana).',
      'Cut each one in turn on the board, transferring pieces to the plate after each.',
      'Pin the fruit with one hand, cut with the other; keep both visible.',
      'Upload as one clip — do not split per fruit.',
    ],
  ),
  Task(
    id: 'kt-tableware-single',
    categoryId: 'kitchen',
    tag: 'Tableware',
    title: 'Set out a single piece of tableware',
    publisher: 'Digients Tasks',
    rewardPoints: 180,
    duration: '15–30 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Bright indoor',
    surface: 'Kitchen counter',
    steps: [
      'Pick one item (plate, bowl, chopsticks, fork, or spoon) and set it neatly on the counter or stovetop.',
      'After placing, pick it back up and return it to its original spot.',
      'Use the full reach-grasp-place motion; do not rush.',
      'Different items count as separate clips.',
    ],
  ),
  Task(
    id: 'kt-tableware-multi',
    categoryId: 'kitchen',
    tag: 'Tableware',
    title: 'Set out multiple pieces of tableware',
    publisher: 'Digients Tasks',
    rewardPoints: 320,
    duration: '45–90 s',
    slots: '0 / 30 slots',
    difficulty: 'Medium',
    lighting: 'Bright indoor',
    surface: 'Kitchen counter',
    steps: [
      'Place each item (plate, bowl, chopsticks, fork, spoon) on the counter one by one, neatly arranged.',
      'Optionally collect them back to their original spot one by one.',
      'Budget about 15–30 s per item; upload as one combined clip.',
      'Light grip; do not drop bowls.',
    ],
  ),
  Task(
    id: 'kt-pour-water',
    categoryId: 'kitchen',
    tag: 'Pouring',
    title: 'Pour water from a kettle into a cup',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '15–30 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Bright indoor',
    surface: 'Kitchen counter',
    steps: [
      'Fill the kettle with water; place a cup on the counter.',
      'Pick up the kettle, aim at the cup, and pour to about 70–80% full.',
      'Set the kettle back on the counter.',
      'Try different cups (glass, ceramic) across attempts; one pour = one clip.',
    ],
  ),
  Task(
    id: 'kt-pour-coffee',
    categoryId: 'kitchen',
    tag: 'Pouring',
    title: 'Pour coffee from a kettle into a cup',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '15–30 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Bright indoor',
    surface: 'Kitchen counter',
    steps: [
      'Fill the kettle with coffee; place a cup on the counter.',
      'Pick up the kettle, aim at the cup, and pour to about 70–80% full.',
      'Set the kettle back on the counter.',
      'Try different cups (glass, ceramic) across attempts; one pour = one clip.',
    ],
  ),
  Task(
    id: 'kt-pour-tea',
    categoryId: 'kitchen',
    tag: 'Pouring',
    title: 'Pour tea from a kettle into a cup',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '15–30 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Bright indoor',
    surface: 'Kitchen counter',
    steps: [
      'Fill the kettle with tea; place a cup on the counter.',
      'Pick up the kettle, aim at the cup, and pour to about 70–80% full.',
      'Set the kettle back on the counter.',
      'Try different cups (glass, ceramic) across attempts; one pour = one clip.',
    ],
  ),
  Task(
    id: 'kt-pour-combo',
    categoryId: 'kitchen',
    tag: 'Pouring',
    title: 'Pour water + coffee + tea',
    publisher: 'Digients Tasks',
    rewardPoints: 360,
    duration: '30–90 s',
    slots: '0 / 30 slots',
    difficulty: 'Medium',
    lighting: 'Bright indoor',
    surface: 'Kitchen counter',
    steps: [
      'Prepare the kettle and cups (use water, tea, or coffee).',
      'Pour 2–3 cups in sequence, swapping cup styles where possible.',
      'After each pour, set the kettle down.',
      'Upload as one clip — pouring multiple cups is a single task.',
    ],
  ),

  // ──────────────── Bathroom ────────────────
  Task(
    id: 'bt-wipe-toilet',
    categoryId: 'bathroom',
    tag: 'Cleaning',
    title: 'Wipe down the outside of the toilet',
    publisher: 'Digients Tasks',
    rewardPoints: 320,
    duration: '120–240 s',
    slots: '0 / 30 slots',
    difficulty: 'Medium',
    lighting: 'Bright indoor',
    surface: 'Toilet',
    steps: [
      'Take a clean cloth and spritz a little cleaner (a damp cloth is fine).',
      'Wipe the tank, lid, and outer body of the toilet, going back and forth.',
      'Cover all outside surfaces; keep your hand visible — do not let your body block the toilet.',
      'Return the cloth when finished.',
    ],
  ),
  Task(
    id: 'bt-clean-toilet-seat',
    categoryId: 'bathroom',
    tag: 'Cleaning',
    title: 'Clean the toilet seat ring',
    publisher: 'Digients Tasks',
    rewardPoints: 240,
    duration: '60–120 s',
    slots: '0 / 30 slots',
    difficulty: 'Easy',
    lighting: 'Bright indoor',
    surface: 'Toilet',
    steps: [
      'Lift the toilet seat ring up; record the lift motion.',
      'Wipe the underside, then flip and wipe the top so both sides are clean.',
      'Lower the seat back into place; put the cloth away.',
      'Mind hygiene — do not splash on yourself.',
    ],
  ),
  Task(
    id: 'bt-clean-basin',
    categoryId: 'bathroom',
    tag: 'Cleaning',
    title: 'Clean the wash basin',
    publisher: 'Digients Tasks',
    rewardPoints: 280,
    duration: '120–240 s',
    slots: '0 / 30 slots',
    difficulty: 'Medium',
    lighting: 'Bright indoor',
    surface: 'Basin',
    steps: [
      'Wipe the inside of the basin, then the surrounding counter, then the tap.',
      'Make sure every wipe motion is captured; do not skip regions.',
      'Avoid splashing water around — clean as you would normally.',
      'Return the cloth.',
    ],
  ),

  // ──────────────── Convenience Store ────────────────
  Task(
    id: 'cs-pick-shelf-single',
    categoryId: 'convenience-store',
    tag: 'Pick & Place',
    title: 'Take a single product off the shelf',
    publisher: 'Digients Tasks',
    rewardPoints: 280,
    duration: '30–60 s',
    slots: '0 / 40 slots',
    difficulty: 'Medium',
    lighting: 'Even overhead',
    surface: 'Store shelf',
    steps: [
      'Set up a shelf with everyday convenience-store items (water, biscuits, toothpaste, etc.).',
      'Take one item off the shelf and place it in the basket in front of you; pause 1 s.',
      'Pick it back out of the basket and return it to its original shelf spot.',
      'Use different shelf heights across attempts but stay reachable — one item = one clip.',
    ],
  ),
  Task(
    id: 'cs-pick-shelf-multi',
    categoryId: 'convenience-store',
    tag: 'Pick & Place',
    title: 'Take 2–3 products off the shelf',
    publisher: 'Digients Tasks',
    rewardPoints: 420,
    duration: '60–180 s',
    slots: '0 / 30 slots',
    difficulty: 'Medium',
    lighting: 'Even overhead',
    surface: 'Store shelf',
    steps: [
      'Stock the shelf with assorted convenience items.',
      'For each of 2–3 items: take it off the shelf, place in the basket, pause 1 s, then return it.',
      'Vary which shelves you pull from (top, middle, bottom).',
      'Upload as a single clip — multiple items is one task.',
    ],
  ),
  Task(
    id: 'cs-wipe-counter',
    categoryId: 'convenience-store',
    tag: 'Cleaning',
    title: 'Wipe down the counter / shelf surface',
    publisher: 'Digients Tasks',
    rewardPoints: 240,
    duration: '60–120 s',
    slots: '0 / 30 slots',
    difficulty: 'Easy',
    lighting: 'Even overhead',
    surface: 'Counter',
    steps: [
      'Take a damp cloth.',
      'Wipe the cashier counter or shelf surface left to right, covering the whole top.',
      'Keep your hand visible throughout the wipe.',
      'Return the cloth when done.',
    ],
  ),
  Task(
    id: 'cs-handover-single',
    categoryId: 'convenience-store',
    tag: 'Handover',
    title: 'Hand a single product to a customer',
    publisher: 'Digients Tasks',
    rewardPoints: 220,
    duration: '15–30 s',
    slots: '0 / 40 slots',
    difficulty: 'Easy',
    lighting: 'Even overhead',
    surface: 'Counter',
    steps: [
      'Stock a shelf with items; have a friend or family member stand in front of you as the "customer".',
      'Take one item (e.g. a bottle of water) off the shelf and hand it to the customer.',
      'The customer takes it; pause 1 s.',
      'Both your hand and the customer\'s hand can be in frame — natural handover motion.',
    ],
  ),
  Task(
    id: 'cs-handover-multi',
    categoryId: 'convenience-store',
    tag: 'Handover',
    title: 'Hand 2–3 products to a customer',
    publisher: 'Digients Tasks',
    rewardPoints: 360,
    duration: '30–90 s',
    slots: '0 / 30 slots',
    difficulty: 'Medium',
    lighting: 'Even overhead',
    surface: 'Counter',
    steps: [
      'Stock a shelf and have a "customer" stand opposite you.',
      'Take an item off the shelf and hand it over; pause 1 s.',
      'Repeat for 2–3 different items.',
      'Upload as one clip — multiple handovers is a single task.',
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

/// Human-readable title for a recording — mirrors the structure of the
/// exported archive filename `<category>-<subSlug>-<sessionId>.tar.gz` so
/// the user can correlate what they see in the Submissions list with the
/// file they just shared. Falls back to the bare session id prefix for
/// recordings that pre-date categoryId/taskId tracking.
String recordingDisplayTitle(Recording r) {
  final cat = r.categoryId != null ? findCategory(r.categoryId!) : null;

  String? subSlug;
  if (r.taskId != null && r.taskId!.isNotEmpty) {
    final match = RegExp(r'^[a-z]{2}-').firstMatch(r.taskId!);
    subSlug = match != null ? r.taskId!.substring(match.end) : r.taskId!;
  }

  if (cat != null && subSlug != null && subSlug.isNotEmpty) {
    return '${cat.title} · ${_titleCase(subSlug)}';
  }
  if (cat != null) {
    return '${cat.title} · ${r.sessionId.substring(0, 8)}';
  }
  return 'Recording ${r.sessionId.substring(0, 8)}';
}

String _titleCase(String slug) {
  return slug
      .split('-')
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

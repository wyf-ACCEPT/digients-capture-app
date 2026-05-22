import '../models/recording.dart';
import '../models/task.dart';

// WF2 (plan 6e20) scene catalog. Slugs must stay in sync with the
// SCENE_CATALOG constant in digients-api/src/lib/s3.ts — both ends
// validate the same set, and changing one without the other breaks
// `/v2/submissions/init`.
//
// Naming convention:
//   - Category.id     = major slug (single English word, ≤ 9 chars)
//   - Task.id         = `<major>-<minor>` (composite, used as S3 path
//                       segment AND as the unique key for findTask)
//   - Category.title  = full Chinese name shown in UI
//   - Task.title      = full Chinese name shown in UI
//
// Chinese labels are populated directly in the `title` field; the i18n
// switch in lib/l10n/localized_fixtures.dart falls through to .title for
// any id it doesn't explicitly map, so English-locale users also see the
// Chinese name — intentional, this is China-only deployment.
//
// Each task carries placeholder metadata (rewardPoints / duration /
// difficulty / lighting / surface / steps). Real per-task instructions
// will come later when Matt + Dylan author them; for now we render a
// single generic Chinese reminder so the steps panel isn't empty.

const _kGenericStep =
    '按真实工作场景采集，保持双手清晰可见，避免遮挡画面。';

const fixtureCategories = <Category>[
  Category(id: 'kitchen',   title: '厨房',                  taskCount: 5, rewardPoints: 1000, tall: true),
  Category(id: 'warehouse', title: '仓库 / 快递仓 / 分拣站',  taskCount: 5, rewardPoints: 1000),
  Category(id: 'delivery',  title: '配送站',                taskCount: 3, rewardPoints: 600,  tall: true),
  Category(id: 'internet',  title: '网吧',                  taskCount: 3, rewardPoints: 600),
  Category(id: 'store',     title: '商店',                  taskCount: 4, rewardPoints: 800,  tall: true),
  Category(id: 'garment',   title: '制衣车间',              taskCount: 3, rewardPoints: 600),
  Category(id: 'repair',    title: '维修车间',              taskCount: 3, rewardPoints: 600),
  // Catch-all: collectors should pick this when the actual scene doesn't
  // fit any of the 7 industry verticals above. Keep the single 'misc'
  // task — if a specific minor recurs, give it its own slot.
  Category(id: 'other',     title: '其他场景',              taskCount: 1, rewardPoints: 200),
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

// 26 tasks across the 7 categories (plan 6e20 WF2 final catalog). Order
// inside each category matches the team's scene-catalog spreadsheet.
const fixtureTasks = <Task>[
  // ──────────────── 厨房 ────────────────
  Task(
    id: 'kitchen-clean',
    categoryId: 'kitchen',
    tag: '清洁',
    title: '环境清洁',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '60–180 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Mixed',
    surface: '厨房地面 / 墙面',
    steps: [_kGenericStep],
  ),
  Task(
    id: 'kitchen-tools',
    categoryId: 'kitchen',
    tag: '清洁',
    title: '台面与器具清洁',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '60–180 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Mixed',
    surface: '台面 / 器具',
    steps: [_kGenericStep],
  ),
  Task(
    id: 'kitchen-wash',
    categoryId: 'kitchen',
    tag: '处理',
    title: '食材清洗',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '30–90 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Bright indoor',
    surface: '水槽',
    steps: [_kGenericStep],
  ),
  Task(
    id: 'kitchen-cook',
    categoryId: 'kitchen',
    tag: '烹饪',
    title: '食材烹饪',
    publisher: 'Digients Tasks',
    rewardPoints: 240,
    duration: '60–180 s',
    slots: '0 / 40 slots',
    difficulty: 'Medium',
    lighting: 'Mixed',
    surface: '炉灶',
    steps: [_kGenericStep],
  ),
  Task(
    id: 'kitchen-drink',
    categoryId: 'kitchen',
    tag: '调制',
    title: '饮品制备',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '30–90 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Bright indoor',
    surface: '吧台',
    steps: [_kGenericStep],
  ),

  // ──────────────── 仓库 / 快递仓 / 分拣站 ────────────────
  Task(
    id: 'warehouse-sort',
    categoryId: 'warehouse',
    tag: '分拣',
    title: '分拣与归类',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '60–180 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Even overhead',
    surface: '分拣台',
    steps: [_kGenericStep],
  ),
  Task(
    id: 'warehouse-pack',
    categoryId: 'warehouse',
    tag: '包装',
    title: '包装与封装',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '60–180 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Even overhead',
    surface: '工作台',
    steps: [_kGenericStep],
  ),
  Task(
    id: 'warehouse-load',
    categoryId: 'warehouse',
    tag: '搬运',
    title: '货物搬运与装载',
    publisher: 'Digients Tasks',
    rewardPoints: 240,
    duration: '60–180 s',
    slots: '0 / 40 slots',
    difficulty: 'Medium',
    lighting: 'Mixed',
    surface: '仓库地面',
    steps: [_kGenericStep],
  ),
  Task(
    id: 'warehouse-inventory',
    categoryId: 'warehouse',
    tag: '盘点',
    title: '库存盘点与管理',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '60–180 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Even overhead',
    surface: '货架',
    steps: [_kGenericStep],
  ),
  Task(
    id: 'warehouse-clean',
    categoryId: 'warehouse',
    tag: '清洁',
    title: '现场清洁维护',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '60–180 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Mixed',
    surface: '仓库地面',
    steps: [_kGenericStep],
  ),

  // ──────────────── 配送站 ────────────────
  Task(
    id: 'delivery-sort',
    categoryId: 'delivery',
    tag: '分拣',
    title: '包裹分拣',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '60–180 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Even overhead',
    surface: '分拣台',
    steps: [_kGenericStep],
  ),
  Task(
    id: 'delivery-dispatch',
    categoryId: 'delivery',
    tag: '配送',
    title: '包裹装载与配送',
    publisher: 'Digients Tasks',
    rewardPoints: 240,
    duration: '60–180 s',
    slots: '0 / 40 slots',
    difficulty: 'Medium',
    lighting: 'Mixed',
    surface: '配送车 / 站点',
    steps: [_kGenericStep],
  ),
  Task(
    id: 'delivery-locker',
    categoryId: 'delivery',
    tag: '操作',
    title: '快递柜操作',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '30–90 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Even overhead',
    surface: '快递柜',
    steps: [_kGenericStep],
  ),

  // ──────────────── 网吧 ────────────────
  Task(
    id: 'internet-serve',
    categoryId: 'internet',
    tag: '服务',
    title: '服务递送',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '30–90 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Mixed',
    surface: '机位 / 吧台',
    steps: [_kGenericStep],
  ),
  Task(
    id: 'internet-operate',
    categoryId: 'internet',
    tag: '操作',
    title: '设备控制与操作',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '30–90 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Mixed',
    surface: '机位',
    steps: [_kGenericStep],
  ),
  Task(
    id: 'internet-clean',
    categoryId: 'internet',
    tag: '清洁',
    title: '设备与环境清洁',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '60–180 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Mixed',
    surface: '机位 / 地面',
    steps: [_kGenericStep],
  ),

  // ──────────────── 商店 ────────────────
  Task(
    id: 'store-display',
    categoryId: 'store',
    tag: '陈列',
    title: '商品摆放与陈列',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '60–180 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Even overhead',
    surface: '货架',
    steps: [_kGenericStep],
  ),
  Task(
    id: 'store-bag',
    categoryId: 'store',
    tag: '包装',
    title: '商品包装与装袋',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '30–90 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Even overhead',
    surface: '收银台',
    steps: [_kGenericStep],
  ),
  Task(
    id: 'store-handover',
    categoryId: 'store',
    tag: '交付',
    title: '顾客递交与交付',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '15–30 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Even overhead',
    surface: '收银台',
    steps: [_kGenericStep],
  ),
  Task(
    id: 'store-clean',
    categoryId: 'store',
    tag: '清洁',
    title: '店面清洁维护',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '60–180 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Mixed',
    surface: '地面 / 货架',
    steps: [_kGenericStep],
  ),

  // ──────────────── 制衣车间 ────────────────
  Task(
    id: 'garment-sew',
    categoryId: 'garment',
    tag: '缝纫',
    title: '衣物缝纫',
    publisher: 'Digients Tasks',
    rewardPoints: 240,
    duration: '60–180 s',
    slots: '0 / 40 slots',
    difficulty: 'Medium',
    lighting: 'Bright indoor',
    surface: '缝纫机',
    steps: [_kGenericStep],
  ),
  Task(
    id: 'garment-fold',
    categoryId: 'garment',
    tag: '折叠',
    title: '衣物折叠',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '30–90 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Bright indoor',
    surface: '工作台',
    steps: [_kGenericStep],
  ),
  Task(
    id: 'garment-clean',
    categoryId: 'garment',
    tag: '清洁',
    title: '设备与环境清洁',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '60–180 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Mixed',
    surface: '缝纫机 / 地面',
    steps: [_kGenericStep],
  ),

  // ──────────────── 维修车间 ────────────────
  Task(
    id: 'repair-fix',
    categoryId: 'repair',
    tag: '维修',
    title: '维修与辅助',
    publisher: 'Digients Tasks',
    rewardPoints: 240,
    duration: '60–180 s',
    slots: '0 / 40 slots',
    difficulty: 'Medium',
    lighting: 'Mixed',
    surface: '工作台',
    steps: [_kGenericStep],
  ),
  Task(
    id: 'repair-tidy',
    categoryId: 'repair',
    tag: '整理',
    title: '维修车间整理',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '60–180 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Mixed',
    surface: '工作台 / 工具架',
    steps: [_kGenericStep],
  ),
  Task(
    id: 'repair-clean',
    categoryId: 'repair',
    tag: '清洁',
    title: '环境清洁',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '60–180 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Mixed',
    surface: '地面 / 工作台',
    steps: [_kGenericStep],
  ),

  // ──────────────── 其他场景 ────────────────
  Task(
    id: 'other-misc',
    categoryId: 'other',
    tag: '其他',
    title: '其他',
    publisher: 'Digients Tasks',
    rewardPoints: 200,
    duration: '60–180 s',
    slots: '0 / 50 slots',
    difficulty: 'Easy',
    lighting: 'Mixed',
    surface: '未指定',
    steps: [_kGenericStep],
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

/// Split a task id (`<major>-<minor>`) into its minor slug. Returns null
/// when the task id doesn't follow the WF2 catalog convention.
String? sceneMinorFromTaskId(String? taskId, String? categoryId) {
  if (taskId == null || taskId.isEmpty) return null;
  if (categoryId != null &&
      categoryId.isNotEmpty &&
      taskId.startsWith('$categoryId-')) {
    return taskId.substring(categoryId.length + 1);
  }
  // Fallback for legacy 2-letter-prefixed tasks (lr-/br-/kt-/bt-/cs-).
  final m = RegExp(r'^[a-z]{2}-').firstMatch(taskId);
  if (m != null) return taskId.substring(m.end);
  return taskId;
}

/// Human-readable title for a recording — mirrors the structure of the
/// exported archive filename `<category>-<minor>-<sessionId>.tar.gz` so
/// the user can correlate the row in the Submissions list with the
/// file they just shared. Falls back to the bare session id prefix for
/// recordings that pre-date categoryId/taskId tracking.
String recordingDisplayTitle(Recording r) {
  final cat = r.categoryId != null ? findCategory(r.categoryId!) : null;
  final subSlug = sceneMinorFromTaskId(r.taskId, r.categoryId);

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

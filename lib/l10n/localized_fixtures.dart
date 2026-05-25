import '../fixtures/data.dart';
import '../models/recording.dart';
import '../models/task.dart';
import 'app_localizations.dart';

extension LocalizedCategory on Category {
  String localizedTitle(AppLocalizations l10n) {
    return switch (id) {
      'kitchen' => l10n.categoryKitchen,
      'warehouse' => l10n.categoryWarehouse,
      'delivery' => l10n.categoryDelivery,
      'internet' => l10n.categoryInternet,
      'store' => l10n.categoryStore,
      'garment' => l10n.categoryGarment,
      'repair' => l10n.categoryRepair,
      'other' => l10n.categoryOther,
      _ => title,
    };
  }
}

extension LocalizedTask on Task {
  String localizedPublisher(AppLocalizations l10n) => l10n.digientsTasks;

  String localizedTag(AppLocalizations l10n) {
    return switch (tag) {
      '清洁' => l10n.taskTagCleaning,
      '处理' => l10n.taskTagProcessing,
      '烹饪' => l10n.taskTagCooking,
      '调制' => l10n.taskTagMixing,
      '分拣' => l10n.taskTagSorting,
      '包装' => l10n.taskTagPacking,
      '搬运' => l10n.taskTagHandling,
      '盘点' => l10n.taskTagInventory,
      '配送' => l10n.taskTagDelivery,
      '操作' => l10n.taskTagOperation,
      '服务' => l10n.taskTagService,
      '陈列' => l10n.taskTagDisplay,
      '交付' => l10n.taskTagHandoff,
      '缝纫' => l10n.taskTagSewing,
      '折叠' => l10n.taskTagFolding,
      '维修' => l10n.taskTagRepair,
      '整理' => l10n.taskTagTidying,
      '其他' => l10n.taskTagOther,
      _ => tag,
    };
  }

  String localizedTitle(AppLocalizations l10n) {
    return switch (id) {
      'kitchen-clean' => l10n.taskKitchenCleanTitle,
      'kitchen-tools' => l10n.taskKitchenToolsTitle,
      'kitchen-wash' => l10n.taskKitchenWashTitle,
      'kitchen-cook' => l10n.taskKitchenCookTitle,
      'kitchen-drink' => l10n.taskKitchenDrinkTitle,
      'warehouse-sort' => l10n.taskWarehouseSortTitle,
      'warehouse-pack' => l10n.taskWarehousePackTitle,
      'warehouse-load' => l10n.taskWarehouseLoadTitle,
      'warehouse-inventory' => l10n.taskWarehouseInventoryTitle,
      'warehouse-clean' => l10n.taskWarehouseCleanTitle,
      'delivery-sort' => l10n.taskDeliverySortTitle,
      'delivery-dispatch' => l10n.taskDeliveryDispatchTitle,
      'delivery-locker' => l10n.taskDeliveryLockerTitle,
      'internet-serve' => l10n.taskInternetServeTitle,
      'internet-operate' => l10n.taskInternetOperateTitle,
      'internet-clean' => l10n.taskInternetCleanTitle,
      'store-display' => l10n.taskStoreDisplayTitle,
      'store-bag' => l10n.taskStoreBagTitle,
      'store-handover' => l10n.taskStoreHandoverTitle,
      'store-clean' => l10n.taskStoreCleanTitle,
      'garment-sew' => l10n.taskGarmentSewTitle,
      'garment-fold' => l10n.taskGarmentFoldTitle,
      'garment-clean' => l10n.taskGarmentCleanTitle,
      'repair-fix' => l10n.taskRepairFixTitle,
      'repair-tidy' => l10n.taskRepairTidyTitle,
      'repair-clean' => l10n.taskRepairCleanTitle,
      'other-misc' => l10n.taskOtherMiscTitle,
      _ => title,
    };
  }

  String localizedDuration(AppLocalizations l10n) {
    return switch (duration) {
      '10–20 s' => l10n.duration10To20,
      '15–30 s' => l10n.duration15To30,
      '30–60 s' => l10n.duration30To60,
      '30–90 s' => l10n.duration30To90,
      '45–90 s' => l10n.duration45To90,
      '60–120 s' => l10n.duration60To120,
      '60–180 s' => l10n.duration60To180,
      '120–240 s' => l10n.duration120To240,
      _ => duration,
    };
  }

  String localizedSlots(AppLocalizations l10n) {
    return switch (slots) {
      '0 / 30 slots' => l10n.slots0Of30,
      '0 / 40 slots' => l10n.slots0Of40,
      '0 / 50 slots' => l10n.slots0Of50,
      _ => slots,
    };
  }

  String localizedDifficulty(AppLocalizations l10n) {
    return switch (difficulty) {
      'Easy' => l10n.difficultyEasy,
      'Medium' => l10n.difficultyMedium,
      _ => difficulty,
    };
  }

  String localizedLighting(AppLocalizations l10n) {
    return switch (lighting) {
      'Bright indoor' => l10n.lightingBrightIndoor,
      'Mixed' => l10n.lightingMixed,
      'Even overhead' => l10n.lightingEvenOverhead,
      _ => lighting,
    };
  }

  String localizedSurface(AppLocalizations l10n) {
    return switch (surface) {
      '厨房地面 / 墙面' => l10n.surfaceKitchenFloorWalls,
      '台面 / 器具' => l10n.surfaceCounterUtensils,
      '水槽' => l10n.surfaceSink,
      '炉灶' => l10n.surfaceStove,
      '吧台' => l10n.surfaceBar,
      '分拣台' => l10n.surfaceSortingTable,
      '工作台' => l10n.surfaceWorkbench,
      '仓库地面' => l10n.surfaceWarehouseFloor,
      '货架' => l10n.surfaceShelving,
      '配送车 / 站点' => l10n.surfaceDeliveryVehicle,
      '快递柜' => l10n.surfaceParcelLocker,
      '机位 / 吧台' => l10n.surfaceStationBar,
      '机位' => l10n.surfaceStation,
      '机位 / 地面' => l10n.surfaceStationFloor,
      '收银台' => l10n.surfaceCheckout,
      '地面 / 货架' => l10n.surfaceFloorShelving,
      '缝纫机' => l10n.surfaceSewingMachine,
      '缝纫机 / 地面' => l10n.surfaceSewingMachineFloor,
      '工作台 / 工具架' => l10n.surfaceWorkbenchToolRack,
      '地面 / 工作台' => l10n.surfaceFloorWorkbench,
      '未指定' => l10n.surfaceUnspecified,
      _ => surface,
    };
  }

  List<String> localizedSteps(AppLocalizations l10n) {
    // Every WF2 catalog task currently carries the same generic Chinese
    // reminder (real per-task instructions are authored later). Route it
    // through l10n so English users don't see the placeholder in Chinese.
    if (steps.length == 1 && steps.first == kGenericStep) {
      return [l10n.taskGenericStep];
    }
    return steps;
  }
}

String localizedRecordingDisplayTitle(
  Recording recording,
  AppLocalizations l10n,
) {
  final cat =
      recording.categoryId != null ? findCategory(recording.categoryId!) : null;
  final task = recording.taskId != null ? findTask(recording.taskId!) : null;
  final idPrefix = recording.sessionId.substring(0, 8);

  if (cat != null && task != null) {
    return '${cat.localizedTitle(l10n)} · ${task.localizedTitle(l10n)}';
  }
  if (cat != null) {
    return l10n.recordingInCategory(cat.localizedTitle(l10n), idPrefix);
  }
  return l10n.recordingTitle(idPrefix);
}

String titleCaseSlug(String slug) {
  return slug
      .split('-')
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

import '../fixtures/data.dart';
import '../models/recording.dart';
import '../models/task.dart';
import 'app_localizations.dart';

extension LocalizedCategory on Category {
  String localizedTitle(AppLocalizations l10n) {
    return switch (id) {
      'living-room' => l10n.categoryLivingRoom,
      'kitchen' => l10n.categoryKitchen,
      'bedroom' => l10n.categoryBedroom,
      'convenience-store' => l10n.categoryConvenienceStore,
      'bathroom' => l10n.categoryBathroom,
      _ => title,
    };
  }
}

extension LocalizedTask on Task {
  String localizedPublisher(AppLocalizations l10n) => l10n.digientsTasks;

  String localizedTag(AppLocalizations l10n) {
    return switch (tag) {
      'Pick & Place' => l10n.taskTagPickPlace,
      'Switch' => l10n.taskTagSwitch,
      'Folding' => l10n.taskTagFolding,
      'Cutting' => l10n.taskTagCutting,
      'Tableware' => l10n.taskTagTableware,
      'Pouring' => l10n.taskTagPouring,
      'Cleaning' => l10n.taskTagCleaning,
      'Handover' => l10n.taskTagHandover,
      _ => tag,
    };
  }

  String localizedTitle(AppLocalizations l10n) {
    return switch (id) {
      'lr-pick-remote' => l10n.taskLrPickRemoteTitle,
      'lr-pick-phone' => l10n.taskLrPickPhoneTitle,
      'lr-pick-powerbank' => l10n.taskLrPickPowerbankTitle,
      'lr-pick-combo' => l10n.taskLrPickComboTitle,
      'lr-switch-light' => l10n.taskLrSwitchLightTitle,
      'lr-switch-drawer' => l10n.taskLrSwitchDrawerTitle,
      'lr-switch-curtain' => l10n.taskLrSwitchCurtainTitle,
      'lr-switch-combo' => l10n.taskLrSwitchComboTitle,
      'br-fold-clothes-single' => l10n.taskBrFoldClothesSingleTitle,
      'br-fold-clothes-multi' => l10n.taskBrFoldClothesMultiTitle,
      'br-fold-towel-single' => l10n.taskBrFoldTowelSingleTitle,
      'br-fold-towel-multi' => l10n.taskBrFoldTowelMultiTitle,
      'kt-cut-fruit-single' => l10n.taskKtCutFruitSingleTitle,
      'kt-cut-fruit-multi' => l10n.taskKtCutFruitMultiTitle,
      'kt-tableware-single' => l10n.taskKtTablewareSingleTitle,
      'kt-tableware-multi' => l10n.taskKtTablewareMultiTitle,
      'kt-pour-water' => l10n.taskKtPourWaterTitle,
      'kt-pour-coffee' => l10n.taskKtPourCoffeeTitle,
      'kt-pour-tea' => l10n.taskKtPourTeaTitle,
      'kt-pour-combo' => l10n.taskKtPourComboTitle,
      'bt-wipe-toilet' => l10n.taskBtWipeToiletTitle,
      'bt-clean-toilet-seat' => l10n.taskBtCleanToiletSeatTitle,
      'bt-clean-basin' => l10n.taskBtCleanBasinTitle,
      'cs-pick-shelf-single' => l10n.taskCsPickShelfSingleTitle,
      'cs-pick-shelf-multi' => l10n.taskCsPickShelfMultiTitle,
      'cs-wipe-counter' => l10n.taskCsWipeCounterTitle,
      'cs-handover-single' => l10n.taskCsHandoverSingleTitle,
      'cs-handover-multi' => l10n.taskCsHandoverMultiTitle,
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
      'Coffee table' => l10n.surfaceCoffeeTable,
      'Wall switch' => l10n.surfaceWallSwitch,
      'Living-room drawer' => l10n.surfaceLivingRoomDrawer,
      'Window' => l10n.surfaceWindow,
      'Living room' => l10n.surfaceLivingRoom,
      'Bed' => l10n.surfaceBed,
      'Cutting board' => l10n.surfaceCuttingBoard,
      'Kitchen counter' => l10n.surfaceKitchenCounter,
      'Toilet' => l10n.surfaceToilet,
      'Basin' => l10n.surfaceBasin,
      'Store shelf' => l10n.surfaceStoreShelf,
      'Counter' => l10n.surfaceCounter,
      _ => surface,
    };
  }

  List<String> localizedSteps(AppLocalizations l10n) {
    return switch (id) {
      'lr-pick-remote' => [
          l10n.taskLrPickRemoteStep1,
          l10n.taskLrPickRemoteStep2,
          l10n.taskLrPickRemoteStep3,
          l10n.taskLrPickRemoteStep4,
        ],
      'lr-pick-phone' => [
          l10n.taskLrPickPhoneStep1,
          l10n.taskLrPickPhoneStep2,
          l10n.taskLrPickPhoneStep3,
          l10n.taskLrPickPhoneStep4,
        ],
      'lr-pick-powerbank' => [
          l10n.taskLrPickPowerbankStep1,
          l10n.taskLrPickPowerbankStep2,
          l10n.taskLrPickPowerbankStep3,
          l10n.taskLrPickPowerbankStep4,
        ],
      'lr-pick-combo' => [
          l10n.taskLrPickComboStep1,
          l10n.taskLrPickComboStep2,
          l10n.taskLrPickComboStep3,
          l10n.taskLrPickComboStep4,
        ],
      'lr-switch-light' => [
          l10n.taskLrSwitchLightStep1,
          l10n.taskLrSwitchLightStep2,
          l10n.taskLrSwitchLightStep3,
          l10n.taskLrSwitchLightStep4,
        ],
      'lr-switch-drawer' => [
          l10n.taskLrSwitchDrawerStep1,
          l10n.taskLrSwitchDrawerStep2,
          l10n.taskLrSwitchDrawerStep3,
          l10n.taskLrSwitchDrawerStep4,
        ],
      'lr-switch-curtain' => [
          l10n.taskLrSwitchCurtainStep1,
          l10n.taskLrSwitchCurtainStep2,
          l10n.taskLrSwitchCurtainStep3,
          l10n.taskLrSwitchCurtainStep4,
        ],
      'lr-switch-combo' => [
          l10n.taskLrSwitchComboStep1,
          l10n.taskLrSwitchComboStep2,
          l10n.taskLrSwitchComboStep3,
          l10n.taskLrSwitchComboStep4,
        ],
      'br-fold-clothes-single' => [
          l10n.taskBrFoldClothesSingleStep1,
          l10n.taskBrFoldClothesSingleStep2,
          l10n.taskBrFoldClothesSingleStep3,
          l10n.taskBrFoldClothesSingleStep4,
        ],
      'br-fold-clothes-multi' => [
          l10n.taskBrFoldClothesMultiStep1,
          l10n.taskBrFoldClothesMultiStep2,
          l10n.taskBrFoldClothesMultiStep3,
          l10n.taskBrFoldClothesMultiStep4,
        ],
      'br-fold-towel-single' => [
          l10n.taskBrFoldTowelSingleStep1,
          l10n.taskBrFoldTowelSingleStep2,
          l10n.taskBrFoldTowelSingleStep3,
          l10n.taskBrFoldTowelSingleStep4,
        ],
      'br-fold-towel-multi' => [
          l10n.taskBrFoldTowelMultiStep1,
          l10n.taskBrFoldTowelMultiStep2,
          l10n.taskBrFoldTowelMultiStep3,
          l10n.taskBrFoldTowelMultiStep4,
        ],
      'kt-cut-fruit-single' => [
          l10n.taskKtCutFruitSingleStep1,
          l10n.taskKtCutFruitSingleStep2,
          l10n.taskKtCutFruitSingleStep3,
          l10n.taskKtCutFruitSingleStep4,
        ],
      'kt-cut-fruit-multi' => [
          l10n.taskKtCutFruitMultiStep1,
          l10n.taskKtCutFruitMultiStep2,
          l10n.taskKtCutFruitMultiStep3,
          l10n.taskKtCutFruitMultiStep4,
        ],
      'kt-tableware-single' => [
          l10n.taskKtTablewareSingleStep1,
          l10n.taskKtTablewareSingleStep2,
          l10n.taskKtTablewareSingleStep3,
          l10n.taskKtTablewareSingleStep4,
        ],
      'kt-tableware-multi' => [
          l10n.taskKtTablewareMultiStep1,
          l10n.taskKtTablewareMultiStep2,
          l10n.taskKtTablewareMultiStep3,
          l10n.taskKtTablewareMultiStep4,
        ],
      'kt-pour-water' => [
          l10n.taskKtPourWaterStep1,
          l10n.taskKtPourWaterStep2,
          l10n.taskKtPourWaterStep3,
          l10n.taskKtPourWaterStep4,
        ],
      'kt-pour-coffee' => [
          l10n.taskKtPourCoffeeStep1,
          l10n.taskKtPourCoffeeStep2,
          l10n.taskKtPourCoffeeStep3,
          l10n.taskKtPourCoffeeStep4,
        ],
      'kt-pour-tea' => [
          l10n.taskKtPourTeaStep1,
          l10n.taskKtPourTeaStep2,
          l10n.taskKtPourTeaStep3,
          l10n.taskKtPourTeaStep4,
        ],
      'kt-pour-combo' => [
          l10n.taskKtPourComboStep1,
          l10n.taskKtPourComboStep2,
          l10n.taskKtPourComboStep3,
          l10n.taskKtPourComboStep4,
        ],
      'bt-wipe-toilet' => [
          l10n.taskBtWipeToiletStep1,
          l10n.taskBtWipeToiletStep2,
          l10n.taskBtWipeToiletStep3,
          l10n.taskBtWipeToiletStep4,
        ],
      'bt-clean-toilet-seat' => [
          l10n.taskBtCleanToiletSeatStep1,
          l10n.taskBtCleanToiletSeatStep2,
          l10n.taskBtCleanToiletSeatStep3,
          l10n.taskBtCleanToiletSeatStep4,
        ],
      'bt-clean-basin' => [
          l10n.taskBtCleanBasinStep1,
          l10n.taskBtCleanBasinStep2,
          l10n.taskBtCleanBasinStep3,
          l10n.taskBtCleanBasinStep4,
        ],
      'cs-pick-shelf-single' => [
          l10n.taskCsPickShelfSingleStep1,
          l10n.taskCsPickShelfSingleStep2,
          l10n.taskCsPickShelfSingleStep3,
          l10n.taskCsPickShelfSingleStep4,
        ],
      'cs-pick-shelf-multi' => [
          l10n.taskCsPickShelfMultiStep1,
          l10n.taskCsPickShelfMultiStep2,
          l10n.taskCsPickShelfMultiStep3,
          l10n.taskCsPickShelfMultiStep4,
        ],
      'cs-wipe-counter' => [
          l10n.taskCsWipeCounterStep1,
          l10n.taskCsWipeCounterStep2,
          l10n.taskCsWipeCounterStep3,
          l10n.taskCsWipeCounterStep4,
        ],
      'cs-handover-single' => [
          l10n.taskCsHandoverSingleStep1,
          l10n.taskCsHandoverSingleStep2,
          l10n.taskCsHandoverSingleStep3,
          l10n.taskCsHandoverSingleStep4,
        ],
      'cs-handover-multi' => [
          l10n.taskCsHandoverMultiStep1,
          l10n.taskCsHandoverMultiStep2,
          l10n.taskCsHandoverMultiStep3,
          l10n.taskCsHandoverMultiStep4,
        ],
      _ => steps,
    };
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

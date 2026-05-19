// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Digients Capture';

  @override
  String get navHome => 'Home';

  @override
  String get navSubmissions => 'Submissions';

  @override
  String get navMe => 'Me';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAccount => 'ACCOUNT';

  @override
  String get settingsUploads => 'UPLOADS';

  @override
  String get settingsRecordingFeedback => 'RECORDING FEEDBACK';

  @override
  String get settingsNotifications => 'NOTIFICATIONS';

  @override
  String get settingsAppearance => 'APPEARANCE';

  @override
  String get settingsAbout => 'ABOUT';

  @override
  String get settingsEmail => 'Email';

  @override
  String get settingsPhone => 'Phone';

  @override
  String get settingsUid => 'UID';

  @override
  String get settingsWifiOnly => 'Wi-Fi only';

  @override
  String get settingsAutoUpload => 'Auto-upload after capture';

  @override
  String get settingsBackgroundUploads => 'Background uploads';

  @override
  String get settingsHandVoiceCues => 'Hand-presence voice cues';

  @override
  String get settingsBorderIndicator => 'Border indicator';

  @override
  String get settingsVibrateOnNoHands => 'Vibrate on no hands';

  @override
  String get settingsApprovalResults => 'Approval results';

  @override
  String get settingsPointsCredited => 'Points credited';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsPrivacyPolicy => 'Privacy Policy';

  @override
  String get settingsTermsOfService => 'Terms of Service';

  @override
  String get settingsOpenSourceLicenses => 'Open-source licenses';

  @override
  String get settingsSignOut => 'Sign Out';

  @override
  String get settingsDeleteAccount => 'Delete account';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get themeAuto => 'Auto';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get authEnterPhoneFirst => 'Enter a phone number first.';

  @override
  String get authEnterEmailFirst => 'Enter an email first.';

  @override
  String get authEnterSixDigitCode => 'Enter the 6-digit code.';

  @override
  String get authInvalidCode => 'Invalid code.';

  @override
  String authSomethingWentWrong(String error) {
    return 'Something went wrong: $error';
  }

  @override
  String get authCreateAccount => 'Create account';

  @override
  String get authWelcomeBack => 'Welcome back';

  @override
  String get authSignUpSubtitle => 'Sign up to start contributing recordings.';

  @override
  String get authSignInSubtitle => 'Sign in to continue capturing.';

  @override
  String get authPhone => 'Phone';

  @override
  String get authEmail => 'Email';

  @override
  String get authAgreementPrefix => 'By creating an account you agree to our ';

  @override
  String get authTerms => 'Terms';

  @override
  String get authAgreementMiddle => ' and ';

  @override
  String get authPrivacyPolicy => 'Privacy Policy';

  @override
  String get authAgreementSuffix => '.';

  @override
  String get authSending => 'Sending...';

  @override
  String get authSendVerificationCode => 'Send verification code';

  @override
  String get authVerifying => 'Verifying...';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authApple => 'Apple';

  @override
  String get authGoogle => 'Google';

  @override
  String get authOr => 'or';

  @override
  String get authAlreadyHaveAccount => 'Already have an account? ';

  @override
  String get authDontHaveAccount => 'Don\'t have an account? ';

  @override
  String get authRegister => 'Register';

  @override
  String get authPhoneComingSoonTitle => 'Phone sign-in is coming later';

  @override
  String get authPhoneComingSoonBody =>
      'We\'re still working on SMS verification. Please use Email or the demo sign-in below for now.';

  @override
  String get authSkipSignIn => 'Skip sign-in (demo)';

  @override
  String get authSkipSignInHint => 'Skipping will leave video upload disabled';

  @override
  String get authInviteCodeSignIn => 'Sign in with invite code';

  @override
  String get authInviteCodeModalTitle => 'Enter Invite Code';

  @override
  String get authInviteCodeModalHint =>
      'Ask the Digients team for a code if you don\'t have one';

  @override
  String get authInviteCodeInputLabel => 'Invite code';

  @override
  String get authInviteCodeSubmit => 'Sign in';

  @override
  String get authInviteCodeMissing => 'Invite code is required';

  @override
  String get uploadLockedTitle => 'Upload requires sign-in';

  @override
  String get uploadLockedBody =>
      'Sign out and use an invite code to enable video upload.';

  @override
  String get uploadLockedSignOut => 'Sign out';

  @override
  String get uploadLockedDismiss => 'Not now';

  @override
  String get uploadLockedShortLabel => 'Locked';

  @override
  String get homeWelcomeBack => 'WELCOME BACK';

  @override
  String get balance => 'BALANCE';

  @override
  String get pending => 'PENDING';

  @override
  String get pointsSuffix => 'pts';

  @override
  String get chooseCategory => 'Choose a category';

  @override
  String tasksCount(int count) {
    return '$count tasks';
  }

  @override
  String get comingSoon => 'SOON';

  @override
  String upToPoints(int points) {
    return 'up to +$points';
  }

  @override
  String get digientsTasks => 'Digients Tasks';

  @override
  String get tasksTitle => 'Tasks';

  @override
  String poolSortedByReward(int count) {
    return '$count tasks · sorted by reward';
  }

  @override
  String get filterAll => 'All';

  @override
  String get filterHighReward => 'High Reward';

  @override
  String get filterQuick => 'Quick (<3 min)';

  @override
  String get filterBeginner => 'Beginner';

  @override
  String get filterVerified => 'Verified';

  @override
  String get noTasks => 'NO TASKS';

  @override
  String get taskNotFound => 'Task not found';

  @override
  String get taskDetails => 'Task Details';

  @override
  String get demoCaption => 'DEMO · 0:08';

  @override
  String get pointsOnApproval => 'points on approval';

  @override
  String get duration => 'Duration';

  @override
  String get difficulty => 'Difficulty';

  @override
  String get lighting => 'Lighting';

  @override
  String get surface => 'Surface';

  @override
  String get steps => 'STEPS';

  @override
  String get headsUp => 'HEADS UP';

  @override
  String get storageWarning =>
      'Recording will auto-stop at 5% remaining storage. Phone will buzz to alert you.';

  @override
  String get storageAvailability => 'Storage · 2h 35m available · 18.0 GB free';

  @override
  String get record => 'Record';

  @override
  String get cameraPermissionRequired => 'Camera permission required';

  @override
  String get failedToInitializeCamera => 'Failed to initialize camera';

  @override
  String get failedToStartRecording => 'Failed to start recording';

  @override
  String get tapToStop => 'TAP TO STOP';

  @override
  String get tapToStart => 'TAP TO START';

  @override
  String get preStartPrompt => 'PLACE HANDS IN VIEW';

  @override
  String get pressVolumeButtonToStart => 'PRESS VOLUME BUTTON TO START';

  @override
  String get mountCaptionPhone =>
      'Place your phone horizontally with arrow pointing upward';

  @override
  String get mountCaptionHeadband => 'Mount on headband for data collection';

  @override
  String instructionsEndIn(int seconds) {
    return 'INSTRUCTIONS END IN ${seconds}s';
  }

  @override
  String get skip => 'SKIP';

  @override
  String get thisSideUp => 'THIS SIDE UP';

  @override
  String get submittedTitle => 'Submitted!';

  @override
  String get successCopyUploading =>
      'Data is uploading and will be under review.';

  @override
  String get successCopyKeepConnection => 'Please keep internet connection.';

  @override
  String get successCopyPointsSoon =>
      'Points will be credited within approximately 48 hours.';

  @override
  String get pendingReview => 'pending review';

  @override
  String get goToSubmissions => 'Go To Submissions';

  @override
  String get submissionSaved => 'Submission saved';

  @override
  String takePoints(int takeNumber, int points) {
    return 'Take $takeNumber · +$points points';
  }

  @override
  String get pressVolumeAnotherTake => 'PRESS VOLUME BUTTON\nFOR ANOTHER TAKE';

  @override
  String get submissionsTitle => 'Submissions';

  @override
  String submissionsTotal(int count, String totalGb) {
    return '$count total · $totalGb GB on device';
  }

  @override
  String get selectMultiple => 'Select multiple';

  @override
  String get selectRecordings => 'Select recordings';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get selectionHint => 'Tap to toggle · long-press a row to start';

  @override
  String get clear => 'Clear';

  @override
  String get selectAll => 'Select all';

  @override
  String get done => 'Done';

  @override
  String get noItems => 'NO ITEMS';

  @override
  String get noItemsPrompt => 'Tap a category from Home to start recording.';

  @override
  String get compressingRecording => 'Compressing recording...';

  @override
  String compressingProgress(int current, int total) {
    return 'Compressing $current of $total...';
  }

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get shareUnavailableOriginalsGone =>
      'Originals removed after upload — share is unavailable.';

  @override
  String get shareSubjectRecording => 'Egocentric Video Recording';

  @override
  String get shareTextRecording => 'Egocentric video recording data package';

  @override
  String shareSubjectRecordings(int count) {
    return 'Egocentric Video Recordings ($count)';
  }

  @override
  String get shareTextRecordings => 'Egocentric video recording data packages';

  @override
  String get deleteRecordingTitle => 'Delete recording?';

  @override
  String deleteRecordingContent(String idPrefix) {
    return 'This removes the local copy of recording $idPrefix.';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get export => 'Export';

  @override
  String get exportSelected => 'EXPORT SELECTED';

  @override
  String exportRecordingCount(int count) {
    return 'EXPORT $count RECORDING(S)';
  }

  @override
  String get uploadToCloud => 'Upload to Cloud';

  @override
  String uploadToCloudCount(int count) {
    return 'UPLOAD $count TO CLOUD';
  }

  @override
  String uploadingPercent(int percent) {
    return 'Uploading $percent%';
  }

  @override
  String get uploadQueuedLabel => 'Queued';

  @override
  String get uploadCompressingShort => 'Compressing';

  @override
  String get uploadCompressingLong => 'Compressing…';

  @override
  String get compressFailedShort => 'Compress failed';

  @override
  String get uploadFinalizingShort => 'Finishing';

  @override
  String get uploadFinalizingLong => 'Finishing up…';

  @override
  String get uploadedLabel => 'Uploaded';

  @override
  String get uploadShort => 'Upload';

  @override
  String get uploadRetryShort => 'Retry';

  @override
  String get uploadFailedShort => 'Failed';

  @override
  String get uploadFailedRetry => 'Upload failed — tap to retry';

  @override
  String get uploadForegroundBannerTitle =>
      'Upload in progress — keep app open if possible';

  @override
  String get uploadForegroundBannerBody =>
      'Force-quitting the app will cancel the upload.';

  @override
  String uploadFailedSnack(String error) {
    return 'Upload failed: $error';
  }

  @override
  String get savedOnDevice => 'SAVED ON DEVICE';

  @override
  String get notUploadedYet =>
      'Not uploaded yet. Use Export to share the recording package via the share sheet.';

  @override
  String get sessionId => 'Session ID';

  @override
  String get captured => 'Captured';

  @override
  String get size => 'Size';

  @override
  String get codec => 'Codec';

  @override
  String get resolution => 'Resolution';

  @override
  String get intrinsics => 'Intrinsics';

  @override
  String get perFrame => 'Per-frame';

  @override
  String get keepAppOpen => 'KEEP THE APP OPEN';

  @override
  String get statusOnDevice => 'On Device';

  @override
  String get statusUploading => 'Uploading';

  @override
  String get statusInReview => 'In Review';

  @override
  String get statusApproved => 'Approved';

  @override
  String get statusRejected => 'Rejected';

  @override
  String recordingTitle(String idPrefix) {
    return 'Recording $idPrefix';
  }

  @override
  String recordingInCategory(String category, String idPrefix) {
    return '$category · $idPrefix';
  }

  @override
  String get profileHours => 'HOURS';

  @override
  String get profileSubmitted => 'SUBMITTED';

  @override
  String get profileApproval => 'APPROVAL';

  @override
  String get profileCapability => 'CAPABILITY';

  @override
  String get capabilityHousehold => 'Household';

  @override
  String get capabilityIndustrial => 'Industrial';

  @override
  String get capabilitySports => 'Sports';

  @override
  String get capabilityVariety => 'Variety';

  @override
  String get capabilitySpeed => 'Speed';

  @override
  String get capabilityApproval => 'Approval';

  @override
  String get leaderboardGlobal => 'LEADERBOARD · GLOBAL';

  @override
  String rankNumber(int rank) {
    return 'Rank #$rank';
  }

  @override
  String get categoryLivingRoom => 'Living Room';

  @override
  String get categoryKitchen => 'Kitchen';

  @override
  String get categoryBedroom => 'Bedroom';

  @override
  String get categoryConvenienceStore => 'Convenience Store';

  @override
  String get categoryBathroom => 'Bathroom';

  @override
  String get taskTagPickPlace => 'Pick & Place';

  @override
  String get taskTagSwitch => 'Switch';

  @override
  String get taskTagFolding => 'Folding';

  @override
  String get taskTagCutting => 'Cutting';

  @override
  String get taskTagTableware => 'Tableware';

  @override
  String get taskTagPouring => 'Pouring';

  @override
  String get taskTagCleaning => 'Cleaning';

  @override
  String get taskTagHandover => 'Handover';

  @override
  String get difficultyEasy => 'Easy';

  @override
  String get difficultyMedium => 'Medium';

  @override
  String get lightingBrightIndoor => 'Bright indoor';

  @override
  String get lightingMixed => 'Mixed';

  @override
  String get lightingEvenOverhead => 'Even overhead';

  @override
  String get duration10To20 => '10-20 s';

  @override
  String get duration15To30 => '15-30 s';

  @override
  String get duration30To60 => '30-60 s';

  @override
  String get duration30To90 => '30-90 s';

  @override
  String get duration45To90 => '45-90 s';

  @override
  String get duration60To120 => '60-120 s';

  @override
  String get duration60To180 => '60-180 s';

  @override
  String get duration120To240 => '120-240 s';

  @override
  String get slots0Of30 => '0 / 30 slots';

  @override
  String get slots0Of40 => '0 / 40 slots';

  @override
  String get slots0Of50 => '0 / 50 slots';

  @override
  String get surfaceCoffeeTable => 'Coffee table';

  @override
  String get surfaceWallSwitch => 'Wall switch';

  @override
  String get surfaceLivingRoomDrawer => 'Living-room drawer';

  @override
  String get surfaceWindow => 'Window';

  @override
  String get surfaceLivingRoom => 'Living room';

  @override
  String get surfaceBed => 'Bed';

  @override
  String get surfaceCuttingBoard => 'Cutting board';

  @override
  String get surfaceKitchenCounter => 'Kitchen counter';

  @override
  String get surfaceToilet => 'Toilet';

  @override
  String get surfaceBasin => 'Basin';

  @override
  String get surfaceStoreShelf => 'Store shelf';

  @override
  String get surfaceCounter => 'Counter';

  @override
  String get taskLrPickRemoteTitle => 'Pick up and place the remote control';

  @override
  String get taskLrPickRemoteStep1 =>
      'Place the remote control on the living room table.';

  @override
  String get taskLrPickRemoteStep2 =>
      'Pick it up, move it to a different spot on the table, sofa, or chair, and pause for 1 second.';

  @override
  String get taskLrPickRemoteStep3 =>
      'Pick it up again and return it to its original spot, then pause for 1 second.';

  @override
  String get taskLrPickRemoteStep4 =>
      'Vary the destination spot across attempts; keep both hands in frame.';

  @override
  String get taskLrPickPhoneTitle => 'Pick up and place a phone';

  @override
  String get taskLrPickPhoneStep1 =>
      'Place the phone on the living room table.';

  @override
  String get taskLrPickPhoneStep2 =>
      'Pick it up, move it to a different spot on the table, sofa, or chair, and pause for 1 second.';

  @override
  String get taskLrPickPhoneStep3 =>
      'Pick it up again and return it to its original spot, then pause for 1 second.';

  @override
  String get taskLrPickPhoneStep4 =>
      'Vary the destination spot across attempts; keep both hands in frame.';

  @override
  String get taskLrPickPowerbankTitle => 'Pick up and place a power bank';

  @override
  String get taskLrPickPowerbankStep1 =>
      'Place the power bank on the living room table.';

  @override
  String get taskLrPickPowerbankStep2 =>
      'Pick it up, move it to a different spot on the table, sofa, or chair, and pause for 1 second.';

  @override
  String get taskLrPickPowerbankStep3 =>
      'Pick it up again and return it to its original spot, then pause for 1 second.';

  @override
  String get taskLrPickPowerbankStep4 =>
      'Vary the destination spot across attempts; keep both hands in frame.';

  @override
  String get taskLrPickComboTitle =>
      'Pick & place - remote + phone + power bank';

  @override
  String get taskLrPickComboStep1 =>
      'Place the remote control, phone, and power bank on the table together.';

  @override
  String get taskLrPickComboStep2 =>
      'Pick up the remote, move it to a new spot on the table / sofa / chair, pause 1 s, then return it.';

  @override
  String get taskLrPickComboStep3 =>
      'Repeat the same routine for the phone, then for the power bank.';

  @override
  String get taskLrPickComboStep4 =>
      'Vary destinations across items; keep the full motion in frame.';

  @override
  String get taskLrSwitchLightTitle => 'Toggle a wall light switch';

  @override
  String get taskLrSwitchLightStep1 => 'Walk up to the wall switch.';

  @override
  String get taskLrSwitchLightStep2 =>
      'Press it once to turn the light on; pause 2 s so the camera catches the light coming on.';

  @override
  String get taskLrSwitchLightStep3 =>
      'Press it again to turn the light off; pause 2 s so the camera catches it going off.';

  @override
  String get taskLrSwitchLightStep4 =>
      'Press fully each time - no half-presses; keep your hand visible.';

  @override
  String get taskLrSwitchDrawerTitle => 'Open and close a drawer';

  @override
  String get taskLrSwitchDrawerStep1 => 'Walk up to the drawer.';

  @override
  String get taskLrSwitchDrawerStep2 =>
      'Grip the handle and pull it fully open; pause 2 s.';

  @override
  String get taskLrSwitchDrawerStep3 => 'Push it fully closed; pause 2 s.';

  @override
  String get taskLrSwitchDrawerStep4 =>
      'Pull / push all the way each time - no half motions.';

  @override
  String get taskLrSwitchCurtainTitle => 'Open and close a curtain';

  @override
  String get taskLrSwitchCurtainStep1 => 'Walk up to the curtain.';

  @override
  String get taskLrSwitchCurtainStep2 =>
      'Grab the cord or fabric and pull it fully open to let light in; pause 2 s.';

  @override
  String get taskLrSwitchCurtainStep3 =>
      'Pull it fully closed again; pause 2 s.';

  @override
  String get taskLrSwitchCurtainStep4 =>
      'Always go from end to end - no half motions.';

  @override
  String get taskLrSwitchComboTitle => 'Light + drawer + curtain combo';

  @override
  String get taskLrSwitchComboStep1 =>
      'Toggle the wall light on, pause 2 s, then off, pause 2 s.';

  @override
  String get taskLrSwitchComboStep2 =>
      'Pull the drawer fully open, pause 2 s, then push it fully closed, pause 2 s.';

  @override
  String get taskLrSwitchComboStep3 =>
      'Pull the curtain fully open, pause 2 s, then close it, pause 2 s.';

  @override
  String get taskLrSwitchComboStep4 =>
      'Run all three in sequence; keep your hand in frame the whole time.';

  @override
  String get taskBrFoldClothesSingleTitle => 'Fold a single piece of clothing';

  @override
  String get taskBrFoldClothesSingleStep1 =>
      'Lay one clean t-shirt, shirt, or pair of trousers flat on the bed.';

  @override
  String get taskBrFoldClothesSingleStep2 =>
      'Fold both sides toward the centre, then roll or fold up from the bottom.';

  @override
  String get taskBrFoldClothesSingleStep3 =>
      'Place the folded item on the headboard or wardrobe shelf and pause 1 s.';

  @override
  String get taskBrFoldClothesSingleStep4 =>
      'Keep both hands visible - do not hold the garment up in front of the camera.';

  @override
  String get taskBrFoldClothesMultiTitle => 'Fold 2-3 pieces of clothing';

  @override
  String get taskBrFoldClothesMultiStep1 =>
      'Lay 2-3 clean garments flat on the bed.';

  @override
  String get taskBrFoldClothesMultiStep2 =>
      'Fold each one in turn - sides to centre, then bottom up - and stack on the shelf.';

  @override
  String get taskBrFoldClothesMultiStep3 =>
      'Finish each garment fully before starting the next.';

  @override
  String get taskBrFoldClothesMultiStep4 =>
      'Use a natural pace; keep hands in frame throughout.';

  @override
  String get taskBrFoldTowelSingleTitle => 'Fold a single towel';

  @override
  String get taskBrFoldTowelSingleStep1 =>
      'Lay one clean towel (face / bath) flat on the bed.';

  @override
  String get taskBrFoldTowelSingleStep2 =>
      'Fold it in half along the long edge, then in half along the short edge into a square.';

  @override
  String get taskBrFoldTowelSingleStep3 =>
      'Place it on the wash counter or wardrobe shelf.';

  @override
  String get taskBrFoldTowelSingleStep4 =>
      'Hands stay in frame; do not block the camera with the towel.';

  @override
  String get taskBrFoldTowelMultiTitle => 'Fold 2-3 towels';

  @override
  String get taskBrFoldTowelMultiStep1 =>
      'Lay 2-3 clean towels flat on the bed.';

  @override
  String get taskBrFoldTowelMultiStep2 =>
      'Fold each one - long edge in half, then short edge in half - and stack.';

  @override
  String get taskBrFoldTowelMultiStep3 =>
      'Finish each towel before moving to the next.';

  @override
  String get taskBrFoldTowelMultiStep4 => 'Natural pace; keep hands in frame.';

  @override
  String get taskKtCutFruitSingleTitle => 'Cut a single piece of fruit';

  @override
  String get taskKtCutFruitSingleStep1 =>
      'Wash one apple, orange, banana, or similar fruit.';

  @override
  String get taskKtCutFruitSingleStep2 =>
      'Place the fruit on the board and chop into pieces with the knife.';

  @override
  String get taskKtCutFruitSingleStep3 => 'Transfer the pieces to a plate.';

  @override
  String get taskKtCutFruitSingleStep4 =>
      'Mind the knife - do not raise it high enough that your hand leaves the frame.';

  @override
  String get taskKtCutFruitMultiTitle => 'Cut 2-3 different fruits';

  @override
  String get taskKtCutFruitMultiStep1 =>
      'Wash 2-3 different fruits (e.g. apple, orange, banana).';

  @override
  String get taskKtCutFruitMultiStep2 =>
      'Cut each one in turn on the board, transferring pieces to the plate after each.';

  @override
  String get taskKtCutFruitMultiStep3 =>
      'Pin the fruit with one hand, cut with the other; keep both visible.';

  @override
  String get taskKtCutFruitMultiStep4 =>
      'Upload as one clip - do not split per fruit.';

  @override
  String get taskKtTablewareSingleTitle =>
      'Set out a single piece of tableware';

  @override
  String get taskKtTablewareSingleStep1 =>
      'Pick one item (plate, bowl, chopsticks, fork, or spoon) and set it neatly on the counter or stovetop.';

  @override
  String get taskKtTablewareSingleStep2 =>
      'After placing, pick it back up and return it to its original spot.';

  @override
  String get taskKtTablewareSingleStep3 =>
      'Use the full reach-grasp-place motion; do not rush.';

  @override
  String get taskKtTablewareSingleStep4 =>
      'Different items count as separate clips.';

  @override
  String get taskKtTablewareMultiTitle =>
      'Set out multiple pieces of tableware';

  @override
  String get taskKtTablewareMultiStep1 =>
      'Place each item (plate, bowl, chopsticks, fork, spoon) on the counter one by one, neatly arranged.';

  @override
  String get taskKtTablewareMultiStep2 =>
      'Optionally collect them back to their original spot one by one.';

  @override
  String get taskKtTablewareMultiStep3 =>
      'Budget about 15-30 s per item; upload as one combined clip.';

  @override
  String get taskKtTablewareMultiStep4 => 'Light grip; do not drop bowls.';

  @override
  String get taskKtPourWaterTitle => 'Pour water from a kettle into a cup';

  @override
  String get taskKtPourWaterStep1 =>
      'Fill the kettle with water; place a cup on the counter.';

  @override
  String get taskKtPourWaterStep2 =>
      'Pick up the kettle, aim at the cup, and pour to about 70-80% full.';

  @override
  String get taskKtPourWaterStep3 => 'Set the kettle back on the counter.';

  @override
  String get taskKtPourWaterStep4 =>
      'Try different cups (glass, ceramic) across attempts; one pour = one clip.';

  @override
  String get taskKtPourCoffeeTitle => 'Pour coffee from a kettle into a cup';

  @override
  String get taskKtPourCoffeeStep1 =>
      'Fill the kettle with coffee; place a cup on the counter.';

  @override
  String get taskKtPourCoffeeStep2 =>
      'Pick up the kettle, aim at the cup, and pour to about 70-80% full.';

  @override
  String get taskKtPourCoffeeStep3 => 'Set the kettle back on the counter.';

  @override
  String get taskKtPourCoffeeStep4 =>
      'Try different cups (glass, ceramic) across attempts; one pour = one clip.';

  @override
  String get taskKtPourTeaTitle => 'Pour tea from a kettle into a cup';

  @override
  String get taskKtPourTeaStep1 =>
      'Fill the kettle with tea; place a cup on the counter.';

  @override
  String get taskKtPourTeaStep2 =>
      'Pick up the kettle, aim at the cup, and pour to about 70-80% full.';

  @override
  String get taskKtPourTeaStep3 => 'Set the kettle back on the counter.';

  @override
  String get taskKtPourTeaStep4 =>
      'Try different cups (glass, ceramic) across attempts; one pour = one clip.';

  @override
  String get taskKtPourComboTitle => 'Pour water + coffee + tea';

  @override
  String get taskKtPourComboStep1 =>
      'Prepare the kettle and cups (use water, tea, or coffee).';

  @override
  String get taskKtPourComboStep2 =>
      'Pour 2-3 cups in sequence, swapping cup styles where possible.';

  @override
  String get taskKtPourComboStep3 => 'After each pour, set the kettle down.';

  @override
  String get taskKtPourComboStep4 =>
      'Upload as one clip - pouring multiple cups is a single task.';

  @override
  String get taskBtWipeToiletTitle => 'Wipe down the outside of the toilet';

  @override
  String get taskBtWipeToiletStep1 =>
      'Take a clean cloth and spritz a little cleaner (a damp cloth is fine).';

  @override
  String get taskBtWipeToiletStep2 =>
      'Wipe the tank, lid, and outer body of the toilet, going back and forth.';

  @override
  String get taskBtWipeToiletStep3 =>
      'Cover all outside surfaces; keep your hand visible - do not let your body block the toilet.';

  @override
  String get taskBtWipeToiletStep4 => 'Return the cloth when finished.';

  @override
  String get taskBtCleanToiletSeatTitle => 'Clean the toilet seat ring';

  @override
  String get taskBtCleanToiletSeatStep1 =>
      'Lift the toilet seat ring up; record the lift motion.';

  @override
  String get taskBtCleanToiletSeatStep2 =>
      'Wipe the underside, then flip and wipe the top so both sides are clean.';

  @override
  String get taskBtCleanToiletSeatStep3 =>
      'Lower the seat back into place; put the cloth away.';

  @override
  String get taskBtCleanToiletSeatStep4 =>
      'Mind hygiene - do not splash on yourself.';

  @override
  String get taskBtCleanBasinTitle => 'Clean the wash basin';

  @override
  String get taskBtCleanBasinStep1 =>
      'Wipe the inside of the basin, then the surrounding counter, then the tap.';

  @override
  String get taskBtCleanBasinStep2 =>
      'Make sure every wipe motion is captured; do not skip regions.';

  @override
  String get taskBtCleanBasinStep3 =>
      'Avoid splashing water around - clean as you would normally.';

  @override
  String get taskBtCleanBasinStep4 => 'Return the cloth.';

  @override
  String get taskCsPickShelfSingleTitle =>
      'Take a single product off the shelf';

  @override
  String get taskCsPickShelfSingleStep1 =>
      'Set up a shelf with everyday convenience-store items (water, biscuits, toothpaste, etc.).';

  @override
  String get taskCsPickShelfSingleStep2 =>
      'Take one item off the shelf and place it in the basket in front of you; pause 1 s.';

  @override
  String get taskCsPickShelfSingleStep3 =>
      'Pick it back out of the basket and return it to its original shelf spot.';

  @override
  String get taskCsPickShelfSingleStep4 =>
      'Use different shelf heights across attempts but stay reachable - one item = one clip.';

  @override
  String get taskCsPickShelfMultiTitle => 'Take 2-3 products off the shelf';

  @override
  String get taskCsPickShelfMultiStep1 =>
      'Stock the shelf with assorted convenience items.';

  @override
  String get taskCsPickShelfMultiStep2 =>
      'For each of 2-3 items: take it off the shelf, place in the basket, pause 1 s, then return it.';

  @override
  String get taskCsPickShelfMultiStep3 =>
      'Vary which shelves you pull from (top, middle, bottom).';

  @override
  String get taskCsPickShelfMultiStep4 =>
      'Upload as a single clip - multiple items is one task.';

  @override
  String get taskCsWipeCounterTitle => 'Wipe down the counter / shelf surface';

  @override
  String get taskCsWipeCounterStep1 => 'Take a damp cloth.';

  @override
  String get taskCsWipeCounterStep2 =>
      'Wipe the cashier counter or shelf surface left to right, covering the whole top.';

  @override
  String get taskCsWipeCounterStep3 =>
      'Keep your hand visible throughout the wipe.';

  @override
  String get taskCsWipeCounterStep4 => 'Return the cloth when done.';

  @override
  String get taskCsHandoverSingleTitle => 'Hand a single product to a customer';

  @override
  String get taskCsHandoverSingleStep1 =>
      'Stock a shelf with items; have a friend or family member stand in front of you as the customer.';

  @override
  String get taskCsHandoverSingleStep2 =>
      'Take one item (e.g. a bottle of water) off the shelf and hand it to the customer.';

  @override
  String get taskCsHandoverSingleStep3 => 'The customer takes it; pause 1 s.';

  @override
  String get taskCsHandoverSingleStep4 =>
      'Both your hand and the customer\'s hand can be in frame - natural handover motion.';

  @override
  String get taskCsHandoverMultiTitle => 'Hand 2-3 products to a customer';

  @override
  String get taskCsHandoverMultiStep1 =>
      'Stock a shelf and have a customer stand opposite you.';

  @override
  String get taskCsHandoverMultiStep2 =>
      'Take an item off the shelf and hand it over; pause 1 s.';

  @override
  String get taskCsHandoverMultiStep3 => 'Repeat for 2-3 different items.';

  @override
  String get taskCsHandoverMultiStep4 =>
      'Upload as one clip - multiple handovers is a single task.';
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'Digients 采集'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get navHome;

  /// No description provided for @navSubmissions.
  ///
  /// In zh, this message translates to:
  /// **'提交'**
  String get navSubmissions;

  /// No description provided for @navMe.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get navMe;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @settingsAccount.
  ///
  /// In zh, this message translates to:
  /// **'账号'**
  String get settingsAccount;

  /// No description provided for @settingsUploads.
  ///
  /// In zh, this message translates to:
  /// **'上传'**
  String get settingsUploads;

  /// No description provided for @settingsRecordingFeedback.
  ///
  /// In zh, this message translates to:
  /// **'录制反馈'**
  String get settingsRecordingFeedback;

  /// No description provided for @settingsNotifications.
  ///
  /// In zh, this message translates to:
  /// **'通知'**
  String get settingsNotifications;

  /// No description provided for @settingsAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get settingsAppearance;

  /// No description provided for @settingsAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get settingsAbout;

  /// No description provided for @settingsEmail.
  ///
  /// In zh, this message translates to:
  /// **'邮箱'**
  String get settingsEmail;

  /// No description provided for @settingsPhone.
  ///
  /// In zh, this message translates to:
  /// **'手机号'**
  String get settingsPhone;

  /// No description provided for @settingsUid.
  ///
  /// In zh, this message translates to:
  /// **'UID'**
  String get settingsUid;

  /// No description provided for @settingsWifiOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅 Wi-Fi 上传'**
  String get settingsWifiOnly;

  /// No description provided for @settingsAutoUpload.
  ///
  /// In zh, this message translates to:
  /// **'采集后自动上传'**
  String get settingsAutoUpload;

  /// No description provided for @settingsBackgroundUploads.
  ///
  /// In zh, this message translates to:
  /// **'后台上传'**
  String get settingsBackgroundUploads;

  /// No description provided for @settingsHandVoiceCues.
  ///
  /// In zh, this message translates to:
  /// **'手部检测语音提示'**
  String get settingsHandVoiceCues;

  /// No description provided for @settingsBorderIndicator.
  ///
  /// In zh, this message translates to:
  /// **'边框提示'**
  String get settingsBorderIndicator;

  /// No description provided for @settingsVibrateOnNoHands.
  ///
  /// In zh, this message translates to:
  /// **'无手部时振动'**
  String get settingsVibrateOnNoHands;

  /// No description provided for @settingsApprovalResults.
  ///
  /// In zh, this message translates to:
  /// **'审核结果'**
  String get settingsApprovalResults;

  /// No description provided for @settingsPointsCredited.
  ///
  /// In zh, this message translates to:
  /// **'积分到账'**
  String get settingsPointsCredited;

  /// No description provided for @settingsTheme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get settingsTheme;

  /// No description provided for @settingsLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingsLanguage;

  /// No description provided for @settingsVersion.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get settingsVersion;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsTermsOfService.
  ///
  /// In zh, this message translates to:
  /// **'服务条款'**
  String get settingsTermsOfService;

  /// No description provided for @settingsOpenSourceLicenses.
  ///
  /// In zh, this message translates to:
  /// **'开源许可证'**
  String get settingsOpenSourceLicenses;

  /// No description provided for @settingsSignOut.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get settingsSignOut;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In zh, this message translates to:
  /// **'删除账号'**
  String get settingsDeleteAccount;

  /// No description provided for @languageChinese.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @themeAuto.
  ///
  /// In zh, this message translates to:
  /// **'自动'**
  String get themeAuto;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// No description provided for @authEnterPhoneFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先输入手机号。'**
  String get authEnterPhoneFirst;

  /// No description provided for @authEnterEmailFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先输入邮箱。'**
  String get authEnterEmailFirst;

  /// No description provided for @authEnterSixDigitCode.
  ///
  /// In zh, this message translates to:
  /// **'请输入 6 位验证码。'**
  String get authEnterSixDigitCode;

  /// No description provided for @authInvalidCode.
  ///
  /// In zh, this message translates to:
  /// **'验证码不正确。'**
  String get authInvalidCode;

  /// No description provided for @authSomethingWentWrong.
  ///
  /// In zh, this message translates to:
  /// **'出错了：{error}'**
  String authSomethingWentWrong(String error);

  /// No description provided for @authCreateAccount.
  ///
  /// In zh, this message translates to:
  /// **'创建账号'**
  String get authCreateAccount;

  /// No description provided for @authWelcomeBack.
  ///
  /// In zh, this message translates to:
  /// **'欢迎回来'**
  String get authWelcomeBack;

  /// No description provided for @authSignUpSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'注册后即可开始贡献录制数据。'**
  String get authSignUpSubtitle;

  /// No description provided for @authSignInSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'登录后继续采集。'**
  String get authSignInSubtitle;

  /// No description provided for @authPhone.
  ///
  /// In zh, this message translates to:
  /// **'手机号'**
  String get authPhone;

  /// No description provided for @authEmail.
  ///
  /// In zh, this message translates to:
  /// **'邮箱'**
  String get authEmail;

  /// No description provided for @authAgreementPrefix.
  ///
  /// In zh, this message translates to:
  /// **'创建账号即表示你同意我们的'**
  String get authAgreementPrefix;

  /// No description provided for @authTerms.
  ///
  /// In zh, this message translates to:
  /// **'服务条款'**
  String get authTerms;

  /// No description provided for @authAgreementMiddle.
  ///
  /// In zh, this message translates to:
  /// **'和'**
  String get authAgreementMiddle;

  /// No description provided for @authPrivacyPolicy.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策'**
  String get authPrivacyPolicy;

  /// No description provided for @authAgreementSuffix.
  ///
  /// In zh, this message translates to:
  /// **'。'**
  String get authAgreementSuffix;

  /// No description provided for @authSending.
  ///
  /// In zh, this message translates to:
  /// **'发送中...'**
  String get authSending;

  /// No description provided for @authSendVerificationCode.
  ///
  /// In zh, this message translates to:
  /// **'发送验证码'**
  String get authSendVerificationCode;

  /// No description provided for @authVerifying.
  ///
  /// In zh, this message translates to:
  /// **'验证中...'**
  String get authVerifying;

  /// No description provided for @authSignIn.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get authSignIn;

  /// No description provided for @authApple.
  ///
  /// In zh, this message translates to:
  /// **'Apple'**
  String get authApple;

  /// No description provided for @authGoogle.
  ///
  /// In zh, this message translates to:
  /// **'Google'**
  String get authGoogle;

  /// No description provided for @authOr.
  ///
  /// In zh, this message translates to:
  /// **'或'**
  String get authOr;

  /// No description provided for @authAlreadyHaveAccount.
  ///
  /// In zh, this message translates to:
  /// **'已有账号？'**
  String get authAlreadyHaveAccount;

  /// No description provided for @authDontHaveAccount.
  ///
  /// In zh, this message translates to:
  /// **'还没有账号？'**
  String get authDontHaveAccount;

  /// No description provided for @authRegister.
  ///
  /// In zh, this message translates to:
  /// **'注册'**
  String get authRegister;

  /// No description provided for @authPhoneComingSoonTitle.
  ///
  /// In zh, this message translates to:
  /// **'手机号登录暂未开放'**
  String get authPhoneComingSoonTitle;

  /// No description provided for @authPhoneComingSoonBody.
  ///
  /// In zh, this message translates to:
  /// **'短信验证还在开发中，请先使用邮箱或下方免登录入口。'**
  String get authPhoneComingSoonBody;

  /// No description provided for @authSkipSignIn.
  ///
  /// In zh, this message translates to:
  /// **'免登录（演示）'**
  String get authSkipSignIn;

  /// No description provided for @authSkipSignInHint.
  ///
  /// In zh, this message translates to:
  /// **'跳过后将无法上传视频'**
  String get authSkipSignInHint;

  /// No description provided for @authInviteCodeSignIn.
  ///
  /// In zh, this message translates to:
  /// **'用邀请码登录'**
  String get authInviteCodeSignIn;

  /// No description provided for @authInviteCodeModalTitle.
  ///
  /// In zh, this message translates to:
  /// **'输入邀请码'**
  String get authInviteCodeModalTitle;

  /// No description provided for @authInviteCodeModalHint.
  ///
  /// In zh, this message translates to:
  /// **'向 Digients 团队获取你的邀请码'**
  String get authInviteCodeModalHint;

  /// No description provided for @authInviteCodeInputLabel.
  ///
  /// In zh, this message translates to:
  /// **'邀请码'**
  String get authInviteCodeInputLabel;

  /// No description provided for @authInviteCodeSubmit.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get authInviteCodeSubmit;

  /// No description provided for @authInviteCodeMissing.
  ///
  /// In zh, this message translates to:
  /// **'请输入邀请码'**
  String get authInviteCodeMissing;

  /// No description provided for @uploadLockedTitle.
  ///
  /// In zh, this message translates to:
  /// **'上传需要登录'**
  String get uploadLockedTitle;

  /// No description provided for @uploadLockedBody.
  ///
  /// In zh, this message translates to:
  /// **'退出登录后用邀请码重新进入即可启用视频上传。'**
  String get uploadLockedBody;

  /// No description provided for @uploadLockedSignOut.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get uploadLockedSignOut;

  /// No description provided for @uploadLockedDismiss.
  ///
  /// In zh, this message translates to:
  /// **'暂不'**
  String get uploadLockedDismiss;

  /// No description provided for @uploadLockedShortLabel.
  ///
  /// In zh, this message translates to:
  /// **'需登录'**
  String get uploadLockedShortLabel;

  /// No description provided for @homeWelcomeBack.
  ///
  /// In zh, this message translates to:
  /// **'欢迎回来'**
  String get homeWelcomeBack;

  /// No description provided for @balance.
  ///
  /// In zh, this message translates to:
  /// **'余额'**
  String get balance;

  /// No description provided for @pending.
  ///
  /// In zh, this message translates to:
  /// **'待入账'**
  String get pending;

  /// No description provided for @pointsSuffix.
  ///
  /// In zh, this message translates to:
  /// **'积分'**
  String get pointsSuffix;

  /// No description provided for @chooseCategory.
  ///
  /// In zh, this message translates to:
  /// **'选择场景'**
  String get chooseCategory;

  /// No description provided for @tasksCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个任务'**
  String tasksCount(int count);

  /// No description provided for @comingSoon.
  ///
  /// In zh, this message translates to:
  /// **'即将开放'**
  String get comingSoon;

  /// No description provided for @upToPoints.
  ///
  /// In zh, this message translates to:
  /// **'最高 +{points}'**
  String upToPoints(int points);

  /// No description provided for @digientsTasks.
  ///
  /// In zh, this message translates to:
  /// **'Digients 任务'**
  String get digientsTasks;

  /// No description provided for @tasksTitle.
  ///
  /// In zh, this message translates to:
  /// **'任务'**
  String get tasksTitle;

  /// No description provided for @poolSortedByReward.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个任务 · 按奖励排序'**
  String poolSortedByReward(int count);

  /// No description provided for @filterAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get filterAll;

  /// No description provided for @filterHighReward.
  ///
  /// In zh, this message translates to:
  /// **'高奖励'**
  String get filterHighReward;

  /// No description provided for @filterQuick.
  ///
  /// In zh, this message translates to:
  /// **'快速（<3 分钟）'**
  String get filterQuick;

  /// No description provided for @filterBeginner.
  ///
  /// In zh, this message translates to:
  /// **'新手'**
  String get filterBeginner;

  /// No description provided for @filterVerified.
  ///
  /// In zh, this message translates to:
  /// **'已验证'**
  String get filterVerified;

  /// No description provided for @noTasks.
  ///
  /// In zh, this message translates to:
  /// **'暂无任务'**
  String get noTasks;

  /// No description provided for @taskNotFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到任务'**
  String get taskNotFound;

  /// No description provided for @taskDetails.
  ///
  /// In zh, this message translates to:
  /// **'任务详情'**
  String get taskDetails;

  /// No description provided for @demoCaption.
  ///
  /// In zh, this message translates to:
  /// **'演示 · 0:08'**
  String get demoCaption;

  /// No description provided for @pointsOnApproval.
  ///
  /// In zh, this message translates to:
  /// **'审核通过后到账'**
  String get pointsOnApproval;

  /// No description provided for @duration.
  ///
  /// In zh, this message translates to:
  /// **'时长'**
  String get duration;

  /// No description provided for @difficulty.
  ///
  /// In zh, this message translates to:
  /// **'难度'**
  String get difficulty;

  /// No description provided for @lighting.
  ///
  /// In zh, this message translates to:
  /// **'光线'**
  String get lighting;

  /// No description provided for @surface.
  ///
  /// In zh, this message translates to:
  /// **'表面'**
  String get surface;

  /// No description provided for @steps.
  ///
  /// In zh, this message translates to:
  /// **'步骤'**
  String get steps;

  /// No description provided for @headsUp.
  ///
  /// In zh, this message translates to:
  /// **'提示'**
  String get headsUp;

  /// No description provided for @storageWarning.
  ///
  /// In zh, this message translates to:
  /// **'剩余存储空间低于 5% 时会自动停止录制，手机会振动提醒。'**
  String get storageWarning;

  /// No description provided for @storageAvailability.
  ///
  /// In zh, this message translates to:
  /// **'存储 · 可录 2小时35分 · 剩余 18.0 GB'**
  String get storageAvailability;

  /// No description provided for @record.
  ///
  /// In zh, this message translates to:
  /// **'录制'**
  String get record;

  /// No description provided for @cameraPermissionRequired.
  ///
  /// In zh, this message translates to:
  /// **'需要相机权限'**
  String get cameraPermissionRequired;

  /// No description provided for @failedToInitializeCamera.
  ///
  /// In zh, this message translates to:
  /// **'相机初始化失败'**
  String get failedToInitializeCamera;

  /// No description provided for @failedToStartRecording.
  ///
  /// In zh, this message translates to:
  /// **'录制启动失败'**
  String get failedToStartRecording;

  /// No description provided for @tapToStop.
  ///
  /// In zh, this message translates to:
  /// **'点击停止'**
  String get tapToStop;

  /// No description provided for @tapToStart.
  ///
  /// In zh, this message translates to:
  /// **'点击开始'**
  String get tapToStart;

  /// No description provided for @preStartPrompt.
  ///
  /// In zh, this message translates to:
  /// **'将双手放在画面内'**
  String get preStartPrompt;

  /// No description provided for @pressVolumeButtonToStart.
  ///
  /// In zh, this message translates to:
  /// **'按音量键开始'**
  String get pressVolumeButtonToStart;

  /// No description provided for @mountCaptionPhone.
  ///
  /// In zh, this message translates to:
  /// **'横向放置手机，并让箭头朝上'**
  String get mountCaptionPhone;

  /// No description provided for @mountCaptionHeadband.
  ///
  /// In zh, this message translates to:
  /// **'固定到头戴绑带上进行采集'**
  String get mountCaptionHeadband;

  /// No description provided for @instructionsEndIn.
  ///
  /// In zh, this message translates to:
  /// **'{seconds} 秒后开始'**
  String instructionsEndIn(int seconds);

  /// No description provided for @skip.
  ///
  /// In zh, this message translates to:
  /// **'跳过'**
  String get skip;

  /// No description provided for @thisSideUp.
  ///
  /// In zh, this message translates to:
  /// **'此面朝上'**
  String get thisSideUp;

  /// No description provided for @submittedTitle.
  ///
  /// In zh, this message translates to:
  /// **'已提交！'**
  String get submittedTitle;

  /// No description provided for @successCopyUploading.
  ///
  /// In zh, this message translates to:
  /// **'数据正在上传，稍后会进入审核。'**
  String get successCopyUploading;

  /// No description provided for @successCopyKeepConnection.
  ///
  /// In zh, this message translates to:
  /// **'请保持网络连接。'**
  String get successCopyKeepConnection;

  /// No description provided for @successCopyPointsSoon.
  ///
  /// In zh, this message translates to:
  /// **'积分通常会在约 48 小时内到账。'**
  String get successCopyPointsSoon;

  /// No description provided for @pendingReview.
  ///
  /// In zh, this message translates to:
  /// **'等待审核'**
  String get pendingReview;

  /// No description provided for @goToSubmissions.
  ///
  /// In zh, this message translates to:
  /// **'前往提交记录'**
  String get goToSubmissions;

  /// No description provided for @submissionSaved.
  ///
  /// In zh, this message translates to:
  /// **'提交已保存'**
  String get submissionSaved;

  /// No description provided for @takePoints.
  ///
  /// In zh, this message translates to:
  /// **'第 {takeNumber} 次 · +{points} 积分'**
  String takePoints(int takeNumber, int points);

  /// No description provided for @pressVolumeAnotherTake.
  ///
  /// In zh, this message translates to:
  /// **'按音量键\n继续录制下一条'**
  String get pressVolumeAnotherTake;

  /// No description provided for @submissionsTitle.
  ///
  /// In zh, this message translates to:
  /// **'提交记录'**
  String get submissionsTitle;

  /// No description provided for @submissionsTotal.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 条 · 设备上 {totalGb} GB'**
  String submissionsTotal(int count, String totalGb);

  /// No description provided for @selectMultiple.
  ///
  /// In zh, this message translates to:
  /// **'多选'**
  String get selectMultiple;

  /// No description provided for @selectRecordings.
  ///
  /// In zh, this message translates to:
  /// **'选择录制'**
  String get selectRecordings;

  /// No description provided for @selectedCount.
  ///
  /// In zh, this message translates to:
  /// **'已选择 {count} 条'**
  String selectedCount(int count);

  /// No description provided for @selectionHint.
  ///
  /// In zh, this message translates to:
  /// **'点击切换选择 · 长按一行开始选择'**
  String get selectionHint;

  /// No description provided for @clear.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get clear;

  /// No description provided for @selectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get selectAll;

  /// No description provided for @done.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get done;

  /// No description provided for @noItems.
  ///
  /// In zh, this message translates to:
  /// **'暂无内容'**
  String get noItems;

  /// No description provided for @noItemsPrompt.
  ///
  /// In zh, this message translates to:
  /// **'从首页选择一个场景开始录制。'**
  String get noItemsPrompt;

  /// No description provided for @compressingRecording.
  ///
  /// In zh, this message translates to:
  /// **'正在压缩录制文件...'**
  String get compressingRecording;

  /// No description provided for @compressingProgress.
  ///
  /// In zh, this message translates to:
  /// **'正在压缩 {current} / {total}...'**
  String compressingProgress(int current, int total);

  /// No description provided for @exportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败：{error}'**
  String exportFailed(String error);

  /// No description provided for @shareUnavailableOriginalsGone.
  ///
  /// In zh, this message translates to:
  /// **'上传后原始文件已清理，无法再分享。'**
  String get shareUnavailableOriginalsGone;

  /// No description provided for @shareSubjectRecording.
  ///
  /// In zh, this message translates to:
  /// **'第一视角视频录制'**
  String get shareSubjectRecording;

  /// No description provided for @shareTextRecording.
  ///
  /// In zh, this message translates to:
  /// **'第一视角视频录制数据包'**
  String get shareTextRecording;

  /// No description provided for @shareSubjectRecordings.
  ///
  /// In zh, this message translates to:
  /// **'第一视角视频录制（{count} 条）'**
  String shareSubjectRecordings(int count);

  /// No description provided for @shareTextRecordings.
  ///
  /// In zh, this message translates to:
  /// **'第一视角视频录制数据包'**
  String get shareTextRecordings;

  /// No description provided for @deleteRecordingTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除录制？'**
  String get deleteRecordingTitle;

  /// No description provided for @deleteRecordingContent.
  ///
  /// In zh, this message translates to:
  /// **'这会删除本地录制 {idPrefix}。'**
  String deleteRecordingContent(String idPrefix);

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @export.
  ///
  /// In zh, this message translates to:
  /// **'导出'**
  String get export;

  /// No description provided for @exportSelected.
  ///
  /// In zh, this message translates to:
  /// **'导出已选'**
  String get exportSelected;

  /// No description provided for @exportRecordingCount.
  ///
  /// In zh, this message translates to:
  /// **'导出 {count} 条录制'**
  String exportRecordingCount(int count);

  /// No description provided for @uploadToCloud.
  ///
  /// In zh, this message translates to:
  /// **'上传到云端'**
  String get uploadToCloud;

  /// No description provided for @uploadToCloudCount.
  ///
  /// In zh, this message translates to:
  /// **'上传 {count} 条到云端'**
  String uploadToCloudCount(int count);

  /// No description provided for @uploadingPercent.
  ///
  /// In zh, this message translates to:
  /// **'上传中 {percent}%'**
  String uploadingPercent(int percent);

  /// No description provided for @uploadQueuedLabel.
  ///
  /// In zh, this message translates to:
  /// **'排队中'**
  String get uploadQueuedLabel;

  /// No description provided for @uploadCompressingShort.
  ///
  /// In zh, this message translates to:
  /// **'压缩中'**
  String get uploadCompressingShort;

  /// No description provided for @uploadCompressingLong.
  ///
  /// In zh, this message translates to:
  /// **'压缩中…'**
  String get uploadCompressingLong;

  /// No description provided for @compressFailedShort.
  ///
  /// In zh, this message translates to:
  /// **'压缩失败'**
  String get compressFailedShort;

  /// No description provided for @uploadFinalizingShort.
  ///
  /// In zh, this message translates to:
  /// **'结尾中'**
  String get uploadFinalizingShort;

  /// No description provided for @uploadFinalizingLong.
  ///
  /// In zh, this message translates to:
  /// **'结尾中…'**
  String get uploadFinalizingLong;

  /// No description provided for @uploadedLabel.
  ///
  /// In zh, this message translates to:
  /// **'已上传'**
  String get uploadedLabel;

  /// No description provided for @uploadShort.
  ///
  /// In zh, this message translates to:
  /// **'上传'**
  String get uploadShort;

  /// No description provided for @uploadRetryShort.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get uploadRetryShort;

  /// No description provided for @uploadFailedShort.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get uploadFailedShort;

  /// No description provided for @uploadFailedRetry.
  ///
  /// In zh, this message translates to:
  /// **'上传失败 — 点击重试'**
  String get uploadFailedRetry;

  /// No description provided for @uploadForegroundBannerTitle.
  ///
  /// In zh, this message translates to:
  /// **'上传中 — 建议保持 App 在前台'**
  String get uploadForegroundBannerTitle;

  /// No description provided for @uploadForegroundBannerBody.
  ///
  /// In zh, this message translates to:
  /// **'强制退出会取消上传。'**
  String get uploadForegroundBannerBody;

  /// No description provided for @uploadFailedSnack.
  ///
  /// In zh, this message translates to:
  /// **'上传失败：{error}'**
  String uploadFailedSnack(String error);

  /// No description provided for @savedOnDevice.
  ///
  /// In zh, this message translates to:
  /// **'已保存在设备上'**
  String get savedOnDevice;

  /// No description provided for @notUploadedYet.
  ///
  /// In zh, this message translates to:
  /// **'尚未上传。你可以使用导出，通过系统分享面板发送录制数据包。'**
  String get notUploadedYet;

  /// No description provided for @sessionId.
  ///
  /// In zh, this message translates to:
  /// **'会话 ID'**
  String get sessionId;

  /// No description provided for @captured.
  ///
  /// In zh, this message translates to:
  /// **'采集时间'**
  String get captured;

  /// No description provided for @size.
  ///
  /// In zh, this message translates to:
  /// **'大小'**
  String get size;

  /// No description provided for @codec.
  ///
  /// In zh, this message translates to:
  /// **'编码'**
  String get codec;

  /// No description provided for @resolution.
  ///
  /// In zh, this message translates to:
  /// **'分辨率'**
  String get resolution;

  /// No description provided for @intrinsics.
  ///
  /// In zh, this message translates to:
  /// **'内参'**
  String get intrinsics;

  /// No description provided for @perFrame.
  ///
  /// In zh, this message translates to:
  /// **'逐帧'**
  String get perFrame;

  /// No description provided for @keepAppOpen.
  ///
  /// In zh, this message translates to:
  /// **'请保持应用打开'**
  String get keepAppOpen;

  /// No description provided for @statusOnDevice.
  ///
  /// In zh, this message translates to:
  /// **'设备上'**
  String get statusOnDevice;

  /// No description provided for @statusUploading.
  ///
  /// In zh, this message translates to:
  /// **'上传中'**
  String get statusUploading;

  /// No description provided for @statusInReview.
  ///
  /// In zh, this message translates to:
  /// **'审核中'**
  String get statusInReview;

  /// No description provided for @statusApproved.
  ///
  /// In zh, this message translates to:
  /// **'已通过'**
  String get statusApproved;

  /// No description provided for @statusRejected.
  ///
  /// In zh, this message translates to:
  /// **'已拒绝'**
  String get statusRejected;

  /// No description provided for @recordingTitle.
  ///
  /// In zh, this message translates to:
  /// **'录制 {idPrefix}'**
  String recordingTitle(String idPrefix);

  /// No description provided for @recordingInCategory.
  ///
  /// In zh, this message translates to:
  /// **'{category} · {idPrefix}'**
  String recordingInCategory(String category, String idPrefix);

  /// No description provided for @profileHours.
  ///
  /// In zh, this message translates to:
  /// **'小时'**
  String get profileHours;

  /// No description provided for @profileSubmitted.
  ///
  /// In zh, this message translates to:
  /// **'已提交'**
  String get profileSubmitted;

  /// No description provided for @profileApproval.
  ///
  /// In zh, this message translates to:
  /// **'通过率'**
  String get profileApproval;

  /// No description provided for @profileCapability.
  ///
  /// In zh, this message translates to:
  /// **'能力'**
  String get profileCapability;

  /// No description provided for @capabilityHousehold.
  ///
  /// In zh, this message translates to:
  /// **'家务'**
  String get capabilityHousehold;

  /// No description provided for @capabilityIndustrial.
  ///
  /// In zh, this message translates to:
  /// **'工业'**
  String get capabilityIndustrial;

  /// No description provided for @capabilitySports.
  ///
  /// In zh, this message translates to:
  /// **'运动'**
  String get capabilitySports;

  /// No description provided for @capabilityVariety.
  ///
  /// In zh, this message translates to:
  /// **'多样性'**
  String get capabilityVariety;

  /// No description provided for @capabilitySpeed.
  ///
  /// In zh, this message translates to:
  /// **'速度'**
  String get capabilitySpeed;

  /// No description provided for @capabilityApproval.
  ///
  /// In zh, this message translates to:
  /// **'通过率'**
  String get capabilityApproval;

  /// No description provided for @leaderboardGlobal.
  ///
  /// In zh, this message translates to:
  /// **'全球排行榜'**
  String get leaderboardGlobal;

  /// No description provided for @rankNumber.
  ///
  /// In zh, this message translates to:
  /// **'排名 #{rank}'**
  String rankNumber(int rank);

  /// No description provided for @categoryLivingRoom.
  ///
  /// In zh, this message translates to:
  /// **'客厅'**
  String get categoryLivingRoom;

  /// No description provided for @categoryKitchen.
  ///
  /// In zh, this message translates to:
  /// **'厨房'**
  String get categoryKitchen;

  /// No description provided for @categoryBedroom.
  ///
  /// In zh, this message translates to:
  /// **'卧室'**
  String get categoryBedroom;

  /// No description provided for @categoryConvenienceStore.
  ///
  /// In zh, this message translates to:
  /// **'便利店'**
  String get categoryConvenienceStore;

  /// No description provided for @categoryBathroom.
  ///
  /// In zh, this message translates to:
  /// **'浴室'**
  String get categoryBathroom;

  /// No description provided for @taskTagPickPlace.
  ///
  /// In zh, this message translates to:
  /// **'抓取放置'**
  String get taskTagPickPlace;

  /// No description provided for @taskTagSwitch.
  ///
  /// In zh, this message translates to:
  /// **'开关'**
  String get taskTagSwitch;

  /// No description provided for @taskTagFolding.
  ///
  /// In zh, this message translates to:
  /// **'折叠'**
  String get taskTagFolding;

  /// No description provided for @taskTagCutting.
  ///
  /// In zh, this message translates to:
  /// **'切配'**
  String get taskTagCutting;

  /// No description provided for @taskTagTableware.
  ///
  /// In zh, this message translates to:
  /// **'餐具'**
  String get taskTagTableware;

  /// No description provided for @taskTagPouring.
  ///
  /// In zh, this message translates to:
  /// **'倒取'**
  String get taskTagPouring;

  /// No description provided for @taskTagCleaning.
  ///
  /// In zh, this message translates to:
  /// **'清洁'**
  String get taskTagCleaning;

  /// No description provided for @taskTagHandover.
  ///
  /// In zh, this message translates to:
  /// **'递交'**
  String get taskTagHandover;

  /// No description provided for @difficultyEasy.
  ///
  /// In zh, this message translates to:
  /// **'简单'**
  String get difficultyEasy;

  /// No description provided for @difficultyMedium.
  ///
  /// In zh, this message translates to:
  /// **'中等'**
  String get difficultyMedium;

  /// No description provided for @lightingBrightIndoor.
  ///
  /// In zh, this message translates to:
  /// **'明亮室内'**
  String get lightingBrightIndoor;

  /// No description provided for @lightingMixed.
  ///
  /// In zh, this message translates to:
  /// **'混合光线'**
  String get lightingMixed;

  /// No description provided for @lightingEvenOverhead.
  ///
  /// In zh, this message translates to:
  /// **'均匀顶光'**
  String get lightingEvenOverhead;

  /// No description provided for @duration10To20.
  ///
  /// In zh, this message translates to:
  /// **'10–20 秒'**
  String get duration10To20;

  /// No description provided for @duration15To30.
  ///
  /// In zh, this message translates to:
  /// **'15–30 秒'**
  String get duration15To30;

  /// No description provided for @duration30To60.
  ///
  /// In zh, this message translates to:
  /// **'30–60 秒'**
  String get duration30To60;

  /// No description provided for @duration30To90.
  ///
  /// In zh, this message translates to:
  /// **'30–90 秒'**
  String get duration30To90;

  /// No description provided for @duration45To90.
  ///
  /// In zh, this message translates to:
  /// **'45–90 秒'**
  String get duration45To90;

  /// No description provided for @duration60To120.
  ///
  /// In zh, this message translates to:
  /// **'60–120 秒'**
  String get duration60To120;

  /// No description provided for @duration60To180.
  ///
  /// In zh, this message translates to:
  /// **'60–180 秒'**
  String get duration60To180;

  /// No description provided for @duration120To240.
  ///
  /// In zh, this message translates to:
  /// **'120–240 秒'**
  String get duration120To240;

  /// No description provided for @slots0Of30.
  ///
  /// In zh, this message translates to:
  /// **'0 / 30 名额'**
  String get slots0Of30;

  /// No description provided for @slots0Of40.
  ///
  /// In zh, this message translates to:
  /// **'0 / 40 名额'**
  String get slots0Of40;

  /// No description provided for @slots0Of50.
  ///
  /// In zh, this message translates to:
  /// **'0 / 50 名额'**
  String get slots0Of50;

  /// No description provided for @surfaceCoffeeTable.
  ///
  /// In zh, this message translates to:
  /// **'茶几'**
  String get surfaceCoffeeTable;

  /// No description provided for @surfaceWallSwitch.
  ///
  /// In zh, this message translates to:
  /// **'墙壁开关'**
  String get surfaceWallSwitch;

  /// No description provided for @surfaceLivingRoomDrawer.
  ///
  /// In zh, this message translates to:
  /// **'客厅抽屉'**
  String get surfaceLivingRoomDrawer;

  /// No description provided for @surfaceWindow.
  ///
  /// In zh, this message translates to:
  /// **'窗户'**
  String get surfaceWindow;

  /// No description provided for @surfaceLivingRoom.
  ///
  /// In zh, this message translates to:
  /// **'客厅'**
  String get surfaceLivingRoom;

  /// No description provided for @surfaceBed.
  ///
  /// In zh, this message translates to:
  /// **'床'**
  String get surfaceBed;

  /// No description provided for @surfaceCuttingBoard.
  ///
  /// In zh, this message translates to:
  /// **'砧板'**
  String get surfaceCuttingBoard;

  /// No description provided for @surfaceKitchenCounter.
  ///
  /// In zh, this message translates to:
  /// **'厨房台面'**
  String get surfaceKitchenCounter;

  /// No description provided for @surfaceToilet.
  ///
  /// In zh, this message translates to:
  /// **'马桶'**
  String get surfaceToilet;

  /// No description provided for @surfaceBasin.
  ///
  /// In zh, this message translates to:
  /// **'洗手盆'**
  String get surfaceBasin;

  /// No description provided for @surfaceStoreShelf.
  ///
  /// In zh, this message translates to:
  /// **'货架'**
  String get surfaceStoreShelf;

  /// No description provided for @surfaceCounter.
  ///
  /// In zh, this message translates to:
  /// **'柜台'**
  String get surfaceCounter;

  /// No description provided for @categoryWarehouse.
  ///
  /// In zh, this message translates to:
  /// **'仓库 / 快递仓 / 分拣站'**
  String get categoryWarehouse;

  /// No description provided for @categoryDelivery.
  ///
  /// In zh, this message translates to:
  /// **'配送站'**
  String get categoryDelivery;

  /// No description provided for @categoryInternet.
  ///
  /// In zh, this message translates to:
  /// **'网吧'**
  String get categoryInternet;

  /// No description provided for @categoryStore.
  ///
  /// In zh, this message translates to:
  /// **'商店'**
  String get categoryStore;

  /// No description provided for @categoryGarment.
  ///
  /// In zh, this message translates to:
  /// **'制衣车间'**
  String get categoryGarment;

  /// No description provided for @categoryRepair.
  ///
  /// In zh, this message translates to:
  /// **'维修车间'**
  String get categoryRepair;

  /// No description provided for @categoryOther.
  ///
  /// In zh, this message translates to:
  /// **'其他场景'**
  String get categoryOther;

  /// No description provided for @taskTagProcessing.
  ///
  /// In zh, this message translates to:
  /// **'处理'**
  String get taskTagProcessing;

  /// No description provided for @taskTagCooking.
  ///
  /// In zh, this message translates to:
  /// **'烹饪'**
  String get taskTagCooking;

  /// No description provided for @taskTagMixing.
  ///
  /// In zh, this message translates to:
  /// **'调制'**
  String get taskTagMixing;

  /// No description provided for @taskTagSorting.
  ///
  /// In zh, this message translates to:
  /// **'分拣'**
  String get taskTagSorting;

  /// No description provided for @taskTagPacking.
  ///
  /// In zh, this message translates to:
  /// **'包装'**
  String get taskTagPacking;

  /// No description provided for @taskTagHandling.
  ///
  /// In zh, this message translates to:
  /// **'搬运'**
  String get taskTagHandling;

  /// No description provided for @taskTagInventory.
  ///
  /// In zh, this message translates to:
  /// **'盘点'**
  String get taskTagInventory;

  /// No description provided for @taskTagDelivery.
  ///
  /// In zh, this message translates to:
  /// **'配送'**
  String get taskTagDelivery;

  /// No description provided for @taskTagOperation.
  ///
  /// In zh, this message translates to:
  /// **'操作'**
  String get taskTagOperation;

  /// No description provided for @taskTagService.
  ///
  /// In zh, this message translates to:
  /// **'服务'**
  String get taskTagService;

  /// No description provided for @taskTagDisplay.
  ///
  /// In zh, this message translates to:
  /// **'陈列'**
  String get taskTagDisplay;

  /// No description provided for @taskTagHandoff.
  ///
  /// In zh, this message translates to:
  /// **'交付'**
  String get taskTagHandoff;

  /// No description provided for @taskTagSewing.
  ///
  /// In zh, this message translates to:
  /// **'缝纫'**
  String get taskTagSewing;

  /// No description provided for @taskTagRepair.
  ///
  /// In zh, this message translates to:
  /// **'维修'**
  String get taskTagRepair;

  /// No description provided for @taskTagTidying.
  ///
  /// In zh, this message translates to:
  /// **'整理'**
  String get taskTagTidying;

  /// No description provided for @taskTagOther.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get taskTagOther;

  /// No description provided for @surfaceKitchenFloorWalls.
  ///
  /// In zh, this message translates to:
  /// **'厨房地面 / 墙面'**
  String get surfaceKitchenFloorWalls;

  /// No description provided for @surfaceCounterUtensils.
  ///
  /// In zh, this message translates to:
  /// **'台面 / 器具'**
  String get surfaceCounterUtensils;

  /// No description provided for @surfaceSink.
  ///
  /// In zh, this message translates to:
  /// **'水槽'**
  String get surfaceSink;

  /// No description provided for @surfaceStove.
  ///
  /// In zh, this message translates to:
  /// **'炉灶'**
  String get surfaceStove;

  /// No description provided for @surfaceBar.
  ///
  /// In zh, this message translates to:
  /// **'吧台'**
  String get surfaceBar;

  /// No description provided for @surfaceSortingTable.
  ///
  /// In zh, this message translates to:
  /// **'分拣台'**
  String get surfaceSortingTable;

  /// No description provided for @surfaceWorkbench.
  ///
  /// In zh, this message translates to:
  /// **'工作台'**
  String get surfaceWorkbench;

  /// No description provided for @surfaceWarehouseFloor.
  ///
  /// In zh, this message translates to:
  /// **'仓库地面'**
  String get surfaceWarehouseFloor;

  /// No description provided for @surfaceShelving.
  ///
  /// In zh, this message translates to:
  /// **'货架'**
  String get surfaceShelving;

  /// No description provided for @surfaceDeliveryVehicle.
  ///
  /// In zh, this message translates to:
  /// **'配送车 / 站点'**
  String get surfaceDeliveryVehicle;

  /// No description provided for @surfaceParcelLocker.
  ///
  /// In zh, this message translates to:
  /// **'快递柜'**
  String get surfaceParcelLocker;

  /// No description provided for @surfaceStationBar.
  ///
  /// In zh, this message translates to:
  /// **'机位 / 吧台'**
  String get surfaceStationBar;

  /// No description provided for @surfaceStation.
  ///
  /// In zh, this message translates to:
  /// **'机位'**
  String get surfaceStation;

  /// No description provided for @surfaceStationFloor.
  ///
  /// In zh, this message translates to:
  /// **'机位 / 地面'**
  String get surfaceStationFloor;

  /// No description provided for @surfaceCheckout.
  ///
  /// In zh, this message translates to:
  /// **'收银台'**
  String get surfaceCheckout;

  /// No description provided for @surfaceFloorShelving.
  ///
  /// In zh, this message translates to:
  /// **'地面 / 货架'**
  String get surfaceFloorShelving;

  /// No description provided for @surfaceSewingMachine.
  ///
  /// In zh, this message translates to:
  /// **'缝纫机'**
  String get surfaceSewingMachine;

  /// No description provided for @surfaceSewingMachineFloor.
  ///
  /// In zh, this message translates to:
  /// **'缝纫机 / 地面'**
  String get surfaceSewingMachineFloor;

  /// No description provided for @surfaceWorkbenchToolRack.
  ///
  /// In zh, this message translates to:
  /// **'工作台 / 工具架'**
  String get surfaceWorkbenchToolRack;

  /// No description provided for @surfaceFloorWorkbench.
  ///
  /// In zh, this message translates to:
  /// **'地面 / 工作台'**
  String get surfaceFloorWorkbench;

  /// No description provided for @surfaceUnspecified.
  ///
  /// In zh, this message translates to:
  /// **'未指定'**
  String get surfaceUnspecified;

  /// No description provided for @taskKitchenCleanTitle.
  ///
  /// In zh, this message translates to:
  /// **'环境清洁'**
  String get taskKitchenCleanTitle;

  /// No description provided for @taskKitchenToolsTitle.
  ///
  /// In zh, this message translates to:
  /// **'台面与器具清洁'**
  String get taskKitchenToolsTitle;

  /// No description provided for @taskKitchenWashTitle.
  ///
  /// In zh, this message translates to:
  /// **'食材清洗'**
  String get taskKitchenWashTitle;

  /// No description provided for @taskKitchenCookTitle.
  ///
  /// In zh, this message translates to:
  /// **'食材烹饪'**
  String get taskKitchenCookTitle;

  /// No description provided for @taskKitchenDrinkTitle.
  ///
  /// In zh, this message translates to:
  /// **'饮品制备'**
  String get taskKitchenDrinkTitle;

  /// No description provided for @taskWarehouseSortTitle.
  ///
  /// In zh, this message translates to:
  /// **'分拣与归类'**
  String get taskWarehouseSortTitle;

  /// No description provided for @taskWarehousePackTitle.
  ///
  /// In zh, this message translates to:
  /// **'包装与封装'**
  String get taskWarehousePackTitle;

  /// No description provided for @taskWarehouseLoadTitle.
  ///
  /// In zh, this message translates to:
  /// **'货物搬运与装载'**
  String get taskWarehouseLoadTitle;

  /// No description provided for @taskWarehouseInventoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'库存盘点与管理'**
  String get taskWarehouseInventoryTitle;

  /// No description provided for @taskWarehouseCleanTitle.
  ///
  /// In zh, this message translates to:
  /// **'现场清洁维护'**
  String get taskWarehouseCleanTitle;

  /// No description provided for @taskDeliverySortTitle.
  ///
  /// In zh, this message translates to:
  /// **'包裹分拣'**
  String get taskDeliverySortTitle;

  /// No description provided for @taskDeliveryDispatchTitle.
  ///
  /// In zh, this message translates to:
  /// **'包裹装载与配送'**
  String get taskDeliveryDispatchTitle;

  /// No description provided for @taskDeliveryLockerTitle.
  ///
  /// In zh, this message translates to:
  /// **'快递柜操作'**
  String get taskDeliveryLockerTitle;

  /// No description provided for @taskInternetServeTitle.
  ///
  /// In zh, this message translates to:
  /// **'服务递送'**
  String get taskInternetServeTitle;

  /// No description provided for @taskInternetOperateTitle.
  ///
  /// In zh, this message translates to:
  /// **'设备控制与操作'**
  String get taskInternetOperateTitle;

  /// No description provided for @taskInternetCleanTitle.
  ///
  /// In zh, this message translates to:
  /// **'设备与环境清洁'**
  String get taskInternetCleanTitle;

  /// No description provided for @taskStoreDisplayTitle.
  ///
  /// In zh, this message translates to:
  /// **'商品摆放与陈列'**
  String get taskStoreDisplayTitle;

  /// No description provided for @taskStoreBagTitle.
  ///
  /// In zh, this message translates to:
  /// **'商品包装与装袋'**
  String get taskStoreBagTitle;

  /// No description provided for @taskStoreHandoverTitle.
  ///
  /// In zh, this message translates to:
  /// **'顾客递交与交付'**
  String get taskStoreHandoverTitle;

  /// No description provided for @taskStoreCleanTitle.
  ///
  /// In zh, this message translates to:
  /// **'店面清洁维护'**
  String get taskStoreCleanTitle;

  /// No description provided for @taskGarmentSewTitle.
  ///
  /// In zh, this message translates to:
  /// **'衣物缝纫'**
  String get taskGarmentSewTitle;

  /// No description provided for @taskGarmentFoldTitle.
  ///
  /// In zh, this message translates to:
  /// **'衣物折叠'**
  String get taskGarmentFoldTitle;

  /// No description provided for @taskGarmentCleanTitle.
  ///
  /// In zh, this message translates to:
  /// **'设备与环境清洁'**
  String get taskGarmentCleanTitle;

  /// No description provided for @taskRepairFixTitle.
  ///
  /// In zh, this message translates to:
  /// **'维修与辅助'**
  String get taskRepairFixTitle;

  /// No description provided for @taskRepairTidyTitle.
  ///
  /// In zh, this message translates to:
  /// **'维修车间整理'**
  String get taskRepairTidyTitle;

  /// No description provided for @taskRepairCleanTitle.
  ///
  /// In zh, this message translates to:
  /// **'环境清洁'**
  String get taskRepairCleanTitle;

  /// No description provided for @taskOtherMiscTitle.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get taskOtherMiscTitle;

  /// No description provided for @taskGenericStep.
  ///
  /// In zh, this message translates to:
  /// **'按真实工作场景采集，保持双手清晰可见，避免遮挡画面。'**
  String get taskGenericStep;

  /// No description provided for @taskLrPickRemoteTitle.
  ///
  /// In zh, this message translates to:
  /// **'拿起并放置遥控器'**
  String get taskLrPickRemoteTitle;

  /// No description provided for @taskLrPickRemoteStep1.
  ///
  /// In zh, this message translates to:
  /// **'把遥控器放在客厅桌面上。'**
  String get taskLrPickRemoteStep1;

  /// No description provided for @taskLrPickRemoteStep2.
  ///
  /// In zh, this message translates to:
  /// **'拿起遥控器，移动到桌面、沙发或椅子的另一个位置，并停顿 1 秒。'**
  String get taskLrPickRemoteStep2;

  /// No description provided for @taskLrPickRemoteStep3.
  ///
  /// In zh, this message translates to:
  /// **'再次拿起并放回原位，然后停顿 1 秒。'**
  String get taskLrPickRemoteStep3;

  /// No description provided for @taskLrPickRemoteStep4.
  ///
  /// In zh, this message translates to:
  /// **'每次尝试更换目标位置；保持双手在画面内。'**
  String get taskLrPickRemoteStep4;

  /// No description provided for @taskLrPickPhoneTitle.
  ///
  /// In zh, this message translates to:
  /// **'拿起并放置手机'**
  String get taskLrPickPhoneTitle;

  /// No description provided for @taskLrPickPhoneStep1.
  ///
  /// In zh, this message translates to:
  /// **'把手机放在客厅桌面上。'**
  String get taskLrPickPhoneStep1;

  /// No description provided for @taskLrPickPhoneStep2.
  ///
  /// In zh, this message translates to:
  /// **'拿起手机，移动到桌面、沙发或椅子的另一个位置，并停顿 1 秒。'**
  String get taskLrPickPhoneStep2;

  /// No description provided for @taskLrPickPhoneStep3.
  ///
  /// In zh, this message translates to:
  /// **'再次拿起并放回原位，然后停顿 1 秒。'**
  String get taskLrPickPhoneStep3;

  /// No description provided for @taskLrPickPhoneStep4.
  ///
  /// In zh, this message translates to:
  /// **'每次尝试更换目标位置；保持双手在画面内。'**
  String get taskLrPickPhoneStep4;

  /// No description provided for @taskLrPickPowerbankTitle.
  ///
  /// In zh, this message translates to:
  /// **'拿起并放置充电宝'**
  String get taskLrPickPowerbankTitle;

  /// No description provided for @taskLrPickPowerbankStep1.
  ///
  /// In zh, this message translates to:
  /// **'把充电宝放在客厅桌面上。'**
  String get taskLrPickPowerbankStep1;

  /// No description provided for @taskLrPickPowerbankStep2.
  ///
  /// In zh, this message translates to:
  /// **'拿起充电宝，移动到桌面、沙发或椅子的另一个位置，并停顿 1 秒。'**
  String get taskLrPickPowerbankStep2;

  /// No description provided for @taskLrPickPowerbankStep3.
  ///
  /// In zh, this message translates to:
  /// **'再次拿起并放回原位，然后停顿 1 秒。'**
  String get taskLrPickPowerbankStep3;

  /// No description provided for @taskLrPickPowerbankStep4.
  ///
  /// In zh, this message translates to:
  /// **'每次尝试更换目标位置；保持双手在画面内。'**
  String get taskLrPickPowerbankStep4;

  /// No description provided for @taskLrPickComboTitle.
  ///
  /// In zh, this message translates to:
  /// **'抓取放置：遥控器 + 手机 + 充电宝'**
  String get taskLrPickComboTitle;

  /// No description provided for @taskLrPickComboStep1.
  ///
  /// In zh, this message translates to:
  /// **'把遥控器、手机和充电宝一起放在桌面上。'**
  String get taskLrPickComboStep1;

  /// No description provided for @taskLrPickComboStep2.
  ///
  /// In zh, this message translates to:
  /// **'拿起遥控器，移动到桌面、沙发或椅子的新位置，停顿 1 秒，再放回原位。'**
  String get taskLrPickComboStep2;

  /// No description provided for @taskLrPickComboStep3.
  ///
  /// In zh, this message translates to:
  /// **'对手机重复同样动作，再对充电宝重复一次。'**
  String get taskLrPickComboStep3;

  /// No description provided for @taskLrPickComboStep4.
  ///
  /// In zh, this message translates to:
  /// **'不同物品尝试不同目标位置；保持完整动作在画面内。'**
  String get taskLrPickComboStep4;

  /// No description provided for @taskLrSwitchLightTitle.
  ///
  /// In zh, this message translates to:
  /// **'切换墙壁灯开关'**
  String get taskLrSwitchLightTitle;

  /// No description provided for @taskLrSwitchLightStep1.
  ///
  /// In zh, this message translates to:
  /// **'走到墙壁开关前。'**
  String get taskLrSwitchLightStep1;

  /// No description provided for @taskLrSwitchLightStep2.
  ///
  /// In zh, this message translates to:
  /// **'按一次打开灯；停顿 2 秒，让相机记录灯亮起。'**
  String get taskLrSwitchLightStep2;

  /// No description provided for @taskLrSwitchLightStep3.
  ///
  /// In zh, this message translates to:
  /// **'再按一次关灯；停顿 2 秒，让相机记录灯熄灭。'**
  String get taskLrSwitchLightStep3;

  /// No description provided for @taskLrSwitchLightStep4.
  ///
  /// In zh, this message translates to:
  /// **'每次都完整按下，不要半按；保持手部可见。'**
  String get taskLrSwitchLightStep4;

  /// No description provided for @taskLrSwitchDrawerTitle.
  ///
  /// In zh, this message translates to:
  /// **'打开并关闭抽屉'**
  String get taskLrSwitchDrawerTitle;

  /// No description provided for @taskLrSwitchDrawerStep1.
  ///
  /// In zh, this message translates to:
  /// **'走到抽屉前。'**
  String get taskLrSwitchDrawerStep1;

  /// No description provided for @taskLrSwitchDrawerStep2.
  ///
  /// In zh, this message translates to:
  /// **'握住把手并完全拉开；停顿 2 秒。'**
  String get taskLrSwitchDrawerStep2;

  /// No description provided for @taskLrSwitchDrawerStep3.
  ///
  /// In zh, this message translates to:
  /// **'把抽屉完全推回关闭；停顿 2 秒。'**
  String get taskLrSwitchDrawerStep3;

  /// No description provided for @taskLrSwitchDrawerStep4.
  ///
  /// In zh, this message translates to:
  /// **'每次都拉/推到底，不要只做半程动作。'**
  String get taskLrSwitchDrawerStep4;

  /// No description provided for @taskLrSwitchCurtainTitle.
  ///
  /// In zh, this message translates to:
  /// **'打开并关闭窗帘'**
  String get taskLrSwitchCurtainTitle;

  /// No description provided for @taskLrSwitchCurtainStep1.
  ///
  /// In zh, this message translates to:
  /// **'走到窗帘前。'**
  String get taskLrSwitchCurtainStep1;

  /// No description provided for @taskLrSwitchCurtainStep2.
  ///
  /// In zh, this message translates to:
  /// **'抓住拉绳或布料并完全拉开，让光线进入；停顿 2 秒。'**
  String get taskLrSwitchCurtainStep2;

  /// No description provided for @taskLrSwitchCurtainStep3.
  ///
  /// In zh, this message translates to:
  /// **'再把窗帘完全拉上；停顿 2 秒。'**
  String get taskLrSwitchCurtainStep3;

  /// No description provided for @taskLrSwitchCurtainStep4.
  ///
  /// In zh, this message translates to:
  /// **'始终从一端拉到另一端，不要做半程动作。'**
  String get taskLrSwitchCurtainStep4;

  /// No description provided for @taskLrSwitchComboTitle.
  ///
  /// In zh, this message translates to:
  /// **'灯 + 抽屉 + 窗帘组合'**
  String get taskLrSwitchComboTitle;

  /// No description provided for @taskLrSwitchComboStep1.
  ///
  /// In zh, this message translates to:
  /// **'打开墙壁灯，停顿 2 秒；再关闭，停顿 2 秒。'**
  String get taskLrSwitchComboStep1;

  /// No description provided for @taskLrSwitchComboStep2.
  ///
  /// In zh, this message translates to:
  /// **'完全拉开抽屉，停顿 2 秒；再完全推回关闭，停顿 2 秒。'**
  String get taskLrSwitchComboStep2;

  /// No description provided for @taskLrSwitchComboStep3.
  ///
  /// In zh, this message translates to:
  /// **'完全拉开窗帘，停顿 2 秒；再关闭，停顿 2 秒。'**
  String get taskLrSwitchComboStep3;

  /// No description provided for @taskLrSwitchComboStep4.
  ///
  /// In zh, this message translates to:
  /// **'按顺序完成三项动作；全程保持手部在画面内。'**
  String get taskLrSwitchComboStep4;

  /// No description provided for @taskBrFoldClothesSingleTitle.
  ///
  /// In zh, this message translates to:
  /// **'折叠一件衣物'**
  String get taskBrFoldClothesSingleTitle;

  /// No description provided for @taskBrFoldClothesSingleStep1.
  ///
  /// In zh, this message translates to:
  /// **'把一件干净的 T 恤、衬衫或裤子平铺在床上。'**
  String get taskBrFoldClothesSingleStep1;

  /// No description provided for @taskBrFoldClothesSingleStep2.
  ///
  /// In zh, this message translates to:
  /// **'把两侧向中间折，再从底部向上卷起或折起。'**
  String get taskBrFoldClothesSingleStep2;

  /// No description provided for @taskBrFoldClothesSingleStep3.
  ///
  /// In zh, this message translates to:
  /// **'把折好的衣物放到床头或衣柜层板上，并停顿 1 秒。'**
  String get taskBrFoldClothesSingleStep3;

  /// No description provided for @taskBrFoldClothesSingleStep4.
  ///
  /// In zh, this message translates to:
  /// **'保持双手可见，不要把衣物举到镜头前遮挡画面。'**
  String get taskBrFoldClothesSingleStep4;

  /// No description provided for @taskBrFoldClothesMultiTitle.
  ///
  /// In zh, this message translates to:
  /// **'折叠 2–3 件衣物'**
  String get taskBrFoldClothesMultiTitle;

  /// No description provided for @taskBrFoldClothesMultiStep1.
  ///
  /// In zh, this message translates to:
  /// **'把 2–3 件干净衣物平铺在床上。'**
  String get taskBrFoldClothesMultiStep1;

  /// No description provided for @taskBrFoldClothesMultiStep2.
  ///
  /// In zh, this message translates to:
  /// **'逐件折叠：两侧向中间折，再从底部向上折，并叠放到层板上。'**
  String get taskBrFoldClothesMultiStep2;

  /// No description provided for @taskBrFoldClothesMultiStep3.
  ///
  /// In zh, this message translates to:
  /// **'完成一件后再开始下一件。'**
  String get taskBrFoldClothesMultiStep3;

  /// No description provided for @taskBrFoldClothesMultiStep4.
  ///
  /// In zh, this message translates to:
  /// **'保持自然速度；全程保持双手在画面内。'**
  String get taskBrFoldClothesMultiStep4;

  /// No description provided for @taskBrFoldTowelSingleTitle.
  ///
  /// In zh, this message translates to:
  /// **'折叠一条毛巾'**
  String get taskBrFoldTowelSingleTitle;

  /// No description provided for @taskBrFoldTowelSingleStep1.
  ///
  /// In zh, this message translates to:
  /// **'把一条干净毛巾（面巾或浴巾）平铺在床上。'**
  String get taskBrFoldTowelSingleStep1;

  /// No description provided for @taskBrFoldTowelSingleStep2.
  ///
  /// In zh, this message translates to:
  /// **'沿长边对折，再沿短边对折成方形。'**
  String get taskBrFoldTowelSingleStep2;

  /// No description provided for @taskBrFoldTowelSingleStep3.
  ///
  /// In zh, this message translates to:
  /// **'把它放到洗漱台或衣柜层板上。'**
  String get taskBrFoldTowelSingleStep3;

  /// No description provided for @taskBrFoldTowelSingleStep4.
  ///
  /// In zh, this message translates to:
  /// **'保持双手在画面内，不要用毛巾遮挡镜头。'**
  String get taskBrFoldTowelSingleStep4;

  /// No description provided for @taskBrFoldTowelMultiTitle.
  ///
  /// In zh, this message translates to:
  /// **'折叠 2–3 条毛巾'**
  String get taskBrFoldTowelMultiTitle;

  /// No description provided for @taskBrFoldTowelMultiStep1.
  ///
  /// In zh, this message translates to:
  /// **'把 2–3 条干净毛巾平铺在床上。'**
  String get taskBrFoldTowelMultiStep1;

  /// No description provided for @taskBrFoldTowelMultiStep2.
  ///
  /// In zh, this message translates to:
  /// **'逐条折叠：长边对折，再短边对折，并叠放起来。'**
  String get taskBrFoldTowelMultiStep2;

  /// No description provided for @taskBrFoldTowelMultiStep3.
  ///
  /// In zh, this message translates to:
  /// **'完成一条后再处理下一条。'**
  String get taskBrFoldTowelMultiStep3;

  /// No description provided for @taskBrFoldTowelMultiStep4.
  ///
  /// In zh, this message translates to:
  /// **'保持自然速度；保持双手在画面内。'**
  String get taskBrFoldTowelMultiStep4;

  /// No description provided for @taskKtCutFruitSingleTitle.
  ///
  /// In zh, this message translates to:
  /// **'切一份水果'**
  String get taskKtCutFruitSingleTitle;

  /// No description provided for @taskKtCutFruitSingleStep1.
  ///
  /// In zh, this message translates to:
  /// **'清洗一个苹果、橙子、香蕉或类似水果。'**
  String get taskKtCutFruitSingleStep1;

  /// No description provided for @taskKtCutFruitSingleStep2.
  ///
  /// In zh, this message translates to:
  /// **'把水果放在砧板上，用刀切成块。'**
  String get taskKtCutFruitSingleStep2;

  /// No description provided for @taskKtCutFruitSingleStep3.
  ///
  /// In zh, this message translates to:
  /// **'把切好的水果转移到盘子里。'**
  String get taskKtCutFruitSingleStep3;

  /// No description provided for @taskKtCutFruitSingleStep4.
  ///
  /// In zh, this message translates to:
  /// **'注意用刀安全，不要把刀举到手部离开画面的高度。'**
  String get taskKtCutFruitSingleStep4;

  /// No description provided for @taskKtCutFruitMultiTitle.
  ///
  /// In zh, this message translates to:
  /// **'切 2–3 种不同水果'**
  String get taskKtCutFruitMultiTitle;

  /// No description provided for @taskKtCutFruitMultiStep1.
  ///
  /// In zh, this message translates to:
  /// **'清洗 2–3 种不同水果（例如苹果、橙子、香蕉）。'**
  String get taskKtCutFruitMultiStep1;

  /// No description provided for @taskKtCutFruitMultiStep2.
  ///
  /// In zh, this message translates to:
  /// **'在砧板上逐个切好，每切完一种就转移到盘子里。'**
  String get taskKtCutFruitMultiStep2;

  /// No description provided for @taskKtCutFruitMultiStep3.
  ///
  /// In zh, this message translates to:
  /// **'一只手固定水果，另一只手切；保持双手可见。'**
  String get taskKtCutFruitMultiStep3;

  /// No description provided for @taskKtCutFruitMultiStep4.
  ///
  /// In zh, this message translates to:
  /// **'作为一个视频上传，不要按水果拆分。'**
  String get taskKtCutFruitMultiStep4;

  /// No description provided for @taskKtTablewareSingleTitle.
  ///
  /// In zh, this message translates to:
  /// **'摆放一件餐具'**
  String get taskKtTablewareSingleTitle;

  /// No description provided for @taskKtTablewareSingleStep1.
  ///
  /// In zh, this message translates to:
  /// **'选择一件物品（盘子、碗、筷子、叉子或勺子），整齐放到台面或炉灶上。'**
  String get taskKtTablewareSingleStep1;

  /// No description provided for @taskKtTablewareSingleStep2.
  ///
  /// In zh, this message translates to:
  /// **'放好后再拿起，并放回原来的位置。'**
  String get taskKtTablewareSingleStep2;

  /// No description provided for @taskKtTablewareSingleStep3.
  ///
  /// In zh, this message translates to:
  /// **'完整完成伸手、抓取、放置动作；不要太快。'**
  String get taskKtTablewareSingleStep3;

  /// No description provided for @taskKtTablewareSingleStep4.
  ///
  /// In zh, this message translates to:
  /// **'不同物品算作不同视频。'**
  String get taskKtTablewareSingleStep4;

  /// No description provided for @taskKtTablewareMultiTitle.
  ///
  /// In zh, this message translates to:
  /// **'摆放多件餐具'**
  String get taskKtTablewareMultiTitle;

  /// No description provided for @taskKtTablewareMultiStep1.
  ///
  /// In zh, this message translates to:
  /// **'把每件餐具（盘子、碗、筷子、叉子、勺子）逐一整齐摆到台面上。'**
  String get taskKtTablewareMultiStep1;

  /// No description provided for @taskKtTablewareMultiStep2.
  ///
  /// In zh, this message translates to:
  /// **'也可以再逐一收回原位。'**
  String get taskKtTablewareMultiStep2;

  /// No description provided for @taskKtTablewareMultiStep3.
  ///
  /// In zh, this message translates to:
  /// **'每件物品约 15–30 秒；作为一个组合视频上传。'**
  String get taskKtTablewareMultiStep3;

  /// No description provided for @taskKtTablewareMultiStep4.
  ///
  /// In zh, this message translates to:
  /// **'轻拿轻放，不要摔落碗具。'**
  String get taskKtTablewareMultiStep4;

  /// No description provided for @taskKtPourWaterTitle.
  ///
  /// In zh, this message translates to:
  /// **'用水壶往杯子里倒水'**
  String get taskKtPourWaterTitle;

  /// No description provided for @taskKtPourWaterStep1.
  ///
  /// In zh, this message translates to:
  /// **'给水壶装水；把杯子放在台面上。'**
  String get taskKtPourWaterStep1;

  /// No description provided for @taskKtPourWaterStep2.
  ///
  /// In zh, this message translates to:
  /// **'拿起水壶，对准杯子，倒到约 70–80% 满。'**
  String get taskKtPourWaterStep2;

  /// No description provided for @taskKtPourWaterStep3.
  ///
  /// In zh, this message translates to:
  /// **'把水壶放回台面。'**
  String get taskKtPourWaterStep3;

  /// No description provided for @taskKtPourWaterStep4.
  ///
  /// In zh, this message translates to:
  /// **'每次尝试可更换不同杯子（玻璃杯、陶瓷杯）；一次倒水就是一个视频。'**
  String get taskKtPourWaterStep4;

  /// No description provided for @taskKtPourCoffeeTitle.
  ///
  /// In zh, this message translates to:
  /// **'用水壶往杯子里倒咖啡'**
  String get taskKtPourCoffeeTitle;

  /// No description provided for @taskKtPourCoffeeStep1.
  ///
  /// In zh, this message translates to:
  /// **'给水壶装咖啡；把杯子放在台面上。'**
  String get taskKtPourCoffeeStep1;

  /// No description provided for @taskKtPourCoffeeStep2.
  ///
  /// In zh, this message translates to:
  /// **'拿起水壶，对准杯子，倒到约 70–80% 满。'**
  String get taskKtPourCoffeeStep2;

  /// No description provided for @taskKtPourCoffeeStep3.
  ///
  /// In zh, this message translates to:
  /// **'把水壶放回台面。'**
  String get taskKtPourCoffeeStep3;

  /// No description provided for @taskKtPourCoffeeStep4.
  ///
  /// In zh, this message translates to:
  /// **'每次尝试可更换不同杯子（玻璃杯、陶瓷杯）；一次倒取就是一个视频。'**
  String get taskKtPourCoffeeStep4;

  /// No description provided for @taskKtPourTeaTitle.
  ///
  /// In zh, this message translates to:
  /// **'用水壶往杯子里倒茶'**
  String get taskKtPourTeaTitle;

  /// No description provided for @taskKtPourTeaStep1.
  ///
  /// In zh, this message translates to:
  /// **'给水壶装茶；把杯子放在台面上。'**
  String get taskKtPourTeaStep1;

  /// No description provided for @taskKtPourTeaStep2.
  ///
  /// In zh, this message translates to:
  /// **'拿起水壶，对准杯子，倒到约 70–80% 满。'**
  String get taskKtPourTeaStep2;

  /// No description provided for @taskKtPourTeaStep3.
  ///
  /// In zh, this message translates to:
  /// **'把水壶放回台面。'**
  String get taskKtPourTeaStep3;

  /// No description provided for @taskKtPourTeaStep4.
  ///
  /// In zh, this message translates to:
  /// **'每次尝试可更换不同杯子（玻璃杯、陶瓷杯）；一次倒取就是一个视频。'**
  String get taskKtPourTeaStep4;

  /// No description provided for @taskKtPourComboTitle.
  ///
  /// In zh, this message translates to:
  /// **'倒水 + 咖啡 + 茶'**
  String get taskKtPourComboTitle;

  /// No description provided for @taskKtPourComboStep1.
  ///
  /// In zh, this message translates to:
  /// **'准备水壶和杯子（可使用水、茶或咖啡）。'**
  String get taskKtPourComboStep1;

  /// No description provided for @taskKtPourComboStep2.
  ///
  /// In zh, this message translates to:
  /// **'连续倒 2–3 杯，尽量更换杯子样式。'**
  String get taskKtPourComboStep2;

  /// No description provided for @taskKtPourComboStep3.
  ///
  /// In zh, this message translates to:
  /// **'每次倒完后都把水壶放下。'**
  String get taskKtPourComboStep3;

  /// No description provided for @taskKtPourComboStep4.
  ///
  /// In zh, this message translates to:
  /// **'作为一个视频上传，多杯倒取属于一个任务。'**
  String get taskKtPourComboStep4;

  /// No description provided for @taskBtWipeToiletTitle.
  ///
  /// In zh, this message translates to:
  /// **'擦拭马桶外侧'**
  String get taskBtWipeToiletTitle;

  /// No description provided for @taskBtWipeToiletStep1.
  ///
  /// In zh, this message translates to:
  /// **'拿一块干净抹布，并喷少量清洁剂（湿抹布也可以）。'**
  String get taskBtWipeToiletStep1;

  /// No description provided for @taskBtWipeToiletStep2.
  ///
  /// In zh, this message translates to:
  /// **'来回擦拭水箱、盖板和马桶外侧主体。'**
  String get taskBtWipeToiletStep2;

  /// No description provided for @taskBtWipeToiletStep3.
  ///
  /// In zh, this message translates to:
  /// **'覆盖所有外部表面；保持手部可见，不要让身体挡住马桶。'**
  String get taskBtWipeToiletStep3;

  /// No description provided for @taskBtWipeToiletStep4.
  ///
  /// In zh, this message translates to:
  /// **'完成后把抹布放回。'**
  String get taskBtWipeToiletStep4;

  /// No description provided for @taskBtCleanToiletSeatTitle.
  ///
  /// In zh, this message translates to:
  /// **'清洁马桶座圈'**
  String get taskBtCleanToiletSeatTitle;

  /// No description provided for @taskBtCleanToiletSeatStep1.
  ///
  /// In zh, this message translates to:
  /// **'掀起马桶座圈，并录下掀起动作。'**
  String get taskBtCleanToiletSeatStep1;

  /// No description provided for @taskBtCleanToiletSeatStep2.
  ///
  /// In zh, this message translates to:
  /// **'擦拭座圈下侧，再翻回擦拭上侧，确保两面都干净。'**
  String get taskBtCleanToiletSeatStep2;

  /// No description provided for @taskBtCleanToiletSeatStep3.
  ///
  /// In zh, this message translates to:
  /// **'把座圈放回原位；收好抹布。'**
  String get taskBtCleanToiletSeatStep3;

  /// No description provided for @taskBtCleanToiletSeatStep4.
  ///
  /// In zh, this message translates to:
  /// **'注意卫生，不要溅到自己身上。'**
  String get taskBtCleanToiletSeatStep4;

  /// No description provided for @taskBtCleanBasinTitle.
  ///
  /// In zh, this message translates to:
  /// **'清洁洗手盆'**
  String get taskBtCleanBasinTitle;

  /// No description provided for @taskBtCleanBasinStep1.
  ///
  /// In zh, this message translates to:
  /// **'先擦拭洗手盆内部，再擦周围台面，最后擦水龙头。'**
  String get taskBtCleanBasinStep1;

  /// No description provided for @taskBtCleanBasinStep2.
  ///
  /// In zh, this message translates to:
  /// **'确保每个擦拭动作都被拍到，不要跳过区域。'**
  String get taskBtCleanBasinStep2;

  /// No description provided for @taskBtCleanBasinStep3.
  ///
  /// In zh, this message translates to:
  /// **'避免把水溅得到处都是，按平时方式清洁。'**
  String get taskBtCleanBasinStep3;

  /// No description provided for @taskBtCleanBasinStep4.
  ///
  /// In zh, this message translates to:
  /// **'把抹布放回。'**
  String get taskBtCleanBasinStep4;

  /// No description provided for @taskCsPickShelfSingleTitle.
  ///
  /// In zh, this message translates to:
  /// **'从货架上取下一件商品'**
  String get taskCsPickShelfSingleTitle;

  /// No description provided for @taskCsPickShelfSingleStep1.
  ///
  /// In zh, this message translates to:
  /// **'准备一个货架，放上常见便利店商品（水、饼干、牙膏等）。'**
  String get taskCsPickShelfSingleStep1;

  /// No description provided for @taskCsPickShelfSingleStep2.
  ///
  /// In zh, this message translates to:
  /// **'从货架上取下一件商品，放入面前的篮子里；停顿 1 秒。'**
  String get taskCsPickShelfSingleStep2;

  /// No description provided for @taskCsPickShelfSingleStep3.
  ///
  /// In zh, this message translates to:
  /// **'再从篮子里拿出商品，放回原来的货架位置。'**
  String get taskCsPickShelfSingleStep3;

  /// No description provided for @taskCsPickShelfSingleStep4.
  ///
  /// In zh, this message translates to:
  /// **'每次尝试可更换不同货架高度，但要在可触及范围内；一件商品就是一个视频。'**
  String get taskCsPickShelfSingleStep4;

  /// No description provided for @taskCsPickShelfMultiTitle.
  ///
  /// In zh, this message translates to:
  /// **'从货架上取下 2–3 件商品'**
  String get taskCsPickShelfMultiTitle;

  /// No description provided for @taskCsPickShelfMultiStep1.
  ///
  /// In zh, this message translates to:
  /// **'在货架上摆放多种便利店商品。'**
  String get taskCsPickShelfMultiStep1;

  /// No description provided for @taskCsPickShelfMultiStep2.
  ///
  /// In zh, this message translates to:
  /// **'对每件商品：从货架取下，放入篮子，停顿 1 秒，再放回原位。'**
  String get taskCsPickShelfMultiStep2;

  /// No description provided for @taskCsPickShelfMultiStep3.
  ///
  /// In zh, this message translates to:
  /// **'尝试从不同层架取物（上层、中层、下层）。'**
  String get taskCsPickShelfMultiStep3;

  /// No description provided for @taskCsPickShelfMultiStep4.
  ///
  /// In zh, this message translates to:
  /// **'作为一个视频上传，多件商品属于一个任务。'**
  String get taskCsPickShelfMultiStep4;

  /// No description provided for @taskCsWipeCounterTitle.
  ///
  /// In zh, this message translates to:
  /// **'擦拭柜台/货架表面'**
  String get taskCsWipeCounterTitle;

  /// No description provided for @taskCsWipeCounterStep1.
  ///
  /// In zh, this message translates to:
  /// **'拿一块湿抹布。'**
  String get taskCsWipeCounterStep1;

  /// No description provided for @taskCsWipeCounterStep2.
  ///
  /// In zh, this message translates to:
  /// **'从左到右擦拭收银台或货架表面，覆盖整个顶部。'**
  String get taskCsWipeCounterStep2;

  /// No description provided for @taskCsWipeCounterStep3.
  ///
  /// In zh, this message translates to:
  /// **'擦拭过程中保持手部可见。'**
  String get taskCsWipeCounterStep3;

  /// No description provided for @taskCsWipeCounterStep4.
  ///
  /// In zh, this message translates to:
  /// **'完成后把抹布放回。'**
  String get taskCsWipeCounterStep4;

  /// No description provided for @taskCsHandoverSingleTitle.
  ///
  /// In zh, this message translates to:
  /// **'把一件商品递给顾客'**
  String get taskCsHandoverSingleTitle;

  /// No description provided for @taskCsHandoverSingleStep1.
  ///
  /// In zh, this message translates to:
  /// **'在货架上摆放商品，请朋友或家人站在你面前扮演“顾客”。'**
  String get taskCsHandoverSingleStep1;

  /// No description provided for @taskCsHandoverSingleStep2.
  ///
  /// In zh, this message translates to:
  /// **'从货架上取下一件商品（例如一瓶水），递给顾客。'**
  String get taskCsHandoverSingleStep2;

  /// No description provided for @taskCsHandoverSingleStep3.
  ///
  /// In zh, this message translates to:
  /// **'顾客接过商品；停顿 1 秒。'**
  String get taskCsHandoverSingleStep3;

  /// No description provided for @taskCsHandoverSingleStep4.
  ///
  /// In zh, this message translates to:
  /// **'你的手和顾客的手都可以出现在画面中，动作保持自然。'**
  String get taskCsHandoverSingleStep4;

  /// No description provided for @taskCsHandoverMultiTitle.
  ///
  /// In zh, this message translates to:
  /// **'把 2–3 件商品递给顾客'**
  String get taskCsHandoverMultiTitle;

  /// No description provided for @taskCsHandoverMultiStep1.
  ///
  /// In zh, this message translates to:
  /// **'准备货架，并让一位“顾客”站在你对面。'**
  String get taskCsHandoverMultiStep1;

  /// No description provided for @taskCsHandoverMultiStep2.
  ///
  /// In zh, this message translates to:
  /// **'从货架上取下一件商品并递过去；停顿 1 秒。'**
  String get taskCsHandoverMultiStep2;

  /// No description provided for @taskCsHandoverMultiStep3.
  ///
  /// In zh, this message translates to:
  /// **'对 2–3 件不同商品重复动作。'**
  String get taskCsHandoverMultiStep3;

  /// No description provided for @taskCsHandoverMultiStep4.
  ///
  /// In zh, this message translates to:
  /// **'作为一个视频上传，多次递交属于一个任务。'**
  String get taskCsHandoverMultiStep4;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

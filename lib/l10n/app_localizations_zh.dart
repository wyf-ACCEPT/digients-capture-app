// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Digients 采集';

  @override
  String get navHome => '首页';

  @override
  String get navSubmissions => '提交';

  @override
  String get navMe => '我的';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsAccount => '账号';

  @override
  String get settingsUploads => '上传';

  @override
  String get settingsRecordingFeedback => '录制反馈';

  @override
  String get settingsNotifications => '通知';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsEmail => '邮箱';

  @override
  String get settingsPhone => '手机号';

  @override
  String get settingsUid => 'UID';

  @override
  String get settingsWifiOnly => '仅 Wi-Fi 上传';

  @override
  String get settingsAutoUpload => '采集后自动上传';

  @override
  String get settingsBackgroundUploads => '后台上传';

  @override
  String get settingsHandVoiceCues => '手部检测语音提示';

  @override
  String get settingsBorderIndicator => '边框提示';

  @override
  String get settingsVibrateOnNoHands => '无手部时振动';

  @override
  String get settingsApprovalResults => '审核结果';

  @override
  String get settingsPointsCredited => '积分到账';

  @override
  String get settingsTheme => '主题';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsVersion => '版本';

  @override
  String get settingsPrivacyPolicy => '隐私政策';

  @override
  String get settingsTermsOfService => '服务条款';

  @override
  String get settingsOpenSourceLicenses => '开源许可证';

  @override
  String get settingsSignOut => '退出登录';

  @override
  String get settingsDeleteAccount => '删除账号';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get themeAuto => '自动';

  @override
  String get themeDark => '深色';

  @override
  String get themeLight => '浅色';

  @override
  String get authEnterPhoneFirst => '请先输入手机号。';

  @override
  String get authEnterEmailFirst => '请先输入邮箱。';

  @override
  String get authEnterSixDigitCode => '请输入 6 位验证码。';

  @override
  String get authInvalidCode => '验证码不正确。';

  @override
  String authSomethingWentWrong(String error) {
    return '出错了：$error';
  }

  @override
  String get authCreateAccount => '创建账号';

  @override
  String get authWelcomeBack => '欢迎回来';

  @override
  String get authSignUpSubtitle => '注册后即可开始贡献录制数据。';

  @override
  String get authSignInSubtitle => '登录后继续采集。';

  @override
  String get authPhone => '手机号';

  @override
  String get authEmail => '邮箱';

  @override
  String get authAgreementPrefix => '创建账号即表示你同意我们的';

  @override
  String get authTerms => '服务条款';

  @override
  String get authAgreementMiddle => '和';

  @override
  String get authPrivacyPolicy => '隐私政策';

  @override
  String get authAgreementSuffix => '。';

  @override
  String get authSending => '发送中...';

  @override
  String get authSendVerificationCode => '发送验证码';

  @override
  String get authVerifying => '验证中...';

  @override
  String get authSignIn => '登录';

  @override
  String get authApple => 'Apple';

  @override
  String get authGoogle => 'Google';

  @override
  String get authOr => '或';

  @override
  String get authAlreadyHaveAccount => '已有账号？';

  @override
  String get authDontHaveAccount => '还没有账号？';

  @override
  String get authRegister => '注册';

  @override
  String get authPhoneComingSoonTitle => '手机号登录暂未开放';

  @override
  String get authPhoneComingSoonBody => '短信验证还在开发中，请先使用邮箱或下方免登录入口。';

  @override
  String get authSkipSignIn => '免登录（演示）';

  @override
  String get authSkipSignInHint => '跳过后将无法上传视频';

  @override
  String get authInviteCodeSignIn => '用邀请码登录';

  @override
  String get authInviteCodeModalTitle => '输入邀请码';

  @override
  String get authInviteCodeModalHint => '向 Digients 团队获取你的邀请码';

  @override
  String get authInviteCodeInputLabel => '邀请码';

  @override
  String get authInviteCodeSubmit => '登录';

  @override
  String get authInviteCodeMissing => '请输入邀请码';

  @override
  String get uploadLockedTitle => '上传需要登录';

  @override
  String get uploadLockedBody => '退出登录后用邀请码重新进入即可启用视频上传。';

  @override
  String get uploadLockedSignOut => '退出登录';

  @override
  String get uploadLockedDismiss => '暂不';

  @override
  String get uploadLockedShortLabel => '需登录';

  @override
  String get homeWelcomeBack => '欢迎回来';

  @override
  String get balance => '余额';

  @override
  String get pending => '待入账';

  @override
  String get pointsSuffix => '积分';

  @override
  String get chooseCategory => '选择场景';

  @override
  String tasksCount(int count) {
    return '$count 个任务';
  }

  @override
  String get comingSoon => '即将开放';

  @override
  String upToPoints(int points) {
    return '最高 +$points';
  }

  @override
  String get digientsTasks => 'Digients 任务';

  @override
  String get tasksTitle => '任务';

  @override
  String poolSortedByReward(int count) {
    return '$count 个任务 · 按奖励排序';
  }

  @override
  String get filterAll => '全部';

  @override
  String get filterHighReward => '高奖励';

  @override
  String get filterQuick => '快速（<3 分钟）';

  @override
  String get filterBeginner => '新手';

  @override
  String get filterVerified => '已验证';

  @override
  String get noTasks => '暂无任务';

  @override
  String get taskNotFound => '未找到任务';

  @override
  String get taskDetails => '任务详情';

  @override
  String get demoCaption => '演示 · 0:08';

  @override
  String get pointsOnApproval => '审核通过后到账';

  @override
  String get duration => '时长';

  @override
  String get difficulty => '难度';

  @override
  String get lighting => '光线';

  @override
  String get surface => '表面';

  @override
  String get steps => '步骤';

  @override
  String get headsUp => '提示';

  @override
  String get storageWarning => '剩余存储空间低于 5% 时会自动停止录制，手机会振动提醒。';

  @override
  String get storageAvailability => '存储 · 可录 2小时35分 · 剩余 18.0 GB';

  @override
  String get record => '录制';

  @override
  String get cameraPermissionRequired => '需要相机权限';

  @override
  String get failedToInitializeCamera => '相机初始化失败';

  @override
  String get failedToStartRecording => '录制启动失败';

  @override
  String get tapToStop => '点击停止';

  @override
  String get tapToStart => '点击开始';

  @override
  String get preStartPrompt => '将双手放在画面内';

  @override
  String get pressVolumeButtonToStart => '按音量键开始';

  @override
  String get mountCaptionPhone => '横向放置手机，并让箭头朝上';

  @override
  String get mountCaptionHeadband => '固定到头戴绑带上进行采集';

  @override
  String instructionsEndIn(int seconds) {
    return '$seconds 秒后开始';
  }

  @override
  String get skip => '跳过';

  @override
  String get thisSideUp => '此面朝上';

  @override
  String get submittedTitle => '已提交！';

  @override
  String get successCopyUploading => '数据正在上传，稍后会进入审核。';

  @override
  String get successCopyKeepConnection => '请保持网络连接。';

  @override
  String get successCopyPointsSoon => '积分通常会在约 48 小时内到账。';

  @override
  String get pendingReview => '等待审核';

  @override
  String get goToSubmissions => '前往提交记录';

  @override
  String get submissionSaved => '提交已保存';

  @override
  String takePoints(int takeNumber, int points) {
    return '第 $takeNumber 次 · +$points 积分';
  }

  @override
  String get pressVolumeAnotherTake => '按音量键\n继续录制下一条';

  @override
  String get submissionsTitle => '提交记录';

  @override
  String submissionsTotal(int count, String totalGb) {
    return '共 $count 条 · 设备上 $totalGb GB';
  }

  @override
  String get selectMultiple => '多选';

  @override
  String get selectRecordings => '选择录制';

  @override
  String selectedCount(int count) {
    return '已选择 $count 条';
  }

  @override
  String get selectionHint => '点击切换选择 · 长按一行开始选择';

  @override
  String get clear => '清除';

  @override
  String get selectAll => '全选';

  @override
  String get done => '完成';

  @override
  String get noItems => '暂无内容';

  @override
  String get noItemsPrompt => '从首页选择一个场景开始录制。';

  @override
  String get compressingRecording => '正在压缩录制文件...';

  @override
  String compressingProgress(int current, int total) {
    return '正在压缩 $current / $total...';
  }

  @override
  String exportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String get shareSubjectRecording => '第一视角视频录制';

  @override
  String get shareTextRecording => '第一视角视频录制数据包';

  @override
  String shareSubjectRecordings(int count) {
    return '第一视角视频录制（$count 条）';
  }

  @override
  String get shareTextRecordings => '第一视角视频录制数据包';

  @override
  String get deleteRecordingTitle => '删除录制？';

  @override
  String deleteRecordingContent(String idPrefix) {
    return '这会删除本地录制 $idPrefix。';
  }

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get export => '导出';

  @override
  String get exportSelected => '导出已选';

  @override
  String exportRecordingCount(int count) {
    return '导出 $count 条录制';
  }

  @override
  String get uploadToCloud => '上传到云端';

  @override
  String uploadToCloudCount(int count) {
    return '上传 $count 条到云端';
  }

  @override
  String uploadingPercent(int percent) {
    return '上传中 $percent%';
  }

  @override
  String get uploadQueuedLabel => '排队中';

  @override
  String get uploadCompressingShort => '压缩中';

  @override
  String get uploadCompressingLong => '压缩中…';

  @override
  String get uploadFinalizingShort => '结尾中';

  @override
  String get uploadFinalizingLong => '结尾中…';

  @override
  String get uploadedLabel => '已上传';

  @override
  String get uploadShort => '上传';

  @override
  String get uploadRetryShort => '重试';

  @override
  String get uploadFailedShort => '失败';

  @override
  String get uploadFailedRetry => '上传失败 — 点击重试';

  @override
  String uploadFailedSnack(String error) {
    return '上传失败：$error';
  }

  @override
  String get savedOnDevice => '已保存在设备上';

  @override
  String get notUploadedYet => '尚未上传。你可以使用导出，通过系统分享面板发送录制数据包。';

  @override
  String get sessionId => '会话 ID';

  @override
  String get captured => '采集时间';

  @override
  String get size => '大小';

  @override
  String get codec => '编码';

  @override
  String get resolution => '分辨率';

  @override
  String get intrinsics => '内参';

  @override
  String get perFrame => '逐帧';

  @override
  String get keepAppOpen => '请保持应用打开';

  @override
  String get statusOnDevice => '设备上';

  @override
  String get statusUploading => '上传中';

  @override
  String get statusInReview => '审核中';

  @override
  String get statusApproved => '已通过';

  @override
  String get statusRejected => '已拒绝';

  @override
  String recordingTitle(String idPrefix) {
    return '录制 $idPrefix';
  }

  @override
  String recordingInCategory(String category, String idPrefix) {
    return '$category · $idPrefix';
  }

  @override
  String get profileHours => '小时';

  @override
  String get profileSubmitted => '已提交';

  @override
  String get profileApproval => '通过率';

  @override
  String get profileCapability => '能力';

  @override
  String get capabilityHousehold => '家务';

  @override
  String get capabilityIndustrial => '工业';

  @override
  String get capabilitySports => '运动';

  @override
  String get capabilityVariety => '多样性';

  @override
  String get capabilitySpeed => '速度';

  @override
  String get capabilityApproval => '通过率';

  @override
  String get leaderboardGlobal => '全球排行榜';

  @override
  String rankNumber(int rank) {
    return '排名 #$rank';
  }

  @override
  String get categoryLivingRoom => '客厅';

  @override
  String get categoryKitchen => '厨房';

  @override
  String get categoryBedroom => '卧室';

  @override
  String get categoryConvenienceStore => '便利店';

  @override
  String get categoryBathroom => '浴室';

  @override
  String get taskTagPickPlace => '抓取放置';

  @override
  String get taskTagSwitch => '开关';

  @override
  String get taskTagFolding => '折叠';

  @override
  String get taskTagCutting => '切配';

  @override
  String get taskTagTableware => '餐具';

  @override
  String get taskTagPouring => '倒取';

  @override
  String get taskTagCleaning => '清洁';

  @override
  String get taskTagHandover => '递交';

  @override
  String get difficultyEasy => '简单';

  @override
  String get difficultyMedium => '中等';

  @override
  String get lightingBrightIndoor => '明亮室内';

  @override
  String get lightingMixed => '混合光线';

  @override
  String get lightingEvenOverhead => '均匀顶光';

  @override
  String get duration10To20 => '10–20 秒';

  @override
  String get duration15To30 => '15–30 秒';

  @override
  String get duration30To60 => '30–60 秒';

  @override
  String get duration30To90 => '30–90 秒';

  @override
  String get duration45To90 => '45–90 秒';

  @override
  String get duration60To120 => '60–120 秒';

  @override
  String get duration60To180 => '60–180 秒';

  @override
  String get duration120To240 => '120–240 秒';

  @override
  String get slots0Of30 => '0 / 30 名额';

  @override
  String get slots0Of40 => '0 / 40 名额';

  @override
  String get slots0Of50 => '0 / 50 名额';

  @override
  String get surfaceCoffeeTable => '茶几';

  @override
  String get surfaceWallSwitch => '墙壁开关';

  @override
  String get surfaceLivingRoomDrawer => '客厅抽屉';

  @override
  String get surfaceWindow => '窗户';

  @override
  String get surfaceLivingRoom => '客厅';

  @override
  String get surfaceBed => '床';

  @override
  String get surfaceCuttingBoard => '砧板';

  @override
  String get surfaceKitchenCounter => '厨房台面';

  @override
  String get surfaceToilet => '马桶';

  @override
  String get surfaceBasin => '洗手盆';

  @override
  String get surfaceStoreShelf => '货架';

  @override
  String get surfaceCounter => '柜台';

  @override
  String get taskLrPickRemoteTitle => '拿起并放置遥控器';

  @override
  String get taskLrPickRemoteStep1 => '把遥控器放在客厅桌面上。';

  @override
  String get taskLrPickRemoteStep2 => '拿起遥控器，移动到桌面、沙发或椅子的另一个位置，并停顿 1 秒。';

  @override
  String get taskLrPickRemoteStep3 => '再次拿起并放回原位，然后停顿 1 秒。';

  @override
  String get taskLrPickRemoteStep4 => '每次尝试更换目标位置；保持双手在画面内。';

  @override
  String get taskLrPickPhoneTitle => '拿起并放置手机';

  @override
  String get taskLrPickPhoneStep1 => '把手机放在客厅桌面上。';

  @override
  String get taskLrPickPhoneStep2 => '拿起手机，移动到桌面、沙发或椅子的另一个位置，并停顿 1 秒。';

  @override
  String get taskLrPickPhoneStep3 => '再次拿起并放回原位，然后停顿 1 秒。';

  @override
  String get taskLrPickPhoneStep4 => '每次尝试更换目标位置；保持双手在画面内。';

  @override
  String get taskLrPickPowerbankTitle => '拿起并放置充电宝';

  @override
  String get taskLrPickPowerbankStep1 => '把充电宝放在客厅桌面上。';

  @override
  String get taskLrPickPowerbankStep2 => '拿起充电宝，移动到桌面、沙发或椅子的另一个位置，并停顿 1 秒。';

  @override
  String get taskLrPickPowerbankStep3 => '再次拿起并放回原位，然后停顿 1 秒。';

  @override
  String get taskLrPickPowerbankStep4 => '每次尝试更换目标位置；保持双手在画面内。';

  @override
  String get taskLrPickComboTitle => '抓取放置：遥控器 + 手机 + 充电宝';

  @override
  String get taskLrPickComboStep1 => '把遥控器、手机和充电宝一起放在桌面上。';

  @override
  String get taskLrPickComboStep2 => '拿起遥控器，移动到桌面、沙发或椅子的新位置，停顿 1 秒，再放回原位。';

  @override
  String get taskLrPickComboStep3 => '对手机重复同样动作，再对充电宝重复一次。';

  @override
  String get taskLrPickComboStep4 => '不同物品尝试不同目标位置；保持完整动作在画面内。';

  @override
  String get taskLrSwitchLightTitle => '切换墙壁灯开关';

  @override
  String get taskLrSwitchLightStep1 => '走到墙壁开关前。';

  @override
  String get taskLrSwitchLightStep2 => '按一次打开灯；停顿 2 秒，让相机记录灯亮起。';

  @override
  String get taskLrSwitchLightStep3 => '再按一次关灯；停顿 2 秒，让相机记录灯熄灭。';

  @override
  String get taskLrSwitchLightStep4 => '每次都完整按下，不要半按；保持手部可见。';

  @override
  String get taskLrSwitchDrawerTitle => '打开并关闭抽屉';

  @override
  String get taskLrSwitchDrawerStep1 => '走到抽屉前。';

  @override
  String get taskLrSwitchDrawerStep2 => '握住把手并完全拉开；停顿 2 秒。';

  @override
  String get taskLrSwitchDrawerStep3 => '把抽屉完全推回关闭；停顿 2 秒。';

  @override
  String get taskLrSwitchDrawerStep4 => '每次都拉/推到底，不要只做半程动作。';

  @override
  String get taskLrSwitchCurtainTitle => '打开并关闭窗帘';

  @override
  String get taskLrSwitchCurtainStep1 => '走到窗帘前。';

  @override
  String get taskLrSwitchCurtainStep2 => '抓住拉绳或布料并完全拉开，让光线进入；停顿 2 秒。';

  @override
  String get taskLrSwitchCurtainStep3 => '再把窗帘完全拉上；停顿 2 秒。';

  @override
  String get taskLrSwitchCurtainStep4 => '始终从一端拉到另一端，不要做半程动作。';

  @override
  String get taskLrSwitchComboTitle => '灯 + 抽屉 + 窗帘组合';

  @override
  String get taskLrSwitchComboStep1 => '打开墙壁灯，停顿 2 秒；再关闭，停顿 2 秒。';

  @override
  String get taskLrSwitchComboStep2 => '完全拉开抽屉，停顿 2 秒；再完全推回关闭，停顿 2 秒。';

  @override
  String get taskLrSwitchComboStep3 => '完全拉开窗帘，停顿 2 秒；再关闭，停顿 2 秒。';

  @override
  String get taskLrSwitchComboStep4 => '按顺序完成三项动作；全程保持手部在画面内。';

  @override
  String get taskBrFoldClothesSingleTitle => '折叠一件衣物';

  @override
  String get taskBrFoldClothesSingleStep1 => '把一件干净的 T 恤、衬衫或裤子平铺在床上。';

  @override
  String get taskBrFoldClothesSingleStep2 => '把两侧向中间折，再从底部向上卷起或折起。';

  @override
  String get taskBrFoldClothesSingleStep3 => '把折好的衣物放到床头或衣柜层板上，并停顿 1 秒。';

  @override
  String get taskBrFoldClothesSingleStep4 => '保持双手可见，不要把衣物举到镜头前遮挡画面。';

  @override
  String get taskBrFoldClothesMultiTitle => '折叠 2–3 件衣物';

  @override
  String get taskBrFoldClothesMultiStep1 => '把 2–3 件干净衣物平铺在床上。';

  @override
  String get taskBrFoldClothesMultiStep2 => '逐件折叠：两侧向中间折，再从底部向上折，并叠放到层板上。';

  @override
  String get taskBrFoldClothesMultiStep3 => '完成一件后再开始下一件。';

  @override
  String get taskBrFoldClothesMultiStep4 => '保持自然速度；全程保持双手在画面内。';

  @override
  String get taskBrFoldTowelSingleTitle => '折叠一条毛巾';

  @override
  String get taskBrFoldTowelSingleStep1 => '把一条干净毛巾（面巾或浴巾）平铺在床上。';

  @override
  String get taskBrFoldTowelSingleStep2 => '沿长边对折，再沿短边对折成方形。';

  @override
  String get taskBrFoldTowelSingleStep3 => '把它放到洗漱台或衣柜层板上。';

  @override
  String get taskBrFoldTowelSingleStep4 => '保持双手在画面内，不要用毛巾遮挡镜头。';

  @override
  String get taskBrFoldTowelMultiTitle => '折叠 2–3 条毛巾';

  @override
  String get taskBrFoldTowelMultiStep1 => '把 2–3 条干净毛巾平铺在床上。';

  @override
  String get taskBrFoldTowelMultiStep2 => '逐条折叠：长边对折，再短边对折，并叠放起来。';

  @override
  String get taskBrFoldTowelMultiStep3 => '完成一条后再处理下一条。';

  @override
  String get taskBrFoldTowelMultiStep4 => '保持自然速度；保持双手在画面内。';

  @override
  String get taskKtCutFruitSingleTitle => '切一份水果';

  @override
  String get taskKtCutFruitSingleStep1 => '清洗一个苹果、橙子、香蕉或类似水果。';

  @override
  String get taskKtCutFruitSingleStep2 => '把水果放在砧板上，用刀切成块。';

  @override
  String get taskKtCutFruitSingleStep3 => '把切好的水果转移到盘子里。';

  @override
  String get taskKtCutFruitSingleStep4 => '注意用刀安全，不要把刀举到手部离开画面的高度。';

  @override
  String get taskKtCutFruitMultiTitle => '切 2–3 种不同水果';

  @override
  String get taskKtCutFruitMultiStep1 => '清洗 2–3 种不同水果（例如苹果、橙子、香蕉）。';

  @override
  String get taskKtCutFruitMultiStep2 => '在砧板上逐个切好，每切完一种就转移到盘子里。';

  @override
  String get taskKtCutFruitMultiStep3 => '一只手固定水果，另一只手切；保持双手可见。';

  @override
  String get taskKtCutFruitMultiStep4 => '作为一个视频上传，不要按水果拆分。';

  @override
  String get taskKtTablewareSingleTitle => '摆放一件餐具';

  @override
  String get taskKtTablewareSingleStep1 => '选择一件物品（盘子、碗、筷子、叉子或勺子），整齐放到台面或炉灶上。';

  @override
  String get taskKtTablewareSingleStep2 => '放好后再拿起，并放回原来的位置。';

  @override
  String get taskKtTablewareSingleStep3 => '完整完成伸手、抓取、放置动作；不要太快。';

  @override
  String get taskKtTablewareSingleStep4 => '不同物品算作不同视频。';

  @override
  String get taskKtTablewareMultiTitle => '摆放多件餐具';

  @override
  String get taskKtTablewareMultiStep1 => '把每件餐具（盘子、碗、筷子、叉子、勺子）逐一整齐摆到台面上。';

  @override
  String get taskKtTablewareMultiStep2 => '也可以再逐一收回原位。';

  @override
  String get taskKtTablewareMultiStep3 => '每件物品约 15–30 秒；作为一个组合视频上传。';

  @override
  String get taskKtTablewareMultiStep4 => '轻拿轻放，不要摔落碗具。';

  @override
  String get taskKtPourWaterTitle => '用水壶往杯子里倒水';

  @override
  String get taskKtPourWaterStep1 => '给水壶装水；把杯子放在台面上。';

  @override
  String get taskKtPourWaterStep2 => '拿起水壶，对准杯子，倒到约 70–80% 满。';

  @override
  String get taskKtPourWaterStep3 => '把水壶放回台面。';

  @override
  String get taskKtPourWaterStep4 => '每次尝试可更换不同杯子（玻璃杯、陶瓷杯）；一次倒水就是一个视频。';

  @override
  String get taskKtPourCoffeeTitle => '用水壶往杯子里倒咖啡';

  @override
  String get taskKtPourCoffeeStep1 => '给水壶装咖啡；把杯子放在台面上。';

  @override
  String get taskKtPourCoffeeStep2 => '拿起水壶，对准杯子，倒到约 70–80% 满。';

  @override
  String get taskKtPourCoffeeStep3 => '把水壶放回台面。';

  @override
  String get taskKtPourCoffeeStep4 => '每次尝试可更换不同杯子（玻璃杯、陶瓷杯）；一次倒取就是一个视频。';

  @override
  String get taskKtPourTeaTitle => '用水壶往杯子里倒茶';

  @override
  String get taskKtPourTeaStep1 => '给水壶装茶；把杯子放在台面上。';

  @override
  String get taskKtPourTeaStep2 => '拿起水壶，对准杯子，倒到约 70–80% 满。';

  @override
  String get taskKtPourTeaStep3 => '把水壶放回台面。';

  @override
  String get taskKtPourTeaStep4 => '每次尝试可更换不同杯子（玻璃杯、陶瓷杯）；一次倒取就是一个视频。';

  @override
  String get taskKtPourComboTitle => '倒水 + 咖啡 + 茶';

  @override
  String get taskKtPourComboStep1 => '准备水壶和杯子（可使用水、茶或咖啡）。';

  @override
  String get taskKtPourComboStep2 => '连续倒 2–3 杯，尽量更换杯子样式。';

  @override
  String get taskKtPourComboStep3 => '每次倒完后都把水壶放下。';

  @override
  String get taskKtPourComboStep4 => '作为一个视频上传，多杯倒取属于一个任务。';

  @override
  String get taskBtWipeToiletTitle => '擦拭马桶外侧';

  @override
  String get taskBtWipeToiletStep1 => '拿一块干净抹布，并喷少量清洁剂（湿抹布也可以）。';

  @override
  String get taskBtWipeToiletStep2 => '来回擦拭水箱、盖板和马桶外侧主体。';

  @override
  String get taskBtWipeToiletStep3 => '覆盖所有外部表面；保持手部可见，不要让身体挡住马桶。';

  @override
  String get taskBtWipeToiletStep4 => '完成后把抹布放回。';

  @override
  String get taskBtCleanToiletSeatTitle => '清洁马桶座圈';

  @override
  String get taskBtCleanToiletSeatStep1 => '掀起马桶座圈，并录下掀起动作。';

  @override
  String get taskBtCleanToiletSeatStep2 => '擦拭座圈下侧，再翻回擦拭上侧，确保两面都干净。';

  @override
  String get taskBtCleanToiletSeatStep3 => '把座圈放回原位；收好抹布。';

  @override
  String get taskBtCleanToiletSeatStep4 => '注意卫生，不要溅到自己身上。';

  @override
  String get taskBtCleanBasinTitle => '清洁洗手盆';

  @override
  String get taskBtCleanBasinStep1 => '先擦拭洗手盆内部，再擦周围台面，最后擦水龙头。';

  @override
  String get taskBtCleanBasinStep2 => '确保每个擦拭动作都被拍到，不要跳过区域。';

  @override
  String get taskBtCleanBasinStep3 => '避免把水溅得到处都是，按平时方式清洁。';

  @override
  String get taskBtCleanBasinStep4 => '把抹布放回。';

  @override
  String get taskCsPickShelfSingleTitle => '从货架上取下一件商品';

  @override
  String get taskCsPickShelfSingleStep1 => '准备一个货架，放上常见便利店商品（水、饼干、牙膏等）。';

  @override
  String get taskCsPickShelfSingleStep2 => '从货架上取下一件商品，放入面前的篮子里；停顿 1 秒。';

  @override
  String get taskCsPickShelfSingleStep3 => '再从篮子里拿出商品，放回原来的货架位置。';

  @override
  String get taskCsPickShelfSingleStep4 =>
      '每次尝试可更换不同货架高度，但要在可触及范围内；一件商品就是一个视频。';

  @override
  String get taskCsPickShelfMultiTitle => '从货架上取下 2–3 件商品';

  @override
  String get taskCsPickShelfMultiStep1 => '在货架上摆放多种便利店商品。';

  @override
  String get taskCsPickShelfMultiStep2 => '对每件商品：从货架取下，放入篮子，停顿 1 秒，再放回原位。';

  @override
  String get taskCsPickShelfMultiStep3 => '尝试从不同层架取物（上层、中层、下层）。';

  @override
  String get taskCsPickShelfMultiStep4 => '作为一个视频上传，多件商品属于一个任务。';

  @override
  String get taskCsWipeCounterTitle => '擦拭柜台/货架表面';

  @override
  String get taskCsWipeCounterStep1 => '拿一块湿抹布。';

  @override
  String get taskCsWipeCounterStep2 => '从左到右擦拭收银台或货架表面，覆盖整个顶部。';

  @override
  String get taskCsWipeCounterStep3 => '擦拭过程中保持手部可见。';

  @override
  String get taskCsWipeCounterStep4 => '完成后把抹布放回。';

  @override
  String get taskCsHandoverSingleTitle => '把一件商品递给顾客';

  @override
  String get taskCsHandoverSingleStep1 => '在货架上摆放商品，请朋友或家人站在你面前扮演“顾客”。';

  @override
  String get taskCsHandoverSingleStep2 => '从货架上取下一件商品（例如一瓶水），递给顾客。';

  @override
  String get taskCsHandoverSingleStep3 => '顾客接过商品；停顿 1 秒。';

  @override
  String get taskCsHandoverSingleStep4 => '你的手和顾客的手都可以出现在画面中，动作保持自然。';

  @override
  String get taskCsHandoverMultiTitle => '把 2–3 件商品递给顾客';

  @override
  String get taskCsHandoverMultiStep1 => '准备货架，并让一位“顾客”站在你对面。';

  @override
  String get taskCsHandoverMultiStep2 => '从货架上取下一件商品并递过去；停顿 1 秒。';

  @override
  String get taskCsHandoverMultiStep3 => '对 2–3 件不同商品重复动作。';

  @override
  String get taskCsHandoverMultiStep4 => '作为一个视频上传，多次递交属于一个任务。';
}

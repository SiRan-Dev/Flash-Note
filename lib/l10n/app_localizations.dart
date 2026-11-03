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
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'闪念'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In zh, this message translates to:
  /// **'捕捉每一个灵感'**
  String get appTagline;

  /// No description provided for @home.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get home;

  /// No description provided for @inspirations.
  ///
  /// In zh, this message translates to:
  /// **'灵感'**
  String get inspirations;

  /// No description provided for @projects.
  ///
  /// In zh, this message translates to:
  /// **'项目'**
  String get projects;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get settings;

  /// No description provided for @captureInspiration.
  ///
  /// In zh, this message translates to:
  /// **'捕捉灵感'**
  String get captureInspiration;

  /// No description provided for @editInspiration.
  ///
  /// In zh, this message translates to:
  /// **'编辑灵感'**
  String get editInspiration;

  /// No description provided for @writeInspiration.
  ///
  /// In zh, this message translates to:
  /// **'写下你的灵感...'**
  String get writeInspiration;

  /// No description provided for @inspirationSource.
  ///
  /// In zh, this message translates to:
  /// **'灵感来源（可选）'**
  String get inspirationSource;

  /// No description provided for @tags.
  ///
  /// In zh, this message translates to:
  /// **'标签（可选）'**
  String get tags;

  /// No description provided for @tagHint.
  ///
  /// In zh, this message translates to:
  /// **'输入标签，回车添加'**
  String get tagHint;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

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

  /// No description provided for @pin.
  ///
  /// In zh, this message translates to:
  /// **'置顶'**
  String get pin;

  /// No description provided for @unpin.
  ///
  /// In zh, this message translates to:
  /// **'取消置顶'**
  String get unpin;

  /// No description provided for @deleteInspiration.
  ///
  /// In zh, this message translates to:
  /// **'删除灵感'**
  String get deleteInspiration;

  /// No description provided for @deleteInspirationConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除这条灵感吗？'**
  String get deleteInspirationConfirm;

  /// No description provided for @searchInspiration.
  ///
  /// In zh, this message translates to:
  /// **'搜索灵感...'**
  String get searchInspiration;

  /// No description provided for @noMatchFound.
  ///
  /// In zh, this message translates to:
  /// **'没有找到匹配的灵感'**
  String get noMatchFound;

  /// No description provided for @noInspirationYet.
  ///
  /// In zh, this message translates to:
  /// **'还没有灵感，快去捕捉吧！'**
  String get noInspirationYet;

  /// No description provided for @all.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get all;

  /// No description provided for @aiCapabilities.
  ///
  /// In zh, this message translates to:
  /// **'AI 能力'**
  String get aiCapabilities;

  /// No description provided for @aiAnalysis.
  ///
  /// In zh, this message translates to:
  /// **'AI 分析'**
  String get aiAnalysis;

  /// No description provided for @aiAnalysisDesc.
  ///
  /// In zh, this message translates to:
  /// **'评估可行性、潜力和风险'**
  String get aiAnalysisDesc;

  /// No description provided for @mindMap.
  ///
  /// In zh, this message translates to:
  /// **'思维导图'**
  String get mindMap;

  /// No description provided for @mindMapDesc.
  ///
  /// In zh, this message translates to:
  /// **'AI 生成思维导图'**
  String get mindMapDesc;

  /// No description provided for @aiChat.
  ///
  /// In zh, this message translates to:
  /// **'AI 对话'**
  String get aiChat;

  /// No description provided for @aiChatDesc.
  ///
  /// In zh, this message translates to:
  /// **'深度探讨灵感'**
  String get aiChatDesc;

  /// No description provided for @createProject.
  ///
  /// In zh, this message translates to:
  /// **'创建项目'**
  String get createProject;

  /// No description provided for @createProjectDesc.
  ///
  /// In zh, this message translates to:
  /// **'将灵感转化为项目'**
  String get createProjectDesc;

  /// No description provided for @catchEveryInspiration.
  ///
  /// In zh, this message translates to:
  /// **'随时记录你的灵感'**
  String get catchEveryInspiration;

  /// No description provided for @contentEmpty.
  ///
  /// In zh, this message translates to:
  /// **'灵感内容不能为空'**
  String get contentEmpty;

  /// No description provided for @sourceFlash.
  ///
  /// In zh, this message translates to:
  /// **'突发奇想'**
  String get sourceFlash;

  /// No description provided for @sourceReading.
  ///
  /// In zh, this message translates to:
  /// **'阅读启发'**
  String get sourceReading;

  /// No description provided for @sourceDialogue.
  ///
  /// In zh, this message translates to:
  /// **'对话碰撞'**
  String get sourceDialogue;

  /// No description provided for @sourceObservation.
  ///
  /// In zh, this message translates to:
  /// **'观察发现'**
  String get sourceObservation;

  /// No description provided for @sourceProblem.
  ///
  /// In zh, this message translates to:
  /// **'问题驱动'**
  String get sourceProblem;

  /// No description provided for @inspirationNotFound.
  ///
  /// In zh, this message translates to:
  /// **'灵感不存在'**
  String get inspirationNotFound;

  /// No description provided for @loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get loadFailed;

  /// No description provided for @projectComingSoon.
  ///
  /// In zh, this message translates to:
  /// **'项目管理即将上线'**
  String get projectComingSoon;

  /// No description provided for @projectComingSoonDesc.
  ///
  /// In zh, this message translates to:
  /// **'S3 阶段实现'**
  String get projectComingSoonDesc;

  /// No description provided for @developer.
  ///
  /// In zh, this message translates to:
  /// **'开发者'**
  String get developer;

  /// No description provided for @version.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get version;

  /// No description provided for @aiSettings.
  ///
  /// In zh, this message translates to:
  /// **'AI 配置'**
  String get aiSettings;

  /// No description provided for @aiSettingsDesc.
  ///
  /// In zh, this message translates to:
  /// **'选择 AI 服务商、填写 API Key'**
  String get aiSettingsDesc;

  /// No description provided for @selectProvider.
  ///
  /// In zh, this message translates to:
  /// **'选择服务商'**
  String get selectProvider;

  /// No description provided for @apiKey.
  ///
  /// In zh, this message translates to:
  /// **'API Key'**
  String get apiKey;

  /// No description provided for @apiKeyHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入 API Key'**
  String get apiKeyHint;

  /// No description provided for @testConnection.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get testConnection;

  /// No description provided for @connectionSuccess.
  ///
  /// In zh, this message translates to:
  /// **'连接成功'**
  String get connectionSuccess;

  /// No description provided for @connectionFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败'**
  String get connectionFailed;

  /// No description provided for @apiKeyRequired.
  ///
  /// In zh, this message translates to:
  /// **'请先配置 API Key'**
  String get apiKeyRequired;

  /// No description provided for @aiAnalyzing.
  ///
  /// In zh, this message translates to:
  /// **'AI 分析中...'**
  String get aiAnalyzing;

  /// No description provided for @aiAnalysisResult.
  ///
  /// In zh, this message translates to:
  /// **'AI 分析结果'**
  String get aiAnalysisResult;

  /// No description provided for @feasibility.
  ///
  /// In zh, this message translates to:
  /// **'可行性'**
  String get feasibility;

  /// No description provided for @potential.
  ///
  /// In zh, this message translates to:
  /// **'潜力'**
  String get potential;

  /// No description provided for @risk.
  ///
  /// In zh, this message translates to:
  /// **'风险'**
  String get risk;

  /// No description provided for @suggestions.
  ///
  /// In zh, this message translates to:
  /// **'建议'**
  String get suggestions;

  /// No description provided for @generatingMindMap.
  ///
  /// In zh, this message translates to:
  /// **'生成思维导图中...'**
  String get generatingMindMap;

  /// No description provided for @mindMapError.
  ///
  /// In zh, this message translates to:
  /// **'思维导图生成失败'**
  String get mindMapError;

  /// No description provided for @expand.
  ///
  /// In zh, this message translates to:
  /// **'展开'**
  String get expand;

  /// No description provided for @collapse.
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get collapse;

  /// No description provided for @send.
  ///
  /// In zh, this message translates to:
  /// **'发送'**
  String get send;

  /// No description provided for @typeMessage.
  ///
  /// In zh, this message translates to:
  /// **'输入消息...'**
  String get typeMessage;

  /// No description provided for @aiThinking.
  ///
  /// In zh, this message translates to:
  /// **'AI 思考中...'**
  String get aiThinking;

  /// No description provided for @messageSendFailed.
  ///
  /// In zh, this message translates to:
  /// **'消息发送失败'**
  String get messageSendFailed;

  /// No description provided for @clearChatHistory.
  ///
  /// In zh, this message translates to:
  /// **'清空对话历史'**
  String get clearChatHistory;

  /// No description provided for @clearChatHistoryConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要清空对话历史吗？'**
  String get clearChatHistoryConfirm;

  /// No description provided for @chatCleared.
  ///
  /// In zh, this message translates to:
  /// **'对话已清空'**
  String get chatCleared;

  /// No description provided for @aiChatWithInspiration.
  ///
  /// In zh, this message translates to:
  /// **'与 AI 探讨这条灵感'**
  String get aiChatWithInspiration;

  /// No description provided for @noApiKeyConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置 API Key'**
  String get noApiKeyConfigured;

  /// No description provided for @goToSettings.
  ///
  /// In zh, this message translates to:
  /// **'去设置'**
  String get goToSettings;

  /// No description provided for @analysisCached.
  ///
  /// In zh, this message translates to:
  /// **'分析结果已缓存'**
  String get analysisCached;

  /// No description provided for @reanalyze.
  ///
  /// In zh, this message translates to:
  /// **'重新分析'**
  String get reanalyze;

  /// No description provided for @editProject.
  ///
  /// In zh, this message translates to:
  /// **'编辑项目'**
  String get editProject;

  /// No description provided for @projectTitle.
  ///
  /// In zh, this message translates to:
  /// **'项目标题'**
  String get projectTitle;

  /// No description provided for @projectDescription.
  ///
  /// In zh, this message translates to:
  /// **'项目描述'**
  String get projectDescription;

  /// No description provided for @projectTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入项目标题'**
  String get projectTitleHint;

  /// No description provided for @projectDescriptionHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入项目描述'**
  String get projectDescriptionHint;

  /// No description provided for @deleteProject.
  ///
  /// In zh, this message translates to:
  /// **'删除项目'**
  String get deleteProject;

  /// No description provided for @deleteProjectConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除这个项目吗？相关任务也会被删除。'**
  String get deleteProjectConfirm;

  /// No description provided for @active.
  ///
  /// In zh, this message translates to:
  /// **'进行中'**
  String get active;

  /// No description provided for @paused.
  ///
  /// In zh, this message translates to:
  /// **'已暂停'**
  String get paused;

  /// No description provided for @completed.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get completed;

  /// No description provided for @progress.
  ///
  /// In zh, this message translates to:
  /// **'进度'**
  String get progress;

  /// No description provided for @tasks.
  ///
  /// In zh, this message translates to:
  /// **'任务'**
  String get tasks;

  /// No description provided for @addTask.
  ///
  /// In zh, this message translates to:
  /// **'添加任务'**
  String get addTask;

  /// No description provided for @taskTitle.
  ///
  /// In zh, this message translates to:
  /// **'任务标题'**
  String get taskTitle;

  /// No description provided for @taskTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入任务标题'**
  String get taskTitleHint;

  /// No description provided for @deleteTask.
  ///
  /// In zh, this message translates to:
  /// **'删除任务'**
  String get deleteTask;

  /// No description provided for @deleteTaskConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除这个任务吗？'**
  String get deleteTaskConfirm;

  /// No description provided for @noTasksYet.
  ///
  /// In zh, this message translates to:
  /// **'暂无任务'**
  String get noTasksYet;

  /// No description provided for @addYourFirstTask.
  ///
  /// In zh, this message translates to:
  /// **'添加你的第一个任务'**
  String get addYourFirstTask;

  /// No description provided for @inspirationToProject.
  ///
  /// In zh, this message translates to:
  /// **'将灵感转化为项目'**
  String get inspirationToProject;

  /// No description provided for @inspirationToProjectConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要将这条灵感转化为项目吗？'**
  String get inspirationToProjectConfirm;

  /// No description provided for @organizeInspiration.
  ///
  /// In zh, this message translates to:
  /// **'梳理灵感思路'**
  String get organizeInspiration;

  /// No description provided for @recentInspirations.
  ///
  /// In zh, this message translates to:
  /// **'最近灵感'**
  String get recentInspirations;

  /// No description provided for @todayTodos.
  ///
  /// In zh, this message translates to:
  /// **'今日待办'**
  String get todayTodos;

  /// No description provided for @quickActions.
  ///
  /// In zh, this message translates to:
  /// **'快捷操作'**
  String get quickActions;

  /// No description provided for @noProjectsYet.
  ///
  /// In zh, this message translates to:
  /// **'暂无项目'**
  String get noProjectsYet;

  /// No description provided for @createYourFirstProject.
  ///
  /// In zh, this message translates to:
  /// **'创建你的第一个项目'**
  String get createYourFirstProject;

  /// No description provided for @projectCreated.
  ///
  /// In zh, this message translates to:
  /// **'项目已创建'**
  String get projectCreated;

  /// No description provided for @taskCompleted.
  ///
  /// In zh, this message translates to:
  /// **'任务已完成'**
  String get taskCompleted;

  /// No description provided for @allTasksCompleted.
  ///
  /// In zh, this message translates to:
  /// **'所有任务已完成！'**
  String get allTasksCompleted;

  /// No description provided for @greeting.
  ///
  /// In zh, this message translates to:
  /// **'你好'**
  String get greeting;

  /// No description provided for @theme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get theme;

  /// No description provided for @themeMode.
  ///
  /// In zh, this message translates to:
  /// **'主题模式'**
  String get themeMode;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @languageDesc.
  ///
  /// In zh, this message translates to:
  /// **'选择应用内显示语言'**
  String get languageDesc;

  /// No description provided for @chinese.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get chinese;

  /// No description provided for @english.
  ///
  /// In zh, this message translates to:
  /// **'英文'**
  String get english;

  /// No description provided for @light.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get dark;

  /// No description provided for @amoledBlack.
  ///
  /// In zh, this message translates to:
  /// **'A屏黑主题'**
  String get amoledBlack;

  /// No description provided for @amoledBlackDesc.
  ///
  /// In zh, this message translates to:
  /// **'在深色模式下使用纯黑背景，节省 AMOLED 屏幕电量'**
  String get amoledBlackDesc;

  /// No description provided for @system.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get system;

  /// No description provided for @dataManagement.
  ///
  /// In zh, this message translates to:
  /// **'数据管理'**
  String get dataManagement;

  /// No description provided for @exportData.
  ///
  /// In zh, this message translates to:
  /// **'导出数据'**
  String get exportData;

  /// No description provided for @importData.
  ///
  /// In zh, this message translates to:
  /// **'导入数据'**
  String get importData;

  /// No description provided for @exportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'导出成功'**
  String get exportSuccess;

  /// No description provided for @exportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败'**
  String get exportFailed;

  /// No description provided for @importSuccess.
  ///
  /// In zh, this message translates to:
  /// **'导入成功'**
  String get importSuccess;

  /// No description provided for @importSuccessAiUpdated.
  ///
  /// In zh, this message translates to:
  /// **'导入成功，AI 配置已更新。请返回设置页面查看。'**
  String get importSuccessAiUpdated;

  /// No description provided for @importFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入失败'**
  String get importFailed;

  /// No description provided for @credentialsNotIncluded.
  ///
  /// In zh, this message translates to:
  /// **'导入/同步的数据不包含 API Key 和 WebDAV 密码，请在本机重新填写。'**
  String get credentialsNotIncluded;

  /// No description provided for @importConfirm.
  ///
  /// In zh, this message translates to:
  /// **'导入将覆盖现有数据，确定继续吗？'**
  String get importConfirm;

  /// No description provided for @sourceManagement.
  ///
  /// In zh, this message translates to:
  /// **'来源管理'**
  String get sourceManagement;

  /// No description provided for @addSource.
  ///
  /// In zh, this message translates to:
  /// **'添加来源'**
  String get addSource;

  /// No description provided for @editSource.
  ///
  /// In zh, this message translates to:
  /// **'编辑来源'**
  String get editSource;

  /// No description provided for @sourceName.
  ///
  /// In zh, this message translates to:
  /// **'来源名称'**
  String get sourceName;

  /// No description provided for @sourceNameHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入来源名称'**
  String get sourceNameHint;

  /// No description provided for @deleteSource.
  ///
  /// In zh, this message translates to:
  /// **'删除来源'**
  String get deleteSource;

  /// No description provided for @deleteSourceConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除这个来源吗？'**
  String get deleteSourceConfirm;

  /// No description provided for @cannotDeleteBuiltIn.
  ///
  /// In zh, this message translates to:
  /// **'内置来源不可删除'**
  String get cannotDeleteBuiltIn;

  /// No description provided for @about.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get about;

  /// No description provided for @clearCache.
  ///
  /// In zh, this message translates to:
  /// **'清除缓存'**
  String get clearCache;

  /// No description provided for @hasCachedResult.
  ///
  /// In zh, this message translates to:
  /// **'已有分析结果'**
  String get hasCachedResult;

  /// No description provided for @hasCachedMindMap.
  ///
  /// In zh, this message translates to:
  /// **'已有思维导图'**
  String get hasCachedMindMap;

  /// No description provided for @hasChatHistory.
  ///
  /// In zh, this message translates to:
  /// **'有对话记录'**
  String get hasChatHistory;

  /// No description provided for @cacheCleared.
  ///
  /// In zh, this message translates to:
  /// **'缓存已清除'**
  String get cacheCleared;

  /// No description provided for @cloudSync.
  ///
  /// In zh, this message translates to:
  /// **'云同步'**
  String get cloudSync;

  /// No description provided for @webdavSettings.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 设置'**
  String get webdavSettings;

  /// No description provided for @webdavSettingsDesc.
  ///
  /// In zh, this message translates to:
  /// **'配置 WebDAV 服务进行多端数据同步'**
  String get webdavSettingsDesc;

  /// No description provided for @serverUrl.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址'**
  String get serverUrl;

  /// No description provided for @serverUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'例如 https://dav.jianguoyun.com/dav/'**
  String get serverUrlHint;

  /// No description provided for @remotePath.
  ///
  /// In zh, this message translates to:
  /// **'远程路径'**
  String get remotePath;

  /// No description provided for @remotePathHint.
  ///
  /// In zh, this message translates to:
  /// **'例如 /FlashNote/'**
  String get remotePathHint;

  /// No description provided for @autoSync.
  ///
  /// In zh, this message translates to:
  /// **'启动时自动同步'**
  String get autoSync;

  /// No description provided for @autoSyncDesc.
  ///
  /// In zh, this message translates to:
  /// **'打开应用时自动执行合并同步'**
  String get autoSyncDesc;

  /// No description provided for @lastSyncTime.
  ///
  /// In zh, this message translates to:
  /// **'上次同步'**
  String get lastSyncTime;

  /// No description provided for @neverSynced.
  ///
  /// In zh, this message translates to:
  /// **'从未同步'**
  String get neverSynced;

  /// No description provided for @syncPull.
  ///
  /// In zh, this message translates to:
  /// **'拉取'**
  String get syncPull;

  /// No description provided for @syncPullDesc.
  ///
  /// In zh, this message translates to:
  /// **'从远端拉取数据到本地（覆盖本地）'**
  String get syncPullDesc;

  /// No description provided for @syncPush.
  ///
  /// In zh, this message translates to:
  /// **'推送'**
  String get syncPush;

  /// No description provided for @syncPushDesc.
  ///
  /// In zh, this message translates to:
  /// **'将本地数据推送到远端（覆盖远端）'**
  String get syncPushDesc;

  /// No description provided for @syncMerge.
  ///
  /// In zh, this message translates to:
  /// **'合并'**
  String get syncMerge;

  /// No description provided for @syncMergeDesc.
  ///
  /// In zh, this message translates to:
  /// **'合并多端数据（以较新者为准）'**
  String get syncMergeDesc;

  /// No description provided for @syncing.
  ///
  /// In zh, this message translates to:
  /// **'同步中...'**
  String get syncing;

  /// No description provided for @syncSuccess.
  ///
  /// In zh, this message translates to:
  /// **'同步成功'**
  String get syncSuccess;

  /// No description provided for @syncFailed.
  ///
  /// In zh, this message translates to:
  /// **'同步失败'**
  String get syncFailed;

  /// No description provided for @syncPullConfirm.
  ///
  /// In zh, this message translates to:
  /// **'拉取将覆盖本地所有数据，确定继续吗？'**
  String get syncPullConfirm;

  /// No description provided for @syncPushConfirm.
  ///
  /// In zh, this message translates to:
  /// **'推送将覆盖远端所有数据，确定继续吗？'**
  String get syncPushConfirm;

  /// No description provided for @syncMergeConfirm.
  ///
  /// In zh, this message translates to:
  /// **'将合并本地和远端数据（以更新时间较新者为准），确定继续吗？'**
  String get syncMergeConfirm;

  /// No description provided for @webdavNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'请先配置 WebDAV 账号信息'**
  String get webdavNotConfigured;

  /// No description provided for @username.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get username;

  /// No description provided for @usernameHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入 WebDAV 用户名'**
  String get usernameHint;

  /// No description provided for @password.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// No description provided for @passwordHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入 WebDAV 应用密码'**
  String get passwordHint;

  /// No description provided for @connectionTestSuccess.
  ///
  /// In zh, this message translates to:
  /// **'连接测试成功'**
  String get connectionTestSuccess;

  /// No description provided for @connectionTestFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接测试失败'**
  String get connectionTestFailed;

  /// No description provided for @syncMode.
  ///
  /// In zh, this message translates to:
  /// **'同步模式'**
  String get syncMode;

  /// No description provided for @syncInterval.
  ///
  /// In zh, this message translates to:
  /// **'定时同步'**
  String get syncInterval;

  /// No description provided for @syncIntervalOff.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get syncIntervalOff;

  /// No description provided for @syncInterval5m.
  ///
  /// In zh, this message translates to:
  /// **'每 5 分钟'**
  String get syncInterval5m;

  /// No description provided for @syncInterval15m.
  ///
  /// In zh, this message translates to:
  /// **'每 15 分钟'**
  String get syncInterval15m;

  /// No description provided for @syncInterval30m.
  ///
  /// In zh, this message translates to:
  /// **'每 30 分钟'**
  String get syncInterval30m;

  /// No description provided for @syncInterval1h.
  ///
  /// In zh, this message translates to:
  /// **'每 1 小时'**
  String get syncInterval1h;

  /// No description provided for @syncCompletedRefresh.
  ///
  /// In zh, this message translates to:
  /// **'同步完成，AI 配置已更新。请返回设置页面查看。'**
  String get syncCompletedRefresh;

  /// No description provided for @customAI.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get customAI;

  /// No description provided for @baseUrl.
  ///
  /// In zh, this message translates to:
  /// **'Base URL'**
  String get baseUrl;

  /// No description provided for @baseUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'例如 https://api.openai.com/v1'**
  String get baseUrlHint;

  /// No description provided for @modelName.
  ///
  /// In zh, this message translates to:
  /// **'模型名称'**
  String get modelName;

  /// No description provided for @modelNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例如 gpt-4o'**
  String get modelNameHint;

  /// No description provided for @claudeMode.
  ///
  /// In zh, this message translates to:
  /// **'Claude 模式'**
  String get claudeMode;

  /// No description provided for @claudeModeDesc.
  ///
  /// In zh, this message translates to:
  /// **'使用 Anthropic API 格式'**
  String get claudeModeDesc;

  /// No description provided for @attachments.
  ///
  /// In zh, this message translates to:
  /// **'附件'**
  String get attachments;

  /// No description provided for @addAttachment.
  ///
  /// In zh, this message translates to:
  /// **'添加附件'**
  String get addAttachment;

  /// No description provided for @noAttachments.
  ///
  /// In zh, this message translates to:
  /// **'暂无附件'**
  String get noAttachments;

  /// No description provided for @deleteAttachment.
  ///
  /// In zh, this message translates to:
  /// **'删除附件'**
  String get deleteAttachment;

  /// No description provided for @deleteAttachmentConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除这个附件吗？'**
  String get deleteAttachmentConfirm;

  /// No description provided for @attachmentPhoto.
  ///
  /// In zh, this message translates to:
  /// **'照片'**
  String get attachmentPhoto;

  /// No description provided for @attachmentVideo.
  ///
  /// In zh, this message translates to:
  /// **'视频'**
  String get attachmentVideo;

  /// No description provided for @attachmentFile.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get attachmentFile;

  /// No description provided for @attachmentAdded.
  ///
  /// In zh, this message translates to:
  /// **'附件已添加'**
  String get attachmentAdded;

  /// No description provided for @attachmentDeleted.
  ///
  /// In zh, this message translates to:
  /// **'附件已删除'**
  String get attachmentDeleted;

  /// No description provided for @attachmentAddFailed.
  ///
  /// In zh, this message translates to:
  /// **'添加附件失败'**
  String get attachmentAddFailed;

  /// No description provided for @storageUsed.
  ///
  /// In zh, this message translates to:
  /// **'已用空间'**
  String get storageUsed;

  /// No description provided for @clearAttachmentCache.
  ///
  /// In zh, this message translates to:
  /// **'清除附件缓存'**
  String get clearAttachmentCache;

  /// No description provided for @attachmentCacheCleared.
  ///
  /// In zh, this message translates to:
  /// **'附件缓存已清除'**
  String get attachmentCacheCleared;

  /// No description provided for @relatedInspirations.
  ///
  /// In zh, this message translates to:
  /// **'相关灵感'**
  String get relatedInspirations;

  /// No description provided for @hierarchyRelations.
  ///
  /// In zh, this message translates to:
  /// **'层级关系'**
  String get hierarchyRelations;

  /// No description provided for @parentInspirations.
  ///
  /// In zh, this message translates to:
  /// **'上级灵感'**
  String get parentInspirations;

  /// No description provided for @childInspirations.
  ///
  /// In zh, this message translates to:
  /// **'下级灵感'**
  String get childInspirations;

  /// No description provided for @noRelatedInspirations.
  ///
  /// In zh, this message translates to:
  /// **'暂无相关灵感'**
  String get noRelatedInspirations;

  /// No description provided for @noHierarchyRelations.
  ///
  /// In zh, this message translates to:
  /// **'还没有建立层级关系'**
  String get noHierarchyRelations;

  /// No description provided for @discoverRelations.
  ///
  /// In zh, this message translates to:
  /// **'AI 发现关联'**
  String get discoverRelations;

  /// No description provided for @addRelation.
  ///
  /// In zh, this message translates to:
  /// **'添加关联'**
  String get addRelation;

  /// No description provided for @addParentInspiration.
  ///
  /// In zh, this message translates to:
  /// **'添加上级灵感'**
  String get addParentInspiration;

  /// No description provided for @addChildInspiration.
  ///
  /// In zh, this message translates to:
  /// **'添加下级灵感'**
  String get addChildInspiration;

  /// No description provided for @unlinkRelation.
  ///
  /// In zh, this message translates to:
  /// **'解除关系'**
  String get unlinkRelation;

  /// No description provided for @relationRemoved.
  ///
  /// In zh, this message translates to:
  /// **'关系已解除'**
  String get relationRemoved;

  /// No description provided for @undo.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get undo;

  /// No description provided for @linkTypeSimilar.
  ///
  /// In zh, this message translates to:
  /// **'相似'**
  String get linkTypeSimilar;

  /// No description provided for @linkTypeCausal.
  ///
  /// In zh, this message translates to:
  /// **'因果'**
  String get linkTypeCausal;

  /// No description provided for @linkTypeComplementary.
  ///
  /// In zh, this message translates to:
  /// **'互补'**
  String get linkTypeComplementary;

  /// No description provided for @linkTypeOpposite.
  ///
  /// In zh, this message translates to:
  /// **'对立'**
  String get linkTypeOpposite;

  /// No description provided for @linkTypeParentChild.
  ///
  /// In zh, this message translates to:
  /// **'层级'**
  String get linkTypeParentChild;

  /// No description provided for @parentRole.
  ///
  /// In zh, this message translates to:
  /// **'上级'**
  String get parentRole;

  /// No description provided for @childRole.
  ///
  /// In zh, this message translates to:
  /// **'子灵感'**
  String get childRole;

  /// No description provided for @currentAsParent.
  ///
  /// In zh, this message translates to:
  /// **'设为下级'**
  String get currentAsParent;

  /// No description provided for @currentAsChild.
  ///
  /// In zh, this message translates to:
  /// **'设为上级'**
  String get currentAsChild;

  /// No description provided for @currentAsParentDesc.
  ///
  /// In zh, this message translates to:
  /// **'把选中的灵感作为当前灵感的下级'**
  String get currentAsParentDesc;

  /// No description provided for @currentAsChildDesc.
  ///
  /// In zh, this message translates to:
  /// **'把选中的灵感作为当前灵感的上级'**
  String get currentAsChildDesc;

  /// No description provided for @parentRelationDesc.
  ///
  /// In zh, this message translates to:
  /// **'当前灵感的上级'**
  String get parentRelationDesc;

  /// No description provided for @childRelationDesc.
  ///
  /// In zh, this message translates to:
  /// **'当前灵感的下级'**
  String get childRelationDesc;

  /// No description provided for @relationLabelGeneral.
  ///
  /// In zh, this message translates to:
  /// **'层级'**
  String get relationLabelGeneral;

  /// No description provided for @relationLabelBelongsTo.
  ///
  /// In zh, this message translates to:
  /// **'归属'**
  String get relationLabelBelongsTo;

  /// No description provided for @relationLabelBreakdown.
  ///
  /// In zh, this message translates to:
  /// **'拆解'**
  String get relationLabelBreakdown;

  /// No description provided for @relationLabelSupports.
  ///
  /// In zh, this message translates to:
  /// **'支撑'**
  String get relationLabelSupports;

  /// No description provided for @relationLabelExtends.
  ///
  /// In zh, this message translates to:
  /// **'延伸'**
  String get relationLabelExtends;

  /// No description provided for @relationLabelHintBelongsTo.
  ///
  /// In zh, this message translates to:
  /// **'适合主题、分类、领域归属'**
  String get relationLabelHintBelongsTo;

  /// No description provided for @relationLabelHintBreakdown.
  ///
  /// In zh, this message translates to:
  /// **'适合问题拆分、步骤拆解'**
  String get relationLabelHintBreakdown;

  /// No description provided for @relationLabelHintSupports.
  ///
  /// In zh, this message translates to:
  /// **'适合证据、理由、支撑材料'**
  String get relationLabelHintSupports;

  /// No description provided for @relationLabelHintExtends.
  ///
  /// In zh, this message translates to:
  /// **'适合后续想法、衍生方向'**
  String get relationLabelHintExtends;

  /// No description provided for @noLinkableInspirations.
  ///
  /// In zh, this message translates to:
  /// **'没有可关联的灵感'**
  String get noLinkableInspirations;

  /// No description provided for @relationAlreadyExists.
  ///
  /// In zh, this message translates to:
  /// **'关联已存在'**
  String get relationAlreadyExists;

  /// No description provided for @parentChildCycleBlocked.
  ///
  /// In zh, this message translates to:
  /// **'不能创建成环的父子关系'**
  String get parentChildCycleBlocked;

  /// No description provided for @knowledgeGraph.
  ///
  /// In zh, this message translates to:
  /// **'知识图谱'**
  String get knowledgeGraph;

  /// No description provided for @knowledgeGraphDesc.
  ///
  /// In zh, this message translates to:
  /// **'查看灵感之间的关联网络'**
  String get knowledgeGraphDesc;

  /// No description provided for @noInspirationsForGraph.
  ///
  /// In zh, this message translates to:
  /// **'灵感数量不足，无法生成图谱'**
  String get noInspirationsForGraph;

  /// No description provided for @dailyReview.
  ///
  /// In zh, this message translates to:
  /// **'每日回顾'**
  String get dailyReview;

  /// No description provided for @dailyReviewDesc.
  ///
  /// In zh, this message translates to:
  /// **'整理今天需要跟进的灵感'**
  String get dailyReviewDesc;

  /// No description provided for @allReviewed.
  ///
  /// In zh, this message translates to:
  /// **'全部已回顾'**
  String get allReviewed;

  /// No description provided for @allReviewedDesc.
  ///
  /// In zh, this message translates to:
  /// **'所有灵感都已回顾，明天再来吧！'**
  String get allReviewedDesc;

  /// No description provided for @markReviewed.
  ///
  /// In zh, this message translates to:
  /// **'已回顾'**
  String get markReviewed;

  /// No description provided for @markFollowUp.
  ///
  /// In zh, this message translates to:
  /// **'需要跟进'**
  String get markFollowUp;

  /// No description provided for @followingUp.
  ///
  /// In zh, this message translates to:
  /// **'跟进中'**
  String get followingUp;

  /// No description provided for @weeklyReport.
  ///
  /// In zh, this message translates to:
  /// **'周报'**
  String get weeklyReport;

  /// No description provided for @weeklyReportDesc.
  ///
  /// In zh, this message translates to:
  /// **'汇总近期灵感与进展'**
  String get weeklyReportDesc;

  /// No description provided for @monthlyReport.
  ///
  /// In zh, this message translates to:
  /// **'月报'**
  String get monthlyReport;

  /// No description provided for @generateReport.
  ///
  /// In zh, this message translates to:
  /// **'生成报告'**
  String get generateReport;

  /// No description provided for @generatingReport.
  ///
  /// In zh, this message translates to:
  /// **'生成报告中...'**
  String get generatingReport;

  /// No description provided for @reportReady.
  ///
  /// In zh, this message translates to:
  /// **'报告已生成'**
  String get reportReady;

  /// No description provided for @noInspirationsForReport.
  ///
  /// In zh, this message translates to:
  /// **'暂无灵感记录'**
  String get noInspirationsForReport;

  /// No description provided for @insights.
  ///
  /// In zh, this message translates to:
  /// **'AI 洞察'**
  String get insights;

  /// No description provided for @insightsDesc.
  ///
  /// In zh, this message translates to:
  /// **'发现灵感里的趋势和线索'**
  String get insightsDesc;

  /// No description provided for @generatingInsights.
  ///
  /// In zh, this message translates to:
  /// **'分析中...'**
  String get generatingInsights;

  /// No description provided for @noInspirationsForInsights.
  ///
  /// In zh, this message translates to:
  /// **'灵感数量不足，暂无洞察'**
  String get noInspirationsForInsights;

  /// No description provided for @regenerate.
  ///
  /// In zh, this message translates to:
  /// **'重新生成'**
  String get regenerate;

  /// No description provided for @aboutDescription.
  ///
  /// In zh, this message translates to:
  /// **'闪念是一个面向灵感捕捉、整理和项目推进的本地优先工具。更新功能会从 GitHub Releases 获取正式版本。'**
  String get aboutDescription;

  /// No description provided for @aboutCurrentVersion.
  ///
  /// In zh, this message translates to:
  /// **'当前版本'**
  String get aboutCurrentVersion;

  /// No description provided for @aboutCheckUpdates.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get aboutCheckUpdates;

  /// No description provided for @aboutCheckUpdatesDesc.
  ///
  /// In zh, this message translates to:
  /// **'立即检查 GitHub Release 是否有可安装的新版本。'**
  String get aboutCheckUpdatesDesc;

  /// No description provided for @aboutAutoCheckUpdates.
  ///
  /// In zh, this message translates to:
  /// **'自动检查更新'**
  String get aboutAutoCheckUpdates;

  /// No description provided for @aboutAutoCheckUpdatesDesc.
  ///
  /// In zh, this message translates to:
  /// **'开启后每次启动会自动检查新版本，并按设备架构选择安装包。'**
  String get aboutAutoCheckUpdatesDesc;

  /// No description provided for @aboutOpenSource.
  ///
  /// In zh, this message translates to:
  /// **'开放源代码'**
  String get aboutOpenSource;

  /// No description provided for @aboutReleases.
  ///
  /// In zh, this message translates to:
  /// **'发布记录'**
  String get aboutReleases;

  /// No description provided for @aboutReleasesDesc.
  ///
  /// In zh, this message translates to:
  /// **'查看版本说明与历史安装包。'**
  String get aboutReleasesDesc;

  /// No description provided for @aboutAlreadyLatest.
  ///
  /// In zh, this message translates to:
  /// **'当前已是最新版本。'**
  String get aboutAlreadyLatest;

  /// No description provided for @aboutCheckFailed.
  ///
  /// In zh, this message translates to:
  /// **'检查更新失败'**
  String get aboutCheckFailed;

  /// No description provided for @userBackground.
  ///
  /// In zh, this message translates to:
  /// **'个人背景'**
  String get userBackground;

  /// No description provided for @userBackgroundDesc.
  ///
  /// In zh, this message translates to:
  /// **'向 AI 说明你的职业与主要工作，AI 才能结合背景更好地协助你。'**
  String get userBackgroundDesc;

  /// No description provided for @editBackground.
  ///
  /// In zh, this message translates to:
  /// **'编辑背景'**
  String get editBackground;

  /// No description provided for @backgroundHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：我是一名产品经理，专注 AI 工具，常思考用户增长与新手引导。'**
  String get backgroundHint;

  /// No description provided for @backgroundSaved.
  ///
  /// In zh, this message translates to:
  /// **'背景已保存'**
  String get backgroundSaved;

  /// No description provided for @globalChat.
  ///
  /// In zh, this message translates to:
  /// **'AI 助手'**
  String get globalChat;

  /// No description provided for @globalChatDesc.
  ///
  /// In zh, this message translates to:
  /// **'与了解你的背景、灵感与项目的助手对话。'**
  String get globalChatDesc;

  /// No description provided for @openGlobalChat.
  ///
  /// In zh, this message translates to:
  /// **'打开 AI 助手'**
  String get openGlobalChat;

  /// No description provided for @clearGlobalChat.
  ///
  /// In zh, this message translates to:
  /// **'清空对话'**
  String get clearGlobalChat;

  /// No description provided for @clearGlobalChatConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定清空全部对话历史吗？'**
  String get clearGlobalChatConfirm;

  /// No description provided for @predictiveBack.
  ///
  /// In zh, this message translates to:
  /// **'预测式返回手势'**
  String get predictiveBack;

  /// No description provided for @predictiveBackDesc.
  ///
  /// In zh, this message translates to:
  /// **'从屏幕左侧边缘滑动时预览返回目标，需要 Android 13 及以上'**
  String get predictiveBackDesc;

  /// No description provided for @shareSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存到灵感'**
  String get shareSaved;

  /// No description provided for @sharePartialFailure.
  ///
  /// In zh, this message translates to:
  /// **'已保存，但有 {count} 个附件读取失败'**
  String sharePartialFailure(int count);

  /// No description provided for @shareEmpty.
  ///
  /// In zh, this message translates to:
  /// **'分享内容为空，未保存'**
  String get shareEmpty;

  /// No description provided for @shareFailed.
  ///
  /// In zh, this message translates to:
  /// **'分享内容保存失败'**
  String get shareFailed;

  /// No description provided for @sharedImageContent.
  ///
  /// In zh, this message translates to:
  /// **'分享的图片'**
  String get sharedImageContent;

  /// No description provided for @hotkeyRegistrationFailed.
  ///
  /// In zh, this message translates to:
  /// **'全局热键注册失败，可能已被其他应用占用'**
  String get hotkeyRegistrationFailed;
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
    'that was used.',
  );
}

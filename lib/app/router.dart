import 'package:flashnote/presentation/pages/home/home_page.dart';
import 'package:flashnote/presentation/pages/inspiration/ai_analysis_page.dart';
import 'package:flashnote/presentation/pages/inspiration/ai_chat_page.dart';
import 'package:flashnote/presentation/pages/inspiration/capture_page.dart';
import 'package:flashnote/presentation/pages/inspiration/daily_review_page.dart';
import 'package:flashnote/presentation/pages/inspiration/inspiration_detail_page.dart';
import 'package:flashnote/presentation/pages/inspiration/inspiration_list_page.dart';
import 'package:flashnote/presentation/pages/inspiration/knowledge_graph_page.dart';
import 'package:flashnote/presentation/pages/inspiration/mind_map_page.dart';
import 'package:flashnote/presentation/pages/inspiration/report_page.dart';
import 'package:flashnote/presentation/pages/project/create_project_page.dart';
import 'package:flashnote/presentation/pages/project/project_detail_page.dart';
import 'package:flashnote/presentation/pages/project/project_list_page.dart';
import 'package:flashnote/presentation/pages/settings/about_app_page.dart';
import 'package:flashnote/presentation/pages/settings/settings_page.dart';
import 'package:flashnote/presentation/pages/settings/source_management_page.dart';
import 'package:flashnote/presentation/pages/settings/theme_color_page.dart';
import 'package:flashnote/presentation/pages/settings/webdav_settings_page.dart';
import 'package:flashnote/presentation/widgets/shell_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => ShellPage(child: child),
      routes: [
        GoRoute(
          path: '/',
          pageBuilder:
              (context, state) => const NoTransitionPage(child: HomePage()),
        ),
        GoRoute(
          path: '/inspirations',
          pageBuilder:
              (context, state) =>
                  const NoTransitionPage(child: InspirationListPage()),
        ),
        GoRoute(
          path: '/projects',
          pageBuilder:
              (context, state) =>
                  const NoTransitionPage(child: ProjectListPage()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder:
              (context, state) => const NoTransitionPage(child: SettingsPage()),
        ),
      ],
    ),
    GoRoute(
      path: '/inspiration/new',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const CapturePage(),
    ),
    GoRoute(
      path: '/inspiration/:id',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return InspirationDetailPage(id: id);
      },
      routes: [
        GoRoute(
          path: 'edit',
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            return CapturePage(editId: id);
          },
        ),
        GoRoute(
          path: 'ai-analysis',
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            final content = state.extra as String? ?? '';
            return AiAnalysisPage(inspirationId: id, content: content);
          },
        ),
        GoRoute(
          path: 'mind-map',
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            final content = state.extra as String? ?? '';
            return MindMapPage(inspirationId: id, content: content);
          },
        ),
        GoRoute(
          path: 'chat',
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            final content = state.extra as String? ?? '';
            return AiChatPage(inspirationId: id, content: content);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/settings/sources',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const SourceManagementPage(),
    ),
    GoRoute(
      path: '/settings/webdav',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const WebDavSettingsPage(),
    ),
    GoRoute(
      path: '/settings/theme-color',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const ThemeColorPage(),
    ),
    GoRoute(
      path: '/settings/about',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const AboutAppPage(),
    ),
    GoRoute(
      path: '/knowledge-graph',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const KnowledgeGraphPage(),
    ),
    GoRoute(
      path: '/daily-review',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const DailyReviewPage(),
    ),
    GoRoute(
      path: '/report/weekly',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const ReportPage(type: ReportType.weekly),
    ),
    GoRoute(
      path: '/report/monthly',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const ReportPage(type: ReportType.monthly),
    ),
    GoRoute(
      path: '/report/insights',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const ReportPage(type: ReportType.insights),
    ),
    GoRoute(
      path: '/project/new',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const CreateProjectPage(),
    ),
    GoRoute(
      path: '/project/:id',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return ProjectDetailPage(projectId: id);
      },
      routes: [
        GoRoute(
          path: 'edit',
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            return CreateProjectPage(projectId: id);
          },
        ),
      ],
    ),
  ],
);

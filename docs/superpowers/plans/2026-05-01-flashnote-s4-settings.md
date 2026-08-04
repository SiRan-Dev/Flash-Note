# FlashNote S4: 设置/主题/数据管理 实施计划

**Goal:** 完成 v1.0 功能，实现主题切换、数据导入导出、来源管理、完整设置页。

---

## Task 1: 依赖添加 + i18n 扩展

- [ ] 添加 `file_picker`、`dynamic_color`、`url_launcher` 依赖
- [ ] 添加 S4 i18n key（主题、数据管理、来源管理相关）

## Task 2: 主题系统

- [ ] 添加 ThemeMode Provider（light/dark/system）
- [ ] 更新 app_theme.dart 支持 dynamic_color
- [ ] 更新 app.dart 使用 themeMode provider

## Task 3: 数据导出

- [ ] 创建 DataExportService（导出全部数据为 JSON）
- [ ] 在设置页添加导出按钮

## Task 4: 数据导入

- [ ] 在 DataExportService 中添加导入方法
- [ ] 在设置页添加导入按钮（带确认对话框）

## Task 5: 来源管理

- [ ] 创建来源管理页面（CRUD，内置来源不可删除）
- [ ] 在设置页添加来源管理入口

## Task 6: 完整设置页

- [ ] 重写设置页，整合所有功能区块

## Task 7: 全量测试与验证

- [ ] 代码生成、测试、分析、编译

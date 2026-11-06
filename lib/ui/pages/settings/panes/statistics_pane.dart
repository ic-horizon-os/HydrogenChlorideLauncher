import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;

import '../../../../core/services/stats_service.dart';
import '../../../../core/utils/format.dart';
import '../../../../state/app_scope.dart';
import '../../../../state/app_state.dart';
import '../../../../theme/fluent_theme.dart';
import '../../../widgets/charts.dart';
import '../../../widgets/fluent_widgets.dart';
import '../../../widgets/hcl_combo_box.dart';
import '../settings_widgets.dart';

class StatisticsPane extends StatelessWidget {
  const StatisticsPane({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    final FluentPalette palette = FluentColors.of(context).palette;
    final StatsSummary summary = app.statsSummary;
    final StatsFilter filter = app.statsFilter;
    final bool empty = summary.sessionCount == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SettingsPaneHeader(
          title: '统计信息',
          description: '运行时长与分布。数据来自本地会话记录。',
          trailing: null,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            SettingsSegmented<StatsKindFilter>(
              selected: filter.kind,
              options: const <SegmentOption<StatsKindFilter>>[
                SegmentOption<StatsKindFilter>(
                  value: StatsKindFilter.all,
                  label: '全部',
                ),
                SegmentOption<StatsKindFilter>(
                  value: StatsKindFilter.games,
                  label: '游戏',
                ),
                SegmentOption<StatsKindFilter>(
                  value: StatsKindFilter.utilities,
                  label: '实用软件',
                ),
              ],
              onSelected: (StatsKindFilter kind) =>
                  app.setStatsFilter(filter.copyWith(kind: kind)),
            ),
            _FilterMenu(
              label: '加载器',
              value: filter.loader ?? '全部',
              options: const <String>[
                '全部',
                'Vanilla',
                'Fabric',
                'Forge',
                'NeoForge',
              ],
              onSelected: (String value) => app.setStatsFilter(
                filter.copyWith(loader: value == '全部' ? null : value),
              ),
            ),
            _FilterMenu(
              label: '版本区间',
              value: switch (filter.era) {
                StatsEraFilter.all => '全部',
                StatsEraFilter.legacy => '1.12 及以前',
                StatsEraFilter.modern => '1.17 及以后',
              },
              options: const <String>['全部', '1.12 及以前', '1.17 及以后'],
              onSelected: (String value) => app.setStatsFilter(
                filter.copyWith(
                  era: switch (value) {
                    '1.12 及以前' => StatsEraFilter.legacy,
                    '1.17 及以后' => StatsEraFilter.modern,
                    _ => StatsEraFilter.all,
                  },
                ),
              ),
            ),
            FluentButton(
              label: '重置筛选',
              icon: Icons.filter_alt_off_outlined,
              dense: true,
              style: FluentButtonStyle.ghost,
              onPressed: () => app.setStatsFilter(const StatsFilter()),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (empty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: EmptyState(
              icon: Icons.insights_outlined,
              title: '当前筛选没有会话记录',
              message: '启动一个条目后停止，或打开演示数据。',
              action: app.settings.demoData
                  ? FluentButton(
                      label: '清除筛选',
                      icon: Icons.refresh,
                      style: FluentButtonStyle.primary,
                      onPressed: () => app.setStatsFilter(const StatsFilter()),
                    )
                  : FluentButton(
                      label: '开启演示数据',
                      icon: Icons.science_outlined,
                      style: FluentButtonStyle.primary,
                      onPressed: () => app.setDemoData(true),
                    ),
            ),
          )
        else ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _SummaryCard(
                  label: '总时长',
                  value: formatDuration(summary.total, compact: true),
                  icon: Icons.schedule,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryCard(
                  label: '最近 7 天',
                  value: formatDuration(summary.weekTotal, compact: true),
                  icon: Icons.calendar_today_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryCard(
                  label: '会话数',
                  value: '${summary.sessionCount}',
                  icon: Icons.repeat,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryCard(
                  label: '平均会话',
                  value: formatDuration(summary.averageSession, compact: true),
                  icon: Icons.timelapse,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget pie = _ChartCard(
                title: '使用时长分布',
                subtitle: '按游戏与实用软件分类',
                child: Row(
                  children: <Widget>[
                    DurationPieChart(data: summary.byCategory, size: 172),
                    const SizedBox(width: 18),
                    Expanded(
                      child: ChartLegend(data: summary.byCategory, maxItems: 4),
                    ),
                  ],
                ),
              );
              final Widget loaders = _ChartCard(
                title: 'Minecraft 加载器分布',
                subtitle: '原版、Fabric、Forge 与 NeoForge',
                child: Row(
                  children: <Widget>[
                    DurationPieChart(
                      data: summary.byLoader,
                      size: 172,
                      centerLabel: 'Minecraft',
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: ChartLegend(data: summary.byLoader, maxItems: 4),
                    ),
                  ],
                ),
              );
              if (constraints.maxWidth >= 820) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: pie),
                    const SizedBox(width: 12),
                    Expanded(child: loaders),
                  ],
                );
              }
              return Column(
                children: <Widget>[pie, const SizedBox(height: 12), loaders],
              );
            },
          ),
          const SizedBox(height: 14),
          _ChartCard(
            title: '应用时长排行',
            subtitle: '按累计运行时长排序，最多显示 8 项',
            child: DurationBarChart(data: summary.byApp, maxItems: 8),
          ),
          const SizedBox(height: 14),
          _ChartCard(
            title: '最近 14 天',
            subtitle: '每日累计运行时长',
            child: DurationLineChart(daily: summary.byDay, height: 180),
          ),
          const SizedBox(height: 14),
          const SettingsBanner(
            message: '统计来自已结束的会话记录。关闭演示数据后，只显示实际运行过的条目。',
            icon: Icons.analytics_outlined,
          ),
          const SizedBox(height: 6),
          Text(
            '数据文件：${app.paths.sessionsFile.path}',
            style: TextStyle(color: palette.textTertiary, fontSize: 10),
          ),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return Card(
      padding: const EdgeInsets.all(14),
      margin: EdgeInsets.zero,
      backgroundColor: palette.surface,
      borderRadius: BorderRadius.circular(FluentTokens.radius),
      borderColor: palette.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 13, color: palette.textTertiary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: palette.textTertiary, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return Card(
      padding: const EdgeInsets.all(18),
      margin: EdgeInsets.zero,
      backgroundColor: palette.surface,
      borderRadius: BorderRadius.circular(FluentTokens.radiusLarge),
      borderColor: palette.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(color: palette.textTertiary, fontSize: 10.5),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final FluentPalette palette = FluentColors.of(context).palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '$label：',
          style: TextStyle(color: palette.textSecondary, fontSize: 11.5),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 128,
          child: HclComboBox<String>(
            value: value,
            items: options
                .map(
                  (String option) =>
                      ComboBoxItem<String>(value: option, child: Text(option)),
                )
                .toList(growable: false),
            onChanged: (String? next) {
              if (next != null) onSelected(next);
            },
          ),
        ),
      ],
    );
  }
}

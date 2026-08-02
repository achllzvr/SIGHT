import 'package:flutter/material.dart';

import '../../services/active_child_context_service.dart';
import '../../theme/lumi_theme.dart';
import 'guardian/child_dashboard/limits_tab.dart';
import 'guardian/child_dashboard/overview_tab.dart';
import 'guardian/child_dashboard/settings_tab.dart';
import 'guardian/child_dashboard/share_tab.dart';

class GuardianChildDashboardScreen extends StatefulWidget {
  final int? childId;

  const GuardianChildDashboardScreen({
    super.key,
    this.childId,
  });

  @override
  State<GuardianChildDashboardScreen> createState() => _GuardianChildDashboardScreenState();
}

class _GuardianChildDashboardScreenState extends State<GuardianChildDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    if (widget.childId != null) {
      ActiveChildContextService.instance.setActiveChildId(widget.childId!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LumiColors.scaffoldMint,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: LumiColors.textDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: LumiColors.primaryPurple),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          LumiTheme.caps('Child Dashboard'),
          style: LumiTheme.joyful(20, color: LumiColors.primaryPurple),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Container(
            margin: const EdgeInsets.fromLTRB(LumiSpacing.md, 0, LumiSpacing.md, LumiSpacing.sm),
            decoration: BoxDecoration(
              color: LumiColors.primaryLight,
              borderRadius: BorderRadius.circular(LumiRadii.pill),
              border: Border.all(color: LumiColors.secondaryLight, width: ArcadeSizes.badgeBorder),
              boxShadow: LumiShadows.badge(LumiColors.secondaryLight),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              labelColor: LumiColors.primaryPurple,
              unselectedLabelColor: LumiColors.textMuted,
              indicator: BoxDecoration(
                color: LumiColors.secondaryPurple,
                borderRadius: BorderRadius.circular(LumiRadii.pill),
                border: Border.all(color: LumiColors.primaryPurple, width: 3),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              dividerHeight: 0,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              labelStyle: LumiTheme.clanMedium(13, color: LumiColors.primaryPurple, letterSpacing: 0.6),
              unselectedLabelStyle: LumiTheme.clanRegular(13, color: LumiColors.textMuted, letterSpacing: 0.6),
              labelPadding: const EdgeInsets.symmetric(horizontal: LumiSpacing.md),
              tabs: const [
                Tab(text: 'OVERVIEW'),
                Tab(text: 'LIMITS'),
                Tab(text: 'SHARE'),
                Tab(text: 'SETTINGS'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ChildDashboardOverviewTab(childId: widget.childId),
          ChildDashboardLimitsTab(childId: widget.childId),
          ChildDashboardShareTab(childId: widget.childId),
          ChildDashboardSettingsTab(childId: widget.childId),
        ],
      ),
    );
  }
}

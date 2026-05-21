import 'package:declarative_nav/declarative_nav.dart';
import 'package:flutter/material.dart';

enum HankoAppTab { design, mySeals, stones }

class HankoTabDefinition {
  const HankoTabDefinition({
    required this.tab,
    required this.rootKey,
    required this.rootName,
  });

  final HankoAppTab tab;
  final String rootKey;
  final String rootName;

  PageEntry get rootPage => PageEntry(key: rootKey, name: rootName);
}

typedef HankoTabPageBuilder =
    Widget Function(BuildContext context, HankoAppTab tab, PageEntry page);

typedef HankoBottomNavigationBuilder =
    Widget Function(
      BuildContext context,
      int selectedIndex,
      ValueChanged<int> onSelected,
    );

class HankoTabNavigationShell extends StatefulWidget {
  const HankoTabNavigationShell({
    super.key,
    required this.tabs,
    required this.buildPage,
    required this.buildBottomNavigation,
  }) : assert(tabs.length > 0);

  final List<HankoTabDefinition> tabs;
  final HankoTabPageBuilder buildPage;
  final HankoBottomNavigationBuilder buildBottomNavigation;

  @override
  State<HankoTabNavigationShell> createState() =>
      _HankoTabNavigationShellState();
}

class _HankoTabNavigationShellState extends State<HankoTabNavigationShell> {
  late HankoAppTab _currentTab;
  late Map<HankoAppTab, List<PageEntry>> _pagesByTab;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.tabs.first.tab;
    _pagesByTab = {
      for (final tab in widget.tabs) tab.tab: [tab.rootPage],
    };
  }

  @override
  void didUpdateWidget(covariant HankoTabNavigationShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextTabs = widget.tabs.map((tab) => tab.tab).toSet();
    if (!nextTabs.contains(_currentTab)) {
      _currentTab = widget.tabs.first.tab;
    }
    _pagesByTab = {
      for (final tab in widget.tabs)
        tab.tab: _pagesByTab[tab.tab] ?? [tab.rootPage],
    };
  }

  int get _currentIndex {
    final index = widget.tabs.indexWhere((tab) => tab.tab == _currentTab);
    return index < 0 ? 0 : index;
  }

  void _setPagesForTab(HankoAppTab tab, List<PageEntry> pages) {
    if (pages.isEmpty) {
      return;
    }
    setState(() {
      _pagesByTab = {..._pagesByTab, tab: List.unmodifiable(pages)};
    });
  }

  void _selectTabIndex(int index) {
    final nextTab = widget.tabs[index].tab;
    if (nextTab == _currentTab) {
      final pages = _pagesByTab[nextTab] ?? const <PageEntry>[];
      if (pages.length > 1) {
        _setPagesForTab(nextTab, [pages.first]);
      }
      return;
    }
    setState(() => _currentTab = nextTab);
  }

  void _popCurrentTabPage() {
    final pages = _pagesByTab[_currentTab] ?? const <PageEntry>[];
    if (pages.length <= 1) {
      return;
    }
    _setPagesForTab(_currentTab, pages.sublist(0, pages.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final safeIndex = _currentIndex;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        final pages = _pagesByTab[_currentTab] ?? const <PageEntry>[];
        if (pages.length > 1) {
          _popCurrentTabPage();
          return;
        }
        if (safeIndex != 0) {
          setState(() => _currentTab = widget.tabs.first.tab);
        }
      },
      child: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: safeIndex,
              children: [
                for (final tab in widget.tabs) _buildNavigatorForTab(tab),
              ],
            ),
          ),
          widget.buildBottomNavigation(context, safeIndex, _selectTabIndex),
        ],
      ),
    );
  }

  Widget _buildNavigatorForTab(HankoTabDefinition tab) {
    final pages = _pagesByTab[tab.tab] ?? [tab.rootPage];
    return DeclarativePagesNavigator(
      pages: pages,
      buildPage: (context, page) => widget.buildPage(context, tab.tab, page),
      onPopTop: () {
        final currentPages = _pagesByTab[tab.tab] ?? const <PageEntry>[];
        if (currentPages.length <= 1) {
          return;
        }
        _setPagesForTab(
          tab.tab,
          currentPages.sublist(0, currentPages.length - 1),
        );
      },
    );
  }
}

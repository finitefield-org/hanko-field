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
    Widget Function(
      BuildContext context,
      HankoAppTab tab,
      PageEntry page,
      HankoTabStackController stack,
    );

typedef HankoBottomNavigationBuilder =
    Widget Function(
      BuildContext context,
      int selectedIndex,
      ValueChanged<int> onSelected,
    );

class HankoTabStackController {
  const HankoTabStackController._({
    required List<PageEntry> Function() readPages,
    required void Function(PageEntry page) pushPage,
    required void Function(PageEntry page) replaceTopPage,
    required VoidCallback popPage,
    required VoidCallback popToRootPage,
    required void Function(HankoAppTab tab) selectTab,
  }) : _readPages = readPages,
       _pushPage = pushPage,
       _replaceTopPage = replaceTopPage,
       _popPage = popPage,
       _popToRootPage = popToRootPage,
       _selectTab = selectTab;

  final List<PageEntry> Function() _readPages;
  final void Function(PageEntry page) _pushPage;
  final void Function(PageEntry page) _replaceTopPage;
  final VoidCallback _popPage;
  final VoidCallback _popToRootPage;
  final void Function(HankoAppTab tab) _selectTab;

  List<PageEntry> get pages => _readPages();

  void push(PageEntry page) => _pushPage(page);

  void replaceTop(PageEntry page) => _replaceTopPage(page);

  void pop() => _popPage();

  void popToRoot() => _popToRootPage();

  void selectTab(HankoAppTab tab) => _selectTab(tab);
}

class HankoTabNavigationShell extends StatefulWidget {
  const HankoTabNavigationShell({
    super.key,
    required this.tabs,
    required this.buildPage,
    required this.buildBottomNavigation,
    this.selectedTab,
    this.selectedTabPages,
  }) : assert(tabs.length > 0);

  final List<HankoTabDefinition> tabs;
  final HankoTabPageBuilder buildPage;
  final HankoBottomNavigationBuilder buildBottomNavigation;
  final HankoAppTab? selectedTab;
  final List<PageEntry>? selectedTabPages;

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
    final selectedTab = widget.selectedTab;
    _currentTab =
        selectedTab != null && widget.tabs.any((tab) => tab.tab == selectedTab)
        ? selectedTab
        : widget.tabs.first.tab;
    _pagesByTab = {
      for (final tab in widget.tabs) tab.tab: [tab.rootPage],
    };
    final selectedPages = widget.selectedTabPages;
    if (selectedTab != null &&
        selectedPages != null &&
        selectedPages.isNotEmpty) {
      _pagesByTab[selectedTab] = List.unmodifiable(selectedPages);
    }
  }

  @override
  void didUpdateWidget(covariant HankoTabNavigationShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextTabs = widget.tabs.map((tab) => tab.tab).toSet();
    if (!nextTabs.contains(_currentTab)) {
      _currentTab = widget.tabs.first.tab;
    }
    final selectedTab = widget.selectedTab;
    if (selectedTab != null &&
        nextTabs.contains(selectedTab) &&
        selectedTab != _currentTab) {
      _currentTab = selectedTab;
    }
    final pagesByTab = {
      for (final tab in widget.tabs)
        tab.tab: _pagesByTab[tab.tab] ?? [tab.rootPage],
    };
    if (selectedTab != null && nextTabs.contains(selectedTab)) {
      final selectedDefinition = widget.tabs.firstWhere(
        (tab) => tab.tab == selectedTab,
      );
      final selectedPages = widget.selectedTabPages;
      pagesByTab[selectedTab] =
          selectedPages != null && selectedPages.isNotEmpty
          ? List.unmodifiable(selectedPages)
          : [selectedDefinition.rootPage];
    }
    _pagesByTab = pagesByTab;
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
    _selectTab(nextTab);
  }

  void _selectTab(HankoAppTab nextTab) {
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

  HankoTabStackController _stackControllerForTab(HankoTabDefinition tab) {
    List<PageEntry> readPages() {
      return _pagesByTab[tab.tab] ?? [tab.rootPage];
    }

    return HankoTabStackController._(
      readPages: readPages,
      pushPage: (page) {
        final pages = readPages();
        if (pages.isNotEmpty && pages.last.key == page.key) {
          return;
        }
        _setPagesForTab(tab.tab, [...pages, page]);
      },
      replaceTopPage: (page) {
        final pages = readPages();
        if (pages.isEmpty) {
          _setPagesForTab(tab.tab, [page]);
          return;
        }
        _setPagesForTab(tab.tab, [...pages.take(pages.length - 1), page]);
      },
      popPage: () {
        final pages = readPages();
        if (pages.length <= 1) {
          return;
        }
        _setPagesForTab(tab.tab, pages.sublist(0, pages.length - 1));
      },
      popToRootPage: () {
        final pages = readPages();
        if (pages.length <= 1) {
          return;
        }
        _setPagesForTab(tab.tab, [pages.first]);
      },
      selectTab: _selectTab,
    );
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
    final stack = _stackControllerForTab(tab);
    return DeclarativePagesNavigator(
      pages: pages,
      buildPage: (context, page) =>
          widget.buildPage(context, tab.tab, page, stack),
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

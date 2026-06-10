with open('lib/screens/home_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add showcaseview import
content = content.replace(
    "import 'package:permission_handler/permission_handler.dart';",
    "import 'package:permission_handler/permission_handler.dart';\nimport 'package:showcaseview/showcaseview.dart';"
)

# 2. Add GlobalKeys to state
state_vars = '''  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';'''

new_state_vars = '''  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final GlobalKey _addKey = GlobalKey();
  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();'''

content = content.replace(state_vars, new_state_vars)

# 3. Add showcase trigger to initState
init_state = '''      final provider = Provider.of<LinkProvider>(context, listen: false);
      if (!await provider.hasCompletedSetup()) {
        if (mounted) _showSetupDialog();
      }'''

new_init_state = '''      final provider = Provider.of<LinkProvider>(context, listen: false);
      if (!await provider.hasCompletedSetup()) {
        if (mounted) _showSetupDialog();
      } else {
        final prefs = await SharedPreferences.getInstance();
        if (!(prefs.getBool('showcase_done') ?? false)) {
          if (mounted) {
            ShowCaseWidget.of(context).startShowCase([_menuKey, _searchKey, _addKey]);
            prefs.setBool('showcase_done', true);
          }
        }
      }'''

content = content.replace(init_state, new_init_state)

# 4. Wrap Scaffold in ShowCaseWidget
build_start = '''  Widget build(BuildContext context) {
    return Consumer<LinkProvider>('''

new_build_start = '''  Widget build(BuildContext context) {
    return ShowCaseWidget(
      builder: Builder(
        builder: (context) => Consumer<LinkProvider>('''

content = content.replace(build_start, new_build_start)

# Add closing braces for ShowCaseWidget
build_end = '''            floatingActionButton: _isSelectionMode ? null : FloatingActionButton(
              onPressed: () => _onFabPressed(context),
              backgroundColor: Colors.blue.shade800,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            ),
          ),
        );
      },
    );

  }'''

new_build_end = '''            floatingActionButton: _isSelectionMode ? null : Showcase(
              key: _addKey,
              description: 'Tap here to save your very first link!',
              child: FloatingActionButton(
                onPressed: () => _onFabPressed(context),
                backgroundColor: Colors.blue.shade800,
                foregroundColor: Colors.white,
                child: const Icon(Icons.add),
              ),
            ),
          ),
        );
      },
      ),
    );
  }'''

content = content.replace(build_end, new_build_end)

# 5. Wrap Menu icon in Showcase
menu_icon = '''              leading: _isSelectionMode
                  ? IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = false;
                          _selectedLinkIds.clear();
                        });
                      },
                    )
                  : null,'''

new_menu_icon = '''              leading: _isSelectionMode
                  ? IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = false;
                          _selectedLinkIds.clear();
                        });
                      },
                    )
                  : Showcase(
                      key: _menuKey,
                      description: 'Open the menu to create folders, change themes, and enable Cloud Backup.',
                      child: Builder(
                        builder: (ctx) => IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          onPressed: () => Scaffold.of(ctx).openDrawer(),
                        ),
                      ),
                    ),'''

content = content.replace(menu_icon, new_menu_icon)

# 6. Wrap Search icon in Showcase
search_icon = '''                  InkWell(
                    onTap: () {
                      setState(() {
                        if (_isSearching) {
                          _isSearching = false;
                          _searchController.clear();
                          _searchQuery = '';
                        } else {
                          _isSearching = true;
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white, size: 20),
                          Text(_isSearching ? 'Close' : 'Search', style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),'''

new_search_icon = '''                  Showcase(
                    key: _searchKey,
                    description: 'Search for any saved link instantly right here.',
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (_isSearching) {
                            _isSearching = false;
                            _searchController.clear();
                            _searchQuery = '';
                          } else {
                            _isSearching = true;
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white, size: 20),
                            Text(_isSearching ? 'Close' : 'Search', style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),'''

content = content.replace(search_icon, new_search_icon)

with open('lib/screens/home_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

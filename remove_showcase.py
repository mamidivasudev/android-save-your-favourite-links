import os

# 1. Restore the file from git to get a totally clean slate (no Showcase)
os.system('git checkout lib/screens/home_screen.dart')

with open('lib/screens/home_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 2. Add 50 link limit logic back
on_fab = '''  void _onFabPressed(BuildContext context) async {
    final provider = Provider.of<LinkProvider>(context, listen: false);'''

new_on_fab = '''  void _onFabPressed(BuildContext context) async {
    final provider = Provider.of<LinkProvider>(context, listen: false);
    if (!provider.isProUser && provider.links.length >= 50) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PremiumScreen()));
      return;
    }'''

content = content.replace(on_fab, new_on_fab)

# 3. Add 50 link limit logic to paste handler
paste_handler = '''                    try {
                      await provider.addLink(titleController.text, normalized, categoryId: selectedCategoryId);'''

new_paste_handler = '''                    try {
                      if (!provider.isProUser && provider.links.length >= 50) {
                        Navigator.of(context).pop(); // Close dialog
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PremiumScreen()));
                        return;
                      }
                      await provider.addLink(titleController.text, normalized, categoryId: selectedCategoryId);'''

content = content.replace(paste_handler, new_paste_handler)


# 4. Add milestone logic back
milestone_method = '''  void _show1kMilestoneWarning(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Expanded(child: Text('Wow, 1,000 Links!', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(
          "You've built a massive collection! To ensure you never lose your data if something happens to your device, we highly recommend enabling Google Drive Backup in the side menu.",
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Maybe Later', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Scaffold.of(context).openDrawer();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade800,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Enable Backup', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }'''

end_state = '''      ),
    );
  }
}

class LinkCard extends StatelessWidget {'''

new_end_state = '''      ),
    );
  }

''' + milestone_method + '''
}

class LinkCard extends StatelessWidget {'''

content = content.replace(end_state, new_end_state)


# 5. Fix link icon and Pro pin logic from earlier
pin_old = '''                  label: link.isPinned ? 'Unpin' : 'Pin',
                  iconColor: Colors.blue.shade700,
                  onTap: () {
                    Navigator.pop(ctx);
                    Provider.of<LinkProvider>(context, listen: false).togglePin(link.id!);
                  },'''

pin_new = '''                  label: link.isPinned ? 'Unpin' : 'Pin',
                  iconColor: Colors.blue.shade700,
                  onTap: () {
                    Navigator.of(context).pop();
                    if (!Provider.of<LinkProvider>(context, listen: false).isProUser) {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PremiumScreen()));
                    } else {
                      Provider.of<LinkProvider>(context, listen: false).togglePin(link.id!);
                    }
                  },'''

content = content.replace(pin_old, pin_new)

icon_old = '''    } else if (url.contains('maps.google') || url.contains('goo.gl/maps') || url.contains('google.com/maps') || url.contains('maps.app.goo.gl')) {
      return Image.asset('assets/icons/maps.png', width: 32, height: 32);
    } else {
      return Container();
    }'''

icon_new = '''    } else if (url.contains('maps.google') || url.contains('goo.gl/maps') || url.contains('google.com/maps') || url.contains('maps.app.goo.gl')) {
      return Image.asset('assets/icons/maps.png', width: 32, height: 32);
    } else {
      return Icon(Icons.link, color: Colors.blue.shade800, size: 28);
    }'''

content = content.replace(icon_old, icon_new)

with open('lib/screens/home_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

# Also remove showcaseview package from pubspec.yaml
os.system('flutter pub remove showcaseview')

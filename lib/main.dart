import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/link_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => LinkProvider()
        ..fetchCategories()
        ..fetchLinks(),
      child: const LinkSaverApp(),
    ),
  );
}

class LinkSaverApp extends StatelessWidget {
  const LinkSaverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Link Saver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: Colors.blue.shade800,
          secondary: Colors.purple.shade700,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const MainWrapper(),
    );
  }
}

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  late StreamSubscription _intentDataStreamSubscription;
  String? _sharedText;

  @override
  void initState() {
    super.initState();

    // For sharing or opening urls/text coming from outside the app while the app is in the memory
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      for (var file in value) {
        if (file.type == SharedMediaType.text || file.type == SharedMediaType.url) {
          setState(() {
            _sharedText = file.path;
            if (_sharedText != null) {
              _showSaveDialog(_sharedText!);
            }
          });
        }
      }
    }, onError: (err) {
      debugPrint("getMediaStream error: $err");
    });

    // For sharing or opening urls/text coming from outside the app while the app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      for (var file in value) {
        if (file.type == SharedMediaType.text || file.type == SharedMediaType.url) {
          setState(() {
            _sharedText = file.path;
            if (_sharedText != null) {
              _showSaveDialog(_sharedText!);
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  String _extractUrl(String text) {
    final urlRegExp = RegExp(r'(https?:\/\/[^\s]+)');
    final match = urlRegExp.firstMatch(text);
    return match?.group(0) ?? text;
  }

  void _showSaveDialog(String sharedContent) {
    final url = _extractUrl(sharedContent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => SaveLinkDialog(url: url),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}

class SaveLinkDialog extends StatefulWidget {
  final String url;
  const SaveLinkDialog({super.key, required this.url});

  @override
  State<SaveLinkDialog> createState() => _SaveLinkDialogState();
}

class _SaveLinkDialogState extends State<SaveLinkDialog> {
  late TextEditingController _controller;
  late TextEditingController _urlController;
  late FocusNode _focusNode;
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _urlController = TextEditingController(text: widget.url);
    _focusNode = FocusNode();
    
    // Auto-generate title based on URL if possible
    _controller.text = _guessTitleFromUrl(widget.url);

    final provider = Provider.of<LinkProvider>(context, listen: false);
    _selectedCategoryId = provider.getAutoCategoryId(widget.url);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _focusNode.requestFocus();
        if (_controller.text.isNotEmpty) {
          _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
        }
      }
    });
  }

  String _guessTitleFromUrl(String url) {
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('youtube.com') || lowerUrl.contains('youtu.be')) return 'YouTube Video';
    if (lowerUrl.contains('instagram.com')) return 'Instagram Post';
    if (lowerUrl.contains('maps.google') || lowerUrl.contains('goo.gl/maps') || lowerUrl.contains('maps.app.goo.gl')) return 'Location';
    if (lowerUrl.contains('google.com')) return 'Google Search';
    return '';
  }

  void _save(LinkProvider provider) {
    if (_controller.text.isNotEmpty && _urlController.text.isNotEmpty) {
      provider.addLink(_controller.text, _urlController.text, categoryId: _selectedCategoryId);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link saved successfully!')),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _urlController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LinkProvider>(
      builder: (context, provider, child) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Text('Save Link', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                    onPressed: () => _save(provider),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        hintText: 'e.g. My Favorite Song',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _urlController,
                      textInputAction: TextInputAction.done,
                      onChanged: (val) {
                        setDialogState(() {
                          _selectedCategoryId = provider.getAutoCategoryId(val);
                        });
                      },
                      onSubmitted: (_) => _save(provider),
                      decoration: InputDecoration(
                        labelText: 'URL',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Select Category:', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 0,
                      children: provider.categories.map((cat) {
                        final isSelected = _selectedCategoryId == cat.id;
                        return ChoiceChip(
                          label: Text(cat.name),
                          selected: isSelected,
                          onSelected: (selected) {
                            setDialogState(() {
                              _selectedCategoryId = selected ? cat.id : null;
                            });
                          },
                          selectedColor: Colors.blue.shade800,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _save(provider),
                  icon: const Icon(Icons.check),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            );
          }
        );
      }
    );
  }
}

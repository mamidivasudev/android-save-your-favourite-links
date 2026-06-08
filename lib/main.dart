import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/link_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'utils/url_validator.dart';
import 'services/auth_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => LinkProvider()
            ..fetchCategories()
            ..fetchLinks(),
        ),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: const LinkSaverApp(),
    ),
  );
}

class LinkSaverApp extends StatelessWidget {
  const LinkSaverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Fav Link Saver',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              primary: Colors.blue.shade800,
              secondary: Colors.purple.shade700,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            textTheme: GoogleFonts.poppinsTextTheme(),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              primary: Colors.blue.shade300,
              secondary: Colors.purple.shade300,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            textTheme: GoogleFonts.poppinsTextTheme(ThemeData(brightness: Brightness.dark).textTheme),
          ),
          home: const MainWrapper(),
        );
      },
    );
  }
}

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> with WidgetsBindingObserver {
  late StreamSubscription _intentDataStreamSubscription;
  String? _sharedText;
  bool _isAuthenticated = false;
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _checkInitialAuth();

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
              _showSaveDialog(_sharedText!, closeAppOnSave: true);
            }
          });
        }
      }
    });
  }

  Future<void> _checkInitialAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final isLocked = prefs.getBool('isAppLockEnabled') ?? false;
    if (isLocked) {
      // Actually we don't need to await here. The build method will show the lock screen
      // because _isAuthenticated is false by default. We just let the UI render the lock screen.
      setState(() {
        _isCheckingAuth = false;
      });
    } else {
      setState(() {
        _isAuthenticated = true;
        _isCheckingAuth = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final provider = Provider.of<LinkProvider>(context, listen: false);
      if (provider.isAuthenticating) return; // Ignore resume if coming back from biometric prompt
      
      final isAppLockEnabled = provider.isAppLockEnabled;
      if (isAppLockEnabled) {
        setState(() {
          _isAuthenticated = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  String _extractUrl(String text) {
    final urlRegExp = RegExp(r'(https?:\/\/[^\s]+)');
    final match = urlRegExp.firstMatch(text);
    return match?.group(0) ?? text;
  }

  void _showSaveDialog(String sharedContent, {bool closeAppOnSave = false}) {
    final url = _extractUrl(sharedContent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => SaveLinkDialog(url: url, closeAppOnSave: closeAppOnSave),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAppLockEnabled = Provider.of<LinkProvider>(context).isAppLockEnabled;

    if (_isCheckingAuth) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (isAppLockEnabled && !_isAuthenticated) {
      return Scaffold(
        body: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.purple.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Colors.white),
              const SizedBox(height: 24),
              Text('App Locked', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                icon: const Icon(Icons.fingerprint, size: 28),
                label: const Text('Tap to Unlock', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue.shade900,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () async {
                  try {
                    final provider = Provider.of<LinkProvider>(context, listen: false);
                    provider.setAuthenticating(true);
                    final authenticated = await AuthService.authenticateForLink();
                    provider.setAuthenticating(false);
                    
                    if (authenticated) {
                      setState(() {
                        _isAuthenticated = true;
                      });
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Authentication failed. Please stop the app and rebuild if this continues.')),
                        );
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e - Try fully stopping the app.')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      );
    }

    return const HomeScreen();
  }
}

class SaveLinkDialog extends StatefulWidget {
  final String url;
  final bool closeAppOnSave;
  const SaveLinkDialog({super.key, required this.url, this.closeAppOnSave = false});

  @override
  State<SaveLinkDialog> createState() => _SaveLinkDialogState();
}

class _SaveLinkDialogState extends State<SaveLinkDialog> {
  late TextEditingController _controller;
  late TextEditingController _urlController;
  late FocusNode _focusNode;
  int? _selectedCategoryId;
  String? _urlError;

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
      final normalized = UrlValidator.normalize(_urlController.text);
      if (normalized == null) {
        setState(() {
          _urlError = UrlValidator.validationError();
        });
        return;
      }

      setState(() {
        _urlError = null;
      });

      try {
        provider.addLink(_controller.text, normalized, categoryId: _selectedCategoryId);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link saved successfully!')),
        );
        if (widget.closeAppOnSave) {
          Future.delayed(const Duration(milliseconds: 500), () => SystemNavigator.pop());
        }
      } on DuplicateLinkException catch (e) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(e.message, style: GoogleFonts.poppins(fontSize: 13)),
              ],
            ),
            backgroundColor: Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
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
                        fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade100,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _urlController,
                      textInputAction: TextInputAction.done,
                      onChanged: (val) {
                        setDialogState(() {
                          _selectedCategoryId = provider.getAutoCategoryId(val);
                          _urlError = null; // clear error when typing
                        });
                      },
                      onSubmitted: (_) => _save(provider),
                      decoration: InputDecoration(
                        labelText: 'URL',
                        errorText: _urlError,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade100,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Select Category:', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.maxFinite,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: provider.categories.map((cat) {
                          final isSelected = _selectedCategoryId == cat.id;
                          return SizedBox(
                            width: 76,
                            child: ChoiceChip(
                              label: Container(
                                alignment: Alignment.center,
                                child: Text(
                                  cat.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              padding: EdgeInsets.zero,
                              labelPadding: EdgeInsets.zero,
                              selected: isSelected,
                              onSelected: (selected) {
                                setDialogState(() {
                                  _selectedCategoryId = selected ? cat.id : null;
                                });
                              },
                              selectedColor: Colors.blue.shade800,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
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

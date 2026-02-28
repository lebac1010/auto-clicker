import 'package:auto_clicker/screens/home_screen.dart';
import 'package:auto_clicker/screens/normal_home_screen.dart';
import 'package:auto_clicker/services/analytics_service.dart';
import 'package:auto_clicker/services/home_mode_service.dart';
import 'package:flutter/material.dart';

class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _selectedIndex = 0;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final preferredMode = await HomeModeService.loadPreferredMode();
    final promptRequired = await HomeModeService.shouldShowModePrompt();
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedIndex = preferredMode == HomeMode.advanced ? 1 : 0;
      _initialized = true;
    });
    if (promptRequired) {
      await _showModePrompt();
    }
  }

  void _setTab(int index, {bool persist = true}) {
    if (_selectedIndex == index) {
      if (persist) {
        HomeModeService.savePreferredMode(
          index == 0 ? HomeMode.normal : HomeMode.advanced,
        );
      }
      return;
    }
    setState(() => _selectedIndex = index);
    final mode = index == 0 ? 'normal' : 'advanced';
    if (persist) {
      HomeModeService.savePreferredMode(
        index == 0 ? HomeMode.normal : HomeMode.advanced,
      );
    }
    AnalyticsService.logEvent(
      'home_mode_selected',
      parameters: <String, Object?>{'mode': mode, 'screen_name': 'home_shell'},
    );
  }

  Future<void> _showModePrompt() async {
    if (!mounted) {
      return;
    }
    final selected = await showDialog<HomeMode>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Choose Home Mode'),
        content: const Text(
          'Normal is simplified for new users. Advanced includes full controls.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(HomeMode.advanced),
            child: const Text('Advanced'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(HomeMode.normal),
            child: const Text('Normal (Recommended)'),
          ),
        ],
      ),
    );
    await HomeModeService.markModePromptSeen();
    if (selected == null || !mounted) {
      return;
    }
    _setTab(selected == HomeMode.normal ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment<int>(
                      value: 0,
                      icon: Icon(Icons.flash_on),
                      label: Text('Normal'),
                    ),
                    ButtonSegment<int>(
                      value: 1,
                      icon: Icon(Icons.tune),
                      label: Text('Advanced'),
                    ),
                  ],
                  selected: {_selectedIndex},
                  onSelectionChanged: (selection) => _setTab(selection.first),
                ),
              ),
            ),
          ),
          Expanded(
            child: _selectedIndex == 0
                ? NormalHomeScreen(onOpenAdvanced: () => _setTab(1))
                : const AdvancedHomeScreen(),
          ),
        ],
      ),
    );
  }
}

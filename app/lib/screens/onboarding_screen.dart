import 'package:auto_clicker/main.dart';
import 'package:auto_clicker/services/analytics_service.dart';
import 'package:auto_clicker/services/onboarding_service.dart';
import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  final List<_OnboardingItem> _items = const [
    _OnboardingItem(
      title: 'Auto Tap and Macro',
      description: 'Create tap scripts and replay actions quickly.',
      icon: Icons.play_circle_outline,
    ),
    _OnboardingItem(
      title: 'Accessibility Permission',
      description:
          'Required to perform touch gestures for your scripts. You will see a disclosure screen before enabling it.',
      icon: Icons.accessibility_new,
    ),
    _OnboardingItem(
      title: 'Overlay Permission',
      description: 'Required to show floating controls over other apps.',
      icon: Icons.layers_outlined,
    ),
  ];

  Future<void> _finish() async {
    await OnboardingService.markCompleted();
    AnalyticsService.logEvent(
      'onboarding_completed',
      parameters: <String, Object?>{
        'slides_count': _items.length,
        'screen_name': 'onboarding',
      },
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(AutoClickerApp.permissionsRoute);
  }

  @override
  Widget build(BuildContext context) {
    final bool isLastPage = _index == _items.length - 1;
    return Scaffold(
      appBar: AppBar(
        actions: [TextButton(onPressed: _finish, child: const Text('Skip'))],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _items.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (_, i) => _OnboardingPage(item: _items[i]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isLastPage
                    ? _finish
                    : () => _controller.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      ),
                child: Text(isLastPage ? 'Start' : 'Next'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.item});

  final _OnboardingItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, size: 84),
          const SizedBox(height: 24),
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            item.description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _OnboardingItem {
  const _OnboardingItem({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

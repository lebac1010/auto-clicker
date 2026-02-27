import 'package:auto_clicker/main.dart';
import 'package:auto_clicker/services/home_mode_service.dart';
import 'package:auto_clicker/services/settings_service.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;
  bool _volumeKeyStopEnabled = false;
  bool _savingVolumeToggle = false;
  HomeMode _preferredHomeMode = HomeMode.normal;
  bool _savingHomeMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final enabled = await SettingsService.getVolumeKeyStopEnabled();
    final preferredMode = await HomeModeService.loadPreferredMode();
    if (!mounted) {
      return;
    }
    setState(() {
      _volumeKeyStopEnabled = enabled;
      _preferredHomeMode = preferredMode;
      _loading = false;
    });
  }

  Future<void> _onVolumeKeyToggleChanged(bool value) async {
    setState(() => _savingVolumeToggle = true);
    final saved = await SettingsService.setVolumeKeyStopEnabled(value);
    if (!mounted) {
      return;
    }
    setState(() {
      _volumeKeyStopEnabled = saved;
      _savingVolumeToggle = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Volume-key emergency stop enabled'
              : 'Volume-key emergency stop disabled',
        ),
      ),
    );
  }

  Future<void> _onPreferredModeChanged(HomeMode mode) async {
    setState(() => _savingHomeMode = true);
    await HomeModeService.savePreferredMode(mode);
    if (!mounted) {
      return;
    }
    setState(() {
      _preferredHomeMode = mode;
      _savingHomeMode = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mode == HomeMode.normal
              ? 'Default home mode set to Normal'
              : 'Default home mode set to Advanced',
        ),
      ),
    );
  }

  Future<void> _resetModePrompt() async {
    await HomeModeService.resetModePrompt();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mode chooser will appear again on next app open.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: SwitchListTile(
                    title: const Text('Volume-key emergency stop'),
                    subtitle: const Text(
                      'Press Volume Up or Down to immediately stop run and overlay.',
                    ),
                    value: _volumeKeyStopEnabled,
                    onChanged: _savingVolumeToggle ? null : _onVolumeKeyToggleChanged,
                  ),
                ),
                const SizedBox(height: 12),
                const Card(
                  child: ListTile(
                    title: Text('Safety'),
                    subtitle: Text(
                      'STOP button stays visible in the floating controller.',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    title: const Text('Default Home Mode'),
                    subtitle: DropdownButton<HomeMode>(
                      value: _preferredHomeMode,
                      isExpanded: true,
                      onChanged: _savingHomeMode
                          ? null
                          : (mode) {
                              if (mode == null) {
                                return;
                              }
                              _onPreferredModeChanged(mode);
                            },
                      items: const [
                        DropdownMenuItem(
                          value: HomeMode.normal,
                          child: Text('Normal'),
                        ),
                        DropdownMenuItem(
                          value: HomeMode.advanced,
                          child: Text('Advanced'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    title: const Text('Show mode chooser again'),
                    subtitle: const Text(
                      'Display Normal/Advanced selector next time app opens.',
                    ),
                    trailing: const Icon(Icons.refresh),
                    onTap: _resetModePrompt,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    title: const Text('Help & Troubleshooting'),
                    subtitle: const Text(
                      'Open quick fixes and export support logs.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).pushNamed(AutoClickerApp.helpRoute);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    title: const Text('Privacy Policy'),
                    subtitle: const Text(
                      'Read how permissions and local data are handled.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(
                        context,
                      ).pushNamed(AutoClickerApp.privacyPolicyRoute);
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

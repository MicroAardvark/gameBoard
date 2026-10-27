import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'demo_seed.dart';

/// A slim strip across the top of every page in the demo build, so nobody
/// mistakes it for the live app.
///
/// The screens size themselves from MediaQuery, so the strip hands the page
/// below it a MediaQuery with the smaller height. Otherwise the bottom of
/// the landscape layouts would be pushed off-screen.
class DemoBanner extends StatelessWidget {
  final Widget child;

  const DemoBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: AppColors.secondaryAmber,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.science_outlined, size: 16, color: AppColors.textOnAmber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Demo with made-up players. Single-player games run fully; '
                      'online play needs the live server. Refreshing starts again.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textOnAmber,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The banner already handles the top inset (notch, status bar)
              final media = MediaQuery.of(context).removePadding(removeTop: true);
              return MediaQuery(
                data: media.copyWith(size: constraints.biggest),
                child: child,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A "Play as the demo player" button that logs straight in, so visitors
/// don't need to type anything.
class DemoLoginPanel extends StatefulWidget {
  final void Function(User) onLoginSuccess;

  const DemoLoginPanel({super.key, required this.onLoginSuccess});

  @override
  State<DemoLoginPanel> createState() => _DemoLoginPanelState();
}

class _DemoLoginPanelState extends State<DemoLoginPanel> {
  bool _loggingIn = false;
  String? _error;

  Future<void> _logIn() async {
    setState(() {
      _loggingIn = true;
      _error = null;
    });
    final result = await AuthService.logIn(
      email: DemoSeed.demoEmail,
      password: DemoSeed.password,
    );
    if (!mounted) return;
    setState(() => _loggingIn = false);
    if (result['success'] == true) {
      widget.onLoginSuccess(User.fromJson(result['user']));
    } else {
      setState(() => _error = result['error']?.toString() ?? 'Could not start the demo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Try the demo',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Play Blackjack, Crazy Eights and Checkers, and look around the '
          'profile and friends list. Everyone here is made up.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _loggingIn ? null : _logIn,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentElectricBlue,
            foregroundColor: AppColors.primaryNavyDark,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: _loggingIn
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryNavyDark,
                  ),
                )
              : const Icon(Icons.play_arrow_rounded),
          label: Text(
            'Play as ${DemoSeed.demoUsername}',
            style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error)),
        ],
        const SizedBox(height: 8),
        const Text(
          'Or log in with ${DemoSeed.demoEmail} / ${DemoSeed.password}',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Shown instead of the online lobby and chat test, which need the live
/// Socket.IO server.
Future<void> showDemoOnlineDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.primaryNavyLight,
      title: const Text(
        'Online play isn\'t in the demo',
        style: TextStyle(fontFamily: 'Montserrat', color: AppColors.textPrimary),
      ),
      content: const Text(
        'Multiplayer Blackjack, Crazy Eights and Checkers, in-game chat and '
        'voice chat all run through a live Node.js and Socket.IO server, so '
        'they aren\'t part of this browser-only demo.\n\n'
        'The single-player games run exactly as they do in the full app.',
        style: TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK', style: TextStyle(color: AppColors.accentElectricBlue)),
        ),
      ],
    ),
  );
}

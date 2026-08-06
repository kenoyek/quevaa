import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_lock_provider.dart';
import '../../../../app/theme/app_colors.dart';

class AppLockWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const AppLockWrapper({super.key, required this.child});

  @override
  ConsumerState<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends ConsumerState<AppLockWrapper> {
  bool _isAuthenticating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(appLockProvider)) {
        _triggerUnlock();
      }
    });
  }

  Future<void> _triggerUnlock() async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    final success = await ref.read(appLockProvider.notifier).unlock();

    if (mounted) {
      setState(() {
        _isAuthenticating = false;
        if (!success) {
          _errorMessage = 'Authentication failed. Tap button to try again.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = ref.watch(appLockProvider);

    ref.listen<bool>(appLockProvider, (previous, next) {
      if (next && !(previous ?? false)) {
        _triggerUnlock();
      }
    });

    return Stack(
      children: [
        widget.child,
        if (isLocked)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                color: Colors.black.withValues(alpha: 0.85),
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          color: AppColors.terracottaPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_person_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Quevaa is Locked',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Biometric authentication required',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          decoration: TextDecoration.none,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                            decoration: TextDecoration.none,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 32),
                      FilledButton.icon(
                        onPressed: _isAuthenticating ? null : _triggerUnlock,
                        icon: _isAuthenticating
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.fingerprint_rounded),
                        label: Text(
                          _isAuthenticating
                              ? 'Authenticating...'
                              : 'Unlock with Biometrics',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.terracottaPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

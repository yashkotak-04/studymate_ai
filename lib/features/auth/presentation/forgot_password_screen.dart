import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/screen_header.dart';
import '../../../app/theme/text_styles.dart';
import '../../../app/theme/app_colors.dart';
import '../data/auth_repository.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your registered email address.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authRepositoryProvider).resetPassword(email);
      if (mounted) {
        setState(() {
          _isSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              ScreenHeader(
                title: '',
                onBack: () => context.pop(),
              ),
              const SizedBox(height: 24),
              Icon(
                LucideIcons.keyRound,
                size: 56,
                color: AppColors.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'Reset Password',
                style: AppTextStyles.displayBold(context, fontSize: 26),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your account email and we will send you a password reset link.',
                style: AppTextStyles.bodySecondary(context, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withOpacity(0.5)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: AppTextStyles.body(context, color: AppColors.error),
                  ),
                ),

              if (_isSuccess)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success.withOpacity(0.4)),
                  ),
                  child: Column(
                    children: [
                      const Icon(LucideIcons.checkCircle2, color: AppColors.success, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'Password Reset Email Sent!',
                        style: AppTextStyles.body(context, fontWeight: FontWeight.w700, color: AppColors.success),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Please check your inbox (and spam folder) for instructions to reset your password.',
                        style: AppTextStyles.bodySecondary(context, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      CustomButton(
                        text: 'Back to Login',
                        variant: ButtonVariant.ghost,
                        onPressed: () => context.go('/login'),
                      ),
                    ],
                  ),
                )
              else ...[
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: 'Email address',
                    prefixIcon: const Icon(LucideIcons.mail, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  style: AppTextStyles.body(context),
                ),
                const SizedBox(height: 24),
                CustomButton(
                  text: _isLoading ? 'Sending Email...' : 'Send Reset Link',
                  isFullWidth: true,
                  onPressed: _isLoading ? null : _sendResetEmail,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

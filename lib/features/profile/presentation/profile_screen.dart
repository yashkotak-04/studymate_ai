import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/widgets/screen_header.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/models/subject.dart';
import '../../../shared/models/chat_model.dart';
import '../../../shared/models/user_profile.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/text_styles.dart';
import '../../auth/data/auth_repository.dart';
import '../data/user_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showAiModeSelectorModal(
    BuildContext context,
    WidgetRef ref,
    UserProfile? profile,
  ) {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentMode = profile?.preferredAiMode ?? 'Student';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Text(
              'Default AI Explanation Mode',
              style: AppTextStyles.displayBold(context, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Select how AI Tutor explains concepts by default.',
              style: AppTextStyles.bodySecondary(context, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ...ExplanationMode.values.map(
              (mode) => _buildAiModeOption(
                context,
                ref,
                user.uid,
                mode,
                currentMode.toLowerCase() == mode.id.toLowerCase(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiModeOption(
    BuildContext context,
    WidgetRef ref,
    String uid,
    ExplanationMode mode,
    bool isSelected,
  ) {
    return ListTile(
      leading: Icon(mode.icon, color: isSelected ? AppColors.primary : null),
      title: Text(
        mode.label,
        style: AppTextStyles.body(
          context,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        mode.desc,
        style: AppTextStyles.bodySecondary(context, fontSize: 11),
      ),
      trailing: isSelected
          ? const Icon(LucideIcons.check, color: AppColors.primary)
          : null,
      onTap: () async {
        await ref
            .read(userRepositoryProvider)
            .updatePreferredAiMode(uid, mode.label);
        if (context.mounted) Navigator.pop(context);
      },
    );
  }

  void _showManageSubjectsModal(
    BuildContext context,
    WidgetRef ref,
    List<String> enrolledIds,
  ) {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Container(
            height: MediaQuery.of(context).size.height * 0.65,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Text(
                  'Manage Enrolled Subjects',
                  style: AppTextStyles.displayBold(context, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select the courses you are studying this term. Historical quiz data will be preserved.',
                  style: AppTextStyles.bodySecondary(context, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: AppSubjects.availableSubjects.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final subject = AppSubjects.availableSubjects[index];
                      final isEnrolled = enrolledIds.contains(subject.id);

                      return CustomCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: subject.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    subject.name,
                                    style: AppTextStyles.body(
                                      context,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    subject.shortName,
                                    style: AppTextStyles.bodySecondary(
                                      context,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: isEnrolled,
                              activeColor: AppColors.primary,
                              onChanged: (val) async {
                                if (val) {
                                  await ref
                                      .read(userRepositoryProvider)
                                      .enrollSubject(user.uid, subject.id);
                                  setModalState(
                                    () => enrolledIds.add(subject.id),
                                  );
                                } else {
                                  if (enrolledIds.length > 1) {
                                    await ref
                                        .read(userRepositoryProvider)
                                        .unenrollSubject(user.uid, subject.id);
                                    setModalState(
                                      () => enrolledIds.remove(subject.id),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'At least one subject must remain enrolled.',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                CustomButton(
                  text: 'Done',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showThemeSelectorModal(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.read(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Text(
              'App Theme',
              style: AppTextStyles.displayBold(context, fontSize: 18),
            ),
            const SizedBox(height: 16),
            _buildThemeOption(
              context,
              ref,
              'System Default',
              ThemeMode.system,
              LucideIcons.laptop,
              currentTheme == ThemeMode.system,
            ),
            _buildThemeOption(
              context,
              ref,
              'Light Mode',
              ThemeMode.light,
              LucideIcons.sun,
              currentTheme == ThemeMode.light,
            ),
            _buildThemeOption(
              context,
              ref,
              'Dark Mode',
              ThemeMode.dark,
              LucideIcons.moon,
              currentTheme == ThemeMode.dark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    WidgetRef ref,
    String title,
    ThemeMode mode,
    IconData icon,
    bool isSelected,
  ) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppColors.primary : null),
      title: Text(
        title,
        style: AppTextStyles.body(
          context,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      trailing: isSelected
          ? const Icon(LucideIcons.check, color: AppColors.primary)
          : null,
      onTap: () {
        ref.read(themeModeProvider.notifier).setThemeMode(mode);
        Navigator.pop(context);
      },
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'New Password (min 6 characters)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Confirm New Password',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (passwordController.text != confirmController.text ||
                  passwordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Passwords must match and be at least 6 characters.',
                    ),
                  ),
                );
                return;
              }
              try {
                await ref
                    .read(authRepositoryProvider)
                    .updatePassword(passwordController.text.trim());
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password changed successfully!'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action is irreversible and will permanently delete your profile, study plans, quiz history, and notes.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Enter your password to confirm',
                hintText: 'Current Password',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final password = passwordController.text.trim();
              if (password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please enter your password to confirm account deletion.',
                    ),
                  ),
                );
                return;
              }

              Navigator.pop(context);
              try {
                await ref
                    .read(authRepositoryProvider)
                    .deleteAccount(passwordForReauth: password);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Your account and all associated data have been deleted.',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  final message = e.toString().contains('wrong-password')
                      ? 'Incorrect password. Account was not deleted.'
                      : 'Your account could not be deleted completely. Please retry or contact support.';
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(message)));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text(
              'Delete Permanently',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(title: 'Profile & Settings'),

              userProfileAsync.when(
                data: (profile) {
                  if (profile == null)
                    return const Center(child: Text('Profile not found'));
                  return CustomCard(
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            (profile.displayName ?? '').isNotEmpty
                                ? (profile.displayName ?? '')[0].toUpperCase()
                                : 'U',
                            style: AppTextStyles.displayBold(
                              context,
                              fontSize: 26,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.displayName ?? 'Student',
                                style: AppTextStyles.displayBold(
                                  context,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                profile.email ?? '',
                                style: AppTextStyles.bodySecondary(
                                  context,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  profile.targetExam ?? 'Finals Prep',
                                  style: AppTextStyles.body(
                                    context,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, st) => Text('Error loading profile: $e'),
              ),
              const SizedBox(height: 20),

              Text(
                'Academic & Study Settings',
                style: AppTextStyles.displayBold(context, fontSize: 15),
              ),
              const SizedBox(height: 10),

              userProfileAsync.when(
                data: (profile) {
                  final enrolled =
                      profile?.enrolledSubjectIds ?? ['os', 'py', 'db', 'net'];
                  return CustomCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            LucideIcons.bookOpen,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            'Manage Subjects',
                            style: AppTextStyles.body(
                              context,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${enrolled.length} subjects enrolled',
                            style: AppTextStyles.bodySecondary(
                              context,
                              fontSize: 12,
                            ),
                          ),
                          trailing: const Icon(
                            LucideIcons.chevronRight,
                            size: 18,
                          ),
                          onTap: () => _showManageSubjectsModal(
                            context,
                            ref,
                            List.from(enrolled),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            LucideIcons.sparkles,
                            size: 20,
                            color: AppColors.accentTeal,
                          ),
                          title: Text(
                            'Default AI Mode',
                            style: AppTextStyles.body(
                              context,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            profile?.preferredAiMode ?? 'Student',
                            style: AppTextStyles.bodySecondary(
                              context,
                              fontSize: 12,
                            ),
                          ),
                          trailing: const Icon(
                            LucideIcons.chevronRight,
                            size: 18,
                          ),
                          onTap: () =>
                              _showAiModeSelectorModal(context, ref, profile),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),

              Text(
                'Preferences & Appearance',
                style: AppTextStyles.displayBold(context, fontSize: 15),
              ),
              const SizedBox(height: 10),

              CustomCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        themeMode == ThemeMode.dark
                            ? LucideIcons.moon
                            : (themeMode == ThemeMode.light
                                  ? LucideIcons.sun
                                  : LucideIcons.laptop),
                        size: 20,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        'Theme Mode',
                        style: AppTextStyles.body(
                          context,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        themeMode == ThemeMode.system
                            ? 'System Default'
                            : (themeMode == ThemeMode.dark
                                  ? 'Dark Mode'
                                  : 'Light Mode'),
                        style: AppTextStyles.bodySecondary(
                          context,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(LucideIcons.chevronRight, size: 18),
                      onTap: () => _showThemeSelectorModal(context, ref),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        LucideIcons.bellRing,
                        size: 20,
                        color: AppColors.accentAmber,
                      ),
                      title: Text(
                        'Daily Study Reminders',
                        style: AppTextStyles.body(
                          context,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Receive reminders to keep your daily streak active',
                        style: AppTextStyles.bodySecondary(
                          context,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(LucideIcons.chevronRight, size: 18),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Study reminders are active for your registered device.',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Account & Security',
                style: AppTextStyles.displayBold(context, fontSize: 15),
              ),
              const SizedBox(height: 10),

              CustomCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        LucideIcons.keyRound,
                        size: 20,
                        color: AppColors.accentAmber,
                      ),
                      title: Text(
                        'Change Password',
                        style: AppTextStyles.body(
                          context,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: const Icon(LucideIcons.chevronRight, size: 18),
                      onTap: () => _showChangePasswordDialog(context, ref),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        LucideIcons.mailCheck,
                        size: 20,
                        color: AppColors.accentTeal,
                      ),
                      title: Text(
                        'Password Reset Email',
                        style: AppTextStyles.body(
                          context,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Send a reset link to ${user?.email ?? "your email"}',
                        style: AppTextStyles.bodySecondary(
                          context,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(LucideIcons.chevronRight, size: 18),
                      onTap: () async {
                        if (user?.email != null) {
                          await ref
                              .read(authRepositoryProvider)
                              .resetPassword(user!.email!);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password reset email sent!'),
                              ),
                            );
                          }
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        LucideIcons.userX,
                        size: 20,
                        color: AppColors.error,
                      ),
                      title: Text(
                        'Delete Account',
                        style: AppTextStyles.body(
                          context,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                      trailing: const Icon(
                        LucideIcons.chevronRight,
                        size: 18,
                        color: AppColors.error,
                      ),
                      onTap: () => _showDeleteAccountDialog(context, ref),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              CustomButton(
                text: 'Sign Out',
                variant: ButtonVariant.ghost,
                icon: LucideIcons.logOut,
                onPressed: () {
                  ref.read(authRepositoryProvider).signOut();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

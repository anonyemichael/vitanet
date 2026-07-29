import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet_frontend/providers/personal_reg_pro.dart';
import 'package:vitanet_frontend/themes/app_theme.dart';
import 'package:vitanet_frontend/themes/responsive_design.dart';
import 'package:vitanet_frontend/widgets/google_logo.dart';

/// SCREEN 2 of the VitaNet Registration Flow: "Create Your Account",
/// shown after the user picks Personal Account on the Welcome screen.
///
/// Layout is deliberately dense and form-first (label-above fields, a
/// step indicator, buttons pinned to the bottom) rather than a tall
/// hero + scrolling stack, so the whole form reads at a glance and only
/// scrolls when the keyboard genuinely needs the room.
class PersonalRegistrationScreen extends ConsumerStatefulWidget {
  const PersonalRegistrationScreen({super.key});

  @override
  ConsumerState<PersonalRegistrationScreen> createState() =>
      _PersonalRegistrationScreenState();
}

class _PersonalRegistrationScreenState
    extends ConsumerState<PersonalRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailOrPhoneController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailOrPhoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(personalRegistrationProvider);
    final notifier = ref.read(personalRegistrationProvider.notifier);
    final isSubmitting = state.status == RegistrationStatus.submitting;

    final pageBg = isDark ? const Color(0xFF0F1720) : const Color(0xFFEDF1F5);
    final cardBg = isDark ? const Color(0xFF161F2A) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
    final labelColor = isDark ? Colors.white70 : const Color(0xFF3A4552);
    final fieldBorder = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : const Color(0xFFD7DEE5);

    ref.listen(personalRegistrationProvider, (previous, next) {
      if (next.status == RegistrationStatus.error &&
          next.errorMessage != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
      if (next.status == RegistrationStatus.success) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Account created!')));
        // TODO: navigate into the personal home/dashboard flow.
      }
    });

    void handleSubmit() {
      if (_formKey.currentState?.validate() ?? false) {
        notifier.submit(
          fullName: _fullNameController.text.trim(),
          emailOrPhone: _emailOrPhoneController.text.trim(),
          password: _passwordController.text,
        );
      }
    }

    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.horizontalPadding,
            vertical: 14,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.maxContentWidth),
              child: SizedBox(
                height: double.infinity,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header: back + title.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                        child: Row(
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => Navigator.of(context).maybePop(),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(Icons.arrow_back_rounded,
                                    size: 20, color: labelColor),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Create Your Account',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: context.responsiveFont(20),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Step indicator.
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            _StepTab(
                              label: 'Account Type',
                              state: _StepState.done,
                            ),
                            _StepTab(
                              label: 'Profile Details',
                              state: _StepState.active,
                            ),
                          ],
                        ),
                      ),
                      Container(height: 1, color: borderColor),

                      // Scrollable form body — only scrolls if the
                      // content or keyboard genuinely needs the space.
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Profile Information',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15.5,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                _FieldRow(children: [
                                  _Field(
                                    label: 'Full Name',
                                    labelColor: labelColor,
                                    child: TextFormField(
                                      controller: _fullNameController,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      decoration: _decoration(
                                        borderColor: fieldBorder,
                                      ),
                                      validator: (value) =>
                                          (value == null || value.trim().isEmpty)
                                              ? 'Required'
                                              : null,
                                    ),
                                  ),
                                  _Field(
                                    label: 'Email Address / Phone Number',
                                    labelColor: labelColor,
                                    child: TextFormField(
                                      controller: _emailOrPhoneController,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: _decoration(
                                        borderColor: fieldBorder,
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Required';
                                        }
                                        final v = value.trim();
                                        final isEmail = RegExp(
                                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                            .hasMatch(v);
                                        final isPhone =
                                            RegExp(r'^[0-9+\s()-]{7,}$')
                                                .hasMatch(v);
                                        if (!isEmail && !isPhone) {
                                          return 'Enter a valid email or phone';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 14),

                                _FieldRow(children: [
                                  _Field(
                                    label: 'Password',
                                    labelColor: labelColor,
                                    child: TextFormField(
                                      controller: _passwordController,
                                      obscureText: state.obscurePassword,
                                      decoration: _decoration(
                                        borderColor: fieldBorder,
                                        suffixIcon: IconButton(
                                          padding: EdgeInsets.zero,
                                          icon: Icon(
                                            state.obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            size: 18,
                                          ),
                                          onPressed:
                                              notifier.toggleObscurePassword,
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Required';
                                        }
                                        if (value.length < 8) {
                                          return 'Min. 8 characters';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  _Field(
                                    label: 'Date of Birth',
                                    labelColor: labelColor,
                                    child: _DateOfBirthField(
                                      value: state.dateOfBirth,
                                      borderColor: fieldBorder,
                                      onPick: () async {
                                        final now = DateTime.now();
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: DateTime(
                                              now.year - 18, now.month, now.day),
                                          firstDate: DateTime(now.year - 120),
                                          lastDate: now,
                                        );
                                        if (picked != null) {
                                          notifier.setDateOfBirth(picked);
                                        }
                                      },
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 14),

                                _Field(
                                  label: 'Gender (Optional)',
                                  required: false,
                                  labelColor: labelColor,
                                  child: _GenderPicker(
                                    value: state.gender,
                                    onChanged: notifier.setGender,
                                    borderColor: fieldBorder,
                                  ),
                                ),
                                const SizedBox(height: 18),

                                Text(
                                  'Fields marked with * are required.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: labelColor.withValues(alpha: 0.75),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Container(height: 1, color: borderColor),
                                const SizedBox(height: 16),

                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 13),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    side: BorderSide(color: fieldBorder),
                                  ),
                                  onPressed: isSubmitting
                                      ? null
                                      : notifier.signInWithGoogle,
                                  icon: const GoogleLogo(size: 18),
                                  label: Text(
                                    'Continue with Google',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Footer — pinned, never scrolls away.
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: borderColor)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: labelColor,
                                backgroundColor: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : const Color(0xFFEFF2F5),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 22, vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => Navigator.of(context).maybePop(),
                              child: const Text(
                                'CANCEL',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 12.5),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.brandGreen,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 22, vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: isSubmitting ? null : handleSubmit,
                              child: isSubmitting
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'CREATE ACCOUNT',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(Icons.arrow_forward_rounded,
                                            size: 16, color: Colors.white),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration({required Color borderColor, Widget? suffixIcon}) {
    final radius = BorderRadius.circular(8);
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      suffixIcon: suffixIcon,
      suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: borderColor)),
      enabledBorder:
          OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.brandBlue, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: Colors.red.shade300),
      ),
      errorStyle: const TextStyle(fontSize: 11.5),
    );
  }
}

enum _StepState { done, active, upcoming }

/// A single tab in the compact step indicator across the top of the
/// form (checkmark for completed, filled dot for active, hollow for
/// upcoming) with a colored underline for its own segment.
class _StepTab extends StatelessWidget {
  const _StepTab({required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (state) {
      _StepState.done => AppColors.brandGreen,
      _StepState.active => AppColors.brandBlue,
      _StepState.upcoming => Colors.grey.shade400,
    };

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  state == _StepState.done
                      ? Icons.check_circle_rounded
                      : (state == _StepState.active
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded),
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 2.5, color: color),
        ],
      ),
    );
  }
}

/// Places 1 or 2 fields side by side on wide screens and stacks them on
/// narrow ones — the responsive part of the layout.
class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 480 && children.length > 1;
        if (!isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) const SizedBox(height: 14),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1) const SizedBox(width: 16),
            ],
          ],
        );
      },
    );
  }
}

/// A label (with a red required marker) stacked above its input.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.child,
    required this.labelColor,
    this.required = true,
  });

  final String label;
  final Widget child;
  final Color labelColor;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            style: TextStyle(
              color: labelColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            children: [
              TextSpan(text: label),
              if (required)
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: Colors.red.shade400),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// Compact pill-style radio group for the optional gender field.
class _GenderPicker extends StatelessWidget {
  const _GenderPicker({
    required this.value,
    required this.onChanged,
    required this.borderColor,
  });

  final Gender? value;
  final ValueChanged<Gender?> onChanged;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 8,
        children: Gender.values.map((g) {
          final selected = value == g;
          return InkWell(
            onTap: () => onChanged(selected ? null : g),
            borderRadius: BorderRadius.circular(6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: selected ? AppColors.brandGreen : Colors.grey.shade500,
                ),
                const SizedBox(width: 6),
                Text(g.label, style: const TextStyle(fontSize: 13.5)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Date of birth picker styled to match the other compact fields.
class _DateOfBirthField extends StatelessWidget {
  const _DateOfBirthField({
    required this.value,
    required this.onPick,
    required this.borderColor,
  });

  final DateTime? value;
  final VoidCallback onPick;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = value == null
        ? null
        : '${value!.day.toString().padLeft(2, '0')}/'
            '${value!.month.toString().padLeft(2, '0')}/${value!.year}';

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label ?? 'DD/MM/YYYY',
                style: label == null
                    ? theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.hintColor, fontSize: 14)
                    : theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
              ),
            ),
            Icon(Icons.calendar_today_outlined, size: 16, color: theme.hintColor),
          ],
        ),
      ),
    );
  }
}
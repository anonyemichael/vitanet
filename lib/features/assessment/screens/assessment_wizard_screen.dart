import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/shared/widgets/gradient_background.dart';
import 'package:vitanet/shared/widgets/gradient_icon.dart';

class AssessmentWizardScreen extends StatefulWidget {
  const AssessmentWizardScreen({super.key});

  @override
  State<AssessmentWizardScreen> createState() => _AssessmentWizardScreenState();
}

class _AssessmentWizardScreenState extends State<AssessmentWizardScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // State for wizard
  String? _selectedBodyPart;
  String? _selectedDuration;
  double _painLevel = 5;
  final List<String> _selectedSymptoms = [];
  final List<String> _selectedRisks = [];

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Go to chat screen passing the initial wizard context
      // For the hackathon, we just navigate to chat
      context.push('/chat');
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Symptom Assessment'),
        centerTitle: true,
        leading: _currentPage > 0 
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _prevPage) 
            : null,
        actions: [
          TextButton(
            onPressed: () => context.push('/chat'), // Skip wizard
            child: const Text('Skip'),
          )
        ],
      ),
      body: GradientBackground(
        child: Column(
          children: [
            // Progress Bar
            LinearProgressIndicator(
              value: (_currentPage + 1) / 5,
              backgroundColor: context.colorScheme.surface.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(context.colorScheme.primary),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  _buildStep1BodyParts(),
                  _buildStep2Duration(),
                  _buildStep3PainScale(),
                  _buildStep4Symptoms(),
                  _buildStep5Risks(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _prevPage,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _nextPage,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(_currentPage == 4 ? 'Complete Assessment' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard({required String title, required String subtitle, required Widget child}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: context.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: AppSpacing.sm),
          Text(subtitle, style: context.textTheme.bodyLarge?.copyWith(color: context.colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.xl),
          child,
        ],
      ),
    );
  }

  Widget _buildStep1BodyParts() {
    final parts = [
      {'icon': Icons.face_rounded, 'name': 'Head & Face'},
      {'icon': Icons.visibility_rounded, 'name': 'Eyes & Vision'},
      {'icon': Icons.hearing_rounded, 'name': 'Ears & Hearing'},
      {'icon': Icons.favorite_rounded, 'name': 'Chest & Heart'},
      {'icon': Icons.local_dining_rounded, 'name': 'Abdomen'},
      {'icon': Icons.accessibility_new_rounded, 'name': 'Back & Spine'},
      {'icon': Icons.do_not_step_rounded, 'name': 'Legs & Feet'},
      {'icon': Icons.back_hand_rounded, 'name': 'Arms & Hands'},
      {'icon': Icons.healing_rounded, 'name': 'Skin'},
      {'icon': Icons.more_horiz_rounded, 'name': 'General / Other'},
    ];

    return _buildStepCard(
      title: 'Where is the problem?',
      subtitle: 'Select the primary area you are experiencing issues with.',
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.2,
        ),
        itemCount: parts.length,
        itemBuilder: (context, index) {
          final p = parts[index];
          final isSelected = _selectedBodyPart == p['name'];
          return InkWell(
            onTap: () => setState(() => _selectedBodyPart = p['name'] as String),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected ? context.colorScheme.primaryContainer : context.colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? context.colorScheme.primary : context.colorScheme.outline.withValues(alpha: 0.1),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(p['icon'] as IconData, size: 32, color: isSelected ? context.colorScheme.primary : context.colorScheme.onSurfaceVariant),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    p['name'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? context.colorScheme.primary : null,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStep2Duration() {
    final durations = ['Just started (Today)', 'Yesterday', 'A few days ago', '1 Week', 'More than a week', 'Ongoing (Chronic)'];

    return _buildStepCard(
      title: 'How long have you had this?',
      subtitle: 'Understanding the timeline helps determine urgency.',
      child: Column(
        children: durations.map((d) {
          final isSelected = _selectedDuration == d;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: InkWell(
              onTap: () => setState(() => _selectedDuration = d),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: isSelected ? context.colorScheme.primaryContainer : context.colorScheme.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? context.colorScheme.primary : context.colorScheme.outline.withValues(alpha: 0.1),
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                      color: isSelected ? context.colorScheme.primary : context.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        d,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStep3PainScale() {
    return _buildStepCard(
      title: 'How severe is the pain/discomfort?',
      subtitle: 'On a scale from 0 to 10, with 0 being none and 10 being the worst imaginable.',
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _painLevel < 4 ? Icons.sentiment_satisfied_rounded 
                : _painLevel < 8 ? Icons.sentiment_dissatisfied_rounded 
                : Icons.sentiment_very_dissatisfied_rounded,
                size: 64,
                color: _painLevel < 4 ? Colors.green 
                     : _painLevel < 8 ? Colors.orange 
                     : Colors.red,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Slider(
            value: _painLevel,
            min: 0,
            max: 10,
            divisions: 10,
            label: _painLevel.round().toString(),
            activeColor: _painLevel < 4 ? Colors.green 
                       : _painLevel < 8 ? Colors.orange 
                       : Colors.red,
            onChanged: (val) => setState(() => _painLevel = val),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0 (None)'),
                Text('10 (Unbearable)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4Symptoms() {
    final symptoms = ['Fever', 'Cough', 'Nausea / Vomiting', 'Fatigue / Weakness', 'Shortness of breath', 'Dizziness', 'Chills', 'Sweating'];

    return _buildStepCard(
      title: 'Any additional symptoms?',
      subtitle: 'Select any other symptoms that apply. You can choose multiple.',
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: symptoms.map((s) {
          final isSelected = _selectedSymptoms.contains(s);
          return FilterChip(
            label: Text(s),
            selected: isSelected,
            onSelected: (val) {
              setState(() {
                if (val) _selectedSymptoms.add(s);
                else _selectedSymptoms.remove(s);
              });
            },
            selectedColor: context.colorScheme.primaryContainer,
            checkmarkColor: context.colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isSelected ? context.colorScheme.primary : context.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStep5Risks() {
    final risks = ['Currently pregnant', 'Recent travel abroad', 'Diabetic', 'High blood pressure', 'Immunocompromised', 'Recent surgery', 'None of the above'];

    return _buildStepCard(
      title: 'Any special risk factors?',
      subtitle: 'This information helps us safely triage your situation.',
      child: Column(
        children: risks.map((r) {
          final isSelected = _selectedRisks.contains(r);
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: CheckboxListTile(
              title: Text(r),
              value: isSelected,
              onChanged: (val) {
                setState(() {
                  if (r == 'None of the above') {
                    _selectedRisks.clear();
                    if (val == true) _selectedRisks.add(r);
                  } else {
                    _selectedRisks.remove('None of the above');
                    if (val == true) _selectedRisks.add(r);
                    else _selectedRisks.remove(r);
                  }
                });
              },
              tileColor: context.colorScheme.surface.withValues(alpha: 0.5),
              selectedTileColor: context.colorScheme.primaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected ? context.colorScheme.primary : context.colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Static string constants used across VitaNet.
class AppStrings {
  AppStrings._();

  static const String appName = 'VitaNet';
  static const String appTagline = 'Your AI Health Triage Assistant';

  // Disclaimer
  static const String disclaimer =
      'This is a triage recommendation, not a medical diagnosis. '
      'Always consult a qualified healthcare professional for medical advice.';

  static const String fullDisclaimer =
      'VitaNet is designed to help you assess whether your symptoms suggest '
      'self-care at home, a visit to a pharmacist, or urgent medical attention. '
      'It does NOT provide medical diagnoses, prescriptions, or treatment plans. '
      'Always seek the advice of a qualified healthcare provider with any '
      'questions you may have regarding a medical condition. Never disregard '
      'professional medical advice or delay in seeking it because of something '
      'suggested by this application. If you think you may have a medical '
      'emergency, call your doctor or emergency services immediately.';

  // Onboarding
  static const String onboardingTitle1 = 'Your Health Companion';
  static const String onboardingSubtext1 =
      'Quickly assess your symptoms from the comfort of your home.';
  static const String onboardingTitle2 = 'Smart Triage, Not Diagnosis';
  static const String onboardingSubtext2 =
      'We guide you — Self-care, Pharmacist, or Urgent Care — safely and responsibly.';
  static const String onboardingTitle3 = 'Private & Secure';
  static const String onboardingSubtext3 =
      'Your data stays on your device. We never store personal health data remotely.';

  // Triage Levels
  static const String triageSelfCare = 'Manage at Home';
  static const String triagePharmacist = 'Visit a Pharmacist';
  static const String triageUrgent = 'Seek Urgent Care';

  // Chat
  static const String chatPlaceholder = 'Describe your symptoms...';
  static const String chatGreeting =
      'Hello! I\'m your VitaNet health assistant. 👋\n\n'
      'I can help you figure out whether your symptoms need self-care at home, '
      'a visit to the pharmacist, or urgent medical attention.\n\n'
      'What symptoms are you experiencing today?';
}

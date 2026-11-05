import 'package:flutter_test/flutter_test.dart';
import 'package:vitanet/features/resources/widgets/resource_media.dart';

void main() {
  group('VnTopics strict classification', () {
    test('Olympic mental-health paper is Mental Health, not Sleep', () {
      const title = 'Mental health symptoms and disorders in Olympic athletes';
      expect(VnTopics.categorize(title), equals('Mental Health'));
      expect(VnTopics.photoForArticle(title, 'Mental Health'),
          anyOf(VnPhotos.meditation, VnPhotos.holdingHands));
    });

    test('AI in sports medicine is not Nutrition / pills', () {
      const title = 'Artificial intelligence in sports medicine: a narrative review';
      final category = VnTopics.categorize(title);
      expect(category, isNot('Nutrition'));
      expect(category, isNot('Medicines'));
      expect(VnTopics.photoForArticle(title, category), isNot(VnPhotos.pillsOrange));
    });

    test('Sleep photo only for genuinely sleep-related titles', () {
      expect(VnTopics.categorize('Insomnia and sleep quality in older adults'), equals('Sleep'));
      expect(VnTopics.photoForArticle('Insomnia and sleep quality', 'Sleep'), equals(VnPhotos.sleep));
      expect(VnTopics.categorize('Brain imaging of cortical networks'), isNot('Sleep'));
    });

    test('Unmatched titles fall back to neutral Research category and photo', () {
      const title = 'A graph neural network for protein structure prediction';
      expect(VnTopics.categorize(title), equals(VnTopics.research));
      expect(VnTopics.photoForArticle(title, VnTopics.research), equals(VnPhotos.laptopStethoscope));
    });

    test('Word boundaries: "heartburn" is not Cardiology, "oxidative stress" is not Mental Health', () {
      expect(VnTopics.categorize('Heartburn management in primary care'), isNot('Cardiology'));
      expect(VnTopics.categorize('Oxidative stress markers in cell culture'), isNot('Mental Health'));
    });

    test('Heart and nutrition titles get matching photos', () {
      expect(VnTopics.categorize('Blood pressure control in hypertension'), equals('Cardiology'));
      expect(VnTopics.photoForArticle('Blood pressure control', 'Cardiology'), equals(VnPhotos.bloodPressureCheck));
      expect(VnTopics.categorize('Mediterranean diet and healthy eating'), equals('Nutrition'));
      expect(VnTopics.photoForArticle('Dietary patterns', 'Nutrition'),
          anyOf(VnPhotos.healthyPlate, VnPhotos.saladBowl));
    });

    test('Respiratory, Endocrinology, and Women\'s Health get dedicated topic photos', () {
      expect(VnTopics.categorize('Asthma control and pulmonary function'), equals('Respiratory'));
      expect(VnTopics.photoForArticle('Asthma control and pulmonary function', 'Respiratory'), equals(VnPhotos.respiratoryHealth));

      expect(VnTopics.categorize('Insulin resistance and glucose metabolism in type 2 diabetes'), equals('Endocrinology'));
      expect(VnTopics.photoForArticle('Glucose monitoring in type 2 diabetes', 'Endocrinology'), equals(VnPhotos.glucoseMonitoring));

      expect(VnTopics.categorize('Maternal health and prenatal care guidelines'), equals("Women's Health"));
      expect(VnTopics.photoForArticle('Maternal health assessment', "Women's Health"), equals(VnPhotos.clinicianFemale));
    });
  });
}

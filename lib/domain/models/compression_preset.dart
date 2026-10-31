/// مستويات ضغط ملفات الـ PDF الثلاثة المحددة في وثيقة المتطلبات.
enum CompressionLevel {
  light(
    id: 'light',
    title: 'ضغط خفيف',
    subtitle: 'دقة 300 DPI — يحافظ على وضوح الطباعة الكامل',
    imageQuality: 85,
    targetDpi: 300,
    expectedRatio: 0.75,
    isRecommended: false,
  ),
  medium(
    id: 'medium',
    title: 'ضغط متوسط',
    subtitle: 'دقة 150 DPI — توازن مثالي بين الوضوح والحجم',
    imageQuality: 55,
    targetDpi: 150,
    expectedRatio: 0.20,
    isRecommended: true,
  ),
  extreme(
    id: 'extreme',
    title: 'ضغط أقصى',
    subtitle: 'دقة 96 DPI — أصغر حجم ممكن للمراسلة السريعة',
    imageQuality: 30,
    targetDpi: 96,
    expectedRatio: 0.12,
    isRecommended: false,
  );

  const CompressionLevel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageQuality,
    required this.targetDpi,
    required this.expectedRatio,
    required this.isRecommended,
  });

  final String id;
  final String title;
  final String subtitle;
  final int imageQuality;
  final int targetDpi;
  final double expectedRatio;
  final bool isRecommended;
}

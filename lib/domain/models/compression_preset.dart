/// مستويات ضغط ملفات الـ PDF الثلاثة المحددة في وثيقة المتطلبات.
enum CompressionLevel {
  light(
    id: 'light',
    title: 'ضغط خفيف (أعلى جودة)',
    subtitle: 'دقة 300 DPI — يحافظ على وضوح الطباعة الكامل',
    imageQuality: 72,
    targetDpi: 300,
    expectedRatio: 0.72,
    isRecommended: false,
  ),
  medium(
    id: 'medium',
    title: 'ضغط متوسط (موصى به)',
    subtitle: 'دقة 150 DPI — توازن مثالي بين الوضوح والحجم',
    imageQuality: 48,
    targetDpi: 150,
    expectedRatio: 0.45,
    isRecommended: true,
  ),
  extreme(
    id: 'extreme',
    title: 'ضغط أقصى (أصغر حجم)',
    subtitle: 'دقة 96 DPI — أصغر حجم ممكن للمراسلة السريعة',
    imageQuality: 26,
    targetDpi: 96,
    expectedRatio: 0.25,
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

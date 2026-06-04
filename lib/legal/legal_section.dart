class LegalSection {
  final String id;
  final String title;
  final List<String> paragraphs;
  final List<String> bullets;

  const LegalSection({
    required this.id,
    required this.title,
    this.paragraphs = const [],
    this.bullets = const [],
  });
}

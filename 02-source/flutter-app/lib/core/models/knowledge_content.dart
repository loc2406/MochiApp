/// A presentation check only: prose length cannot verify academic correctness.
bool hasKnowledgeExplanation(String text) {
  final prose = text
      .replaceAll(
        RegExp(
          r'\$\$[\s\S]*?\$\$|\$[^\$]*\$|\\\([\s\S]*?\\\)|\\\[[\s\S]*?\\\]',
        ),
        ' ',
      )
      .replaceAll(RegExp(r'\\[A-Za-z]+'), ' ');
  return RegExp(r'[a-zA-ZÀ-ỹ]{2,}').allMatches(prose).length >= 20;
}

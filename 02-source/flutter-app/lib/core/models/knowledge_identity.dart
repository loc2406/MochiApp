/// Old releases assigned the same millisecond ID to a whole generated deck.
/// Preserve every card, with deterministic IDs across devices; never deduplicate
/// by ID and discard distinct learning content.
List<Map<String, dynamic>> repairKnowledgeIds(List<Map<String, dynamic>> rows) {
  final used = <String>{};
  final result = <Map<String, dynamic>>[];
  for (final row in rows) {
    final copy = Map<String, dynamic>.from(row);
    final original = (copy['id'] ?? '').toString();
    var id = original;
    if (id.isEmpty || used.contains(id)) {
      final payload = '${copy['deckId']}|${copy['front']}|${copy['back']}';
      var hash = 2166136261;
      for (final unit in payload.codeUnits) {
        hash = ((hash ^ unit) * 16777619) & 0xffffffff;
      }
      final base =
          '${original.isEmpty ? 'legacy_card' : original}_recovered_${hash.toRadixString(16)}';
      id = base;
      var duplicate = 1;
      while (used.contains(id)) {
        id = '${base}_${duplicate++}';
      }
      copy['id'] = id;
    }
    used.add(id);
    result.add(copy);
  }
  return result;
}

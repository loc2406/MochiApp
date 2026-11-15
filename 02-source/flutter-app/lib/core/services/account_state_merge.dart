class AccountStateConflict implements Exception {
  final String path;
  const AccountStateConflict(this.path);
}

const _absent = Object();

/// Merge changes relative to an acknowledged DB snapshot. Concurrent edits to
/// different fields/entities merge; incompatible edits are preserved, not guessed.
Map<String, dynamic> mergeAccountState(
  Map<String, dynamic> base,
  Map<String, dynamic> local,
  Map<String, dynamic> remote,
) => Map<String, dynamic>.from(_merge(base, local, remote, '') as Map);

bool _same(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && _same(a[k], b[k]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        Iterable<int>.generate(a.length).every((i) => _same(a[i], b[i]));
  }
  return a == b;
}

Object? _merge(Object? base, Object? local, Object? remote, String path) {
  if (_same(local, base)) return remote;
  if (_same(remote, base) || _same(local, remote)) return local;
  if (base is Map && local is Map && remote is Map) {
    final result = <String, dynamic>{};
    for (final k in {...base.keys, ...local.keys, ...remote.keys}) {
      final merged = _merge(
        base.containsKey(k) ? base[k] : _absent,
        local.containsKey(k) ? local[k] : _absent,
        remote.containsKey(k) ? remote[k] : _absent,
        '$path/$k',
      );
      if (!identical(merged, _absent)) result[k.toString()] = merged;
    }
    return result;
  }
  bool keyed(Object? list) =>
      list is List && list.every((v) => v is Map && v['id'] != null);
  if (keyed(base) && keyed(local) && keyed(remote)) {
    Map<String, dynamic> index(Object? v) => {
      for (final item in v as List) (item as Map)['id'].toString(): item,
    };
    return (_merge(index(base), index(local), index(remote), path) as Map)
        .values
        .toList();
  }
  throw AccountStateConflict(path);
}

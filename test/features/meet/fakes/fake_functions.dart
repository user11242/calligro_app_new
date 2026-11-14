/// Records every Cloud Function call and answers from a script.
class FakeFunctions {
  final calls = <(String, Map<String, dynamic>)>[];
  final List<Object? Function(String, Map<String, dynamic>)> _answers = [];

  void answer(Object? Function(String name, Map<String, dynamic> data) a) => _answers.add(a);
  void answerWith(Object? value) => answer((_, _) => value);
  void failWith(Object error) => answer((_, _) => throw error);

  Future<Object?> call(String name, Map<String, dynamic> data) async {
    calls.add((name, Map.of(data)));
    if (_answers.isEmpty) return null;
    final next = _answers.length > 1 ? _answers.removeAt(0) : _answers.first;
    return next(name, data);
  }
}

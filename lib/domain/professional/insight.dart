/// One thing somebody agreed to do.
final class ActionItem {
  /// Creates an action item.
  const ActionItem({required this.description, this.owner, this.deadline});

  /// What is to be done.
  final String description;

  /// Who is to do it, when the transcript named someone.
  final String? owner;

  /// When it is due, as the transcript expressed it — kept as text because
  /// "before Eid" is a real deadline and is not a DateTime.
  final String? deadline;

  @override
  bool operator ==(Object other) =>
      other is ActionItem &&
      other.description == description &&
      other.owner == owner &&
      other.deadline == deadline;

  @override
  int get hashCode => Object.hash(description, owner, deadline);
}

/// The AI summary of a session.
///
/// Always displayed with the disclaimer: AI output is never presented as
/// authoritative (docs/instructions.md §3).
final class Insight {
  /// Creates an insight.
  const Insight({
    required this.summary,
    required this.generatedAt,
    this.keyPoints = const <String>[],
    this.actionItems = const <ActionItem>[],
    this.people = const <String>[],
  });

  /// A few sentences describing the session.
  final String summary;

  /// The main points.
  final List<String> keyPoints;

  /// What people committed to.
  final List<ActionItem> actionItems;

  /// People the transcript mentioned.
  final List<String> people;

  /// When this was generated.
  final DateTime generatedAt;

  /// Whether the model returned anything worth showing.
  bool get isEmpty =>
      summary.trim().isEmpty && keyPoints.isEmpty && actionItems.isEmpty;
}

// lib/models/tree_spot.dart
import '../services/ml_service.dart' show LabelResult;
import 'comment.dart';

class TreeSpot {
  final String id;
  final double lat;
  final double lng;
  final String? comment;     // заметка автора точки
  final String? imagePath;   // локальный путь к фото
  final List<LabelResult> labels;
  final DateTime createdAt;
  final List<Comment> comments;

  const TreeSpot({
    required this.id,
    required this.lat,
    required this.lng,
    required this.labels,
    required this.createdAt,
    this.comment,
    this.imagePath,
    this.comments = const [],
  });

  TreeSpot copyWith({
    String? id,
    double? lat,
    double? lng,
    String? comment,
    String? imagePath,
    List<LabelResult>? labels,
    DateTime? createdAt,
    List<Comment>? comments,
  }) {
    return TreeSpot(
      id: id ?? this.id,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      comment: comment ?? this.comment,
      imagePath: imagePath ?? this.imagePath,
      labels: labels ?? this.labels,
      createdAt: createdAt ?? this.createdAt,
      comments: comments ?? this.comments,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'lat': lat,
    'lng': lng,
    'comment': comment,
    'imagePath': imagePath,
    'labels': labels.map((e) => e.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'comments': comments.map((c) => c.toJson()).toList(),
  };

  factory TreeSpot.fromJson(Map<String, dynamic> json) => TreeSpot(
    id: json['id'] as String,
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    comment: json['comment'] as String?,
    imagePath: json['imagePath'] as String?,
    labels: (json['labels'] as List<dynamic>? ?? [])
        .map((e) => LabelResult.fromJson(e as Map<String, dynamic>))
        .toList(),
    createdAt:
    DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    comments: (json['comments'] as List<dynamic>? ?? [])
        .map((e) => Comment.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

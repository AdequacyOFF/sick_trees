class TreeSpot {
  final String id;
  final double lat;
  final double lng;
  final String? comment;
  final String? imagePath;
  final List<LabelResult> labels;
  final DateTime createdAt;

  TreeSpot({
    required this.id,
    required this.lat,
    required this.lng,
    required this.labels,
    this.comment,
    this.imagePath,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'lat': lat,
        'lng': lng,
        'comment': comment,
        'imagePath': imagePath,
        'labels': labels.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory TreeSpot.fromJson(Map<String, dynamic> json) => TreeSpot(
        id: json['id'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        comment: json['comment'] as String?,
        imagePath: json['imagePath'] as String?,
        labels: (json['labels'] as List<dynamic>)
            .map((e) => LabelResult.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class LabelResult {
  final String label;
  final double confidence;
  LabelResult({required this.label, required this.confidence});

  Map<String, dynamic> toJson() => {
        'label': label,
        'confidence': confidence,
      };

  factory LabelResult.fromJson(Map<String, dynamic> json) => LabelResult(
        label: json['label'] as String,
        confidence: (json['confidence'] as num).toDouble(),
      );
}
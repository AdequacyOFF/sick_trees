// lib/models/analysis_results.dart
class AnalysisSummary {
  final int instances;
  final List<String> instanceDirs;

  AnalysisSummary({
    required this.instances,
    required this.instanceDirs,
  });

  factory AnalysisSummary.fromJson(Map<String, dynamic> json) {
    return AnalysisSummary(
      instances: json['instances'] as int,
      instanceDirs: List<String>.from(json['instance_dirs']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'instances': instances,
      'instance_dirs': instanceDirs,
    };
  }
}

class TreeReport {
  final String type;
  final double score;
  final List<int> bbox;
  final double leanAngle;
  final int topK;
  final String species;
  final double speciesScore;
  final List<SpeciesPrediction> topKSpecies;
  final List<Disease> diseases;

  TreeReport({
    required this.type,
    required this.score,
    required this.bbox,
    required this.leanAngle,
    required this.topK,
    required this.species,
    required this.speciesScore,
    required this.topKSpecies,
    required this.diseases,
  });

  factory TreeReport.fromJson(Map<String, dynamic> json) {
    return TreeReport(
      type: json['type'] as String,
      score: (json['score'] as num).toDouble(),
      bbox: List<int>.from(json['bbox']),
      leanAngle: (json['lean_angle'] as num).toDouble(),
      topK: json['top_k'] as int,
      species: json['species'] as String,
      speciesScore: (json['species_score'] as num).toDouble(),
      topKSpecies: (json['top_k_species'] as List)
          .map((e) => SpeciesPrediction.fromJson(e))
          .toList(),
      diseases: (json['diseases'] as List)
          .map((e) => Disease.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'score': score,
      'bbox': bbox,
      'lean_angle': leanAngle,
      'top_k': topK,
      'species': species,
      'species_score': speciesScore,
      'top_k_species': topKSpecies.map((e) => e.toJson()).toList(),
      'diseases': diseases.map((e) => e.toJson()).toList(),
    };
  }
}

class SpeciesPrediction {
  final String label;
  final double prob;

  SpeciesPrediction({
    required this.label,
    required this.prob,
  });

  factory SpeciesPrediction.fromJson(Map<String, dynamic> json) {
    return SpeciesPrediction(
      label: json['label'] as String,
      prob: (json['prob'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'prob': prob,
    };
  }
}

class Disease {
  final String name;
  final double score;

  Disease({
    required this.name,
    required this.score,
  });

  factory Disease.fromJson(Map<String, dynamic> json) {
    // diseases приходят как [{"crown damage": 0.39}, {"trunk damage": 0.41}]
    final entry = json.entries.first;
    return Disease(
      name: entry.key,
      score: (entry.value as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {name: score};
  }
}
class SplitPerson {
  final String id;
  final String name;

  const SplitPerson({
    required this.id,
    required this.name,
  });

  SplitPerson copyWith({
    String? id,
    String? name,
  }) {
    return SplitPerson(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };

  factory SplitPerson.fromJson(Map<String, dynamic> json) {
    return SplitPerson(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

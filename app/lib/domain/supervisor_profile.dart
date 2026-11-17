enum SupervisorType { permanent, acting }

class SupervisorProfile {
  const SupervisorProfile({
    required this.id,
    required this.name,
    this.type = SupervisorType.permanent,
    this.phone = '',
    this.notes = '',
  });

  final String id;
  final String name;
  final SupervisorType type;
  final String phone;
  final String notes;

  SupervisorProfile copyWith({
    String? name,
    SupervisorType? type,
    String? phone,
    String? notes,
  }) => SupervisorProfile(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    phone: phone ?? this.phone,
    notes: notes ?? this.notes,
  );

  @override
  bool operator ==(Object other) =>
      other is SupervisorProfile &&
      other.id == id &&
      other.name == name &&
      other.type == type &&
      other.phone == phone &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(id, name, type, phone, notes);
}

enum EnergyTag { low, moderate, high, flexible }

class TaskEntity {
  final int id;
  final String title;
  final String? description;
  final EnergyTag energyTag;
  final String targetPhase; // Menstrual, Follicular, Ovulation, Luteal, All
  final String priority; // Low, Medium, High
  final bool isCompleted;
  final DateTime? dueDate;
  final int estimatedMinutes;
  final String category;

  const TaskEntity({
    required this.id,
    required this.title,
    this.description,
    this.energyTag = EnergyTag.flexible,
    this.targetPhase = 'All',
    this.priority = 'Medium',
    this.isCompleted = false,
    this.dueDate,
    this.estimatedMinutes = 30,
    this.category = 'General',
  });
}

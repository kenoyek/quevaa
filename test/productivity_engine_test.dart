import 'package:flutter_test/flutter_test.dart';
import 'package:quevaa/features/productivity/domain/entities/task_entity.dart';
import 'package:quevaa/features/productivity/domain/productivity_engine.dart';

void main() {
  group('Phase 7: Productivity Engine Unit Tests', () {
    test(
      'Ranks Low energy tasks first when user energy is low or pain is high',
      () {
        final tasks = [
          const TaskEntity(
            id: 1,
            title: 'Record Course Video',
            energyTag: EnergyTag.high,
          ),
          const TaskEntity(
            id: 2,
            title: 'Organize Email Inbox',
            energyTag: EnergyTag.low,
          ),
          const TaskEntity(
            id: 3,
            title: 'Review Weekly Board',
            energyTag: EnergyTag.moderate,
          ),
        ];

        final ranked = ProductivityEngine.rankTasks(
          tasks: tasks,
          userEnergyLevel: 2,
          userPainLevel: 3,
        );

        expect(ranked.first.title, 'Organize Email Inbox');
      },
    );

    test(
      'Ranks High energy tasks first when user energy is high and pain is 0',
      () {
        final tasks = [
          const TaskEntity(
            id: 1,
            title: 'Organize Files',
            energyTag: EnergyTag.low,
          ),
          const TaskEntity(
            id: 2,
            title: 'Presentation Launch',
            energyTag: EnergyTag.high,
          ),
        ];

        final ranked = ProductivityEngine.rankTasks(
          tasks: tasks,
          userEnergyLevel: 5,
          userPainLevel: 0,
        );

        expect(ranked.first.title, 'Presentation Launch');
      },
    );
  });
}

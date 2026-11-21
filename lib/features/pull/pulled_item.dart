import '../../core/task.dart';

/// One entry of DeskPlan's answer to "what changed?".
sealed class PulledItem {
  const PulledItem();
}

/// A task as DeskPlan has it now.
class PulledTask extends PulledItem {
  final Task task;
  const PulledTask(this.task);
}

/// DeskPlan deleted this task, or it stopped being a task or assignment
/// there. Either way it goes from the phone.
class PulledDeletion extends PulledItem {
  final String id;
  const PulledDeletion(this.id);
}

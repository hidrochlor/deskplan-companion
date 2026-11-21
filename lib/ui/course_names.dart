import '../core/task.dart';
import '../features/connection/destination.dart';

/// The course to show for an item (protocol.md section 4 "Assignments, steps
/// and courses"). DeskPlan sends it as `course` and the phone shows that.
/// Only a DeskPlan from before the calendar leaves it out: then the
/// top-level folder of the item's path stands in.
class CourseNames {
  /// DeskPlan's folders, from the ping (`destinations`).
  final List<Destination> folders;

  /// The phone's items by id, to find the assignment a step sits in.
  final Map<String, Task> byId;

  CourseNames(this.folders, Iterable<Task> items)
    : byId = {for (final t in items) t.id: t};

  /// The path separator in a destination's `label` ("CSC101 › Week 1").
  static const _separator = ' › ';

  String? of(Task task) => _of(task, 0);

  String? _of(Task task, int depth) {
    if (task.courseKnown) return task.course;
    final parent = task.parentId;
    if (parent == null || depth > 50) return null;
    for (final d in folders) {
      if (d.id == 'folder:$parent') return d.label.split(_separator).first;
    }
    // Not a folder: a step inside an assignment has the assignment's course.
    final holder = byId[parent];
    return holder == null ? null : _of(holder, depth + 1);
  }
}

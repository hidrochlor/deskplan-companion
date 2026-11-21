import '../../core/task.dart';
import '../../features/connection/destination.dart';

/// Where a note can sit (protocol.md section 4 "Where things may live"):
/// the top level of Home, a folder, or an assignment. Folders come from
/// DeskPlan's `destinations`; assignments are the ones the phone has, each
/// listed under its folder.
class NotePlaces {
  static const homeId = '';
  static const _folder = 'folder:';
  static const _assignment = 'assignment:';

  /// For the picker: Home first, then the tree of folders and assignments.
  final List<Destination> entries;

  /// Which [entries] are assignments.
  final Set<String> assignmentIds;

  final Map<String, String> _names;

  /// The full path of each place ("CSC101 › Week 1 › HW 2").
  final Map<String, String> _paths;

  NotePlaces._(this.entries, this.assignmentIds, this._names, this._paths);

  factory NotePlaces(List<Destination> folders, List<Task> assignments) {
    final entries = <Destination>[const Destination(id: homeId, label: 'Home')];
    final assignmentIds = <String>{};
    final names = <String, String>{};
    final paths = <String, String>{};
    final placed = <String>{};

    void addAssignment(Task a, {String? folderLabel, int depth = 0}) {
      final id = '$_assignment${a.id}';
      final title = a.title.isEmpty ? 'Untitled assignment' : a.title;
      final label = folderLabel == null ? title : '$folderLabel › $title';
      entries.add(Destination(id: id, label: label, name: title, depth: depth));
      assignmentIds.add(id);
      names[id] = title;
      paths[id] = label;
      placed.add(a.id);
    }

    for (final folder in folders) {
      entries.add(folder);
      names[folder.id] = folder.name ?? folder.label;
      paths[folder.id] = folder.label;
      for (final a in assignments) {
        if (folder.id == '$_folder${a.parentId}') {
          addAssignment(a, folderLabel: folder.label, depth: folder.depth + 1);
        }
      }
    }
    // An assignment whose folder the phone has not heard of yet.
    for (final a in assignments) {
      if (!placed.contains(a.id)) addAssignment(a);
    }
    return NotePlaces._(entries, assignmentIds, names, paths);
  }

  /// The picker id for a note's [parentId].
  String idFor(String? parentId) {
    if (parentId == null) return homeId;
    final asAssignment = '$_assignment$parentId';
    return assignmentIds.contains(asAssignment)
        ? asAssignment
        : '$_folder$parentId';
  }

  /// The note's `parentId` for a picker id (null for Home).
  static String? parentIdFor(String id) {
    if (id == homeId) return null;
    if (id.startsWith(_assignment)) return id.substring(_assignment.length);
    if (id.startsWith(_folder)) return id.substring(_folder.length);
    return id;
  }

  /// A short name of where [parentId] is, if the phone knows it.
  String? nameOf(String? parentId) =>
      parentId == null ? null : _names[idFor(parentId)];

  /// The folders down to where [parentId] is ("CSC101 › Week 1"), or null
  /// for the top level of Home or a place the phone does not know.
  String? placeOf(String? parentId) =>
      parentId == null ? null : _paths[idFor(parentId)];

  /// The whole way down from Home to where [parentId] is
  /// ("Home › CSC101 › Week 1"); just "Home" for the top level or a place
  /// the phone does not know.
  String pathOf(String? parentId) {
    final path = parentId == null ? null : _paths[idFor(parentId)];
    return path == null ? 'Home' : 'Home › $path';
  }
}

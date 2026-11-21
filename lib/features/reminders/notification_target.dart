/// What a tapped notification is about, so the app can open it. Stored in
/// the notification as its payload text: `item:<id>` for a task, assignment
/// or step reminder, `event:<id>` for an exam reminder.
sealed class NotificationTarget {
  const NotificationTarget();

  static const _item = 'item:';
  static const _event = 'event:';

  /// The payload for one of the phone's items.
  static String forItem(String id) => '$_item$id';

  /// The payload for a calendar event (an exam).
  static String forEvent(String id) => '$_event$id';

  /// Reads a payload. Null for none, or one that opens nothing in particular
  /// (the daily goal).
  static NotificationTarget? parse(String? payload) {
    if (payload == null) return null;
    if (payload.startsWith(_item) && payload.length > _item.length) {
      return ItemTarget(payload.substring(_item.length));
    }
    if (payload.startsWith(_event) && payload.length > _event.length) {
      return EventTarget(payload.substring(_event.length));
    }
    return null;
  }
}

/// A task, assignment or step, by its id.
class ItemTarget extends NotificationTarget {
  final String id;
  const ItemTarget(this.id);
}

/// A calendar event, by its id.
class EventTarget extends NotificationTarget {
  final String id;
  const EventTarget(this.id);
}

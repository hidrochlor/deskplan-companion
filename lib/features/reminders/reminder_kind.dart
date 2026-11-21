/// The reminders a task can have: when it starts, when it is due, and the
/// optional warnings before it is due. New kinds go at the end: start and end
/// are told apart by their place, and saved reminders keep their ids.
enum ReminderKind {
  start,
  end,
  dayBefore,
  hourBefore,
  minutes30Before,
  hours3Before,
  hours5Before,
}

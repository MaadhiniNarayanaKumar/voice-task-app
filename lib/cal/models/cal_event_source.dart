/// Where a [CalEvent] came from. Views / voice / free-time treat them alike.
enum CalEventSource {
  /// Written in-app (add form, paste, voice later).
  manual,

  /// Chrome extension (or other clients) writing to Firestore.
  extension,

  /// Synced from Google Calendar (optional; deferred).
  google,

  /// Imported from an .ics / invite file (later).
  ics,
}

extension CalEventSourceX on CalEventSource {
  String get wireName => name;

  static CalEventSource fromWire(String? value) {
    switch (value) {
      case 'extension':
        return CalEventSource.extension;
      case 'google':
        return CalEventSource.google;
      case 'ics':
        return CalEventSource.ics;
      case 'manual':
      default:
        return CalEventSource.manual;
    }
  }

  String get label {
    switch (this) {
      case CalEventSource.manual:
        return 'Manual';
      case CalEventSource.extension:
        return 'Extension';
      case CalEventSource.google:
        return 'Google';
      case CalEventSource.ics:
        return 'Invite';
    }
  }
}

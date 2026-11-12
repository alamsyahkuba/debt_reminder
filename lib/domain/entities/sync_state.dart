/// Local synchronization state for a business entity.
enum SyncState {
  pending,
  synced,
  conflict;

  static SyncState fromDatabase(String value) {
    return values.firstWhere(
      (state) => state.name == value,
      orElse: () => SyncState.pending,
    );
  }
}

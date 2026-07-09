/// Which experience the portal locked onto for this install.
///
/// - [webShell]   → the previous launch routed the user to the WebView.
/// - [nativeShow] → the previous launch routed the user to the game.
/// - [unset]      → first launch, no decision has been persisted yet.
enum AppFlavor {
  webShell,
  nativeShow,
  unset;

  static AppFlavor read(String? raw) {
    switch (raw) {
      case 'webShell':
        return AppFlavor.webShell;
      case 'nativeShow':
        return AppFlavor.nativeShow;
      default:
        return AppFlavor.unset;
    }
  }

  String write() => name;
}

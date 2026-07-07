/// Central place for every asset path used across the app so a typo
/// only ever has to be fixed in one spot.
class AppAssets {
  AppAssets._();

  static const String background = 'assets/Background_FestivalStreet.webp';
  static const String festivalStar = 'assets/Collectible_FestivalStar.webp';
  static const String shadowMime = 'assets/Enemy_ShadowMime.webp';
  static const String streetGremlin = 'assets/Enemy_StreetGremlin.webp';
  static const String gameLogo = 'assets/Game_Name.webp';
  static const String hero = 'assets/Hero.webp';
  static const String horizontalLoading = 'assets/Horizontal_Loading.webp';
  static const String icon = 'assets/Icon.png';
  static const String magicLantern = 'assets/Obstacle_MagicLantern.webp';
  static const String carnivalFever = 'assets/Powerup_CarnivalFever.webp';
  static const String verticalLoading = 'assets/Vertical_Loading.webp';

  /// All assets that should be pre-cached before the loading screen
  /// reports 100% progress, ensuring the progress bar can never finish
  /// before the app is actually ready to play.
  static const List<String> precacheTargets = [
    background,
    festivalStar,
    shadowMime,
    streetGremlin,
    gameLogo,
    hero,
    magicLantern,
    carnivalFever,
  ];
}

/// Product-level constants shared by the UI, services and documentation.
class AppInfo {
  AppInfo._();

  static const String name = 'Hydrogen Chloride Launcher';
  static const String shortName = 'HCl Launcher';
  static const String version = '0.1.0-alpha.2';
  static const String channel = 'Alpha';
  static const String license = 'GPL-3.0-only';
  static const String githubUrl =
      'https://github.com/HyaLab/HydrogenChlorideLauncher';
  static const String issuesUrl = '$githubUrl/issues';
  static const String microsoftClientIdEnv = 'HCL_MS_CLIENT_ID';

  /// Default public client so the launcher can sign in without each user
  /// registering their own Azure app. Users may override it in settings.
  static const String defaultMicrosoftClientId = '00000000402b5328';

  static const String disclaimer =
      'Hydrogen Chloride Launcher 是非官方的第三方启动器，与 Mojang Studios、'
      'Microsoft 或任何模组/整合包作者均无隶属关系。Minecraft 是 Mojang Studios 的商标。'
      '使用本软件下载、安装和启动的内容由用户自行负责，请遵守相应内容的许可协议。';

  static const String demoNotice = 'Alpha 版本：浏览、社区与启动流程使用演示数据。';
}

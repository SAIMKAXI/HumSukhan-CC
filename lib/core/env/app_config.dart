/// Build-time configuration.
///
/// No third-party API key ever appears here. Provider credentials live in
/// Supabase Edge Functions; the client receives short-lived tokens only
/// (architecture.md §11). The two values below are a project URL and its
/// publishable anon key, both of which are safe in a client and are useless
/// without the row-level-security policies behind them.
final class AppConfig {
  /// Creates a configuration.
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.tokenFunction = 'deepgram-token',
    this.summariseFunction = 'summarise-session',
    this.cloudTtsFunction = 'synthesise-speech',
  });

  /// Reads the configuration from `--dart-define`s.
  factory AppConfig.fromEnvironment() => const AppConfig(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  /// The Supabase project URL.
  final String supabaseUrl;

  /// The publishable anon key.
  final String supabaseAnonKey;

  /// Edge Function that mints short-lived recognition tokens.
  final String tokenFunction;

  /// Edge Function that summarises a transcript.
  final String summariseFunction;

  /// Edge Function that synthesises speech when the platform engine cannot.
  final String cloudTtsFunction;

  /// Whether a backend is configured at all.
  ///
  /// When false the app still runs: recognition and summaries report a specific
  /// failure with a remedy instead of appearing to work.
  bool get hasBackend =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;
}

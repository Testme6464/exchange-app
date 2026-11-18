// Supabase connection settings — the SAME project as the website
// (see baht-kyat-exchange/js/config.js). The anon key is publishable by
// design: row-level security (RLS) is what protects the data. NEVER put
// the service_role key here.
//
// GOOGLE_WEB_CLIENT_ID: the OAuth "Web application" client ID from
// Google Cloud Console (APIs & Services > Credentials). It is filled in
// after the OAuth setup (see README.md). While it is empty, the Google
// sign-in button is hidden and email/password sign-in works normally.
class AppConfig {
  AppConfig._();

  static const String supabaseUrl =
      'https://mottxqcfmsgbcuzcdpve.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1vdHR4cWNmbXNnYmN1emNkcHZlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ4NTk1NDgsImV4cCI6MjExMDQzNTU0OH0.vY1bncSmLFbZ2W_O3zUzn4yGmHMvu4rLlBSGkIa7lP8';

  /// Web OAuth client ID for Google sign-in. Empty until OAuth is set up.
  static const String googleWebClientId = '';

  static bool get googleSignInConfigured => googleWebClientId.isNotEmpty;
}

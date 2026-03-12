import 'package:shared_preferences/shared_preferences.dart';

const _keySaveLogin = 'login_save_credentials';
const _keySavedEmail = 'login_saved_email';

/// Preferências de login: lembrar e-mail para pré-preenchimento.
class LoginPreferences {
  LoginPreferences._();

  /// Por padrão true: "Salvar login" fica marcado na primeira vez.
  static Future<bool> get saveLogin async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySaveLogin) ?? true;
  }

  static Future<void> setSaveLogin(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySaveLogin, value);
    if (!value) await prefs.remove(_keySavedEmail);
  }

  static Future<String?> get savedEmail async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySavedEmail);
  }

  static Future<void> setSavedEmail(String? email) async {
    final prefs = await SharedPreferences.getInstance();
    if (email == null || email.isEmpty) {
      await prefs.remove(_keySavedEmail);
    } else {
      await prefs.setString(_keySavedEmail, email);
    }
  }
}

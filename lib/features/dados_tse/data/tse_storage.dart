import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const _keyRows = 'tse_csv_rows';
const _keyNmVotavel = 'tse_nm_votavel_selected';

/// Persiste e carrega dados TSE (linhas do CSV e nome do candidato em NM_VOTAVEL).
class TseStorage {
  static Future<void> saveRows(List<Map<String, dynamic>> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRows, jsonEncode(rows));
  }

  static Future<List<Map<String, dynamic>>> loadRows() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_keyRows);
    if (s == null || s.isEmpty) return [];
    try {
      final list = jsonDecode(s) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveNmVotavelSelected(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.isEmpty) {
      await prefs.remove(_keyNmVotavel);
    } else {
      await prefs.setString(_keyNmVotavel, value);
    }
  }

  static Future<String?> loadNmVotavelSelected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyNmVotavel);
  }
}

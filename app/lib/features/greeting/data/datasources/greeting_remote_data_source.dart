import 'package:dio/dio.dart';

/// Source de données distante de la feature `greeting`.
///
/// Contrat (couche data) : expose un appel **brut** au backend. Peut lever une
/// [DioException] (ou [FormatException] si la réponse est malformée) ; la
/// conversion en `Result`/`Failure` est faite par le repository.
abstract interface class GreetingRemoteDataSource {
  /// Appelle `GET /api/v1/greeting?name=<name>` et renvoie le champ `message`.
  ///
  /// [name] vide → l'argument est omis (le backend renvoie alors la salutation
  /// générique « Bonjour, monde ! 👋 »).
  Future<String> fetchGreeting(String name);
}

/// Implémentation HTTP sur [Dio].
///
/// Tape le backend Rust via le client transverse (baseUrl par flavor). Le
/// chemin de version `/api/v1` est porté **ici** : bumper l'API = changer cette
/// constante (et la datasource concernée), pas la config.
class GreetingHttpDataSource implements GreetingRemoteDataSource {
  const GreetingHttpDataSource(this._dio);

  static const _path = '/api/v1/greeting';

  final Dio _dio;

  @override
  Future<String> fetchGreeting(String name) async {
    final response = await _dio.get<Map<String, dynamic>>(
      _path,
      // name vide → param omis (contrat : absent ⇒ salutation générique).
      queryParameters: name.isEmpty ? null : {'name': name},
    );

    final message = response.data?['message'];
    if (message is! String) {
      throw const FormatException(
        'Réponse /greeting invalide : champ "message" absent ou non-string.',
      );
    }
    return message;
  }
}

import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/product.dart';

enum AttachmentKind {
  photo('foto', 'Foto do produto', ['png', 'jpg', 'jpeg']),
  sheet('ficha', 'Ficha técnica', ['pdf']);

  const AttachmentKind(this.path, this.label, this.extensions);

  final String path;
  final String label;
  final List<String> extensions;
}

class Attachment {
  Attachment.fromJson(Map<String, dynamic> json)
    : name = json['nome'] as String,
      size = json['tamanho'] as int;

  final String name;
  final int size;

  static String formatSize(int bytes) =>
      bytes < 1024 ? '$bytes B' : '${(bytes / 1024).toStringAsFixed(1)} KiB';
}

class CatalogEntry {
  CatalogEntry.fromJson(Map<String, dynamic> json)
    : product = Product.fromJson(json),
      attachments = {
        for (final field in (json['anexos'] as Map<String, dynamic>).entries)
          AttachmentKind.values.firstWhere((kind) => kind.path == field.key):
              Attachment.fromJson(field.value as Map<String, dynamic>),
      };

  final Product product;
  final Map<AttachmentKind, Attachment> attachments;
}

class StaffProfile {
  StaffProfile.fromJson(Map<String, dynamic> json)
    : email = json['email'] as String,
      canUpload = json['perfil'] == 'funcionario';

  final String email;
  final bool canUpload;
}

class StaffApiError implements Exception {
  const StaffApiError(this.status, this.message);

  final int? status;
  final String message;

  @override
  String toString() => status == null ? message : 'HTTP $status · $message';
}

// Centraliza os pedidos à API para as telas trabalharem com dados e erros já interpretados.
class StaffApi {
  StaffApi()
    : _dio = Dio(
        BaseOptions(
          baseUrl: const String.fromEnvironment(
            'STAFF_API_URL',
            defaultValue:
                'https://lanche-facil-etapa3.mateus2002ns.workers.dev',
          ),
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 25),
          sendTimeout: const Duration(seconds: 25),
        ),
      );

  static const maxBytes = 1024 * 1024;
  final Dio _dio;

  // O mesmo formulário escolhe a rota de cadastro ou login. As duas emitem um token.
  Future<({String token, StaffProfile profile})> signIn(
    String email,
    String password, {
    required bool signup,
  }) async {
    final data = await _call(
      () => _dio.post<Map<String, dynamic>>(
        signup ? '/auth/cadastro' : '/auth/login',
        data: {'email': email, 'senha': password},
      ),
    );
    return (
      token: data['token'] as String,
      profile: StaffProfile.fromJson(data),
    );
  }

  Future<StaffProfile> profile(String token) async {
    final data = await _call(
      () => _dio.get<Map<String, dynamic>>(
        '/auth/perfil',
        options: _bearer(token),
      ),
    );
    return StaffProfile.fromJson(data);
  }

  Future<void> logout(String token) async {
    await _call(
      () => _dio.post<Map<String, dynamic>>(
        '/auth/logout',
        options: _bearer(token),
      ),
    );
  }

  Future<List<CatalogEntry>> catalog(String token) async {
    final data = await _call(
      () => _dio.get<List<dynamic>>('/produtos', options: _bearer(token)),
    );
    return data
        .map((item) => CatalogEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // Envia os bytes no campo multipart 'arquivo'. O Dio informa quantos bytes foram transmitidos.
  Future<Attachment> upload(
    String token,
    String productId,
    AttachmentKind kind,
    String filename,
    Uint8List bytes,
    ProgressCallback onProgress,
  ) async {
    final data = await _call(
      () => _dio.post<Map<String, dynamic>>(
        _attachmentPath(productId, kind),
        options: _bearer(token),
        data: FormData.fromMap({
          'arquivo': MultipartFile.fromBytes(bytes, filename: filename),
        }),
        onSendProgress: onProgress,
      ),
    );
    return Attachment.fromJson(data);
  }

  Future<Uint8List> download(
    String token,
    String productId,
    AttachmentKind kind,
  ) async {
    final bytes = await _call(
      () => _dio.get<List<int>>(
        _attachmentPath(productId, kind),
        options: _bearer(token)..responseType = ResponseType.bytes,
      ),
    );
    return Uint8List.fromList(bytes);
  }

  String _attachmentPath(String productId, AttachmentKind kind) =>
      '/produtos/${Uri.encodeComponent(productId)}/anexos/${kind.path}';

  // Apresenta o token da sessão no cabeçalho exigido pelas rotas protegidas.
  Options _bearer(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  // Preserva o status HTTP e transforma falhas da API em mensagens para a interface.
  Future<T> _call<T>(Future<Response<T>> Function() send) async {
    try {
      final response = await send();
      final data = response.data;
      if (data == null) {
        throw const StaffApiError(null, 'Resposta vazia da API.');
      }
      return data;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final data = error.response?.data;
      if (data is Map && data['erro'] is String) {
        throw StaffApiError(status, data['erro'] as String);
      }
      final message = switch (status) {
        401 => 'Sua sessão expirou. Entre novamente.',
        403 => 'Seu perfil não tem permissão para esta operação.',
        404 => 'Arquivo ou produto não encontrado.',
        413 => 'O arquivo excede o limite de 1 MiB.',
        429 => 'Muitas tentativas. Aguarde um minuto.',
        int code when code >= 500 =>
          'O servidor está indisponível. Tente novamente.',
        _ => 'Falha de comunicação. Verifique a conexão e tente novamente.',
      };
      throw StaffApiError(status, message);
    }
  }
}

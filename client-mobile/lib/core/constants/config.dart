import 'dart:io' show Platform;

class AppConfig {
  // ═══════════════════════════════════════════════════════════════
  // DOMAIN CONFIGURATION
  // ═══════════════════════════════════════════════════════════════

  static String get _domain {
    const domain = String.fromEnvironment('GUARDYN_DOMAIN');
    if (domain.isNotEmpty) return domain;
    const host = String.fromEnvironment('GRPC_HOST');
    if (host.isNotEmpty) return host;
    if (Platform.isAndroid) return '10.0.2.2';
    return 'localhost';
  }

  static bool get _isProduction {
    final domain = _domain;
    return domain != 'localhost' && 
           domain != '127.0.0.1' && 
           domain != '10.0.2.2';
  }

  static bool get _secure {
    const secure = String.fromEnvironment('WEBSOCKET_SECURE');
    if (secure.isNotEmpty) return secure == 'true';
    return _isProduction;
  }

  static int get _grpcPort {
    if (_isProduction) return 443;
    const port = String.fromEnvironment('GRPC_PORT');
    if (port.isNotEmpty) return int.tryParse(port) ?? 50051;
    return 50051;
  }

  // ═══════════════════════════════════════════════════════════════
  // GATEWAY ROUTES (Nginx locations)
  // ═══════════════════════════════════════════════════════════════
  //
  // location /auth/      → grpc://127.0.0.1:52015
  // location /messaging/ → grpc://127.0.0.1:52016
  // location /presence/  → grpc://127.0.0.1:52018
  // location /media/     → grpc://127.0.0.1:52019
  // location /notification/ → grpc://127.0.0.1:52022
  // location /calls/     → grpc://127.0.0.1:52020
  // location /ws/        → http://127.0.0.1:52017
  // location /storage/   → http://127.0.0.1:52010
  // location /api/       → http://127.0.0.1:52012
  // location /minio-console/ → http://127.0.0.1:52011
  // location /redpanda-console/ → http://127.0.0.1:52023

  static String get _scheme => _secure ? 'https' : 'http';
  static String get _wsScheme => _secure ? 'wss' : 'ws';
  static String get _port => _isProduction ? '' : ':${_grpcPort}';

  static String get baseUrl => '$_scheme://$_domain$_port';
  static String get wsBaseUrl => '$_wsScheme://$_domain$_port';

  // ═══════════════════════════════════════════════════════════════
  // GATEWAY HOSTS (all services share same domain)
  // ═══════════════════════════════════════════════════════════════

  static String get authHost => _domain;
  static String get messagingHost => _domain;
  static String get presenceHost => _domain;
  static String get mediaHost => _domain;
  static String get notificationHost => _domain;
  static String get callHost => _domain;
  static String get minioHost => _domain;
  static String get websocketHost => _domain;

  // ═══════════════════════════════════════════════════════════════
  // GATEWAY PORTS (all services via Nginx on 443/80)
  // ═══════════════════════════════════════════════════════════════

  static int get authPort => _isProduction ? 443 : 50051;
  static int get messagingPort => _isProduction ? 443 : 50052;
  static int get presencePort => _isProduction ? 443 : 50053;
  static int get mediaPort => _isProduction ? 443 : 50054;
  static int get notificationPort => _isProduction ? 443 : 50055;
  static int get callPort => _isProduction ? 443 : 50056;
  static int get minioPort => _isProduction ? 443 : 9000;
  static int get websocketPort => _isProduction ? 443 : 8081;

  // ═══════════════════════════════════════════════════════════════
  // PROTOCOLS
  // ═══════════════════════════════════════════════════════════════

  static bool get websocketSecure => _secure;

  // ═══════════════════════════════════════════════════════════════
  // URL BUILDERS
  // ═══════════════════════════════════════════════════════════════

  static String getWebSocketUrl(String token) {
    return '$wsBaseUrl/ws?token=$token';
  }

  static String getGrpcUrl(String service) {
    return '$baseUrl/$service';
  }

  static String transformPresignedUrl(String presignedUrl) {
    final uri = Uri.parse(presignedUrl);
    if (uri.host == 'minio' || uri.host == 'localhost' || uri.host == '127.0.0.1') {
      return uri.replace(
        scheme: _scheme,
        host: _domain,
        port: _isProduction ? 443 : 9000,
        path: '/storage${uri.path}',
      ).toString();
    }
    return presignedUrl;
  }

  // ═══════════════════════════════════════════════════════════════
  // METADATA
  // ═══════════════════════════════════════════════════════════════

  static const String appName = 'Guardyn';
  static const String appVersion = '0.1.0';
}

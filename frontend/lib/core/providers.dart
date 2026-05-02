import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'network/api_client.dart';
import 'storage/secure_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  throw UnimplementedError('Override tokenStorageProvider in main()');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(tokenStorageProvider));
});

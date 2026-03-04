import 'package:flutter_test/flutter_test.dart';

import 'package:mnavb/models/backend_type.dart';

void main() {
  test('mapea backendType desde storage', () {
    expect(backendTypeFromStorage('firebase'), BackendType.firebase);
    expect(backendTypeFromStorage('external_api'), BackendType.externalApi);
    expect(backendTypeFromStorage(null), BackendType.firebase);
  });
}

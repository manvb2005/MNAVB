enum BackendType { firebase, externalApi }

extension BackendTypeX on BackendType {
  String get storageValue {
    switch (this) {
      case BackendType.firebase:
        return 'firebase';
      case BackendType.externalApi:
        return 'external_api';
    }
  }

  String get label {
    switch (this) {
      case BackendType.firebase:
        return 'Base de datos interna';
      case BackendType.externalApi:
        return 'API externa';
    }
  }

  String get description {
    switch (this) {
      case BackendType.firebase:
        return 'Tus movimientos se guardan en Firebase';
      case BackendType.externalApi:
        return 'Tus movimientos se envian a un servicio externo';
    }
  }
}

BackendType backendTypeFromStorage(String? value) {
  switch (value) {
    case 'external_api':
      return BackendType.externalApi;
    case 'firebase':
    default:
      return BackendType.firebase;
  }
}

/// Çevrimdışı işlem hatası.
class OfflineException implements Exception {
  final String message;
  final bool isWrite;

  const OfflineException(this.message, {this.isWrite = false});

  factory OfflineException.readMissing() =>
      const OfflineException('Bu veri çevrimdışıyken mevcut değil.');

  factory OfflineException.writeRequired() =>
      const OfflineException('Çevrimdışısınız; bu işlem için bağlantı gerekli.', isWrite: true);

  @override
  String toString() => message;
}

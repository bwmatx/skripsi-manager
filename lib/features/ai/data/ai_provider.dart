/// Abstract AI provider interface.
///
/// Every provider (Gemini, DeepSeek, OpenRouter) MUST implement this contract.
/// This is the single abstraction layer that [AiProviderManager] operates on.
abstract class AiProvider {
  /// Human-readable provider name, e.g. "Gemini", "DeepSeek", "OpenRouter".
  String get providerName;

  /// Send [userPrompt] and return a response string.
  ///
  /// On success: returns the AI response text.
  /// On failure: NEVER throws — returns a human-readable Indonesian error string.
  Future<String> generateResponse(String userPrompt);

  /// Quick availability check — validates that the provider has a key configured.
  ///
  /// Does NOT perform an actual HTTP call. Returns [false] if the API key is
  /// empty or obviously misconfigured.
  bool checkAvailability();

  /// Returns [true] if [result] is a valid user-displayable AI response
  /// (i.e. not an error sentinel or message).
  bool isSuccessResponse(String result) {
    if (result.isEmpty) return false;
    const errorPrefixes = [
      'Error',
      'Limit',
      'Terlalu',
      'Server AI',
      'Koneksi',
      'AI sedang',
      'Tidak ada',
      'Kuota',
      'Timeout',
      'Tidak dapat',
    ];
    for (final prefix in errorPrefixes) {
      if (result.startsWith(prefix)) return false;
    }
    // Catch raw JSON error objects
    if (result.startsWith('{') && result.contains('"error"')) return false;
    return true;
  }
}

/// Enum for selecting preferred AI provider.
enum AiProviderType {
  gemini('Gemini'),
  deepSeek('DeepSeek'),
  openRouter('OpenRouter');

  const AiProviderType(this.displayName);
  final String displayName;

  static AiProviderType fromString(String value) {
    return AiProviderType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AiProviderType.gemini,
    );
  }
}

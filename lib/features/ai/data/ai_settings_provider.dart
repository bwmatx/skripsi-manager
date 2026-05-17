import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skripsi_manager/features/ai/data/ai_provider.dart';
import 'package:skripsi_manager/features/ai/data/ai_provider_manager.dart';
import 'package:skripsi_manager/features/ai/data/ai_settings_repository.dart';

// ── Repository singleton ───────────────────────────────────────────────────────

final aiSettingsRepositoryProvider = Provider<AiSettingsRepository>(
  (ref) => AiSettingsRepository(),
);

// ── Settings state notifier ────────────────────────────────────────────────────

/// Async provider that loads all AI settings from secure storage.
/// Invalidate this provider after saving settings to refresh UI.
final aiSettingsProvider = FutureProvider<AiSettings>((ref) async {
  final repo = ref.watch(aiSettingsRepositoryProvider);
  return repo.loadAll();
});

// ── Mutable notifier for settings screen ─────────────────────────────────────

class AiSettingsNotifier extends AsyncNotifier<AiSettings> {
  late AiSettingsRepository _repo;

  @override
  Future<AiSettings> build() async {
    _repo = ref.watch(aiSettingsRepositoryProvider);
    return _repo.loadAll();
  }

  Future<void> setDeepSeekKey(String key) async {
    await _repo.saveDeepSeekApiKey(key);
    state = AsyncData((state.value ?? _empty()).copyWith(deepSeekApiKey: key));
  }

  Future<void> setOpenRouterKey(String key) async {
    await _repo.saveOpenRouterApiKey(key);
    state = AsyncData((state.value ?? _empty()).copyWith(openRouterApiKey: key));
  }

  Future<void> setPreferredProvider(AiProviderType type) async {
    await _repo.savePreferredProvider(type);
    state = AsyncData((state.value ?? _empty()).copyWith(preferredProvider: type));
  }

  Future<void> setAutoFallback(bool enabled) async {
    await _repo.saveAutoFallback(enabled);
    state = AsyncData((state.value ?? _empty()).copyWith(autoFallback: enabled));
  }

  AiSettings _empty() => const AiSettings(
    deepSeekApiKey: '',
    openRouterApiKey: '',
    preferredProvider: AiProviderType.gemini,
    autoFallback: true,
  );
}

final aiSettingsNotifierProvider =
    AsyncNotifierProvider<AiSettingsNotifier, AiSettings>(
  AiSettingsNotifier.new,
);

// ── AiProviderManager singleton provider ─────────────────────────────────────

/// Provides the singleton [AiProviderManager].
/// This is what [ResultCard] and any AI-calling widget should use
/// instead of directly instantiating [GeminiService].
final aiProviderManagerProvider = Provider<AiProviderManager>(
  (ref) => AiProviderManager(),
);

# Waterfly III - Quick Architecture Reference

This is a quick reference guide to the Waterfly III architecture. For detailed information, see:
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Complete architecture documentation
- **[DATA_FLOW.md](DATA_FLOW.md)** - Detailed data flow diagrams

---

## What is Waterfly III?

**Unofficial Android/iOS mobile client** for Firefly III (self-hosted personal finance manager)
- Built with **Flutter** (Dart)
- Material 3 design
- No trackers, minimal dependencies
- Companion app (not full web feature parity)

---

## Tech Stack at a Glance

| Component | Technology |
|-----------|-----------|
| **Framework** | Flutter 3.7.0+ |
| **Language** | Dart |
| **State Management** | Provider (ChangeNotifier) |
| **API Client** | Chopper + Swagger Code Gen |
| **Data Caching** | Stock library (Fetcher pattern) |
| **Secure Storage** | flutter_secure_storage (Keystore/Keychain) |
| **Preferences** | shared_preferences |
| **UI Design** | Material 3 |
| **HTTP Client** | CronetClient (Android optimized) |

---

## Project Structure

```
lib/
├── main.dart                  # Entry point
├── app.dart                   # Root widget (theme, providers)
├── auth.dart                  # FireflyService, AuthUser (API)
├── settings.dart              # SettingsProvider (user prefs)
├── stock.dart                 # TransStock (caching)
├── pages/                     # UI screens
│   ├── home/                 # Dashboard & transactions
│   ├── transaction/          # Add/edit transactions
│   ├── settings/             # App settings
│   ├── bills/                # Bill management
│   └── categories/           # Category management
├── widgets/                   # Reusable components
└── generated/                 # Auto-generated code
    ├── swagger_fireflyiii_api/  # API client & models
    └── l10n/                    # Localizations
```

---

## Key Architecture Patterns

### 1. State Management: Provider

```dart
// Global providers
MultiProvider(
  providers: [
    ChangeNotifierProvider<FireflyService>(),   // API & auth
    ChangeNotifierProvider<SettingsProvider>(), // Settings
  ],
)

// Access in UI
context.read<FireflyService>().api.v1TransactionsGet()
context.watch<SettingsProvider>().theme
```

### 2. Data Caching: Stock Pattern

```dart
Stock<Key, Value>(
  fetcher: Fetcher.ofFuture(...),      // Network
  sourceOfTruth: CachedSourceOfTruth(), // Cache
)

// Usage
transStock.stream(queryKey).listen((response) {
  // Loading → Data → NoNewData → Error
});
```

### 3. API Integration: Chopper + Swagger

- Swagger spec → Code generation → Type-safe API
- Automatic JSON serialization/deserialization
- Request interceptor adds Bearer auth

---

## Data Storage

### Secure Storage (Encrypted)
- `api_host`: Firefly III server URL
- `api_key`: Bearer token

### Shared Preferences (Plain)
- User settings (theme, locale, etc.)
- Boolean flags (packed in bitmask)
- Dashboard layout preferences
- Notification settings

---

## Data Flow Overview

```
User Action
    ↓
Provider (FireflyService)
    ↓
Stock Cache (check)
    ↓ (cache miss)
API Client (Chopper)
    ↓
HTTP Request (with auth interceptor)
    ↓
Firefly III Server
    ↓
Response (JSON)
    ↓
Swagger Models (deserialize)
    ↓
Cache Update (SourceOfTruth)
    ↓
notifyListeners()
    ↓
UI Rebuild (StreamBuilder/Consumer)
```

---

## Key Components

### FireflyService (auth.dart)
- Central API service
- Manages authentication state
- Provides API client access
- Handles sign in/out

### AuthUser (auth.dart)
- API client wrapper
- Validates Firefly III instance
- Manages auth headers

### SettingsProvider (settings.dart)
- User preferences
- Theme, locale, feature flags
- Bitmask-packed boolean settings

### TransStock (stock.dart)
- Transaction caching
- Two-level cache: list IDs + individual objects
- Stream-based data access

---

## Authentication Flow

1. User enters host + API key
2. Validate URL format
3. Test `/api/v1/about` endpoint
4. Check API version (min 6.3.2)
5. Create AuthUser with API client
6. Fetch default currency & timezone
7. Initialize TransStock cache
8. Save credentials to secure storage
9. Set `signedIn = true` → UI updates

---

## Common Operations

### Load Transactions
```dart
final stream = context
  .read<FireflyService>()
  .transStock
  .stream(queryKey);

StreamBuilder<StockResponse>(
  stream: stream,
  builder: (context, snapshot) {
    if (snapshot.data is Data) {
      // Render list
    }
  },
)
```

### Create Transaction
```dart
final transaction = TransactionStore(...);
final response = await context
  .read<FireflyService>()
  .api
  .v1TransactionsPost(body: transaction);

if (response.isSuccessful) {
  // Clear cache to force refresh
  context.read<FireflyService>().transStock.clear();
  Navigator.pop(context);
}
```

### Change Setting
```dart
await context
  .read<SettingsProvider>()
  .setTheme(ThemeMode.dark);
// UI auto-updates, persisted to storage
```

---

## Features

- ✅ Dashboard (charts, balance, budgets)
- ✅ Transaction list & add/edit
- ✅ Account overview
- ✅ Bill management
- ✅ Category management
- ✅ Piggy banks
- ✅ Attachments & file sharing
- ✅ Multi-currency support
- ✅ Split transactions
- ✅ Tags & budgets
- ✅ Notification listener (auto-add transactions)
- ✅ Quick actions (Android shortcuts)
- ✅ Biometric authentication
- ✅ Dynamic colors (Material You)
- ✅ Multi-language support

---

## Security Features

- ✅ Encrypted credential storage (Keystore/Keychain)
- ✅ Bearer token authentication
- ✅ API version validation
- ✅ Optional biometric auth (10-min idle timeout)
- ✅ No third-party trackers
- ✅ HTTPS enforcement

---

## Development Workflow

### Generate API Client
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Run App
```bash
flutter run
```

### Build Release
```bash
flutter build apk --release       # Android APK
flutter build appbundle --release # Android App Bundle
flutter build ios --release       # iOS
```

### Lint & Test
```bash
flutter analyze
flutter test
```

---

## Important Files

| File | Purpose |
|------|---------|
| `lib/auth.dart` | API service & authentication |
| `lib/settings.dart` | User preferences provider |
| `lib/stock.dart` | Data caching layer |
| `lib/app.dart` | Root widget setup |
| `pubspec.yaml` | Dependencies |
| `build.yaml` | Code generation config |
| `swagger_input/firefly-iii.yaml` | API spec |

---

## Cache Strategy

### When to Clear Cache

| Action | Cache Operation |
|--------|----------------|
| Create transaction | `transStock.clear()` |
| Edit transaction | `_singleSoT.delete(id)` + `_listSoT.clear()` |
| Delete transaction | `transStock.clear()` |
| Create category | `catStock.clear()` |
| Logout | Clear all + storage |

### Cache Levels

1. **In-Memory**: TransStock (session lifetime)
2. **Network**: HTTP cache headers
3. **No Persistent Cache**: Fresh data on restart

---

## API Version Requirements

- **Minimum**: Firefly III API 6.3.2
- **Recommended**: Latest stable
- **Development**: 9.9.9 (auto-detected)

---

## Localization

- Uses `flutter_localizations`
- Generated from ARB files
- Access: `S.of(context).translationKey`
- Contribute: [Crowdin project](https://crowdin.com/project/waterfly-iii)

---

## Testing

- Unit tests: Model serialization, business logic
- Widget tests: Custom components, forms
- Integration tests: API mocking, auth flow

**Note**: Current coverage is minimal, priority on stability.

---

## Performance Optimizations

1. **Lazy Loading**: Infinite scroll pagination
2. **Efficient Rebuilds**: `context.select()` for granular updates
3. **Image Optimization**: SVG for icons, lazy loading
4. **Network**: HTTP/2 with CronetClient (Android)
5. **Caching**: Request deduplication via Stock library

---

## Future Improvements

- Offline-first with local database (Drift/Hive)
- Modular architecture (feature packages)
- Enhanced testing (BLoC pattern?)
- Dependency injection (GetIt/Riverpod)
- Background sync

---

## Resources

- [Firefly III](https://www.firefly-iii.org/)
- [Firefly III API Docs](https://api-docs.firefly-iii.org/)
- [Flutter](https://flutter.dev/)
- [Material 3](https://m3.material.io/)
- [Provider](https://pub.dev/packages/provider)
- [Chopper](https://pub.dev/packages/chopper)
- [Stock](https://pub.dev/packages/stock)

---

## Quick Troubleshooting

### "Invalid API key" error
- Check API key in Firefly III web interface
- Ensure URL is correct (no trailing slash)
- Verify network connectivity

### "API version too low"
- Upgrade Firefly III to 6.3.2+
- Check server version at `/api/v1/about`

### Cache not updating
- Pull to refresh on lists
- Or call `transStock.clear()` to force refresh

### Authentication loop
- Clear app data
- Sign in again with fresh credentials

---

**For comprehensive details, refer to:**
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Full architecture documentation
- **[DATA_FLOW.md](DATA_FLOW.md)** - Detailed data flow diagrams
- **[README.md](README.md)** - Project overview & features
- **[FAQ.md](FAQ.md)** - Frequently asked questions

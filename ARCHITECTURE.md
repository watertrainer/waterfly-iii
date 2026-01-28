# Waterfly III - Architecture Overview

## Table of Contents
1. [Introduction](#introduction)
2. [Technology Stack](#technology-stack)
3. [Project Structure](#project-structure)
4. [Architecture Patterns](#architecture-patterns)
5. [Data Management](#data-management)
6. [Data Flow](#data-flow)
7. [Authentication Flow](#authentication-flow)
8. [Key Components](#key-components)
9. [Code Organization](#code-organization)

---

## Introduction

Waterfly III is an **unofficial Android/iOS mobile client** for [Firefly III](https://github.com/firefly-iii/firefly-iii), a free and open-source personal finance manager. The app is built using **Flutter** and follows Material 3 design guidelines, providing a native mobile experience for managing personal finances on-the-go.

**Design Philosophy:**
- Clean, minimal dependency footprint
- No trackers or analytics
- Companion app (not a full feature replica of web interface)
- Focus on most-used functions for mobile users

---

## Technology Stack

### Core Framework
- **Flutter** (SDK 3.7.0+): Cross-platform mobile development
- **Dart**: Primary programming language
- **Material 3**: UI design system

### Key Dependencies

| Library | Purpose | Version |
|---------|---------|---------|
| `provider` | State management | 6.1.2 |
| `chopper` | HTTP client with code generation | 8.4.0 |
| `stock` | Data caching/fetcher pattern | 1.1.0 |
| `flutter_secure_storage` | Encrypted credential storage | 10.0.0 |
| `shared_preferences` | User preferences storage | 2.3.4 |
| `swagger_dart_code_generator` | API client generation | 4.1.0 |
| `infinite_scroll_pagination` | List pagination | 5.1.1 |
| `syncfusion_flutter_charts` | Data visualization | 32.1.21 |
| `flutter_local_notifications` | Notification handling | 19.4.0 |

### Development Tools
- `build_runner`: Code generation orchestration
- `chopper_generator`: REST client code generation
- `json_serializable`: JSON serialization
- `flutter_lints`: Code quality enforcement

---

## Project Structure

```
waterfly-iii/
├── android/                    # Android-specific configuration
├── ios/                        # iOS-specific configuration
├── assets/                     # Static assets (images, icons)
├── lib/                        # Main Dart source code
│   ├── generated/             # Auto-generated code
│   │   ├── swagger_fireflyiii_api/  # API client & models
│   │   └── l10n/                    # Localization strings
│   ├── pages/                 # Application screens/routes
│   │   ├── home/             # Dashboard & transactions
│   │   ├── bills/            # Bill management
│   │   ├── categories/       # Category management
│   │   ├── settings/         # App settings
│   │   └── transaction/      # Transaction add/edit
│   ├── widgets/              # Reusable UI components
│   ├── main.dart            # App entry point
│   ├── app.dart             # Root widget with theme & routing
│   ├── auth.dart            # Authentication & API service
│   ├── settings.dart        # Settings provider
│   ├── stock.dart           # Data caching layer
│   └── extensions.dart      # Utility extensions
├── test/                     # Unit & widget tests
├── swagger_input/           # Swagger API specification
├── pubspec.yaml            # Project dependencies
└── build.yaml              # Code generation config
```

---

## Architecture Patterns

### 1. State Management: Provider Pattern

The app uses **Provider** (with ChangeNotifier) for state management:

```dart
// Global state providers
MultiProvider(
  providers: [
    ChangeNotifierProvider<FireflyService>(),  // API & auth state
    ChangeNotifierProvider<SettingsProvider>(), // User preferences
  ],
  child: MaterialApp(...),
)
```

**Benefits:**
- Simple, lightweight, and built-in to Flutter
- Easy to test and reason about
- Efficient rebuild optimization via `select()`
- Clear separation of concerns

### 2. Repository Pattern: Stock Library

Uses the `stock` library implementing the **Fetcher/SourceOfTruth** pattern:

```dart
Stock<Key, Value>(
  fetcher: Fetcher.ofFuture(...),      // API data source
  sourceOfTruth: CachedSourceOfTruth(), // In-memory cache
)
```

**Key Features:**
- Automatic caching with invalidation
- Network request deduplication
- Lazy loading with pagination
- Single source of truth

### 3. API Client: Chopper + Swagger

**Swagger Code Generation:**
```yaml
# build.yaml
targets:
  $default:
    builders:
      swagger_dart_code_generator:
        options:
          input_folder: 'swagger_input'
          output_folder: 'lib/generated/swagger_fireflyiii_api'
```

**Generated Structure:**
- `firefly_iii.swagger.dart`: API client class
- `firefly_iii.models.swagger.dart`: Data models
- `firefly_iii.enums.swagger.dart`: Enumerations

**Benefits:**
- Type-safe API calls
- Automatic serialization/deserialization
- Contract-driven development
- Easy API updates (regenerate from spec)

### 4. Navigation: Material Router

Standard Flutter Navigator with named routes and bottom navigation:

```dart
NavPage (BottomNavigationBar)
├── Home (Dashboard)
├── Transactions
├── Accounts
├── Categories
└── More (Settings, Bills, etc.)
```

---

## Data Management

### Storage Architecture

The app uses a **two-tier storage system**:

#### 1. Secure Storage (Encrypted)
**Library:** `flutter_secure_storage`  
**Purpose:** Sensitive credentials

```dart
FlutterSecureStorage(
  aOptions: AndroidOptions(resetOnError: true),
)
```

**Stored Data:**
- `api_host`: Firefly III server URL
- `api_key`: Bearer token for authentication

**Security Features:**
- Platform-native encryption (Keystore/Keychain)
- Automatic reset on tamper detection
- Cleared on logout

#### 2. Shared Preferences (Plain Text)
**Library:** `shared_preferences`  
**Purpose:** User settings and app state

**Stored Data:**
```dart
// Boolean flags (packed in bitmask)
BOOLBITMASK:
  - debug: Enable debug mode
  - lock: Require biometric auth
  - showFutureTXs: Show future transactions
  - dynamicColors: Use system colors
  - useServerTime: Use server timezone
  - hideTags: Hide tags in UI
  - billsShowOnlyActive/Expected: Bill filters

// UI Preferences
LOCALE: User language (e.g., "en_US")
THEME: ThemeMode (system/light/dark)
DASHBOARD_CARDS: Comma-separated card order
DASHBOARD_DATE_RANGE: Transaction filter range

// Notification Settings
NL_APPS: JSON array of app configurations
NL_APP_<name>: Individual app settings
```

**Settings Bitmask Implementation:**
```dart
class SettingsBitmask {
  int _value;
  
  bool operator [](BoolSettings flag) => 
    (_value & (1 << flag.index)) != 0;
    
  void operator []=(BoolSettings flag, bool value) {
    if (value) {
      _value |= (1 << flag.index);  // Set bit
    } else {
      _value &= ~(1 << flag.index); // Clear bit
    }
  }
}
```

### Caching Strategy

**Three-Level Cache:**

1. **In-Memory Cache** (TransStock/CatStock)
   - Lifetime: App session
   - Invalidation: Manual via `clear()` or `invalidate()`
   - Used for: Frequently accessed data

2. **Network Cache** (Chopper)
   - Lifetime: HTTP cache headers
   - Location: HTTP client layer
   - Used for: API responses

3. **No Persistent Cache**
   - Data is always fresh on app restart
   - Design trade-off: Freshness over offline access

---

## Data Flow

### Overview Diagram

```
User Action (UI)
    ↓
Provider.read<FireflyService>()
    ↓
TransStock.stream() or api.v1*()
    ↓
[Cache Check] → Cache Hit? → Return Cached Data
    ↓ Cache Miss
Fetcher.fetch()
    ↓
AuthUser.api (Chopper Client)
    ↓
APIRequestInterceptor (adds Bearer token)
    ↓
HTTP Request → Firefly III Server
    ↓
Response<Model>
    ↓
JSON Deserialization (swagger models)
    ↓
SourceOfTruth.write() (update cache)
    ↓
notifyListeners()
    ↓
UI Rebuild (context.watch/select)
```

### Detailed Flow Examples

#### Example 1: Loading Transactions

```dart
// 1. UI requests data
Consumer<FireflyService>(
  builder: (context, fireflyService, _) {
    return FutureBuilder(
      future: fireflyService.transStock.stream(queryKey),
      builder: (context, snapshot) { ... },
    );
  },
)

// 2. TransStock checks cache
Stock<String, List<String>> _getStock = Stock(
  fetcher: Fetcher.ofFuture((String id) {
    // 3. Parse query parameters
    final query = _getOptions.fromJson(jsonDecode(id));
    
    // 4. Make API call
    return api.v1TransactionsGet(
      page: query.page,
      limit: query.limit,
      start: query.start,
      end: query.end,
    ).then((response) {
      // 5. Cache individual transactions
      for (var transaction in response.body.data) {
        _singleSoT.write(transaction.id, transaction);
      }
      
      // 6. Return list of IDs
      return response.body.data.map((e) => e.id).toList();
    });
  }),
  sourceOfTruth: _listSoT,
);

// 7. UI receives Stream<StockResponse<List<String>>>
// 8. UI can then fetch individual transactions from _singleStock
```

#### Example 2: Creating a Transaction

```dart
// 1. User submits form
onPressed: () async {
  // 2. Build transaction model
  final transaction = TransactionStore(
    transactions: [TransactionSplit(...)],
  );
  
  // 3. Direct API call (bypass cache)
  final response = await context
    .read<FireflyService>()
    .api
    .v1TransactionsPost(body: transaction);
  
  // 4. Check response
  if (response.isSuccessful) {
    // 5. Invalidate cache to force refresh
    context.read<FireflyService>().transStock.clear();
    
    // 6. Navigate back
    Navigator.pop(context);
  }
}
```

---

## Authentication Flow

### Sign-In Process

```
LoginPage: User enters host URL + API key
    ↓
FireflyService.signIn(host, apiKey)
    ↓
AuthUser.create(host, apiKey)
    ↓
[Validation Step 1] Parse URL
    ↓ FormatException → throw AuthErrorHost
    ↓
[Validation Step 2] HTTP GET /api/v1/about
    ↓ Content-Type: text/html → throw AuthErrorApiKey
    ↓ Status != 200 → throw AuthErrorStatusCode
    ↓
[Validation Step 3] Parse SystemInfo JSON
    ↓ FormatException → throw AuthErrorNoInstance
    ↓
[Validation Step 4] Check API version
    ↓ version < 6.3.2 → throw AuthErrorVersionTooLow
    ↓
AuthUser object created
    ↓
FireflyService initialization:
  - Fetch default currency
  - Fetch server timezone
  - Initialize TransStock cache
  - Store credentials in secure storage
  - Set _signedIn = true
    ↓
notifyListeners() → UI updates
    ↓
MaterialApp shows NavPage (home)
```

### API Request Authentication

Every API request includes authentication via interceptor:

```dart
class APIRequestInterceptor implements Interceptor {
  @override
  FutureOr<Response> intercept(Chain chain) {
    final request = applyHeaders(
      chain.request,
      {
        'Authorization': 'Bearer $_apiKey',
        'Accept': 'application/json',
      },
    );
    return chain.proceed(request);
  }
}
```

### Biometric Authentication (Optional)

If enabled via settings:

```dart
AppLifecycleListener(
  onResume: () {
    if (_requiresAuth && _lastOpen > 10 minutes ago) {
      LocalAuthentication().authenticate(
        localizedReason: "Waterfly III",
      ).then((authed) {
        if (!authed) {
          SystemNavigator.pop(); // Close app
        }
      });
    }
  },
)
```

---

## Key Components

### 1. FireflyService (auth.dart)

**Responsibility:** Central service for API access and authentication state

```dart
class FireflyService with ChangeNotifier {
  AuthUser? _currentUser;          // Current authenticated user
  bool _signedIn = false;          // Authentication status
  TransStock? _transStock;         // Transaction cache
  CurrencyRead defaultCurrency;    // Default currency
  TimeZoneHandler tzHandler;       // Timezone management
  
  // API accessor
  FireflyIii get api => _currentUser!.api;
  
  // Public methods
  Future<bool> signIn(String host, String apiKey);
  Future<void> signOut();
  Future<bool> signInFromStorage();
}
```

**Usage:**
```dart
// Access API
context.read<FireflyService>().api.v1TransactionsGet(...);

// Check auth state
context.watch<FireflyService>().signedIn

// Access cache
context.read<FireflyService>().transStock.stream(...)
```

### 2. AuthUser (auth.dart)

**Responsibility:** Encapsulates API client for a single authenticated user

```dart
class AuthUser {
  late Uri _host;                  // Server URL
  late String _apiKey;             // Bearer token
  late FireflyIii _api;           // Chopper client
  
  Uri get host => _host;
  FireflyIii get api => _api;
  Map<String, String> headers();   // Auth headers
  
  static Future<AuthUser> create(String host, String apiKey);
}
```

### 3. SettingsProvider (settings.dart)

**Responsibility:** User preferences and app configuration

```dart
class SettingsProvider with ChangeNotifier {
  bool _loaded = false;
  SettingsBitmask _boolSettings;
  ThemeMode _theme;
  Locale? _locale;
  List<DashboardCards> _dashboardCards;
  TransactionDateFilter _dashboardDateRange;
  
  // Boolean settings (packed)
  bool get debug => _boolSettings[BoolSettings.debug];
  bool get lock => _boolSettings[BoolSettings.lock];
  bool get dynamicColors => _boolSettings[BoolSettings.dynamicColors];
  
  // Load/save
  Future<void> loadSettings();
  Future<void> setBool(BoolSettings setting, bool value);
}
```

### 4. TransStock (stock.dart)

**Responsibility:** Transaction caching and pagination

```dart
class TransStock with ChangeNotifier {
  final FireflyIii api;
  
  Stock<String, TransactionRead> _singleStock;      // Single TX cache
  Stock<String, List<String>> _getStock;           // List cache
  Stock<String, List<String>> _getAccountStock;    // Account TXs
  Stock<String, List<String>> _getSearchStock;     // Search results
  
  // Stream access
  Stream<StockResponse<TransactionRead>> get(String id);
  Stream<StockResponse<List<String>>> getList(...);
  
  // Cache management
  void clear();
  void invalidate(String id);
}
```

**Stock Response States:**
```dart
StockResponse<T>:
  - Loading: Initial state
  - Data: Success with payload
  - Error: Failure with exception
  - NoNewData: Cache hit (no network request)
```

---

## Code Organization

### Feature-Based Organization

Each major feature is self-contained:

```
lib/pages/transaction/
├── transaction.dart        # Main add/edit screen
├── attachments.dart       # File attachment management
├── bill.dart             # Bill selection
├── currencies.dart       # Multi-currency support
├── delete.dart          # Delete confirmation
├── piggy.dart           # Piggy bank linking
└── tags.dart            # Tag management
```

### Shared Components

```
lib/widgets/
├── logo.dart             # App logo
├── input/               # Custom form fields
│   ├── autocomplete.dart
│   ├── switch.dart
│   └── date.dart
├── charts/             # Chart widgets
└── transaction_list.dart  # Reusable TX list
```

### Generated Code

```
lib/generated/
├── swagger_fireflyiii_api/
│   ├── firefly_iii.swagger.dart        # Main API client
│   ├── firefly_iii.models.swagger.dart # Data models
│   └── firefly_iii.enums.swagger.dart  # Enumerations
└── l10n/
    └── app_localizations.dart          # i18n strings
```

### Code Generation Commands

```bash
# Regenerate API client from Swagger spec
flutter pub run build_runner build --delete-conflicting-outputs

# Generate localization files
flutter gen-l10n
```

---

## Advanced Features

### 1. Notification Listener

Parses incoming Android notifications from banking apps to pre-fill transactions:

```dart
class NotificationTransaction {
  String title;
  String text;
  String appName;
  DateTime timestamp;
  
  // Extract amount using regex
  static final RegExp amountPattern = RegExp(r'[\d.,]+');
}
```

**Flow:**
1. Android notification arrives
2. NotificationListenerService captures it
3. Parse amount, description, timestamp
4. Store in local notification
5. On notification tap → open TransactionPage with pre-filled data

### 2. File Sharing Intent

Accept images shared from other apps as transaction attachments:

```dart
FlutterSharingIntent.instance.getInitialSharing().then((files) {
  if (files.isNotEmpty) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionPage(files: files),
      ),
    );
  }
});
```

### 3. Quick Actions

Android app shortcuts for quick transaction entry:

```dart
QuickActions().setShortcutItems([
  ShortcutItem(
    type: 'action_transaction_add',
    localizedTitle: 'Add Transaction',
    icon: 'ic_shortcut_add',
  ),
]);
```

### 4. Dynamic Colors (Material You)

Adapts to system color scheme on Android 12+:

```dart
DynamicColorBuilder(
  builder: (lightDynamic, darkDynamic) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: useDynamicColors 
          ? lightDynamic?.harmonized() 
          : ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
    );
  },
)
```

---

## Testing Strategy

### Unit Tests
- Model serialization/deserialization
- Business logic in providers
- Utility functions

### Widget Tests
- Custom widget rendering
- Form validation
- Navigation flows

### Integration Tests
- API mock responses
- Authentication flow
- Transaction CRUD operations

**Note:** Current test coverage is minimal. Priority is on stability and feature completeness.

---

## Performance Considerations

### 1. Lazy Loading
- Transactions loaded on-demand with pagination
- `infinite_scroll_pagination` for seamless UX

### 2. Efficient Rebuilds
- `context.select()` for granular subscriptions
- `Consumer` widgets for targeted updates

### 3. Image Optimization
- SVG for vector graphics (small bundle size)
- Lazy image loading in lists

### 4. Network Optimization
- Request deduplication via Stock library
- HTTP/2 with Cronet on Android

---

## Security Best Practices

✅ **Implemented:**
- Encrypted credential storage (Keystore/Keychain)
- Bearer token authentication
- HTTPS enforcement
- API version validation
- Biometric authentication option
- No third-party analytics/tracking

⚠️ **Considerations:**
- No certificate pinning (trust system CA store)
- No refresh token mechanism (API key only)
- Local notifications stored unencrypted

---

## Development Workflow

### Adding a New API Endpoint

1. Update `swagger_input/firefly-iii.yaml`
2. Run `flutter pub run build_runner build --delete-conflicting-outputs`
3. Import generated models/methods
4. Add Stock cache if needed
5. Update UI to consume new endpoint

### Adding a New Setting

1. Add enum to `BoolSettings` in `settings.dart`
2. Add getter/setter in `SettingsProvider`
3. Update settings UI in `lib/pages/settings.dart`
4. Access via `context.watch<SettingsProvider>().yourSetting`

### Adding a New Page

1. Create `lib/pages/yourpage.dart`
2. Add route to `NavPage` or `home.dart`
3. Add navigation logic
4. Update localization strings if needed

---

## Build & Deployment

### Android Build
```bash
# Debug build
flutter build apk --debug

# Release build (requires signing config)
flutter build apk --release
flutter build appbundle --release
```

### iOS Build
```bash
flutter build ios --release
```

### Code Quality
```bash
# Run linter
flutter analyze

# Run tests
flutter test
```

---

## Future Architecture Improvements

**Potential Enhancements:**
1. **Offline-First Architecture**: Local database (Drift/Hive) with sync
2. **Modular Architecture**: Split features into packages
3. **BLoC Pattern**: For more complex state management
4. **Dependency Injection**: GetIt or Riverpod for better testability
5. **GraphQL**: If Firefly III adds GraphQL support
6. **Background Sync**: Periodic data refresh

---

## Glossary

- **Firefly III**: The backend server (self-hosted personal finance manager)
- **Waterfly III**: This mobile app (client)
- **Stock**: The caching library pattern (Fetcher + SourceOfTruth)
- **Chopper**: HTTP client code generator for Dart
- **Provider**: State management solution for Flutter
- **TransStock**: Transaction cache manager
- **FireflyService**: Central API & auth service
- **SettingsProvider**: User preferences manager

---

## Resources

- [Firefly III API Docs](https://api-docs.firefly-iii.org/)
- [Flutter Documentation](https://docs.flutter.dev/)
- [Provider Package](https://pub.dev/packages/provider)
- [Chopper Documentation](https://pub.dev/packages/chopper)
- [Stock Library](https://pub.dev/packages/stock)
- [Material 3 Design](https://m3.material.io/)

---

## Conclusion

Waterfly III demonstrates a **clean, maintainable architecture** suitable for a mobile finance app:

- ✅ Clear separation of concerns (UI, business logic, data)
- ✅ Type-safe API integration with code generation
- ✅ Efficient caching with the Stock pattern
- ✅ Simple but effective state management with Provider
- ✅ Security-first approach (encrypted storage, auth validation)
- ✅ Minimal external dependencies
- ✅ Follows Flutter/Material 3 best practices

This architecture allows for rapid feature development while maintaining code quality and user experience.

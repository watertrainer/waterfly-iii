# Waterfly III - Data Flow Documentation

This document provides detailed visual representations of how data flows through the Waterfly III application.

## Network Requirements Legend

- 🌐 **Internet Required** - Step requires active internet connection to Firefly III server
- 💾 **Offline Capable** - Step can work with cached data (no internet needed)
- ⚡ **Local Only** - Step is completely local (never requires internet)

---

## Table of Contents
1. [Application Startup Flow](#application-startup-flow)
2. [Authentication Flow](#authentication-flow)
3. [Transaction Loading Flow](#transaction-loading-flow)
4. [Transaction Creation Flow](#transaction-creation-flow)
5. [Settings Management Flow](#settings-management-flow)
6. [Notification Processing Flow](#notification-processing-flow)
7. [Cache Invalidation Flow](#cache-invalidation-flow)
8. [Network Requirements Summary](#network-requirements-summary)

---

## Application Startup Flow

```
┌──────────────────────────────────────────────────────────────────────┐
│                          App Launch (main.dart)                      │
│                              ⚡ LOCAL ONLY                           │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Initialize Logger, Timezone, Intl                 ⚡ LOCAL ONLY      │
│ - Logger.root.level = DEBUG/INFO                                     │
│ - tz.initializeTimeZones()                                           │
│ - Intl.defaultLocale = findSystemLocale()                            │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    runApp(WaterflyApp())          ⚡ LOCAL ONLY      │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ WaterflyApp._initState()                          ⚡ LOCAL ONLY      │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ Setup FlutterLocalNotificationsPlugin                           │ │
│ │ Setup QuickActions listener                                      │ │
│ │ Setup AppLifecycleListener (for biometric auth)                 │ │
│ │ Setup FlutterSharingIntent (for file sharing)                   │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ MultiProvider (app.dart)                          ⚡ LOCAL ONLY      │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ ChangeNotifierProvider<FireflyService>                          │ │
│ │ ChangeNotifierProvider<SettingsProvider>                        │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Load Settings (_startup = true)                   ⚡ LOCAL ONLY      │
│ context.read<SettingsProvider>().loadSettings()                      │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ SettingsProvider.loadSettings()                   ⚡ LOCAL ONLY      │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ prefs = SharedPreferences.getInstance()                         │ │
│ │ Load: theme, locale, boolSettings, dashboardCards, etc.         │ │
│ │ _loaded = true                                                   │ │
│ │ notifyListeners()                                                │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
                    ┌────────┴────────┐
                    │ Lock Enabled?    │
                    └────────┬────────┘
                 YES ────────┤         NO
                             │          │
                             ▼          ▼
┌──────────────────────────────────────────────────────────────────────┐
│ LocalAuthentication.authenticate() ⚡ LOCAL ONLY                     │
│ - Show biometric prompt               │    Skip biometric auth       │
│ - Wait for user authentication        │                              │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                   ┌─────────┴─────────┐
                   │ Authentication     │
                   │   Successful?      │
                   └─────────┬─────────┘
               YES ─────────┤          NO
                            │           │
                            ▼           ▼
                      Continue    SystemNavigator.pop()
                                   (Close app)
                            │
                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│ FireflyService.signInFromStorage()                                   │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ storage.read('api_host')                      ⚡ LOCAL ONLY      │ │
│ │ storage.read('api_key')                                          │ │
│ └────────────────────────────┬───────────────────────────────────┘ │
└──────────────────────────────┼───────────────────────────────────────┘
                               │
                    ┌──────────┴──────────┐
                    │ Credentials Found?   │
                    └──────────┬──────────┘
                  YES ─────────┤          NO
                               │           │
                               ▼           ▼
┌──────────────────────────────────────────────────────────────────────┐
│ FireflyService.signIn(host, key)      │   Show LoginPage             │
│ (See Authentication Flow)              │                              │
└────────────────────────────┬───────────┴──────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ _startup = false, _authed = true                                     │
│ setState() → Rebuild                                                 │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ MaterialApp home: determined by state                                │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ _startup || !_authed? → SplashPage                              │ │
│ │ storageSignInException? → SplashPage                            │ │
│ │ signedIn && notificationPayload? → TransactionPage              │ │
│ │ signedIn && quickAction? → TransactionPage                      │ │
│ │ signedIn && filesShared? → TransactionPage                      │ │
│ │ signedIn → NavPage (Dashboard)                                  │ │
│ │ else → LoginPage                                                │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Authentication Flow

```
┌──────────────────────────────────────────────────────────────────────┐
│ LoginPage: User enters host & API key                                │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ FireflyService.signIn(host, apiKey)                                  │
│ - Strip whitespace and trailing slashes                              │
│ - Store lastTriedHost for error display                              │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ AuthUser.create(host, apiKey)                                        │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ STEP 1: Parse & Validate URL                                         │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ try { uri = Uri.parse(host) }                                    │ │
│ │ catch FormatException → throw AuthErrorHost(host)                │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ STEP 2: Test API Endpoint                                            │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ aboutUri = uri + "/api/v1/about"                                 │ │
│ │ request = http.Request(GET, aboutUri)                            │ │
│ │ request.headers['Authorization'] = "Bearer $apiKey"              │ │
│ │ request.followRedirects = true                                   │ │
│ │ request.maxRedirects = 5                                         │ │
│ │ response = await client.send(request)                            │ │
│ └────────────────────────────┬───────────────────────────────────┘ │
└──────────────────────────────┼───────────────────────────────────────┘
                               │
                    ┌──────────┴──────────┐
                    │ Content-Type:        │
                    │   text/html?         │
                    └──────────┬──────────┘
                      YES ─────┤          NO
                               │           │
                               ▼           │
             throw AuthErrorApiKey()       │
             (redirect to login page)      │
                                           │
                    ┌──────────────────────┘
                    │ Status Code?
                    └──────────┬──────────┐
                    200 ───────┤         != 200
                               │           │
                               │           ▼
                               │  throw AuthErrorStatusCode(code)
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────────┐
│ STEP 3: Parse Response Body                                          │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ stringData = await response.stream.bytesToString()               │ │
│ │ try { SystemInfo.fromJson(json.decode(stringData)) }            │ │
│ │ catch FormatException → throw AuthErrorNoInstance(host)          │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ STEP 4: Validate API Version                                         │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ about = api.v1AboutGet()                                         │ │
│ │ apiVersionStr = about.body.data.apiVersion                       │ │
│ │ if (apiVersionStr.startsWith("develop/"))                        │ │
│ │   apiVersionStr = "9.9.9"                                        │ │
│ │ apiVersion = Version.parse(apiVersionStr)                        │ │
│ │                                                                   │ │
│ │ if (apiVersion < 6.3.2)                                          │ │
│ │   throw AuthErrorVersionTooLow(minApiVersion)                    │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ AuthUser._create(uri, apiKey)                                        │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ _host = uri + "/api"                                             │ │
│ │ _apiKey = apiKey                                                 │ │
│ │ _api = FireflyIii.create(                                        │ │
│ │   baseUrl: _host,                                                │ │
│ │   httpClient: CronetClient,                                      │ │
│ │   interceptors: [APIRequestInterceptor(headers)]                 │ │
│ │ )                                                                 │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Back to FireflyService.signIn()                                      │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ _currentUser = authUser                                          │ │
│ │                                                                   │ │
│ │ // Fetch default currency                                        │ │
│ │ currencyInfo = api.v1CurrenciesPrimaryGet()                      │ │
│ │ defaultCurrency = currencyInfo.body.data                         │ │
│ │                                                                   │ │
│ │ // Fetch server timezone                                         │ │
│ │ tzUri = host + "/v1/configuration/app.timezone"                  │ │
│ │ response = client.get(tzUri, headers: user.headers())            │ │
│ │ reply = APITZReply.fromJson(json.decode(response.body))          │ │
│ │ tzHandler = TimeZoneHandler(reply.data.value)                    │ │
│ │                                                                   │ │
│ │ // Initialize cache                                              │ │
│ │ _transStock = TransStock(api)                                    │ │
│ │                                                                   │ │
│ │ // Update state                                                  │ │
│ │ _signedIn = true                                                 │ │
│ │ notifyListeners()                                                │ │
│ │                                                                   │ │
│ │ // Save credentials                                              │ │
│ │ storage.write('api_host', host)                                  │ │
│ │ storage.write('api_key', apiKey)                                 │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ UI Rebuilds (context.watch<FireflyService>().signedIn)               │
│ MaterialApp shows NavPage (Dashboard)                                │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Transaction Loading Flow

```
┌──────────────────────────────────────────────────────────────────────┐
│ TransactionListPage: User opens transaction list                     │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Build query key                                                       │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ queryOptions = {                                                 │ │
│ │   page: currentPage,                                             │ │
│ │   limit: 50,                                                     │ │
│ │   start: startDate,                                              │ │
│ │   end: endDate,                                                  │ │
│ │   type: TransactionTypeFilter.all                                │ │
│ │ }                                                                 │ │
│ │ queryKey = jsonEncode(queryOptions)                              │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ transStock.stream(queryKey)                                          │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Stock<String, List<String>>._getStock                                │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ Check _listSoT (SourceOfTruth cache)                            │ │
│ └────────────────────────────┬───────────────────────────────────┘ │
└──────────────────────────────┼───────────────────────────────────────┘
                               │
                    ┌──────────┴──────────┐
                    │ Cache Hit?           │
                    └──────────┬──────────┘
                  YES ─────────┤          NO
                               │           │
                               ▼           ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Return cached data                 │   Fetcher.fetch(queryKey)       │
│ StockResponse.Data(                │                                 │
│   value: cachedList,               │                                 │
│   origin: SourceOfTruth            │                                 │
│ )                                  │                                 │
└──────────────────────────────────────────────────────────────────────┘
                                           │
                                           ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Fetcher: Parse query & make API call                                 │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ query = _getOptions.fromJson(jsonDecode(queryKey))              │ │
│ │ response = api.v1TransactionsGet(                                │ │
│ │   page: query.page,                                              │ │
│ │   limit: query.limit,                                            │ │
│ │   start: query.start,                                            │ │
│ │   end: query.end,                                                │ │
│ │   type: query.type                                               │ │
│ │ )                                                                 │ │
│ └────────────────────────────┬───────────────────────────────────┘ │
└──────────────────────────────┼───────────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────────┐
│ APIRequestInterceptor.intercept()                                    │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ Add headers:                                                     │ │
│ │   Authorization: Bearer <apiKey>                                 │ │
│ │   Accept: application/json                                       │ │
│ │ Set followRedirects: true, maxRedirects: 5                       │ │
│ └────────────────────────────┬───────────────────────────────────┘ │
└──────────────────────────────┼───────────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────────┐
│ HTTP GET → Firefly III Server                                        │
│ URL: https://firefly.example.com/api/v1/transactions?page=1&limit=50 │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Response<TransactionArray>                                           │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ {                                                                │ │
│ │   "data": [                                                      │ │
│ │     {                                                            │ │
│ │       "id": "123",                                               │ │
│ │       "type": "withdrawal",                                      │ │
│ │       "attributes": { ... }                                      │ │
│ │     },                                                           │ │
│ │     ...                                                          │ │
│ │   ],                                                             │ │
│ │   "meta": { "pagination": { ... } }                              │ │
│ │ }                                                                 │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Chopper: JSON Deserialization                                        │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ jsonDecode(response.body)                                        │ │
│ │ TransactionArray.fromJson(json)                                  │ │
│ │ - TransactionRead objects created                                │ │
│ └────────────────────────────┬───────────────────────────────────┘ │
└──────────────────────────────┼───────────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────────┐
│ TransStock._onAPIValue(response)                                     │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ Check response.isSuccessful && body != null                      │ │
│ │                                                                   │ │
│ │ for (transaction in response.body.data) {                        │ │
│ │   // Cache individual transactions                               │ │
│ │   _singleSoT.write(transaction.id, transaction)                  │ │
│ │ }                                                                 │ │
│ │                                                                   │ │
│ │ // Return list of IDs                                            │ │
│ │ return response.body.data.map((e) => e.id).toList()              │ │
│ └────────────────────────────┬───────────────────────────────────┘ │
└──────────────────────────────┼───────────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────────┐
│ SourceOfTruth: Write to cache                                        │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ _listSoT.write(queryKey, idList)                                 │ │
│ │ Cache entry:                                                     │ │
│ │   key: '{"page":1,"limit":50,...}'                               │ │
│ │   value: ["123", "124", "125", ...]                              │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Stock: Emit StockResponse                                            │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ Stream emits:                                                    │ │
│ │   StockResponse.Loading()       // Initial                       │ │
│ │   StockResponse.Data(           // After fetch                   │ │
│ │     value: ["123", "124", ...],                                  │ │
│ │     origin: Fetcher                                              │ │
│ │   )                                                               │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ UI: StreamBuilder rebuilds                                           │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ if (snapshot.hasData && snapshot.data is Data) {                │ │
│ │   final idList = snapshot.data.value;                           │ │
│ │                                                                   │ │
│ │   // Fetch individual transactions from cache                   │ │
│ │   for (id in idList) {                                           │ │
│ │     final tx = await transStock.get(id).first;                  │ │
│ │     // tx is loaded from _singleSoT cache (instant)             │ │
│ │   }                                                               │ │
│ │                                                                   │ │
│ │   // Render list                                                 │ │
│ │   return ListView.builder(...);                                  │ │
│ │ }                                                                 │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

**Key Observations:**
1. **Two-level cache**: List of IDs (page) + Individual transactions
2. **Stream-based**: UI automatically updates when data arrives
3. **Request deduplication**: Multiple calls with same key use single fetch
4. **Efficient pagination**: Only IDs stored in list cache, full objects in single cache

---

## Transaction Creation Flow

```
┌──────────────────────────────────────────────────────────────────────┐
│ TransactionPage: User fills form                                     │
│ - Amount, description, date                                          │
│ - Source/destination accounts                                        │
│ - Category, budget, tags                                             │
│ - Attachments                                                        │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ User taps "Save" button                                              │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Form Validation                                                      │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ _formKey.currentState.validate()                                 │ │
│ │ - Amount > 0                                                     │ │
│ │ - Description not empty                                          │ │
│ │ - Source account set                                             │ │
│ │ - Destination account set (for transfers)                        │ │
│ └────────────────────────────┬───────────────────────────────────┘ │
└──────────────────────────────┼───────────────────────────────────────┘
                               │
                    ┌──────────┴──────────┐
                    │ Valid?               │
                    └──────────┬──────────┘
                  YES ─────────┤          NO
                               │           │
                               │           ▼
                               │   Show error messages
                               │   Stay on form
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Build TransactionStore object                                        │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ transaction = TransactionStore(                                  │ │
│ │   transactions: [                                                │ │
│ │     TransactionSplit(                                            │ │
│ │       type: TransactionTypeProperty.withdrawal,                  │ │
│ │       date: DateTime(...),                                       │ │
│ │       amount: "123.45",                                          │ │
│ │       description: "Grocery shopping",                           │ │
│ │       sourceId: accountId,                                       │ │
│ │       categoryId: categoryId,                                    │ │
│ │       budgetId: budgetId,                                        │ │
│ │       tags: ["groceries", "food"],                               │ │
│ │       notes: "Monthly shopping",                                 │ │
│ │     )                                                            │ │
│ │   ]                                                               │ │
│ │ )                                                                 │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ API Call: context.read<FireflyService>().api.v1TransactionsPost()   │
│ body: transaction                                                    │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Chopper: JSON Serialization                                          │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ transaction.toJson()                                             │ │
│ │ jsonEncode(map)                                                  │ │
│ └────────────────────────────┬───────────────────────────────────┘ │
└──────────────────────────────┼───────────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────────┐
│ APIRequestInterceptor: Add auth headers                              │
│ Authorization: Bearer <apiKey>                                       │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ HTTP POST → Firefly III Server                                       │
│ URL: https://firefly.example.com/api/v1/transactions                 │
│ Body: { "transactions": [ { ... } ] }                                │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Server: Process & Validate                                           │
│ - Create transaction in database                                     │
│ - Update account balances                                            │
│ - Link to budget/category                                            │
│ - Return created transaction                                         │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Response<TransactionSingle>                                          │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ {                                                                │ │
│ │   "data": {                                                      │ │
│ │     "id": "456",                                                 │ │
│ │     "type": "transactions",                                      │ │
│ │     "attributes": { ... }                                        │ │
│ │   }                                                               │ │
│ │ }                                                                 │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Check Response Status                                                │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ if (response.isSuccessful && response.body != null) {           │ │
│ │   // Success path                                                │ │
│ │ } else {                                                         │ │
│ │   // Error path                                                  │ │
│ │   throw Exception(response.error)                                │ │
│ │ }                                                                 │ │
│ └────────────────────────────┬───────────────────────────────────┘ │
└──────────────────────────────┼───────────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Upload Attachments (if any)                                          │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ for (file in attachments) {                                      │ │
│ │   // Create attachment metadata                                  │ │
│ │   attachmentResp = api.v1AttachmentsPost(...)                    │ │
│ │   attachmentId = attachmentResp.body.data.id                     │ │
│ │                                                                   │ │
│ │   // Upload file content                                         │ │
│ │   fileBytes = await file.readAsBytes()                           │ │
│ │   api.v1AttachmentsIdUploadPost(                                 │ │
│ │     id: attachmentId,                                            │ │
│ │     body: fileBytes                                              │ │
│ │   )                                                               │ │
│ │ }                                                                 │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Invalidate Cache                                                     │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ context.read<FireflyService>().transStock.clear()                │ │
│ │ - Clears all cached transaction lists                           │ │
│ │ - Clears individual transaction cache                           │ │
│ │ - Forces fresh fetch on next access                             │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Show Success Feedback                                                │
│ - ScaffoldMessenger.showSnackBar("Transaction created")              │
│ - Navigator.pop(context) → Return to previous screen                 │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Previous Screen (e.g., Transaction List)                             │
│ - Automatically refreshes due to cache invalidation                  │
│ - New transaction appears in list                                    │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Settings Management Flow

```
┌──────────────────────────────────────────────────────────────────────┐
│ App Launch → SettingsProvider.loadSettings()                         │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ SharedPreferences.getInstance()                                      │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Load Settings from Storage                                           │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ // Boolean flags (packed in single int)                          │ │
│ │ int bitmask = prefs.getInt('BOOLBITMASK') ?? 0                   │ │
│ │ _boolSettings = SettingsBitmask(bitmask)                         │ │
│ │                                                                   │ │
│ │ // Theme                                                          │ │
│ │ String? themeStr = prefs.getString('THEME')                      │ │
│ │ _theme = ThemeMode.values.byName(themeStr ?? 'system')           │ │
│ │                                                                   │ │
│ │ // Locale                                                         │ │
│ │ String? localeStr = prefs.getString('LOCALE')                    │ │
│ │ _locale = Locale(localeStr ?? systemLocale)                      │ │
│ │                                                                   │ │
│ │ // Dashboard cards                                                │ │
│ │ String? cardsStr = prefs.getString('DASHBOARD_CARDS')            │ │
│ │ _dashboardCards = cardsStr.split(',')                            │ │
│ │   .map((s) => DashboardCards.values.byName(s))                   │ │
│ │   .toList()                                                       │ │
│ │                                                                   │ │
│ │ // Notification apps                                              │ │
│ │ String? nlApps = prefs.getString('NL_APPS')                      │ │
│ │ _nlApps = jsonDecode(nlApps)                                     │ │
│ │   .map((app) => NotificationAppSettings.fromJson(app))           │ │
│ │   .toList()                                                       │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ _loaded = true, notifyListeners()                                    │
│ → App can now access settings via context.watch<SettingsProvider>()  │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│ User Changes Setting (e.g., toggle dark mode)                        │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ SettingsProvider.setTheme(ThemeMode.dark)                            │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ _theme = ThemeMode.dark                                          │ │
│ │ notifyListeners() → UI rebuilds immediately                      │ │
│ │                                                                   │ │
│ │ // Persist to storage                                            │ │
│ │ prefs = await SharedPreferences.getInstance()                    │ │
│ │ await prefs.setString('THEME', 'dark')                           │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│ Boolean Setting Example: Toggle Lock                                 │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ SettingsProvider.setBool(BoolSettings.lock, true)                    │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ _boolSettings[BoolSettings.lock] = true                          │ │
│ │ // Updates bitmask: _value |= (1 << lock.index)                  │ │
│ │                                                                   │ │
│ │ notifyListeners() → UI updates                                   │ │
│ │                                                                   │ │
│ │ // Persist bitmask                                                │ │
│ │ prefs = await SharedPreferences.getInstance()                    │ │
│ │ await prefs.setInt('BOOLBITMASK', _boolSettings._value)          │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

**Bitmask Storage Benefit:**
- Single `int` stores 8+ boolean flags
- Efficient storage (4 bytes vs 8+ keys)
- Atomic read/write operations

---

## Notification Processing Flow

```
┌──────────────────────────────────────────────────────────────────────┐
│ Android: Banking app sends notification                              │
│ "You spent $25.50 at Starbucks"                                      │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ NotificationListenerService (Android)                                │
│ - Intercepts notification                                            │
│ - Extracts: title, text, app package name                            │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Waterfly III: notificationlistener.dart                              │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ onNotification(title, text, packageName) {                       │ │
│ │   // Check if app is in configured list                          │ │
│ │   appSettings = settings.nlApps                                  │ │
│ │     .firstWhere((app) => app.packageName == packageName)         │ │
│ │                                                                   │ │
│ │   if (appSettings == null) return; // Ignore                     │ │
│ └────────────────────────────┬───────────────────────────────────┘ │
└──────────────────────────────┼───────────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Parse Notification Content                                           │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ notificationTx = NotificationTransaction(                        │ │
│ │   title: title,                                                  │ │
│ │   text: text,                                                    │ │
│ │   appName: appSettings.appName,                                  │ │
│ │   timestamp: DateTime.now()                                      │ │
│ │ )                                                                 │ │
│ │                                                                   │ │
│ │ // Extract amount using regex                                    │ │
│ │ RegExp amountPattern = RegExp(r'[\d.,]+')                        │ │
│ │ match = amountPattern.firstMatch(text)                           │ │
│ │ amount = match?.group(0) ?? ""                                   │ │
│ │                                                                   │ │
│ │ // Clean description (remove amount, symbols)                    │ │
│ │ description = text                                               │ │
│ │   .replaceAll(amount, "")                                        │ │
│ │   .replaceAll(RegExp(r'[$€£¥]'), "")                             │ │
│ │   .trim()                                                         │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
                    ┌────────┴────────┐
                    │ Auto-add enabled?│
                    └────────┬────────┘
                  YES ───────┤         NO
                             │          │
                             ▼          ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Auto-create transaction               │   Show local notification   │
│ (background)                          │   for manual review         │
│                                       │                              │
│ api.v1TransactionsPost(              │   FlutterLocalNotifications  │
│   TransactionStore(                   │   .show(                     │
│     amount: amount,                   │     title: "New expense",    │
│     description: description,         │     body: "$amount - $desc", │
│     sourceId: appSettings.accountId,  │     payload: json.encode(    │
│     date: timestamp                   │       notificationTx         │
│   )                                   │     )                        │
│ )                                     │   )                          │
└──────────────────────────────────────────────────────────────────────┘
                             │                           │
                             │                           ▼
                             │            ┌──────────────────────────┐
                             │            │ User taps notification    │
                             │            └──────────┬───────────────┘
                             │                       │
                             │                       ▼
                             │            ┌──────────────────────────┐
                             │            │ nlNotificationTap()       │
                             │            │ - Parse payload JSON      │
                             │            │ - Open TransactionPage    │
                             │            │ - Pre-fill form with data │
                             │            └───────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ TransStock.clear() → Refresh lists                                   │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Cache Invalidation Flow

```
┌──────────────────────────────────────────────────────────────────────┐
│ Trigger Event (User action that modifies data)                       │
│ - Create transaction                                                 │
│ - Edit transaction                                                   │
│ - Delete transaction                                                 │
│ - Create/edit category                                               │
│ - Modify account                                                     │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Determine Invalidation Scope                                         │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ 1. Single item modified?                                         │ │
│ │    → Invalidate single cache entry                               │ │
│ │                                                                   │ │
│ │ 2. List affected?                                                │ │
│ │    → Clear list cache (all queries)                              │ │
│ │                                                                   │ │
│ │ 3. Related data changed?                                         │ │
│ │    → Clear dependent caches                                      │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Example 1: Transaction Created                                       │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ context.read<FireflyService>().transStock.clear()                │ │
│ │                                                                   │ │
│ │ TransStock.clear() {                                             │ │
│ │   _listSoT.clear()      // All transaction lists                 │ │
│ │   _singleSoT.clear()    // All individual transactions           │ │
│ │   notifyListeners()                                              │ │
│ │ }                                                                 │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Example 2: Transaction Edited                                        │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ // Option A: Clear everything (simple but inefficient)           │ │
│ │ transStock.clear()                                               │ │
│ │                                                                   │ │
│ │ // Option B: Invalidate specific item (efficient)                │ │
│ │ _singleSoT.delete(transactionId)                                 │ │
│ │ _listSoT.clear() // Lists may contain this transaction           │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Stock Library: Handle Invalidation                                   │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ 1. Mark cache entries as stale                                   │ │
│ │ 2. Active streams receive StockResponse.NoNewData                │ │
│ │ 3. Next access triggers fresh fetch                              │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ UI Subscribers React                                                 │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ StreamBuilder receives new event                                 │ │
│ │                                                                   │ │
│ │ if (snapshot.data is NoNewData) {                                │ │
│ │   // Show loading indicator or keep old data                     │ │
│ │   return CircularProgressIndicator();                            │ │
│ │ }                                                                 │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Fresh Data Fetch Triggered                                           │
│ (See "Transaction Loading Flow")                                     │
│ - Fetcher makes API call                                             │
│ - New data populates cache                                           │
│ - Stream emits StockResponse.Data                                    │
│ - UI updates with fresh data                                         │
└──────────────────────────────────────────────────────────────────────┘
```

**Cache Invalidation Strategies:**

| Event | Scope | Method |
|-------|-------|--------|
| Create TX | Clear all TX lists & singles | `transStock.clear()` |
| Edit TX | Invalidate single + clear lists | `_singleSoT.delete(id)` + `_listSoT.clear()` |
| Delete TX | Clear all | `transStock.clear()` |
| Create Category | Clear category cache | `catStock.clear()` |
| Account balance change | Clear account cache | `accountStock.clear()` |
| Logout | Clear all caches + storage | `signOut()` |

---

## Network Requirements Summary

This section provides a comprehensive overview of where internet connectivity is required throughout the application.

### Authentication Flow - Network Requirements

| Step | Network Required | Details |
|------|-----------------|---------|
| User enters credentials | ⚡ Local Only | Form input processing |
| Parse & validate URL | ⚡ Local Only | URL format validation |
| **Test API endpoint** | **🌐 Internet Required** | **HTTP GET /api/v1/about** |
| **Validate response** | **🌐 Internet Required** | **Check server is Firefly III** |
| **Check API version** | **🌐 Internet Required** | **HTTP GET /api/v1/about** |
| **Fetch default currency** | **🌐 Internet Required** | **HTTP GET /api/v1/currencies/primary** |
| **Fetch server timezone** | **🌐 Internet Required** | **HTTP GET /api/v1/configuration/app.timezone** |
| Store credentials | ⚡ Local Only | Save to secure storage |
| Initialize cache | ⚡ Local Only | Create cache structures |

**Total: Authentication process requires internet to validate and configure**

---

### Transaction Loading Flow - Network Requirements

| Step | Network Required | Details |
|------|-----------------|---------|
| Build query parameters | ⚡ Local Only | Construct query string |
| Check cache | 💾 Offline Capable | Read from in-memory cache |
| **Fetch from API (cache miss)** | **🌐 Internet Required** | **HTTP GET /api/v1/transactions** |
| Parse JSON response | ⚡ Local Only | Deserialize data |
| Update cache | ⚡ Local Only | Write to cache |
| Render UI | 💾 Offline Capable | Display cached or fresh data |

**Total: Initial load requires internet; subsequent views use cache**

---

### Transaction Creation Flow - Network Requirements

| Step | Network Required | Details |
|------|-----------------|---------|
| Fill form | ⚡ Local Only | User input |
| Form validation | ⚡ Local Only | Client-side validation |
| Build transaction object | ⚡ Local Only | Create model |
| **Submit to server** | **🌐 Internet Required** | **HTTP POST /api/v1/transactions** |
| **Upload attachments** | **🌐 Internet Required** | **HTTP POST /api/v1/attachments** |
| Invalidate cache | ⚡ Local Only | Clear cached lists |
| Navigate back | ⚡ Local Only | UI navigation |

**Total: Creating/editing transactions requires internet**

---

### Settings Management Flow - Network Requirements

| Step | Network Required | Details |
|------|-----------------|---------|
| Load settings | ⚡ Local Only | Read from SharedPreferences |
| Change theme | ⚡ Local Only | Update local setting |
| Change locale | ⚡ Local Only | Update local setting |
| Save settings | ⚡ Local Only | Write to SharedPreferences |
| Apply settings | ⚡ Local Only | Update UI |

**Total: Settings management is completely offline**

---

### Notification Processing Flow - Network Requirements

| Step | Network Required | Details |
|------|-----------------|---------|
| Receive notification | ⚡ Local Only | Android system notification |
| Parse notification | ⚡ Local Only | Extract amount/description |
| Show local notification | ⚡ Local Only | User prompt |
| **Auto-add transaction** | **🌐 Internet Required** | **HTTP POST /api/v1/transactions** |
| User taps notification | ⚡ Local Only | Open form |
| Pre-fill form | ⚡ Local Only | Populate fields |

**Total: Notification parsing is offline; auto-add requires internet**

---

### Cache Operations - Network Requirements

| Operation | Network Required | Details |
|-----------|-----------------|---------|
| Read from cache | 💾 Offline Capable | Return cached data |
| Write to cache | ⚡ Local Only | Update cache |
| Invalidate cache | ⚡ Local Only | Mark as stale |
| Clear cache | ⚡ Local Only | Delete all entries |
| **Refresh cache** | **🌐 Internet Required** | **Fetch fresh data from server** |

---

### Complete Operations Matrix

#### 🌐 Operations REQUIRING Internet

1. **Authentication**
   - Initial login
   - Sign in from storage
   - API version check
   - Fetch server configuration

2. **Data Synchronization**
   - Load transactions (first time / cache miss)
   - Create transaction
   - Edit transaction
   - Delete transaction
   - Upload attachments
   - Load accounts, categories, budgets, bills
   - Search transactions
   - Fetch account balances
   - Load piggy banks

3. **Real-time Updates**
   - Pull to refresh
   - Sync latest data
   - Background data fetch

#### 💾 Operations WORKING Offline (with cache)

1. **Viewing Cached Data**
   - Browse previously loaded transactions
   - View cached account list
   - View cached categories
   - View cached bills
   - View charts with cached data
   - Open transaction details (if cached)

2. **Navigation**
   - Switch between tabs
   - Open screens
   - Browse UI

3. **Draft Creation** (Limited)
   - Fill transaction form
   - Select from cached accounts/categories
   - **Cannot submit until online**

#### ⚡ Operations COMPLETELY Local

1. **App Settings**
   - Change theme (light/dark/system)
   - Change language
   - Enable/disable biometric lock
   - Configure notification parsing
   - Adjust dashboard layout
   - Reorder dashboard cards

2. **Security**
   - Biometric authentication (fingerprint/face)
   - App lock/unlock
   - Screen timeout

3. **Cache Management**
   - Clear cache
   - View cache status

4. **UI Interactions**
   - Form validation (client-side)
   - Date/time picker
   - Amount calculator
   - Autocomplete (from cache)
   - Filtering (cached data)
   - Sorting (cached data)

---

### Network Error Handling

#### When Internet is Unavailable:

**What Happens:**
- API calls fail with timeout/connection errors
- App displays cached data if available
- Create/edit operations cannot complete
- Error messages: "No internet connection" or "Cannot reach server"

**User Experience:**
- ✅ Can browse previously loaded data
- ✅ Can change app settings
- ✅ Can fill transaction forms (but not submit)
- ❌ Cannot load new data
- ❌ Cannot submit transactions
- ❌ Cannot sync with server
- ❌ Cannot login (if not already logged in)

**Best Practices:**
1. Use app with internet connection for full functionality
2. Browse cached data when offline
3. Enable "show cached data" if available
4. Draft transactions will be lost on app close (no offline queue)
5. Always sync before going offline to ensure cache is fresh

---

### Cache Behavior & Limitations

**Cache Lifetime:**
- In-memory cache lives for current app session only
- Cache cleared on logout
- Cache cleared on app restart
- No persistent offline storage (by design)

**Cache Invalidation:**
- Automatic on create/edit/delete operations
- Manual via pull-to-refresh
- Automatic on cache timeout (per query)

**Offline Limitations:**
- No offline queue for pending transactions
- No background sync when offline
- Draft transactions not saved on app close
- Cache size limited by device memory

---

## Summary

This data flow documentation demonstrates:

1. **Startup Flow**: Multi-stage initialization with settings load and optional biometric auth (⚡ mostly local, 🌐 internet for sign-in)
2. **Authentication**: Robust validation with version checking and error handling (🌐 requires internet)
3. **Transaction Loading**: Two-level cache (IDs + objects) with stream-based updates (🌐 initial load, 💾 cached viewing)
4. **Transaction Creation**: Form validation → API call → cache invalidation → UI refresh (🌐 requires internet)
5. **Settings Management**: Bitmask-optimized storage with instant UI updates (⚡ completely local)
6. **Notification Processing**: Parse banking notifications → auto-add or manual review (⚡ parsing local, 🌐 submission requires internet)
7. **Cache Invalidation**: Strategic clearing based on data relationships (⚡ local operation)

**Key Architectural Strengths:**
- ✅ Clear unidirectional data flow (Action → API → Cache → UI)
- ✅ Efficient caching with granular invalidation
- ✅ Stream-based reactivity for real-time updates
- ✅ Type-safe API integration with code generation
- ✅ Separation of concerns (UI, business logic, data layer)
- ✅ **Clear network boundaries** - users know when internet is needed
5. **Settings Management**: Bitmask-optimized storage with instant UI updates
6. **Notification Processing**: Parse banking notifications → auto-add or manual review
7. **Cache Invalidation**: Strategic clearing based on data relationships

**Key Architectural Strengths:**
- ✅ Clear unidirectional data flow (Action → API → Cache → UI)
- ✅ Efficient caching with granular invalidation
- ✅ Stream-based reactivity for real-time updates
- ✅ Type-safe API integration with code generation
- ✅ Separation of concerns (UI, business logic, data layer)

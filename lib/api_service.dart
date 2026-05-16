import 'package:chopper/chopper.dart';
import 'package:flutter/foundation.dart';
import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';

class ApiService with ChangeNotifier {
  FireflyIii api;
  ApiService({required this.api});
  Future<CurrencyArray?> getCurrencyList() async {
    final Response<CurrencyArray> response = await api.v1CurrenciesGet();
    if (response.isSuccessful) {
      return response.body!;
    } else {
      log.warning("api currency fetch failed");
      return null;
    }
  }

  Future<AccountArray?> getAccountList({AccountTypeFilter? type}) async {
    final Response<AccountArray> response = await api.v1AccountsGet(type: type);
    if (response.isSuccessful) {
      return response.body!;
    } else {
      log.warning("api account fetch failed");
      return null;
    }
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qadam/core/services/cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('offline wallet data and balance cannot cross accounts', () async {
    SharedPreferences.setMockInitialValues({
      'qadam_cache_points_balance': '{"balance":999}',
    });
    final alice = CacheService(userId: 'alice');
    final bob = CacheService(userId: 'bob');
    await alice.cacheData('points_balance', {'balance': 50});
    expect(await alice.getCachedData('points_balance'), {'balance': 50});
    expect(await bob.getCachedData('points_balance'), isNull);
    expect(await CacheService().getCachedData('points_balance'), isNull);
    await bob.cacheData('points_balance', {'balance': 10});
    await alice.clearAccountCache();
    expect(await alice.getCachedData('points_balance'), isNull);
    expect(await bob.getCachedData('points_balance'), {'balance': 10});
  });
}

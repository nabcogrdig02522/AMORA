import 'package:flutter_test/flutter_test.dart';
import 'package:amora/regional/regional_country.dart';

void main() {
  group('AMORA regional market catalogue', () {
    test('Ghana is the initial market', () {
      expect(AmoraMarkets.byCode('GH').name, 'Ghana');
      expect(AmoraMarkets.byCode('GH').isInitialMarket, isTrue);
    });
    test('market codes are unique and include 16 planned markets', () {
      final codes = AmoraMarkets.countries.map((country) => country.code).toList();
      expect(codes.length, 16);
      expect(codes.toSet().length, codes.length);
    });
  });
}

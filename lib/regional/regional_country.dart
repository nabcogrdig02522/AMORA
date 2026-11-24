class RegionalCountry {
  const RegionalCountry({required this.code, required this.name, required this.currency, required this.exampleCity});
  final String code;
  final String name;
  final String currency;
  final String exampleCity;
  bool get isInitialMarket => code == 'GH';
}

class AmoraMarkets {
  static const countries = <RegionalCountry>[
    RegionalCountry(code: 'GH', name: 'Ghana', currency: 'GHS', exampleCity: 'Accra'),
    RegionalCountry(code: 'NG', name: 'Nigeria', currency: 'NGN', exampleCity: 'Lagos'),
    RegionalCountry(code: 'CI', name: 'Côte d’Ivoire', currency: 'XOF', exampleCity: 'Abidjan'),
    RegionalCountry(code: 'SN', name: 'Senegal', currency: 'XOF', exampleCity: 'Dakar'),
    RegionalCountry(code: 'BJ', name: 'Benin', currency: 'XOF', exampleCity: 'Cotonou'),
    RegionalCountry(code: 'TG', name: 'Togo', currency: 'XOF', exampleCity: 'Lomé'),
    RegionalCountry(code: 'BF', name: 'Burkina Faso', currency: 'XOF', exampleCity: 'Ouagadougou'),
    RegionalCountry(code: 'ML', name: 'Mali', currency: 'XOF', exampleCity: 'Bamako'),
    RegionalCountry(code: 'NE', name: 'Niger', currency: 'XOF', exampleCity: 'Niamey'),
    RegionalCountry(code: 'GN', name: 'Guinea', currency: 'GNF', exampleCity: 'Conakry'),
    RegionalCountry(code: 'GW', name: 'Guinea-Bissau', currency: 'XOF', exampleCity: 'Bissau'),
    RegionalCountry(code: 'LR', name: 'Liberia', currency: 'LRD', exampleCity: 'Monrovia'),
    RegionalCountry(code: 'SL', name: 'Sierra Leone', currency: 'SLE', exampleCity: 'Freetown'),
    RegionalCountry(code: 'GM', name: 'The Gambia', currency: 'GMD', exampleCity: 'Banjul'),
    RegionalCountry(code: 'CV', name: 'Cabo Verde', currency: 'CVE', exampleCity: 'Praia'),
    RegionalCountry(code: 'MR', name: 'Mauritania', currency: 'MRU', exampleCity: 'Nouakchott')
  ];

  static RegionalCountry byCode(String code) => countries.firstWhere(
    (country) => country.code == code,
    orElse: () => countries.first,
  );
}

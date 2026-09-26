/// Dial codes with the national-number length allowed for each country (digits after the code).
/// ponytail: hand-picked common countries; swap in a full ITU table if a market outside this list is added.
class Country {
  const Country(this.iso, this.name, this.dial, this.min, [int? max]) : max = max ?? min;
  final String iso, name, dial;
  final int min, max;
}

const india = Country('IN', 'India', '+91', 10);

const countries = <Country>[
  india,
  Country('US', 'United States', '+1', 10),
  Country('CA', 'Canada', '+1', 10),
  Country('GB', 'United Kingdom', '+44', 10),
  Country('AE', 'United Arab Emirates', '+971', 9),
  Country('SA', 'Saudi Arabia', '+966', 9),
  Country('QA', 'Qatar', '+974', 8),
  Country('KW', 'Kuwait', '+965', 8),
  Country('OM', 'Oman', '+968', 8),
  Country('BH', 'Bahrain', '+973', 8),
  Country('PK', 'Pakistan', '+92', 10),
  Country('BD', 'Bangladesh', '+880', 10),
  Country('LK', 'Sri Lanka', '+94', 9),
  Country('NP', 'Nepal', '+977', 10),
  Country('BT', 'Bhutan', '+975', 8),
  Country('MV', 'Maldives', '+960', 7),
  Country('SG', 'Singapore', '+65', 8),
  Country('MY', 'Malaysia', '+60', 9, 10),
  Country('ID', 'Indonesia', '+62', 9, 12),
  Country('TH', 'Thailand', '+66', 9),
  Country('VN', 'Vietnam', '+84', 9),
  Country('PH', 'Philippines', '+63', 10),
  Country('CN', 'China', '+86', 11),
  Country('JP', 'Japan', '+81', 10),
  Country('KR', 'South Korea', '+82', 9, 10),
  Country('AU', 'Australia', '+61', 9),
  Country('NZ', 'New Zealand', '+64', 8, 10),
  Country('DE', 'Germany', '+49', 10, 11),
  Country('FR', 'France', '+33', 9),
  Country('IT', 'Italy', '+39', 9, 10),
  Country('ES', 'Spain', '+34', 9),
  Country('NL', 'Netherlands', '+31', 9),
  Country('BE', 'Belgium', '+32', 8, 9),
  Country('CH', 'Switzerland', '+41', 9),
  Country('SE', 'Sweden', '+46', 7, 10),
  Country('IE', 'Ireland', '+353', 9),
  Country('PL', 'Poland', '+48', 9),
  Country('TR', 'Turkey', '+90', 10),
  Country('RU', 'Russia', '+7', 10),
  Country('EG', 'Egypt', '+20', 10),
  Country('ZA', 'South Africa', '+27', 9),
  Country('NG', 'Nigeria', '+234', 10),
  Country('KE', 'Kenya', '+254', 9),
  Country('BR', 'Brazil', '+55', 10, 11),
  Country('MX', 'Mexico', '+52', 10),
  Country('AR', 'Argentina', '+54', 10),
];

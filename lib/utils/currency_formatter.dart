import 'package:intl/intl.dart';

final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'es_AR');

String formatCurrency(num? value) => '\$' + _currencyFormat.format(value ?? 0);

String formatNumber(num? value) => _currencyFormat.format(value ?? 0);

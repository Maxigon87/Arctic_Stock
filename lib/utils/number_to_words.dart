String numberToWords(double number) {
  if (number < 0) {
    return 'menos ' + numberToWords(-number);
  }
  
  int integerPart = number.truncate();
  int decimalPart = ((number - integerPart).abs() * 100).round();

  String integerText = _integerToWordsInternal(integerPart);
  if (integerText.isEmpty) {
    integerText = 'cero';
  }

  // Adjust grammatical endings in Spanish (e.g., "uno" -> "un" / "veintiuno" -> "veintiún")
  integerText = _cleanUpSuffix(integerText);

  String currencyLabel = (integerPart == 1) ? 'peso' : 'pesos';
  String prep = '';
  if (integerText.endsWith('millón') || integerText.endsWith('millones')) {
    prep = 'de ';
  }
  
  String result = '$integerText $prep$currencyLabel';
  
  if (decimalPart > 0) {
    String decimalText = _integerToWordsInternal(decimalPart);
    decimalText = _cleanUpSuffix(decimalText);
    String centsLabel = (decimalPart == 1) ? 'centavo' : 'centavos';
    result += ' con $decimalText $centsLabel';
  }

  if (result.isNotEmpty) {
    result = result[0].toUpperCase() + result.substring(1);
  }
  return result;
}

String _cleanUpSuffix(String text) {
  if (text == 'uno') return 'un';
  if (text.endsWith(' veintiuno')) {
    return text.substring(0, text.length - 9) + 'veintiún';
  }
  if (text == 'veintiuno') {
    return 'veintiún';
  }
  if (text.endsWith(' uno')) {
    return text.substring(0, text.length - 4) + ' un';
  }
  return text;
}

String _integerToWordsInternal(int number) {
  if (number == 0) return '';

  if (number < 30) {
    const List<String> units = [
      '', 'uno', 'dos', 'tres', 'cuatro', 'cinco', 'seis', 'siete', 'ocho', 'nueve', 'diez',
      'once', 'doce', 'trece', 'catorce', 'quince', 'dieciséis', 'diecisiete', 'dieciocho', 'diecinueve', 'veinte',
      'veintiuno', 'veintidós', 'veintitrés', 'veinticuatro', 'veinticinco', 'veintiséis', 'veintisiete', 'veintiocho', 'veintinueve'
    ];
    return units[number];
  }

  if (number < 100) {
    const List<String> tens = [
      '', '', '', 'treinta', 'cuarenta', 'cincuenta', 'sesenta', 'setenta', 'ochenta', 'noventa'
    ];
    int ten = number ~/ 10;
    int unit = number % 10;
    if (unit == 0) return tens[ten];
    return tens[ten] + ' y ' + _integerToWordsInternal(unit);
  }

  if (number < 100) {
    return '';
  }

  if (number < 1000) {
    if (number == 100) return 'cien';
    const List<String> hundreds = [
      '', 'ciento', 'doscientos', 'trescientos', 'cuatrocientos', 'quinientos', 'seiscientos', 'setecientos', 'ochocientos', 'novecientos'
    ];
    int hundred = number ~/ 100;
    int remainder = number % 100;
    if (remainder == 0) return hundreds[hundred];
    return hundreds[hundred] + ' ' + _integerToWordsInternal(remainder);
  }

  if (number < 1000000) {
    int thousands = number ~/ 1000;
    int remainder = number % 1000;
    
    String thousandStr;
    if (thousands == 1) {
      thousandStr = 'mil';
    } else {
      String thText = _integerToWordsInternal(thousands);
      if (thText.endsWith('uno')) {
        thText = thText.substring(0, thText.length - 3) + 'ún';
      } else if (thText == 'uno') {
        thText = 'un';
      }
      thousandStr = '$thText mil';
    }
    
    if (remainder == 0) return thousandStr;
    return thousandStr + ' ' + _integerToWordsInternal(remainder);
  }

  if (number < 1000000000000) {
    int millions = number ~/ 1000000;
    int remainder = number % 1000000;
    
    String millionStr;
    if (millions == 1) {
      millionStr = 'un millón';
    } else {
      String millText = _integerToWordsInternal(millions);
      if (millText.endsWith('uno')) {
        millText = millText.substring(0, millText.length - 3) + 'ún';
      } else if (millText == 'uno') {
        millText = 'un';
      }
      millionStr = '$millText millones';
    }
    
    if (remainder == 0) return millionStr;
    return millionStr + ' ' + _integerToWordsInternal(remainder);
  }

  return number.toString();
}

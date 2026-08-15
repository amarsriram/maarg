class StringUtils {
  static String capitalizeWords(String input) {
    if (input.trim().isEmpty) return input;
    return input.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  static String formatWeight(String weight) {
    if (weight.trim().isEmpty) return '';
    final w = double.tryParse(weight.replaceAll(RegExp(r'[^0-9.]'), ''));
    if (w == null) return weight;
    final suffix = (w <= 1.0) ? 'Ton' : 'Tons';
    final wStr = w == w.toInt() ? w.toInt().toString() : w.toString();
    return '$wStr $suffix';
  }
}

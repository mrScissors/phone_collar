String formatPhoneNumber(String phoneNumber) {
  // Remove all non-numeric characters
  String numericPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');

  // Get the last 10 digits
  return numericPhone.length <= 10 ? numericPhone : numericPhone.substring(numericPhone.length - 10);
}

bool containsAlphabet(String input) {
  return RegExp(r'[a-zA-Z]').hasMatch(input);
}
String formatPhoneNumber(String phoneNumber) {
  // Get last 10 digits of the phone number
  return phoneNumber.substring(
      phoneNumber.length < 10 ? 0 : phoneNumber.length - 10
  );
}
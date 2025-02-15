String formatSearchName(String name) {
  // Remove special characters, extra spaces, and convert to lowercase
  return name
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]+'), '')
      .trim();
}
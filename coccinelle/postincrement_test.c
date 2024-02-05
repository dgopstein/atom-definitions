int main() {
  int x = 1;

  x++; // value is not used, should not be replaced

  a + x++; // should parenthesize replacement

  return 0;
}

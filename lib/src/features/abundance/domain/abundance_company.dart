/// Whether the authenticated user's active InnerU company is Abundance.
///
/// The company code is authoritative. Display names are deliberately ignored
/// because they are mutable labels and cannot establish tenant membership.
class AbundanceCompany {
  const AbundanceCompany._();

  static bool matches(String? code, String? name) {
    final normalizedCode = (code ?? '').trim().toUpperCase();
    return normalizedCode == 'ABU15DN';
  }
}

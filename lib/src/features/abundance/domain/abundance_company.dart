/// Whether the authenticated user's active InnerU company is Abundance.
///
/// The company code is authoritative. Display names are deliberately ignored
/// because they are mutable labels and cannot establish tenant membership.
class AbundanceCompany {
  const AbundanceCompany._();

  static const code = 'ABU15DN';
  static const coachSignupRestrictionTitle =
      'Coach accounts are managed by Abundance admins';
  static const coachSignupRestrictionMessage =
      'You cannot create a Coach account with the Abundance company code. '
      'Create a User account instead, then ask the Abundance administrator '
      'to make you a Coach.';
  static const coachSignupRestrictionAction = 'Create a User account instead';

  static bool matches(String? code, String? name) {
    final normalizedCode = (code ?? '').trim().toUpperCase();
    return normalizedCode == AbundanceCompany.code;
  }
}

import '../models/payment.dart';
import '../models/platform.dart';

/// Internal. Not exported from `package:branta/branta.dart`.
extension EffectiveBrand on Payment {
  /// `brand` if set, otherwise the deprecated `childPlatform`.
  Platform? get effectiveBrand =>
      // ignore: deprecated_member_use_from_same_package
      brand ?? childPlatform;
}

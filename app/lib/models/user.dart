class AppUser {
  final String id;
  final String email;
  final double mileageRate;
  final String currency;
  final String subscriptionStatus;
  final bool classifyWeekendsAsPersonal;

  AppUser({
    required this.id,
    required this.email,
    required this.mileageRate,
    required this.currency,
    required this.subscriptionStatus,
    required this.classifyWeekendsAsPersonal,
  });

  bool get isSubscribed => subscriptionStatus == 'active';

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      mileageRate: (json['mileageRate'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      subscriptionStatus: json['subscriptionStatus'] as String? ?? 'free',
      classifyWeekendsAsPersonal: json['classifyWeekendsAsPersonal'] as bool? ?? false,
    );
  }
}

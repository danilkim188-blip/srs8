import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

/// Автор. Содержит вложенные модели [Company] и [Address];
/// необязательные поля — nullable.
@JsonSerializable(explicitToJson: true)
class User {
  const User({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    this.phone,
    this.website,
    this.company,
    this.address,
  });

  final int id;
  final String name;
  final String username;
  final String email;
  final String? phone;
  final String? website;
  final Company? company;
  final Address? address;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}

@JsonSerializable()
class Company {
  const Company({required this.name, this.catchPhrase, this.bs});

  final String name;
  final String? catchPhrase;
  final String? bs;

  factory Company.fromJson(Map<String, dynamic> json) =>
      _$CompanyFromJson(json);
  Map<String, dynamic> toJson() => _$CompanyToJson(this);
}

@JsonSerializable()
class Address {
  const Address({this.street, this.suite, this.city, this.zipcode});

  final String? street;
  final String? suite;
  final String? city;
  final String? zipcode;

  factory Address.fromJson(Map<String, dynamic> json) =>
      _$AddressFromJson(json);
  Map<String, dynamic> toJson() => _$AddressToJson(this);
}

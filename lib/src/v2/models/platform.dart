class Platform {
  final String? name;
  final String? logoUrl;
  final String? logoLightUrl;

  const Platform({this.name, this.logoUrl, this.logoLightUrl});

  factory Platform.fromJson(Map<String, dynamic> json) => Platform(
        name: json['name'] as String?,
        logoUrl: json['logo_url'] as String?,
        logoLightUrl: json['logo_light_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (logoUrl != null) 'logo_url': logoUrl,
        if (logoLightUrl != null) 'logo_light_url': logoLightUrl,
      };
}

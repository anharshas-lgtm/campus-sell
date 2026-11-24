class CloudinaryConfig {
  // ⚠️ Replace these with your actual Cloudinary values
  static const String cloudName   = 'dwqy5mcbq';
  static const String uploadPreset = 'campus_mart_preset';

  // Upload endpoint — no API key needed for unsigned uploads
  static String get uploadUrl =>
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
}
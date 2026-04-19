import 'package:url_launcher/url_launcher.dart';

/// WhatsApp Service for sending payment reminder messages
///
/// Purpose: This service provides functionality to send payment reminder messages
/// via WhatsApp without using any paid APIs. It simply opens WhatsApp with a
/// pre-filled message that the user can review and send manually.
///
/// The service handles:
/// - Phone number formatting (Pakistan: 92 country code, no leading 0)
/// - Message encoding for URL safety
/// - WhatsApp URL launching with proper error handling
class WhatsAppService {
  /// Sends a WhatsApp message to the specified phone number
  ///
  /// Parameters:
  /// - [phoneNumber]: The customer's phone number (can be in various formats)
  /// - [message]: The message content to send (automatically URL-encoded)
  ///
  /// Returns:
  /// - A string with the result message (success or error description)
  ///
  /// The phone number is expected to be in formats like:
  /// - "03001234567" (Pakistan format without country code)
  /// - "923001234567" (Pakistan format with country code)
  /// - "+923001234567" (International format)
  ///
  /// The function will format it to the international format required by WhatsApp
  static Future<String> sendWhatsAppMessage({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      // Step 1: Validate that phone number is not empty
      if (phoneNumber.isEmpty) {
        return 'Error: Phone number is required';
      }

      // Step 2: Validate that message is not empty
      if (message.isEmpty) {
        return 'Error: Message cannot be empty';
      }

      // Step 3: Format the phone number to international format
      final formattedPhone = _formatPhoneNumber(phoneNumber);

      // Step 4: Validate formatted phone number
      if (formattedPhone.isEmpty) {
        return 'Error: Invalid phone number format';
      }

      // Step 5: Encode the message for URL safety
      final encodedMessage = Uri.encodeComponent(message);

      // Step 6: Build the WhatsApp URL
      final whatsappUrl = Uri.parse('https://wa.me/$formattedPhone?text=$encodedMessage');

      // Step 7: Launch WhatsApp with external application mode
      final bool canLaunch = await canLaunchUrl(whatsappUrl);
      if (!canLaunch) {
        return 'Error: WhatsApp is not installed on this device';
      }

      // Step 8: Open WhatsApp
      await launchUrl(
        whatsappUrl,
        mode: LaunchMode.externalApplication,
      );

      return 'WhatsApp opened successfully';
    } catch (e) {
      return 'Error: Failed to open WhatsApp - ${e.toString()}';
    }
  }

  /// Formats phone number to international format (Pakistan: 92 prefix)
  ///
  /// This function handles various input formats:
  /// - "03001234567" → "923001234567"
  /// - "923001234567" → "923001234567"
  /// - "+923001234567" → "923001234567"
  /// - "3001234567" → "923001234567" (assumes Pakistan)
  ///
  /// Returns the formatted phone number without any special characters
  static String _formatPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters except leading +
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // Remove leading +
    if (cleaned.startsWith('+')) {
      cleaned = cleaned.substring(1);
    }

    // If it starts with 0 (Pakistan local format), replace with 92 (country code)
    if (cleaned.startsWith('0')) {
      cleaned = '92${cleaned.substring(1)}';
    }

    // If it doesn't start with country code, assume Pakistan (92)
    if (!cleaned.startsWith('92') && cleaned.length >= 10) {
      // If it's 10 digits and starts with 3, it's likely Pakistan format
      if (cleaned.startsWith('3') && cleaned.length == 10) {
        cleaned = '92$cleaned';
      }
    }

    // Validate that we have a reasonable phone number
    if (cleaned.isEmpty || cleaned.length < 10) {
      return '';
    }

    return cleaned;
  }
}


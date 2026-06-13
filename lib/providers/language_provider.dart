import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

class LanguageProvider extends ChangeNotifier {
  // Google Cloud Translation API Key
  static const String _googleApiKey = 'AIzaSyD4Xeo3GNpP0ZhIMGeFub_o6pPwBmAHk5s';

  Locale _locale = const Locale('en');
  bool _isLoading = false;
  Map<String, String> _dynamicTranslations = {};
  final Set<String> _pendingTranslations = {};

  Locale get locale => _locale;
  bool get isLoading => _isLoading;

  LanguageProvider() {
    _loadLanguage();
  }

  // Load language from Shared Preferences and dynamic cache
  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('language_code') ?? 'en';
    _locale = Locale(langCode);
    await _loadCachedTranslations(langCode);
    debugPrint('LanguageProvider initialized with locale: $langCode. Cached translations count: ${_dynamicTranslations.length}');
    notifyListeners();
  }

  // Save/Change language and download translations if not cached
  Future<void> setLanguage(String langCode) async {
    debugPrint('setLanguage called with langCode: $langCode');
    if (_locale.languageCode == langCode && _dynamicTranslations.isNotEmpty) {
      debugPrint('Language is already $langCode and cache is not empty. Skipping download.');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      if (langCode != 'en') {
        final cachedJson = prefs.getString('cached_translations_$langCode');
        bool needsFetch = false;
        if (cachedJson == null) {
          debugPrint('No cached translations found for $langCode. Will download.');
          needsFetch = true;
        } else {
          try {
            final Map<String, dynamic> decoded = jsonDecode(cachedJson);
            if (decoded.isEmpty) {
              debugPrint('Cached translations for $langCode are empty. Will re-download.');
              needsFetch = true;
            } else {
              debugPrint('Found ${decoded.length} cached translations for $langCode.');
            }
          } catch (e) {
            debugPrint('Failed to parse cached translations for $langCode: $e. Will re-download.');
            needsFetch = true;
          }
        }

        if (needsFetch) {
          final Map<String, String> newTranslations = await _fetchTranslationsFromGoogle(langCode);
          if (newTranslations.isNotEmpty) {
            await prefs.setString('cached_translations_$langCode', jsonEncode(newTranslations));
            debugPrint('Successfully saved ${newTranslations.length} translations for $langCode to SharedPreferences.');
          } else {
            debugPrint('No translations returned from Google Translate for $langCode.');
          }
        }
      }

      _locale = Locale(langCode);
      await prefs.setString('language_code', langCode);
      await _loadCachedTranslations(langCode);
    } catch (e) {
      debugPrint('Error setting language / fetching Google translations: $e');
      // Fallback: still change language code so hardcoded translations work
      _locale = Locale(langCode);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language_code', langCode);
      await _loadCachedTranslations(langCode);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load dynamic translations from local SharedPreferences cache
  Future<void> _loadCachedTranslations(String langCode) async {
    if (langCode == 'en') {
      _dynamicTranslations = {};
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString('cached_translations_$langCode');
    if (cachedJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(cachedJson);
        _dynamicTranslations = decoded.map((key, value) => MapEntry(key, value.toString()));
        debugPrint('Loaded ${_dynamicTranslations.length} dynamic translations from cache for $langCode.');
      } catch (e) {
        debugPrint('Error decoding cached translations: $e');
        _dynamicTranslations = {};
      }
    } else {
      debugPrint('No SharedPreferences entry for cached_translations_$langCode');
      _dynamicTranslations = {};
    }
  }

  // Fetch all translations for a given language code using Google Translate API in chunks
  Future<Map<String, String>> _fetchTranslationsFromGoogle(String langCode) async {
    debugPrint('Starting fetch from Google Translate for language: $langCode');
    if (_googleApiKey.isEmpty || _googleApiKey == 'YOUR_GOOGLE_TRANSLATION_API_KEY') {
      debugPrint('Google Translation API Key is missing or default. Falling back to local maps.');
      return {};
    }

    final englishMap = _translations['en'];
    if (englishMap == null || englishMap.isEmpty) {
      debugPrint('English translations map is empty or null.');
      return {};
    }

    final keys = englishMap.keys.toList();
    final Map<String, String> result = {};

    // Use chunks of 40 to avoid hitting Google Translate request payload or URI size limitations
    const int chunkSize = 40;
    debugPrint('Translating ${keys.length} keys in chunks of $chunkSize...');

    for (int i = 0; i < keys.length; i += chunkSize) {
      final chunkKeys = keys.sublist(i, i + chunkSize > keys.length ? keys.length : i + chunkSize);
      final chunkValues = chunkKeys.map((k) => englishMap[k]!).toList();

      final url = Uri.parse('https://translation.googleapis.com/language/translate/v2?key=$_googleApiKey');
      
      debugPrint('Posting chunk ${i ~/ chunkSize + 1} (${chunkKeys.length} items) to Google Translate...');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'q': chunkValues,
          'target': langCode,
          'source': 'en',
          'format': 'text',
        }),
      );

      debugPrint('Google Translate response status for chunk ${i ~/ chunkSize + 1}: ${response.statusCode}');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> translations = data['data']['translations'];
        debugPrint('Received ${translations.length} translations for chunk.');
        
        for (int j = 0; j < chunkKeys.length; j++) {
          if (j < translations.length) {
            result[chunkKeys[j]] = translations[j]['translatedText']?.toString() ?? chunkValues[j];
          } else {
            result[chunkKeys[j]] = chunkValues[j];
          }
        }
      } else {
        debugPrint('Google Translate error response body: ${response.body}');
        throw Exception('Google Translate API error: ${response.statusCode} - ${response.body}');
      }
    }

    debugPrint('Finished fetching all translations from Google. Total items translated: ${result.length}');
    return result;
  }

  // Translation helper (Checks dynamic cache first, then static fallbacks, then English)
  String translate(String key) {
    final currentLang = _locale.languageCode;
    
    // 1. If English, return English value directly
    if (currentLang == 'en') {
      return _translations['en']?[key] ?? key;
    }

    // 2. Try dynamically translated and cached values from Google API
    if (_dynamicTranslations.containsKey(key)) {
      return _dynamicTranslations[key]!;
    }

    // 3. Try hardcoded static fallback translations
    if (_translations.containsKey(currentLang) &&
        _translations[currentLang]!.containsKey(key)) {
      return _translations[currentLang]![key]!;
    }

    // 4. Try English master dictionary as a last resort
    if (_translations['en']!.containsKey(key)) {
      return _translations['en']!.containsKey(key) ? _translations['en']![key]! : key;
    }

    return key;
  }

  // Dynamic on-demand translation helper for hardcoded English texts
  String translateDynamic(String text) {
    if (text.isEmpty) return text;
    
    final currentLang = _locale.languageCode;
    if (currentLang == 'en') {
      return text;
    }

    // 1. If the text itself matches a key in our translations map, translate it using standard method
    if (_translations['en']!.containsKey(text)) {
      return translate(text);
    }
    
    // Also check lowercase version of the text
    final lowerKey = text.toLowerCase().replaceAll(' ', '_');
    if (_translations['en']!.containsKey(lowerKey)) {
      return translate(lowerKey);
    }

    // 2. Check if we already have it in our dynamic cache
    if (_dynamicTranslations.containsKey(text)) {
      return _dynamicTranslations[text]!;
    }

    // 3. Trigger asynchronous background translation
    if (!_pendingTranslations.contains(text)) {
      _pendingTranslations.add(text);
      _fetchAndCacheSingleText(text, currentLang);
    }

    return text;
  }

  // Fetch translation for a single text asynchronously in the background and notify listeners
  Future<void> _fetchAndCacheSingleText(String text, String langCode) async {
    try {
      if (_googleApiKey.isEmpty || _googleApiKey == 'YOUR_GOOGLE_TRANSLATION_API_KEY') {
        _pendingTranslations.remove(text);
        return;
      }

      final url = Uri.parse('https://translation.googleapis.com/language/translate/v2?key=$_googleApiKey');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'q': [text],
          'target': langCode,
          'source': 'en',
          'format': 'text',
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> translations = data['data']['translations'];
        if (translations.isNotEmpty) {
          final translatedText = translations[0]['translatedText']?.toString() ?? text;
          
          // Save in memory
          _dynamicTranslations[text] = translatedText;
          
          // Save in SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_translations_$langCode', jsonEncode(_dynamicTranslations));
          debugPrint('On-demand translation cached: "$text" -> "$translatedText" ($langCode)');
        }
      }
    } catch (e) {
      debugPrint('Error in dynamic translation for "$text": $e');
    } finally {
      _pendingTranslations.remove(text);
      notifyListeners();
    }
  }

  static const Map<String, Map<String, String>> _translations = {
    'en': {
      'dashboard': 'Dashboard',
      'menu': 'Menu',
      'new_job': 'New Job',
      'book_now': 'Book Now',
      'bookings': 'Bookings',
      'bill': 'Bill',
      'outstanding': 'Outstanding',
      'receipt': 'Receipt',
      'customers': 'Customers',
      'schemes': 'Schemes',
      'reports': 'Reports',
      'vehicle': 'Vehicle',
      'broadcasts': 'Broadcasts',
      'language': 'Language',
      'complaints': 'Complaints',
      'logout': 'Logout',
      'welcome_back': 'Welcome Back',
      'quick_menu': 'Quick Menu',
      'login': 'Login',
      'username_or_email': 'Username or Email',
      'enter_username_or_email': 'Enter username or email',
      'password': 'Password',
      'enter_password': 'Enter password',
      'remember_me': 'Remember me',
      'forgot_password': 'Forgot Password?',
      'sign_in': 'Sign In',
      'logout_confirm': 'Are you sure you want to logout?',
      'cancel': 'Cancel',
      'branch_admin': 'Branch Admin',
      'company_admin': 'Company Admin',
      'recent_invoices': 'Recent Invoices',
      'select_language': 'Select Language',
      'admin_login': 'Admin Login',
      'username': 'Username',
      'please_enter_credentials': 'Please enter username and password',
      'todays_summary': "Today's Summary",
      'overview': 'Overview',
      'todays_recent_jobs': "Today's Recent Jobs",
      'revenue': 'Revenue',
      'collected': 'Collected',
      'jobs': 'Jobs',
      'due': 'Due',
      'paid': 'Paid',
      'invoices_count': 'invoices',
      'exit_app': 'Exit App',
      'exit_confirm': 'Do you want to close the app?',
      'exit': 'Exit',
      'bills': 'Bills',
      'vehicle_search': 'Vehicle Search',
      'not_authenticated': 'Not authenticated',
      'network_error': 'Network error',
      'failed_to_load': 'Failed to load',
      'retry': 'Retry',
      'save': 'Save',
      'saving': 'Saving...',
      'delete': 'Delete',
      'add': 'Add',
      'create': 'Create',
      'date': 'Date',
      'start': 'Start',
      'end': 'End',
      'status': 'Status',
      'description': 'Description',
      'name': 'Name',
      'phone': 'Phone',
      'email': 'Email',
      'address': 'Address',
      'actions': 'Actions',
      'total': 'Total',
      'balance': 'Balance',
      'amount': 'Amount',
      'all': 'All',
      'available_schemes': 'Available Schemes',
      'no_schemes_available': 'No schemes available',
      'add_scheme': 'Add Scheme',
      'scheme_name': 'Scheme Name',
      'scheme_type': 'Scheme Type',
      'paid_visits': 'Paid Visits',
      'free_visits': 'Free Visits',
      'discount_percentage': 'Discount Percentage',
      'voucher_no': 'Voucher No',
      'add_voucher': 'Add Voucher',
      'services': 'Services',
      'customer_types': 'Customer Types',
      'vehicle_types': 'Vehicle Types',
      'save_scheme': 'Save Scheme',
      'scheme_created': 'Scheme created',
      'enter_scheme_details_error': 'Enter scheme name and type',
      'booking_details': 'Booking Details',
      'customer_name': 'Customer Name',
      'phone_number': 'Phone Number',
      'vehicle_number': 'Vehicle Number',
      'select_service': 'Select Service',
      'select_date': 'Select Date',
      'time_slot': 'Time Slot',
      'booking_created': 'Booking created',
      'booking_failed': 'Booking failed',
      'bookings_list': 'Bookings List',
      'no_bookings_found': 'No bookings found',
      'receipts': 'Receipts',
      'no_receipts_found': 'No receipts found',
      'collection': 'Collection',
      'collect_payment': 'Collect Payment',
      'payment_collected': 'Payment collected',
      'add_complaint': 'Add Complaint',
      'subject': 'Subject',
      'complaint_created': 'Complaint created',
      'no_complaints_found': 'No complaints found',
      'add_new_customer': 'Add New Customer',
      'edit_customer': 'Edit Customer',
      'customer_created': 'Customer created',
      'customer_updated': 'Customer updated',
      'no_customers_found': 'No customers found',
      'create_invoice': 'Create Invoice',
      'invoice_details': 'Invoice Details',
      'invoice_created': 'Invoice created',
      'invoice_number': 'Invoice Number',
      'subtotal': 'Subtotal',
      'tax': 'Tax',
      'grand_total': 'Grand Total',
      'select_vehicle': 'Select Vehicle',
      'select_scheme': 'Select Scheme',
      'job_details': 'Job Details',
      'revenue_report': 'Revenue Report',
      'jobs_report': 'Jobs Report',
      'sales_summary': 'Sales Summary',
      'search_by_vehicle_number': 'Search by Vehicle Number',
      'vehicle_details': 'Vehicle Details',
    },
    'hi': {
      'dashboard': 'डैशबोर्ड',
      'menu': 'मेनू',
      'new_job': 'नया कार्य',
      'book_now': 'अभी बुक करें',
      'bookings': 'बुकिंग',
      'bill': 'बिल',
      'outstanding': 'बकाया',
      'receipt': 'रसीद',
      'customers': 'ग्राहक',
      'schemes': 'योजनाएं',
      'reports': 'रिपोर्ट',
      'vehicle': 'वाहन',
      'broadcasts': 'प्रसारण',
      'language': 'भाषा',
      'complaints': 'शिकायतें',
      'logout': 'लॉग आउट',
      'welcome_back': 'आपका स्वागत है',
      'quick_menu': 'त्वरित मेनू',
      'login': 'लॉगिन',
      'username_or_email': 'उपयोगकर्ता नाम या ईमेल',
      'enter_username_or_email': 'उपयोगकर्ता नाम या ईमेल दर्ज करें',
      'password': 'पासवर्ड',
      'enter_password': 'पासवर्ड दर्ज करें',
      'remember_me': 'मुझे याद रखें',
      'forgot_password': 'पासवर्ड भूल गए?',
      'sign_in': 'साइन इन करें',
      'logout_confirm': 'क्या आप वाकई लॉग आउट करना चाहते हैं?',
      'cancel': 'रद्द करें',
      'branch_admin': 'शाखा व्यवस्थापक',
      'company_admin': 'कंपनी व्यवस्थापक',
      'recent_invoices': 'हाल के इनवॉइस',
      'select_language': 'भाषा चुनें',
      'admin_login': 'व्यवस्थापक लॉगिन',
      'username': 'उपयोगकर्ता नाम',
      'please_enter_credentials': 'कृपया उपयोगकर्ता नाम और पासवर्ड दर्ज करें',
      'todays_summary': 'आज का सारांश',
      'overview': 'अवलोकन',
      'todays_recent_jobs': 'आज के हालिया कार्य',
      'revenue': 'राजस्व',
      'collected': 'एकत्रित',
      'jobs': 'कार्य',
      'due': 'देय',
      'paid': 'भुगतान किया गया',
      'invoices_count': 'इनवॉइस',
      'exit_app': 'ऐप से बाहर निकलें',
      'exit_confirm': 'क्या आप ऐप बंद करना चाहते हैं?',
      'exit': 'बाहर निकलें',
      'bills': 'बिल',
      'vehicle_search': 'वाहन खोज',
      'not_authenticated': 'प्रमाणित नहीं है',
      'network_error': 'नेटवर्क त्रुटि',
      'failed_to_load': 'लोड करने में विफल',
      'retry': 'पुनः प्रयास करें',
      'save': 'सहेजें',
      'saving': 'सहेज रहा है...',
      'delete': 'हटाएं',
      'add': 'जोड़ें',
      'create': 'बनाएं',
      'date': 'तारीख',
      'start': 'प्रारंभ',
      'end': 'समाप्त',
      'status': 'स्थिति',
      'description': 'विवरण',
      'name': 'नाम',
      'phone': 'फ़ोन',
      'email': 'ईमेल',
      'address': 'पता',
      'actions': 'कार्रवाई',
      'total': 'कुल',
      'balance': 'शेष',
      'amount': 'राशि',
      'all': 'सभी',
      'available_schemes': 'उपलब्ध योजनाएं',
      'no_schemes_available': 'कोई योजना उपलब्ध नहीं है',
      'add_scheme': 'योजना जोड़ें',
      'scheme_name': 'योजना का नाम',
      'scheme_type': 'योजना का प्रकार',
      'paid_visits': 'भुगतान की गई विज़िट',
      'free_visits': 'मुफ़्त विज़िट',
      'discount_percentage': 'छूट प्रतिशत',
      'voucher_no': 'वाउचर संख्या',
      'add_voucher': 'वाउचर जोड़ें',
      'services': 'सेवाएं',
      'customer_types': 'ग्राहक प्रकार',
      'vehicle_types': 'वाहन प्रकार',
      'save_scheme': 'योजना सहेजें',
      'scheme_created': 'योजना बनाई गई',
      'enter_scheme_details_error': 'योजना का नाम और प्रकार दर्ज करें',
      'booking_details': 'बुकिंग विवरण',
      'customer_name': 'ग्राहक का नाम',
      'phone_number': 'फ़ोन नंबर',
      'vehicle_number': 'वाहन संख्या',
      'select_service': 'सेवा चुनें',
      'select_date': 'तारीख चुनें',
      'time_slot': 'समय स्लॉट',
      'booking_created': 'बुकिंग बनाई गई',
      'booking_failed': 'बुकिंग विफल रही',
      'bookings_list': 'बुकिंग सूची',
      'no_bookings_found': 'कोई बुकिंग नहीं मिली',
      'receipts': 'रसीदें',
      'no_receipts_found': 'कोई रसीद नहीं मिली',
      'collection': 'संग्रह',
      'collect_payment': 'भुगतान एकत्र करें',
      'payment_collected': 'भुगतान एकत्र किया गया',
      'add_complaint': 'शिकायत जोड़ें',
      'subject': 'विषय',
      'complaint_created': 'शिकायत दर्ज की गई',
      'no_complaints_found': 'कोई शिकायत नहीं मिली',
      'add_new_customer': 'नया ग्राहक जोड़ें',
      'edit_customer': 'ग्राहक संपादित करें',
      'customer_created': 'ग्राहक बनाया गया',
      'customer_updated': 'ग्राहक अपडेट किया गया',
      'no_customers_found': 'कोई ग्राहक नहीं मिला',
      'create_invoice': 'इनवॉइस बनाएं',
      'invoice_details': 'इनवॉइस विवरण',
      'invoice_created': 'इनवॉइस बनाया गया',
      'invoice_number': 'इनवॉइस संख्या',
      'subtotal': 'उप-योग',
      'tax': 'कर',
      'grand_total': 'कुल योग',
      'select_vehicle': 'वाहन चुनें',
      'select_scheme': 'योजना चुनें',
      'job_details': 'कार्य विवरण',
      'revenue_report': 'राजस्व रिपोर्ट',
      'jobs_report': 'कार्य रिपोर्ट',
      'sales_summary': 'बिक्री सारांश',
      'search_by_vehicle_number': 'वाहन संख्या द्वारा खोजें',
      'vehicle_details': 'वाहन विवरण',
    },
    'ur': {
      'dashboard': 'ڈیش بورڈ',
      'menu': 'مینو',
      'new_job': 'نیا کام',
      'book_now': 'ابھی بک کریں',
      'bookings': 'بکنگ',
      'bill': 'بل',
      'outstanding': 'بقایا جات',
      'receipt': 'رسید',
      'customers': 'گاہکوں',
      'schemes': 'اسکیمیں',
      'reports': 'رپورٹیں',
      'vehicle': 'گاڑی',
      'broadcasts': 'نشریات',
      'language': 'زبان',
      'complaints': 'شکایات',
      'logout': 'لاگ آؤٹ',
      'welcome_back': 'خوش آمدید',
      'quick_menu': 'فوری مینو',
      'login': 'لاگ ان',
      'username_or_email': 'صارف نام یا ای میل',
      'enter_username_or_email': 'صارف نام یا ای میل درج کریں',
      'password': 'پاس ورڈ',
      'enter_password': 'پاس ورڈ درج کریں',
      'remember_me': 'مجھے یاد رکھیں',
      'forgot_password': 'پاس ورڈ بھول گئے؟',
      'sign_in': 'سائن ان کریں',
      'logout_confirm': 'کیا آپ واقعی لاگ آؤٹ کرنا چاہتے ہیں؟',
      'cancel': 'منسوخ کریں',
      'branch_admin': 'برانچ ایڈمن',
      'company_admin': 'کمپنی ایڈمن',
      'recent_invoices': 'حالیہ انوائسز',
      'select_language': 'زبان منتخب کریں',
      'admin_login': 'ایڈمن لاگ ان',
      'username': 'صارف نام',
      'please_enter_credentials': 'براہ کرم صارف نام اور پاس ورڈ درج کریں',
      'todays_summary': 'آج کا خلاصہ',
      'overview': 'جائزہ',
      'todays_recent_jobs': 'آج کے حالیہ کام',
      'revenue': 'آمدنی',
      'collected': 'جمع شدہ',
      'jobs': 'کام',
      'due': 'واجب الادا',
      'paid': 'ادا شدہ',
      'invoices_count': 'انوائسز',
      'exit_app': 'ایپ سے باہر نکلیں',
      'exit_confirm': 'کیا آپ ایپ بند کرنا چاہتے ہیں؟',
      'exit': 'باہر نکلیں',
      'bills': 'بلز',
      'vehicle_search': 'گاڑی کی تلاش',
      'not_authenticated': 'تصدیق شدہ نہیں ہے',
      'network_error': 'نیٹ ورک کی خرابی',
      'failed_to_load': 'لوڈ کرنے میں ناکام',
      'retry': 'دوبارہ کوشش کریں',
      'save': 'محفوظ کریں',
      'saving': 'محفوظ ہو رہا ہے...',
      'delete': 'حذف کریں',
      'add': 'شامل کریں',
      'create': 'تخلیق کریں',
      'date': 'تاریخ',
      'start': 'شروع',
      'end': 'ختم',
      'status': 'حیثیت',
      'description': 'تفصیل',
      'name': 'نام',
      'phone': 'فون',
      'email': 'ای میل',
      'address': 'پتہ',
      'actions': 'اقدامات',
      'total': 'کل',
      'balance': 'باقی رقم',
      'amount': 'رقم',
      'all': 'تمام',
      'available_schemes': 'دستیاب اسکیمیں',
      'no_schemes_available': 'کوئی اسکیم دستیاب نہیں ہے',
      'add_scheme': 'اسکیم شامل کریں',
      'scheme_name': 'اسکیم کا نام',
      'scheme_type': 'اسکیم کی قسم',
      'paid_visits': 'ادا شدہ وزٹ',
      'free_visits': 'مفت وزٹ',
      'discount_percentage': 'چھوٹ کا فیصد',
      'voucher_no': 'واؤچر نمبر',
      'add_voucher': 'واؤچر شامل کریں',
      'services': 'خدمات',
      'customer_types': 'گاہکوں کی اقسام',
      'vehicle_types': 'گاڑیوں کی اقسام',
      'save_scheme': 'اسکیم محفوظ کریں',
      'scheme_created': 'اسکیم بنا دی گئی',
      'enter_scheme_details_error': 'اسکیم کا نام اور قسم درج کریں',
      'booking_details': 'بکنگ کی تفصیلات',
      'customer_name': 'گاہک کا نام',
      'phone_number': 'فون نمبر',
      'vehicle_number': 'گاڑی کا نمبر',
      'select_service': 'سروس منتخب کریں',
      'select_date': 'تاریخ منتخب کریں',
      'time_slot': 'وقت کا سلاٹ',
      'booking_created': 'بکنگ ہو گئی',
      'booking_failed': 'بکنگ ناکام ہو گئی',
      'bookings_list': 'بکنگ کی فہرست',
      'no_bookings_found': 'کوئی booking نہیں ملی',
      'receipts': 'رسیدیں',
      'no_receipts_found': 'کوئی رسید نہیں ملی',
      'collection': 'مجموعہ',
      'collect_payment': 'ادائیگی جمع کریں',
      'payment_collected': 'ادائیگی جمع کرلی گئی',
      'add_complaint': 'شکایت درج کریں',
      'subject': 'موضوع',
      'complaint_created': 'شکایت درج کرلی گئی',
      'no_complaints_found': 'کوئی شکایت نہیں ملی',
      'add_new_customer': 'نیا گاہک شامل کریں',
      'edit_customer': 'گاہک کی معلومات تبدیل کریں',
      'customer_created': 'گاہک کا پروفائل بن گیا',
      'customer_updated': 'گاہک کی معلومات اپ ڈیٹ ہوگئیں',
      'no_customers_found': 'کوئی گاہک نہیں ملا',
      'create_invoice': 'انوائس بنائیں',
      'invoice_details': 'انوائس کی تفصیلات',
      'invoice_created': 'انوائس بنا دی گئی',
      'invoice_number': 'انوائس نمبر',
      'subtotal': 'ذیلی کل',
      'tax': 'ٹیکس',
      'grand_total': 'کل مجموعہ',
      'select_vehicle': 'گاڑی منتخب کریں',
      'select_scheme': 'اسکیم منتخب کریں',
      'job_details': 'کام کی تفصیلات',
      'revenue_report': 'آمدنی کی رپورٹ',
      'jobs_report': 'کاموں کی رپورٹ',
      'sales_summary': 'فروخت का خلاصہ',
      'search_by_vehicle_number': 'گاڑی کے نمبر سے تلاش کریں',
      'vehicle_details': 'گاڑی کی تفصیلات',
    },
    'ar': {
      'dashboard': 'لوحة القيادة',
      'menu': 'القائمة',
      'new_job': 'عمل جديد',
      'book_now': 'احجز الآن',
      'bookings': 'الحجوزات',
      'bill': 'الفاتورة',
      'outstanding': 'المستحقات',
      'receipt': 'الإيصال',
      'customers': 'العملاء',
      'schemes': 'العروض',
      'reports': 'التقارير',
      'vehicle': 'المركبة',
      'broadcasts': 'البث',
      'language': 'اللغة',
      'complaints': 'الشكاوى',
      'logout': 'تسجيل الخروج',
      'welcome_back': 'مرحباً بعودتك',
      'quick_menu': 'القائمة السريعة',
      'login': 'تسجيل الدخول',
      'username_or_email': 'اسم المستخدم أو البريد الإلكتروني',
      'enter_username_or_email': 'أدخل اسم المستخدم أو البريد الإلكتروني',
      'password': 'كلمة المرور',
      'enter_password': 'أدخل كلمة المرور',
      'remember_me': 'تذكرني',
      'forgot_password': 'هل نسيت كلمة المرور؟',
      'sign_in': 'تسجيل الدخول',
      'logout_confirm': 'هل أنت متأكد أنك تريد تسجيل الخروج؟',
      'cancel': 'إلغاء',
      'branch_admin': 'مسؤول الفرع',
      'company_admin': 'مسؤول الشركة',
      'recent_invoices': 'الفواتير الأخيرة',
      'select_language': 'اختر اللغة',
      'admin_login': 'دخول المسؤول',
      'username': 'اسم المستخدم',
      'please_enter_credentials': 'يرجى إدخال اسم المستخدم وكلمة المرور',
      'todays_summary': 'ملخص اليوم',
      'overview': 'نظرة عامة',
      'todays_recent_jobs': 'أعمال اليوم الأخيرة',
      'revenue': 'الإيرادات',
      'collected': 'المحصلة',
      'jobs': 'الأعمال',
      'due': 'المستحقة',
      'paid': 'المدفوعة',
      'invoices_count': 'الفواتير',
      'exit_app': 'الخروج من التطبيق',
      'exit_confirm': 'هل تريد إغلاق التطبيق؟',
      'exit': 'خروج',
      'bills': 'الفواتير',
      'vehicle_search': 'البحث عن المركبة',
      'not_authenticated': 'غير مصرح',
      'network_error': 'خطأ في الشبكة',
      'failed_to_load': 'فشل التحميل',
      'retry': 'إعادة المحاولة',
      'save': 'حفظ',
      'saving': 'جاري الحفظ...',
      'delete': 'حذف',
      'add': 'إضافة',
      'create': 'إنشاء',
      'date': 'التاريخ',
      'start': 'البدء',
      'end': 'الانتهاء',
      'status': 'الحالة',
      'description': 'الوصف',
      'name': 'الاسم',
      'phone': 'الهاتف',
      'email': 'البريد الإلكتروني',
      'address': 'العنوان',
      'actions': 'الإجراءات',
      'total': 'الإجمالي',
      'balance': 'الرصيد',
      'amount': 'المبلغ',
      'all': 'الكل',
      'available_schemes': 'العروض المتاحة',
      'no_schemes_available': 'لا توجد عروض متاحة',
      'add_scheme': 'إضافة عرض',
      'scheme_name': 'اسم العرض',
      'scheme_type': 'نوع العرض',
      'paid_visits': 'الزيارات المدفوعة',
      'free_visits': 'الزيارات المجانية',
      'discount_percentage': 'نسبة الخصم',
      'voucher_no': 'رقم القسيمة',
      'add_voucher': 'إضافة قسيمة',
      'services': 'الخدمات',
      'customer_types': 'أنواع العملاء',
      'vehicle_types': 'أنواع المركبات',
      'save_scheme': 'حفظ العرض',
      'scheme_created': 'تم إنشاء العرض',
      'enter_scheme_details_error': 'أدخل اسم ونوع العرض',
      'booking_details': 'تفاصيل الحجز',
      'customer_name': 'اسم العميل',
      'phone_number': 'رقم الهاتف',
      'vehicle_number': 'رقم المركبة',
      'select_service': 'اختر الخدمة',
      'select_date': 'اختر التاريخ',
      'time_slot': 'الفترة الزمنية',
      'booking_created': 'تم إنشاء الحجز',
      'booking_failed': 'فشل الحجز',
      'bookings_list': 'قائمة الحجوزات',
      'no_bookings_found': 'لم يتم العثور على حجوزات',
      'receipts': 'الإيصالات',
      'no_receipts_found': 'لم يتم العثور على إيصالات',
      'collection': 'التحصيل',
      'collect_payment': 'تحصيل الدفعة',
      'payment_collected': 'تم تحصيل الدفعة',
      'add_complaint': 'إضافة شكوى',
      'subject': 'الموضوع',
      'complaint_created': 'تم تسجيل الشكوى',
      'no_complaints_found': 'لم يتم العثور على شكاوى',
      'add_new_customer': 'إضافة عميل جديد',
      'edit_customer': 'تعديل العميل',
      'customer_created': 'تم إنشاء العميل',
      'customer_updated': 'تم تحديث العميل',
      'no_customers_found': 'لم يتم العثور على عملاء',
      'create_invoice': 'إنشاء فاتورة',
      'invoice_details': 'تفاصيل الفاتورة',
      'invoice_created': 'تم إنشاء الفاتورة',
      'invoice_number': 'رقم الفاتورة',
      'subtotal': 'المجموع الفرعي',
      'tax': 'الضريبة',
      'grand_total': 'المجموع الكلي',
      'select_vehicle': 'اختر المركبة',
      'select_scheme': 'اختر العرض',
      'job_details': 'تفاصيل العمل',
      'revenue_report': 'تقرير الإيرادات',
      'jobs_report': 'تقرير الأعمال',
      'sales_summary': 'ملخص المبيعات',
      'search_by_vehicle_number': 'البحث برقم المركبة',
      'vehicle_details': 'تفاصيل المركبة',
    },
    'bn': {
      'dashboard': 'ড্যাশবোর্ড',
      'menu': 'মেনু',
      'new_job': 'নতুন কাজ',
      'book_now': 'এখনই বুক করুন',
      'bookings': 'বুকিং সমূহ',
      'bill': 'বিল',
      'outstanding': 'বকেয়া',
      'receipt': 'রশিদ',
      'customers': 'গ্রাহক সমূহ',
      'schemes': 'স্কিম সমূহ',
      'reports': 'রিপোর্ট সমূহ',
      'vehicle': 'যানবাহন',
      'broadcasts': 'ব্রডকাস্ট',
      'language': 'ভাষা',
      'complaints': 'অভিযোগ সমূহ',
      'logout': 'লগ আউট',
      'welcome_back': 'স্বাগতম',
      'quick_menu': 'কুইক মেনু',
      'login': 'লগইন',
      'username_or_email': 'ইউজারনেম বা ইমেল',
      'enter_username_or_email': 'ইউজারনেম বা ইমেল লিখুন',
      'password': 'পাসওয়ার্ড',
      'enter_password': 'পাসওয়ার্ড লিখুন',
      'remember_me': 'আমাকে মনে রাখুন',
      'forgot_password': 'পাসওয়ার্ড ভুলে গেছেন?',
      'sign_in': 'সাইন ইন',
      'logout_confirm': 'আপনি কি নিশ্চিত যে লগ আউট করতে চান?',
      'cancel': 'বাতিল',
      'branch_admin': 'শাখা প্রশাসক',
      'company_admin': 'কোম্পানি প্রশাসক',
      'recent_invoices': 'সাম্প্রতিক চালান',
      'select_language': 'ভাষা নির্বাচন করুন',
      'admin_login': 'অ্যাডমিন লগইন',
      'username': 'ইউজারনেম',
      'please_enter_credentials': 'অনুগ্রহ করে ইউজারনেম এবং পাসওয়ার্ড লিখুন',
      'todays_summary': 'আজকের সংক্ষিপ্ত বিবরণ',
      'overview': 'অভারভিউ',
      'todays_recent_jobs': 'আজকের সাম্প্রতিক কাজ',
      'revenue': 'রাজস্ব',
      'collected': 'সংগৃহীত',
      'jobs': 'কাজ সমূহ',
      'due': 'বকেয়া',
      'paid': 'পরিশোধিত',
      'invoices_count': 'চালান',
      'exit_app': 'অ্যাপ থেকে প্রস্থান করুন',
      'exit_confirm': 'আপনি কি অ্যাপটি বন্ধ করতে চান?',
      'exit': 'প্রস্থান',
      'bills': 'বিল সমূহ',
      'vehicle_search': 'যানবাহন অনুসন্ধান',
      'not_authenticated': 'অনুমোদিত নয়',
      'network_error': 'নেটওয়ার্ক ত্রুটি',
      'failed_to_load': 'লোড হতে ব্যর্থ হয়েছে',
      'retry': 'পুনরায় চেষ্টা করুন',
      'save': 'সংরক্ষণ করুন',
      'saving': 'সংরক্ষণ করা হচ্ছে...',
      'delete': 'মুছে ফেলুন',
      'add': 'যোগ করুন',
      'create': 'তৈরি করুন',
      'date': 'তারিখ',
      'start': 'শুরু',
      'end': 'শেষ',
      'status': 'অবস্থা',
      'description': 'বর্ণنا',
      'name': 'নাম',
      'phone': 'ফোন',
      'email': 'ইমেল',
      'address': 'ঠিকানা',
      'actions': 'পদক্ষেপ সমূহ',
      'total': 'মোট',
      'balance': 'অবশিষ্ট',
      'amount': 'পরিমাণ',
      'all': 'সব',
      'available_schemes': 'উপলব্ধ স্কিম সমূহ',
      'no_schemes_available': 'কোন স্কিম উপলব্ধ নেই',
      'add_scheme': 'স্কিম যোগ করুন',
      'scheme_name': 'স্কিমের নাম',
      'scheme_type': 'স্কিমের ধরন',
      'paid_visits': 'পেইড ভিজিট',
      'free_visits': 'ফ্রি ভিজিট',
      'discount_percentage': 'ছাড়ের শতাংশ',
      'voucher_no': 'ভাউচার নম্বর',
      'add_voucher': 'ভাউচার যোগ করুন',
      'services': 'সেবা সমূহ',
      'customer_types': 'গ্রাহকের ধরন',
      'vehicle_types': 'যানবাহনের ধরন',
      'save_scheme': 'স্কিম সংরক্ষণ করুন',
      'scheme_created': 'স্কিম তৈরি হয়েছে',
      'enter_scheme_details_error': 'স্কিমের নাম এবং ধরন লিখুন',
      'booking_details': 'বুকিংয়ের বিবরণ',
      'customer_name': 'গ্রাহকের নাম',
      'phone_number': 'ফোন নম্বর',
      'vehicle_number': 'যানবাহন নম্বর',
      'select_service': 'সেবা নির্বাচন করুন',
      'select_date': 'তারিখ নির্বাচন করুন',
      'time_slot': 'समय স্লট',
      'booking_created': 'বুকিং তৈরি হয়েছে',
      'booking_failed': 'বুকিং ব্যর্থ হয়েছে',
      'bookings_list': 'বুকিং তালিকা',
      'no_bookings_found': 'কোন বুকিং পাওয়া যায়নি',
      'receipts': 'রশিদ সমূহ',
      'no_receipts_found': 'কোন রশিদ পাওয়া যায়নি',
      'collection': 'সংগ্রহ',
      'collect_payment': 'পেমেন্ট সংগ্রহ করুন',
      'payment_collected': 'পেমেন্ট সংগৃহীত হয়েছে',
      'add_complaint': 'অভিযোগ যোগ করুন',
      'subject': 'বিষয়',
      'complaint_created': 'অভিযোগ নিবন্ধিত হয়েছে',
      'no_complaints_found': 'কোন অভিযোগ পাওয়া যায়নি',
      'add_new_customer': 'নতুন গ্রাহক যোগ করুন',
      'edit_customer': 'গ্রাহক সম্পাদনা করুন',
      'customer_created': 'গ্রাহক তৈরি হয়েছে',
      'customer_updated': 'গ্রাহক আপডেট হয়েছে',
      'no_customers_found': 'কোন গ্রাহক পাওয়া যায়নি',
      'create_invoice': 'চালান তৈরি করুন',
      'invoice_details': 'চালানের বিবরণ',
      'invoice_created': 'চালান তৈরি হয়েছে',
      'invoice_number': 'চালান নম্বর',
      'subtotal': 'সাবটোটাল',
      'tax': 'ট্যাক্স',
      'grand_total': 'সর্বমোট',
      'select_vehicle': 'যানবাহন নির্বাচন করুন',
      'select_scheme': 'স্কিম নির্বাচন করুন',
      'job_details': 'কাজের বিবরণ',
      'revenue_report': 'রাজস্ব রিপোর্ট',
      'jobs_report': 'কাজের রিপোর্ট',
      'sales_summary': 'বিক্রয় সারসংক্ষেপ',
      'search_by_vehicle_number': 'যানবাহন নম্বর দিয়ে অনুসন্ধান করুন',
      'vehicle_details': 'যানবাহনের বিবরণ',
    },
    'ml': {
      'dashboard': 'ഡാഷ്‌ബോർഡ്',
      'menu': 'മെനു',
      'new_job': 'പുതിയ ജോലി',
      'book_now': 'ഇപ്പോൾ ബുക്ക് ചെയ്യുക',
      'bookings': 'ബുക്കിംഗുകൾ',
      'bill': 'ബിൽ',
      'outstanding': 'കുടിശ്ശിക',
      'receipt': 'രസീത്',
      'customers': 'ഉപഭോക്താക്കൾ',
      'schemes': 'സ്കീമുകൾ',
      'reports': 'റിപ്പോർട്ടുകൾ',
      'vehicle': 'വാഹനം',
      'broadcasts': 'ബ്രോഡ്കാസ്റ്റുകൾ',
      'language': 'ഭാഷ',
      'complaints': 'പരാതികൾ',
      'logout': 'ലോഗ് ഔട്ട്',
      'welcome_back': 'സ്വാഗതം',
      'quick_menu': 'ക്വിക്ക് മെനു',
      'login': 'ലോഗിൻ',
      'username_or_email': 'ഉപയോക്തൃനാമം അല്ലെങ്കിൽ ഇമെയിൽ',
      'enter_username_or_email': 'ഉപയോക്തൃനാമം അല്ലെങ്കിൽ ഇമെയിൽ നൽകുക',
      'password': 'പാസ്‌വേഡ്',
      'enter_password': 'പാസ്‌വേഡ് നൽകുക',
      'remember_me': 'എന്നെ ഓർമ്മിക്കുക',
      'forgot_password': 'പാസ്‌വേഡ് മറന്നുപോയോ?',
      'sign_in': 'സൈൻ ഇൻ',
      'logout_confirm': 'നിങ്ങൾ ലോഗ് ഔട്ട് ചെയ്യാൻ ആഗ്രഹിക്കുന്നുവെന്ന് ഉറപ്പാണോ?',
      'cancel': 'റദ്ദാക്കുക',
      'branch_admin': 'ബ്രാഞ്ച് അഡ്മിൻ',
      'company_admin': 'കമ്പനി അഡ്മിൻ',
      'recent_invoices': 'അടുത്തകാലത്തെ ബില്ലുകൾ',
      'select_language': 'ഭാഷ തിരഞ്ഞെടുക്കുക',
      'admin_login': 'അഡ്മിൻ ലോഗിൻ',
      'username': 'ഉപയോക്തൃനാമം',
      'please_enter_credentials': 'ദയവായി ഉപയോക്തൃനാമവും പാസ്‌വേഡും നൽകുക',
      'todays_summary': 'ഇന്നത്തെ ചുരുക്കം',
      'overview': 'അവലോകനം',
      'todays_recent_jobs': 'ഇന്നത്തെ സമീപകാല ജോലികൾ',
      'revenue': 'വരുമാനം',
      'collected': 'ശേഖരിച്ചത്',
      'jobs': 'ജോലികൾ',
      'due': 'ബാക്കി',
      'paid': 'അടച്ചു',
      'invoices_count': 'ഇൻവോയ്സുകൾ',
      'exit_app': 'ആപ്പിൽ നിന്ന് പുറത്തുകടക്കുക',
      'exit_confirm': 'നിങ്ങൾക്ക് ആപ്പ് അടക്കണോ?',
      'exit': 'പുറത്തുകടക്കുക',
      'bills': 'ബില്ലുകൾ',
      'vehicle_search': 'വാഹനം തിരയുക',
      'not_authenticated': 'അംഗീകരിക്കപ്പെട്ടിട്ടില്ല',
      'network_error': 'നെറ്റ്‌വർക്ക് തകരാർ',
      'failed_to_load': 'ലോഡ് ചെയ്യാൻ കഴിഞ്ഞില്ല',
      'retry': 'വീണ്ടും ശ്രമിക്കുക',
      'save': 'സൂക്ഷിക്കുക',
      'saving': 'സൂക്ഷിക്കുന്നു...',
      'delete': 'ഇല്ലാതാക്കുക',
      'add': 'ചേർക്കുക',
      'create': 'നിർമ്മിക്കുക',
      'date': 'തീയതി',
      'start': 'ആരംഭം',
      'end': 'അവസാനം',
      'status': 'നില',
      'description': 'വിവരണം',
      'name': 'പേര്',
      'phone': 'ഫോൺ',
      'email': 'ഇമെയിൽ',
      'address': 'മേൽവിലാസം',
      'actions': 'നടപടികൾ',
      'total': 'ആകെ',
      'balance': 'ബാക്കി',
      'amount': 'തുക',
      'all': 'എല്ലാം',
      'available_schemes': 'ലഭ്യമായ സ്കീമുകൾ',
      'no_schemes_available': 'സ്കീമുകൾ ഒന്നും ലഭ്യമായിട്ടില്ല',
      'add_scheme': 'സ്കീം ചേർക്കുക',
      'scheme_name': 'സ്കീമിന്റെ പേര്',
      'scheme_type': 'സ്കീമിന്റെ തരം',
      'paid_visits': 'പെയ്ഡ് സന്ദർശനങ്ങൾ',
      'free_visits': 'സൗജന്യ സന്ദർശനങ്ങൾ',
      'discount_percentage': 'ഡിസ്കൗണ്ട് ശതമാനം',
      'voucher_no': 'വൗച്ചർ നമ്പർ',
      'add_voucher': 'വൗച്ചർ ചേർക്കുക',
      'services': 'സേവനങ്ങൾ',
      'customer_types': 'ഉപഭോക്തൃ തരങ്ങൾ',
      'vehicle_types': 'വാഹന തരങ്ങൾ',
      'save_scheme': 'സ്കീം സൂക്ഷിക്കുക',
      'scheme_created': 'സ്കീം നിർമ്മിച്ചു',
      'enter_scheme_details_error': 'സ്കീമിന്റെ പേരും തരവും നൽകുക',
      'booking_details': 'ബുക്കിംഗ് വിവരങ്ങൾ',
      'customer_name': 'ഉപഭോക്താവിന്റെ പേര്',
      'phone_number': 'ഫോൺ നമ്പർ',
      'vehicle_number': 'വാഹന നമ്പർ',
      'select_service': 'സേവനം തിരഞ്ഞെടുക്കുക',
      'select_date': 'തീയതി തിരഞ്ഞെടുക്കുക',
      'time_slot': 'സമയ ക്രമം',
      'booking_created': 'ബുക്കിംഗ് വിജയകരമായി',
      'booking_failed': 'ബുക്കിംഗ് പരാജയപ്പെട്ടു',
      'bookings_list': 'ബുക്കിംഗ് ലിസ്റ്റ്',
      'no_bookings_found': 'ബുക്കിംഗുകൾ ഒന്നും കണ്ടെത്തിയില്ല',
      'receipts': 'രസീതുകൾ',
      'no_receipts_found': 'രസീതുകൾ ഒന്നും കണ്ടെത്തിയില്ല',
      'collection': 'ശേഖരണം',
      'collect_payment': 'പണം സ്വീകരിക്കുക',
      'payment_collected': 'പണം സ്വീകരിച്ചു',
      'add_complaint': 'പരാതി നൽകുക',
      'subject': 'വിഷയം',
      'complaint_created': 'പരാതി രജിസ്റ്റർ ചെയ്തു',
      'no_complaints_found': 'പരാതികൾ ഒന്നും കണ്ടെത്തിയില്ല',
      'add_new_customer': 'പുതിയ ഉപഭോക്താവിനെ ചേർക്കുക',
      'edit_customer': 'ഉപഭോക്താവിനെ തിരുത്തുക',
      'customer_created': 'ഉപഭോക്താവിനെ ചേർത്തു',
      'customer_updated': 'ഉപഭോക്താവിനെ പുതുക്കി',
      'no_customers_found': 'ഉപഭോക്താക്കളെ കണ്ടെത്തിയില്ല',
      'create_invoice': 'ബില്ല് നിർമ്മിക്കുക',
      'invoice_details': 'ബില്ല് വിവരങ്ങൾ',
      'invoice_created': 'ബില്ല് നിർമ്മിച്ചു',
      'invoice_number': 'ബില്ല് നമ്പർ',
      'subtotal': 'സബ്‌ടോട്ടൽ',
      'tax': 'നികുതി',
      'grand_total': 'ആകെ തുക',
      'select_vehicle': 'വാഹനം തിരഞ്ഞെടുക്കുക',
      'select_scheme': 'സ്കീം തിരഞ്ഞെടുക്കുക',
      'job_details': 'ജോലി വിവരങ്ങൾ',
      'revenue_report': 'വരുമാന റിപ്പോർട്ട്',
      'jobs_report': 'ജോലി റിപ്പോർട്ട്',
      'sales_summary': 'വില്പന വിവരണം',
      'search_by_vehicle_number': 'വാഹന നമ്പർ ഉപയോഗിച്ച് തിരയുക',
      'vehicle_details': 'വാഹന വിവരങ്ങൾ',
    },
  };
}

// BuildContext extension shortcut
extension LanguageExtension on BuildContext {
  String translate(String key) {
    try {
      return Provider.of<LanguageProvider>(this).translate(key);
    } catch (_) {
      return Provider.of<LanguageProvider>(this, listen: false).translate(key);
    }
  }

  String tr(String text) {
    try {
      return Provider.of<LanguageProvider>(this).translateDynamic(text);
    } catch (_) {
      return Provider.of<LanguageProvider>(this, listen: false).translateDynamic(text);
    }
  }
}

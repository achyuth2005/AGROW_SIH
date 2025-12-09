import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/localization_service.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();

  // Supported languages (Hindi, Bengali, English only for now)
  final List<AppLanguage> _supportedLanguages = [
    AppLanguage.english,
    AppLanguage.hindi,
    AppLanguage.bengali,
  ];

  List<AppLanguage> _filteredLanguages = [];

  @override
  void initState() {
    super.initState();
    _filteredLanguages = _supportedLanguages;
  }

  void _filterLanguages(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredLanguages = _supportedLanguages;
      } else {
        _filteredLanguages = _supportedLanguages.where((lang) {
          final name = lang.englishName.toLowerCase();
          final native = lang.nativeName.toLowerCase();
          final q = query.toLowerCase();
          return name.contains(q) || native.contains(q);
        }).toList();
      }
    });
  }

  void _selectLanguage(AppLanguage language) {
    final locProvider = context.read<LocalizationProvider>();
    locProvider.setLanguage(language);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${locProvider.tr('language_changed')}: ${language.nativeName}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE1EFEF), // Light background from design
      body: Column(
        children: [
          // Header
          Stack(
            children: [
              SizedBox(
                width: double.infinity,
                height: 120, // Adjusted height for header
                child: Image.asset(
                  'assets/backsmall.png', // Using the requested header image
                  fit: BoxFit.fill,
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                        ),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            "Language",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 40), // Balance the back button
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterLanguages,
                decoration: const InputDecoration(
                  hintText: "Search",
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
            ),
          ),

          // Language List
          Expanded(
            child: Consumer<LocalizationProvider>(
              builder: (context, locProvider, _) {
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredLanguages.length,
                  itemBuilder: (context, index) {
                    final lang = _filteredLanguages[index];
                    final isSelected = lang == locProvider.currentLanguage;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _selectLanguage(lang),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFE8F5E9) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang.englishName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F3C33),
                                      ),
                                    ),
                                    if (lang.englishName != lang.nativeName)
                                      Text(
                                        lang.nativeName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
                                ),
                                if (isSelected)
                                  const Icon(Icons.check, color: Color(0xFF9FE870)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


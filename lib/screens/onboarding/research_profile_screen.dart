/// ===========================================================================
/// RESEARCH PROFILE SCREEN
/// ===========================================================================
///
/// PURPOSE: Onboarding questionnaire to collect user profile data.
///          Determines user role (Farmer vs Researcher) and preferences.
///
/// QUESTIONNAIRE FLOW:
///   1. Role selection (Farmer/Agro-tech Researcher)
///   2. Age group
///   3. Role-specific questions:
///      - Researcher: Research area, data needs, insight level
///      - Farmer: Smartphone familiarity, farm type, farming goal
///   4. Referral source
///
/// CONDITIONAL NAVIGATION:
///   - Farmer → /farmers-home
///   - Researcher → /main-menu
///
/// DATA PERSISTENCE:
///   - Saves to Supabase user_profiles table
///   - Sets role in UserRoleProvider for app-wide access
///
/// DEPENDENCIES:
///   - firebase_auth: User identification
///   - supabase_flutter: Profile storage
///   - UserRoleProvider: Role state management
///   - research_data.dart: Question definitions
/// ===========================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/research_data.dart';
import '../../services/user_role_provider.dart';

class ResearchProfileScreen extends StatefulWidget {
  const ResearchProfileScreen({super.key});

  @override
  State<ResearchProfileScreen> createState() => _ResearchProfileScreenState();
}

class _ResearchProfileScreenState extends State<ResearchProfileScreen> {
  int _currentIndex = 0;
  final Map<String, dynamic> _answers = {};
  final Set<String> _selectedOptions = {};

  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleNext() async {
    final currentQuestion = listResearchQuestions[_currentIndex];
    final key = currentQuestion['key'] as String;

    // Save answer
    if (currentQuestion['isInput'] == true) {
      if (_textController.text.trim().isEmpty) return;
      _answers[key] = _textController.text.trim();
    } else {
      if (_selectedOptions.isEmpty) return;
      if (currentQuestion['multiSelect'] == true) {
        _answers[key] = _selectedOptions.toList();
      } else {
        _answers[key] = _selectedOptions.first;
      }
    }

    if (_currentIndex < listResearchQuestions.length - 1) {
      setState(() {
        // Conditional Flow Logic
        
        if (key == 'age_group') {
           // ... (Existing Age Logic) ...
           final role = _answers['role'];
           if (role != 'Agro-tech Researcher') {
             // FARMER FLOW: Go to Smartphone Familiarity
             final farmerStartIndex = listResearchQuestions.indexWhere((q) => q['key'] == 'smartphone_familiarity');
             if (farmerStartIndex != -1) {
               _currentIndex = farmerStartIndex;
             } else {
               _currentIndex++;
             }
           } else {
             // RESEARCHER FLOW: Continue to Research Area
             _currentIndex++;
           }
        } else if (key == 'insight_level') {
          // End of Researcher questions. Jump to Referral.
          final referralIndex = listResearchQuestions.indexWhere((q) => q['key'] == 'referral_source');
          if (referralIndex != -1) {
            _currentIndex = referralIndex;
          } else {
            _currentIndex++;
          }
        } else if (key == 'farming_goal') {
          // Check if "Other" was selected
          final selected = _answers['farming_goal'];
          if (selected == 'Other') {
            // Go to farming_goal_other
            final otherIndex = listResearchQuestions.indexWhere((q) => q['key'] == 'farming_goal_other');
            if (otherIndex != -1) {
              _currentIndex = otherIndex;
            } else {
              _currentIndex++;
            }
          } else {
            // Skip other input, go to Referral
            final referralIndex = listResearchQuestions.indexWhere((q) => q['key'] == 'referral_source');
            if (referralIndex != -1) {
              _currentIndex = referralIndex;
            } else {
              _currentIndex++;
            }
          }
        } else if (key == 'farming_goal_other') {
           // Finished custom input, go to Referral
            final referralIndex = listResearchQuestions.indexWhere((q) => q['key'] == 'referral_source');
            if (referralIndex != -1) {
              _currentIndex = referralIndex;
            } else {
              _currentIndex++;
            }
        } else {
          // Normal progression
          _currentIndex++;
        }
        
        _loadSavedAnswer();
      });
    } else {
      // Finished - Save answers and redirect based on role
      _saveAnswers();
      
      final role = _answers['role'] as String?;
      
      // Set role in provider for app-wide access
      await UserRoleProvider().setRole(role ?? 'unknown');
      
      if (role == 'Farmer') {
        // Redirect to Farmers Home Screen
        if (mounted) Navigator.pushReplacementNamed(context, '/farmers-home');
      } else {
        // Redirect to Agronomist/Researcher Home Screen (existing main menu)
        if (mounted) Navigator.pushReplacementNamed(context, '/main-menu');
      }
    }
  }

  Future<void> _saveAnswers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client.from('user_profiles').upsert({
        'user_id': user.uid,
        'questionnaire_data': _answers,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving profile: $e');
    }
  }

  void _handleBack() {
    if (_currentIndex > 0) {
      setState(() {
        final currentKey = listResearchQuestions[_currentIndex]['key'];
        
        // If we are at referral_source, check where we came from
        if (currentKey == 'referral_source') {
           final role = _answers['role'];
           if (role != 'Agro-tech Researcher') {
             // Came from Farmer flow
             // Check if we came from 'farming_goal_other' or 'farming_goal'
             final farmingGoalAnswer = _answers['farming_goal'];
             if (farmingGoalAnswer == 'Other') {
                // Go back to farming_goal_other
                final otherIndex = listResearchQuestions.indexWhere((q) => q['key'] == 'farming_goal_other');
                if (otherIndex != -1) {
                  _currentIndex = otherIndex;
                } else {
                  _currentIndex--;
                }
             } else {
                // Go back to farming_goal
                final farmingGoalIndex = listResearchQuestions.indexWhere((q) => q['key'] == 'farming_goal');
                if (farmingGoalIndex != -1) {
                  _currentIndex = farmingGoalIndex;
                } else {
                  _currentIndex--;
                }
             }
           } else {
             // Came from Researcher flow (last question was insight_level)
             final insightIndex = listResearchQuestions.indexWhere((q) => q['key'] == 'insight_level');
             if (insightIndex != -1) {
               _currentIndex = insightIndex;
             } else {
               _currentIndex--;
             }
           }
        } else if (currentKey == 'farming_goal_other') {
          // Back to farming_goal
          final farmingGoalIndex = listResearchQuestions.indexWhere((q) => q['key'] == 'farming_goal');
          if (farmingGoalIndex != -1) {
            _currentIndex = farmingGoalIndex;
          } else {
            _currentIndex--;
          }
        } else if (currentKey == 'smartphone_familiarity') {
          // First question of Farmer flow. Back goes to Age.
          final ageIndex = listResearchQuestions.indexWhere((q) => q['key'] == 'age_group');
          if (ageIndex != -1) {
            _currentIndex = ageIndex;
          } else {
            _currentIndex--;
          }
        } else {
          _currentIndex--;
        }
        
        _loadSavedAnswer();
      });
    }
  }

  void _handleSkipAll() {
    Navigator.pushReplacementNamed(context, '/main-menu');
  }

  void _loadSavedAnswer() {
    _selectedOptions.clear();
    _textController.clear();
    
    final currentQuestion = listResearchQuestions[_currentIndex];
    final key = currentQuestion['key'] as String;
    
    if (_answers.containsKey(key)) {
      final saved = _answers[key];
      if (currentQuestion['isInput'] == true) {
        _textController.text = saved as String;
      } else {
        if (saved is List) {
          _selectedOptions.addAll(saved.cast<String>());
        } else if (saved is String) {
          _selectedOptions.add(saved);
        }
      }
    }
  }

  void _toggleOption(String option, bool isMultiSelect) {
    setState(() {
      if (isMultiSelect) {
        if (_selectedOptions.contains(option)) {
          _selectedOptions.remove(option);
        } else {
          _selectedOptions.add(option);
        }
      } else {
        if (_selectedOptions.contains(option)) {
          _selectedOptions.clear();
        } else {
          _selectedOptions.clear();
          _selectedOptions.add(option);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = listResearchQuestions[_currentIndex];
    final isInput = currentQuestion['isInput'] == true;
    final options = !isInput ? currentQuestion['options'] as List<String> : <String>[];
    final isMultiSelect = currentQuestion['multiSelect'] == true;
    
    const Color primaryDark = Color(0xFF0F3C33);
    const Color backgroundLight = Color(0xFFE1EFEF);
    const Color selectedColor = Color(0xFFAEF051); // Bright lime green

    return Scaffold(
      backgroundColor: backgroundLight,
      body: Column(
        children: [
          // Header
          Image.asset(
            'assets/backsmall.png',
            width: double.infinity,
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
          ),

          Expanded(
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // Question
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      currentQuestion['question'] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),

                  // Image Placeholder (if enabled)
                  if (currentQuestion['showImagePlaceholder'] == true)
                    Expanded(
                      flex: 2,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 20),
                        // Placeholder for the image
                      ),
                    )
                  else
                    const SizedBox(height: 30),

                  // Options List or Input Field
                    Expanded(
                    flex: currentQuestion['showImagePlaceholder'] == true ? 0 : 1,
                    child: isInput
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextField(
                                  controller: _textController,
                                  decoration: InputDecoration(
                                    hintText: "Enter your Goal",
                                    hintStyle: TextStyle(color: Colors.grey[500]),
                                    filled: true,
                                    fillColor: Colors.white.withValues(alpha: 0.8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                  ),
                                  onChanged: (value) {
                                    setState(() {}); // Rebuild to enable/disable button
                                  },
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          )
                        : currentQuestion['key'] == 'area_of_research'
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(5, 10, 5, 0),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4E8D4), // Light green background
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Column(
                                children: [
                                  _buildOptionRow(options, [0, 1], isMultiSelect),
                                  _buildOptionRow(options, [2, 3], isMultiSelect),
                                  _buildOptionRow(options, [4, 5, 6], isMultiSelect),
                                  _buildOptionRow(options, [7], isMultiSelect),
                                  _buildOptionRow(options, [8, 9], isMultiSelect),
                                  _buildOptionRow(options, [10, 11], isMultiSelect),
                                  _buildOptionRow(options, [12], isMultiSelect),
                                  _buildOptionRow(options, [13], isMultiSelect),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: currentQuestion['showImagePlaceholder'] == true,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final option = options[index];
                              final isSelected = _selectedOptions.contains(option);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: InkWell(
                                  onTap: () => _toggleOption(option, isMultiSelect),
                                  borderRadius: BorderRadius.circular(30),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                                    decoration: BoxDecoration(
                                      color: isSelected ? selectedColor : Colors.white.withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: isSelected ? selectedColor : Colors.transparent,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        if (!isSelected)
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                      ],
                                    ),
                                    child: Text(
                                      option,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: isSelected ? primaryDark : primaryDark, // Always dark text for contrast with lime green
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // Footer Buttons (Back + Next/Submit)
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Back Button
                            if (_currentIndex > 0)
                              TextButton(
                                onPressed: _handleBack,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                ),
                                child: const Text(
                                  "Back",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                            else
                              const SizedBox(width: 60), // Placeholder to keep alignment if needed, or just empty

                            // Next/Submit Button
                            if (isInput)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 20),
                                  child: ElevatedButton(
                                    onPressed: _textController.text.trim().isNotEmpty ? _handleNext : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: selectedColor, // Lime Green for Submit
                                      foregroundColor: primaryDark,
                                      disabledBackgroundColor: Colors.grey[400],
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      "Submit",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else
                              ElevatedButton(
                                onPressed: _selectedOptions.isNotEmpty ? _handleNext : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryDark,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.grey[400],
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  "Next",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        
                        // Skip Button (Only for Role Selection)
                        if (currentQuestion['key'] == 'role')
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: TextButton(
                              onPressed: _handleSkipAll,
                              child: const Text(
                                "Skip All",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionRow(List<String> allOptions, List<int> indices, bool isMultiSelect) {
    const Color primaryDark = Color(0xFF0F3C33);
    const Color selectedColor = Color(0xFFAEF051);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: indices.map((index) {
          if (index >= allOptions.length) return const SizedBox.shrink();
          final option = allOptions[index];
          final isSelected = _selectedOptions.contains(option);
          
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: InkWell(
                onTap: () => _toggleOption(option, isMultiSelect),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? selectedColor : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.transparent,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    option,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: primaryDark, // Dark text for contrast
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

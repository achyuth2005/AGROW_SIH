import 'package:flutter/material.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  // Mock Data for News
  final List<Map<String, dynamic>> _newsItems = [
    {
      'title': 'Grow Smarter, Not Harder: Must-Know Tech for the Modern Farmer',
      'description':
          '¡Domina la revolución agrícola! Descubre las últimas tecnologías que transforman tu granja: sensores de suelo, drones y análisis de datos. Optimiza el riego y la fertilización para aumentar tus cosechas y reducir costos significativamente. La agricultura de precisión es el futuro, ¡y está a tu alcance hoy!',
      'image': null, // Text only card
      'hasActions': true,
    },
    {
      'title': 'Grow Smarter, Not Harder: Must-Know Tech for the Modern Farmer',
      'description':
          '¡Domina la revolución agrícola! Descubre las últimas tecnologías que transforman tu granja: sensores de suelo, drones y análisis de datos. Optimiza el riego y la fertilización para aumentar tus cosechas y reducir costos significativamente. La agricultura de precisión es el futuro, ¡y está a tu alcance hoy!',
      'image': 'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?q=80&w=1000&auto=format&fit=crop', // Placeholder image
      'hasActions': false,
    },
    {
      'title': 'Sustainable Farming Practices for 2025',
      'description':
          'Learn about the new sustainable farming practices that are taking the world by storm. From vertical farming to hydroponics, see how you can implement these in your own farm.',
      'image': null,
      'hasActions': true,
    },
  ];

  final List<String> _categories = [
    'Agricultural Revolution',
    'Farms & Beyond',
    'Market Trends',
    'Tech Innovation',
    'Sustainable Living'
  ];

  int _selectedCategoryIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5F3), // Light mint background
      body: Column(
        children: [
          // Custom Header
          _buildHeader(),

          // Filters and Categories
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                // Top Filter Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildFilterOption('Search'),
                        _buildVerticalDivider(),
                        _buildFilterOption('Sort'),
                        _buildVerticalDivider(),
                        _buildFilterOption('Saved'),
                        _buildVerticalDivider(),
                        _buildFilterOption('Liked'),
                      ],
                    ),
                  ),
                ),

                // Category Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: List.generate(_categories.length, (index) {
                      final isSelected = index == _selectedCategoryIndex;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedCategoryIndex = index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFAEF051) // Lime Green
                                  : const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _categories[index],
                              style: TextStyle(
                                color: const Color(0xFF1B4D3E),
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          // News Feed
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _newsItems.length + 1, // +1 for Load More button
              itemBuilder: (context, index) {
                if (index == _newsItems.length) {
                  return _buildLoadMoreButton();
                }
                return _buildNewsCard(_newsItems[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        Container(
          height: 120,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF1B4D3E), // Dark Green
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          // Using a gradient or image if available to match the "leafy" look
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            child: Image.asset(
              'assets/backsmall.png',
              fit: BoxFit.cover,
              color: const Color(0xFF1B4D3E).withOpacity(0.8),
              colorBlendMode: BlendMode.darken,
              errorBuilder: (c, o, s) => const SizedBox(), // Fallback if asset missing
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () => Navigator.pop(context), // Or open drawer
                ),
                const Text(
                  'Newsletter',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterOption(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.grey.shade700,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 20,
      width: 1,
      color: Colors.grey.shade300,
    );
  }

  Widget _buildNewsCard(Map<String, dynamic> item) {
    final hasImage = item['image'] != null;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage)
            Image.network(
              item['image'],
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (c, o, s) => Container(
                height: 200,
                color: Colors.grey.shade200,
                child: const Center(child: Icon(Icons.image_not_supported)),
              ),
            ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Block
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item['title'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  item['description'],
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                
                if (item['hasActions'] == true) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFAEF051), // Lime Green
                            foregroundColor: const Color(0xFF1B4D3E),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Interested?'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFCDD2), // Light Red
                            foregroundColor: const Color(0xFFB71C1C),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Uninterested'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          child: const Text('Load More'),
        ),
      ),
    );
  }
}

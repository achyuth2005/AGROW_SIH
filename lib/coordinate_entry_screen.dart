import 'package:flutter/material.dart';
import 'coming_soon_screen.dart';

class CoordinateEntryScreen extends StatefulWidget {
  @override
  _CoordinateEntryScreenState createState() => _CoordinateEntryScreenState();
}

class _CoordinateEntryScreenState extends State<CoordinateEntryScreen> {
  final List<TextEditingController> _latControllers = List.generate(4, (_) => TextEditingController());
  final List<TextEditingController> _lonControllers = List.generate(4, (_) => TextEditingController());
  final List<String> _latDirections = List.generate(4, (_) => 'N');
  final List<String> _lonDirections = List.generate(4, (_) => 'E');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D986A), Color(0xFF167339)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(18.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, color: Color(0xFF0D986A)),
                      ),
                      SizedBox(width: 18),
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.green.shade300,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Row(
                            children: [
                              SizedBox(width: 12),
                              Icon(Icons.search, color: Color(0xFF167339)),
                              SizedBox(width: 8),
                              Text(
                                "Search",
                                style: TextStyle(color: Color(0xFF167339)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Enter Coordinates",
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    fontSize: 22,
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(18),
                  margin: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF000000), // Solid black
                        Color(0x00000000)  // Transparent black
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Column(
                    children: List.generate(4, (i) => Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          // Latitude
                          Expanded(
                            flex: 10,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: TextField(
                                controller: _latControllers[i],
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "Lat ${i + 1} (e.g. 26.18)",
                                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  hintStyle: TextStyle(
                                    color: Color(0xFF167339),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ),
                          SizedBox(width: 6),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButton<String>(
                              value: _latDirections[i],
                              items: ['N', 'S'].map((dir) => DropdownMenuItem(
                                value: dir,
                                child: Text(dir, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              )).toList(),
                              underline: SizedBox.shrink(),
                              onChanged: (val) {
                                setState(() {
                                  _latDirections[i] = val!;
                                });
                              },
                              isDense: true,
                            ),
                          ),
                          SizedBox(width: 8),
                          // Longitude
                          Expanded(
                            flex: 10,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: TextField(
                                controller: _lonControllers[i],
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "Lon ${i + 1} (e.g. 91.73)",
                                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  hintStyle: TextStyle(
                                    color: Color(0xFF167339),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ),
                          SizedBox(width: 6),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButton<String>(
                              value: _lonDirections[i],
                              items: ['E', 'W'].map((dir) => DropdownMenuItem(
                                value: dir,
                                child: Text(dir, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              )).toList(),
                              underline: SizedBox.shrink(),
                              onChanged: (val) {
                                setState(() {
                                  _lonDirections[i] = val!;
                                });
                              },
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
                    )) + [
                      Padding(
                        padding: EdgeInsets.only(top: 10.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => ComingSoonScreen()),
                              );
                            },
                            style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all(Color(0xFF0D986A)),
                              padding: MaterialStateProperty.all(EdgeInsets.symmetric(vertical: 16)),
                              shape: MaterialStateProperty.all(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            child: const Text(
                              "Proceed",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "Select on map",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 22)
                ),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 26, vertical: 10),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.green.shade900, width: 2)),
                  height: 180,
                  child: Center(
                      child: Text("Map preview here", style: TextStyle(color: Colors.white70))),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _HomeNavBar(),
    );
  }
}

class _HomeNavBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Color(0xFF167339),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Center(
        child: Icon(Icons.home, color: Colors.white, size: 40),
      ),
    );
  }
}

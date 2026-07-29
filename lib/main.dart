import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const StationXApp());
}

class StationXApp extends StatelessWidget {
  const StationXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Station X - Hyper Local',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        primaryColor: const Color(0xFF00FF66),
        fontFamily: 'monospace',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF66),
          secondary: Color(0xFF00D2FF),
          surface: Color(0xFF161616),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// 🔐 Authentication Gate (Checks if user is logged in)
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFF00FF66))),
          );
        }
        if (snapshot.hasData) {
          return const MainHomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

// 🔑 Login & Sign Up Screen
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isSignUp = false;

  void _authenticate() async {
    try {
      if (_isSignUp) {
        UserCredential userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set({
          'uid': userCred.user!.uid,
          'username': '@${_usernameController.text.trim()}',
          'current_station': 'DHA Station, Lahore',
          'is_online': true,
          'communities': ['#dha-general', '#dha-mechanics'],
          'last_active': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '[ STATION X : TERMINAL ]',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF00FF66), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
            const SizedBox(height: 30),
            if (_isSignUp) ...[
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Unique Username (e.g. script_sector)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
            ],
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email (Hidden in App)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF66), foregroundColor: Colors.black),
              onPressed: _authenticate,
              child: Text(_isSignUp ? 'REGISTER ACCOUNT' : 'CONNECT TO STATION X'),
            ),
            TextButton(
              onPressed: () => setState(() => _isSignUp = !_isSignUp),
              child: Text(_isSignUp ? 'Already connected? Login' : 'Need an account? Sign Up', style: const TextStyle(color: Color(0xFF00D2FF))),
            ),
          ],
        ),
      ),
    );
  }
}

// 📱 Main Home Dashboard (4 Tabs: Chats, Explore, Radar, Profile)
class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ChatsTab(),
    const ExploreStationsTab(),
    const NearbyRadarTab(),
    const ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text('[ STATION X ]', style: TextStyle(fontSize: 14, color: Color(0xFF00FF66), letterSpacing: 1.2)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.grey),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: const Color(0xFF121212),
        selectedItemColor: const Color(0xFF00FF66),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.radar), label: 'Radar'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// 1. Chats Tab (Real-time active users list)
class ChatsTab extends StatelessWidget {
  const ChatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var users = snapshot.data!.docs;
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            var user = users[index];
            if (user.id == FirebaseAuth.instance.currentUser!.uid) return const SizedBox.shrink();
            return ListTile(
              leading: Stack(
                children: [
                  const CircleAvatar(backgroundColor: Color(0xFF222222), child: Icon(Icons.person, color: Colors.white70)),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: Color(0xFF00FF66), shape: BoxShape.circle),
                    ),
                  ),
                ],
              ),
              title: Text(user['username'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Station: ${user['current_station']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                // Open 1-on-1 private chat / video call interface
              },
            );
          },
        );
      },
    );
  }
}

// 2. Explore Stations & Service Hubs Tab
class ExploreStationsTab extends StatelessWidget {
  const ExploreStationsTab({super.key});

  final List<String> _stationRooms = const [
    '#lahore-dha-general',
    '#dha-mechanics (Verified Hub)',
    '#dha-electricians-hub',
    '#mughalpura-station',
    '#islamabad-blue-area',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '[ STATION X CHANNELS & SERVICE HUBS ]',
            style: TextStyle(color: Color(0xFF00FF66), fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: ListView.builder(
              itemCount: _stationRooms.length,
              itemBuilder: (context, index) {
                return Card(
                  color: const Color(0xFF161616),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.tag, color: Color(0xFF00FF66)),
                    title: Text(_stationRooms[index], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Public text & audio channel', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    onTap: () {
                      // Open room chat
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// 3. Nearby Radar Tab (GPS Proximity Scan)
class NearbyRadarTab extends StatefulWidget {
  const NearbyRadarTab({super.key});

  @override
  State<NearbyRadarTab> createState() => _NearbyRadarTabState();
}

class _NearbyRadarTabState extends State<NearbyRadarTab> {
  double _selectedRadius = 2.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('[ STATION X RADAR RANGE ]', style: TextStyle(color: Color(0xFF00D2FF), fontWeight: FontWeight.bold, fontSize: 12)),
              Text('${_selectedRadius.toStringAsFixed(0)} KM', style: const TextStyle(color: Color(0xFF00FF66), fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: _selectedRadius,
            min: 1.0,
            max: 5.0,
            divisions: 4,
            activeColor: const Color(0xFF00D2FF),
            inactiveColor: Colors.grey[800],
            onChanged: (value) => setState(() => _selectedRadius = value),
          ),
          const SizedBox(height: 10),
          const Expanded(
            child: Center(
              child: Text(
                'Scanning active users within radius...',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 4. Profile Tab & Community Badges
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final userUid = FirebaseAuth.instance.currentUser!.uid;
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userUid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const CircleAvatar(
                radius: 40,
                backgroundColor: Color(0xFF222222),
                child: Icon(Icons.person, size: 40, color: Color(0xFF00FF66)),
              ),
              const SizedBox(height: 15),
              Text(data['username'] ?? '@user', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text('[ STATION: ${data['current_station'] ?? 'Unknown'} ]', style: const TextStyle(color: Color(0xFF00D2FF), fontSize: 11)),
              const SizedBox(height: 25),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('JOINED COMMUNITIES:', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: (data['communities'] as List<dynamic>? ?? []).map((c) => Chip(label: Text(c.toString()), backgroundColor: const Color(0xFF161616))).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

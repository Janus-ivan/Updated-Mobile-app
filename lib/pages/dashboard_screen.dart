import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_service.dart';
import '../components/CustomBottomNavBar.dart';
import 'branches_screen.dart';
import '../components/zoomable_image_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  int _selectedIndex = 0;
  late List<Map<String, dynamic>> _branches = [];
  bool _branchesLoading = true;
  int _notificationCount = 0;
  StreamSubscription<List<Map<String, dynamic>>>? _appointmentChangesSubscription;
  String? _currentUserId;

  final List<String> _featuredImagePaths = [
    'assets/loading/load1 (1).jpg',
    'assets/loading/load1 (2).jpg',
    'assets/loading/load1 (3).jpg',
    'assets/loading/load1 (4).jpg',
  ];

  @override
  void initState() {
    super.initState();
    _currentUserId = _supabase.auth.currentUser?.id;
    _loadBranches();
    if (_currentUserId != null) {
      _fetchNotificationCount();
      _listenToAppointmentChanges();
    }
    _supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.initialSession) {
        setState(() {
          _currentUserId = data.session?.user.id;
        });
        if (_currentUserId != null) {
          _fetchNotificationCount();
          _listenToAppointmentChanges();
        }
      } else if (event == AuthChangeEvent.signedOut) {
        setState(() {
          _currentUserId = null;
          _notificationCount = 0;
        });
        _appointmentChangesSubscription?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _appointmentChangesSubscription?.cancel();
    super.dispose();
  }

  void _showSignInRequiredSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please sign in to access this feature.'),
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.pushNamed(context, '/sign-in');
  }

  Future<void> _fetchNotificationCount() async {
    if (_currentUserId == null) {
      if (mounted) {
        setState(() => _notificationCount = 0);
      }
      return;
    }
    try {
      final response = await _supabase
          .from('appointments')
          .select()
          .eq('user_id', _currentUserId!)
          .eq('isUserView', false)
          .filter('status', 'in', '("confirmed","in_progress","completed")')
          .count(CountOption.exact);

      if (mounted) {
        setState(() {
          _notificationCount = response.count ?? 0;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching notification count (attempt 1 with .count()): $e");
      }
      try {
        if (kDebugMode) print("Falling back to fetching data and counting client-side.");
        final List<Map<String, dynamic>> data = await _supabase
            .from('appointments')
            .select('id')
            .eq('user_id', _currentUserId!)
            .eq('isUserView', false)
            .filter('status', 'in', '("confirmed","in_progress","completed")');

        if (mounted) {
          setState(() {
            _notificationCount = data.length;
          });
        }
      } catch (e2) {
        if (kDebugMode) {
          print("Error fetching notification count (fallback client-side count): $e2");
        }
        if (mounted) {
          setState(() => _notificationCount = 0);
        }
      }
    }
  }

  void _listenToAppointmentChanges() {
    if (_currentUserId == null) return;
    _appointmentChangesSubscription?.cancel();

    _appointmentChangesSubscription = _supabase
        .from('appointments')
        .stream(primaryKey: ['id'])
        .eq('user_id', _currentUserId!)
        .listen((List<Map<String, dynamic>> data) {
      if (kDebugMode) {
        print("Appointment change detected, refetching notification count.");
      }
      _fetchNotificationCount();
    });
  }

  Future<void> _handleNotificationTap() async {
    if (_currentUserId == null) {
      _showSignInRequiredSnackBar(context);
      return;
    }

    if (_notificationCount == 0) {
      Navigator.pushNamed(context, '/bookings');
      return;
    }
    try {
      await _supabase
          .from('appointments')
          .update({'isUserView': true})
          .eq('user_id', _currentUserId!)
          .eq('isUserView', false)
          .filter('status', 'in', '("confirmed","in_progress","completed")');

      if (mounted) {
        setState(() {
          _notificationCount = 0;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error updating isUserView: $e");
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not update notifications: ${e.toString()}')));
      }
    } finally {
      Navigator.pushNamed(context, '/bookings');
    }
  }
  
  Future<void> _loadBranches() async {
    try {
      final response = await _supabase
          .from('branches')
          .select('id, name, address, status')
          .eq('status', 'open')
          .order('name');
      setState(() {
        _branches = response;
        _branchesLoading = false;
      });
    } catch (e) { 
      if (kDebugMode) {
        print("Error loading branches: $e");
      }
      setState(() => _branchesLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'M Speed On The Go',
          style: TextStyle(
            color: Color(0xFF1A73E8),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          Stack(
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.black),
                onPressed:_handleNotificationTap,
              ),
              if (_notificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_notificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          if (_currentUserId == null) _buildSignInButton(context),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildWelcomeBanner(),
            _buildBranchesSection(),
            _buildFeaturedServicesImages(),
            _buildServiceCategoriesSection(),
            _buildMobileServiceOption(),
            _buildReviewsSection(),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          final routes = ['/dashboard', '/bookings', '/services', '/profile'];
          if (index < routes.length) {
            if (ModalRoute.of(context)?.settings.name != routes[index]) {
              Navigator.pushNamed(context, routes[index]);
            }
          }
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_currentUserId == null) {
            _showSignInRequiredSnackBar(context);
          } else {
            Navigator.pushNamed(context, '/booking');
          }
        },
        backgroundColor: const Color(0xFF1A73E8),
        icon: const Icon(Icons.add),
        label: const Text('Book Now'),
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A73E8), Color(0xFF0D47A1)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome to M Speed On The Go',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Book your car wash appointment instantly',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (_currentUserId == null) {
                      _showSignInRequiredSnackBar(context);
                    } else {
                      Navigator.pushNamed(context, '/booking');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFAB40),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'BOOK NOW',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.local_car_wash,
                size: 40,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchesSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Our Branches',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BranchesScreen()),
                  );
                },
                child: const Text(
                  'View All',
                  style: TextStyle(color: Color(0xFF1A73E8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: _branchesLoading
                ? const Center(child: CircularProgressIndicator())
                : _branches.isEmpty
                ? const Center(child: Text("No open branches found."))
                : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: min(5, _branches.length),
              itemBuilder: (context, index) {
                return _buildBranchCard(_branches[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchCard(Map<String, dynamic> branch) {
    Color statusColor;
    String statusText = branch['status']?.toString().toUpperCase() ?? 'UNKNOWN';
    switch (statusText.toLowerCase()) {
      case 'open': statusColor = Colors.green; break;
      case 'closed': statusColor = Colors.orange; break;
      case 'maintenance': statusColor = Colors.red; break;
      default: statusColor = Colors.grey;
    }

    return GestureDetector(
      onTap: () {
        if (_currentUserId == null) {
          _showSignInRequiredSnackBar(context);
        } else {
          Navigator.pushNamed(context, '/booking');
        }
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 70,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Center(
                child: Icon(Icons.store, size: 40, color: Colors.blue[800]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    branch['name'] ?? 'Unnamed Branch',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    branch['address'] ?? 'No address',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              color: statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedServicesImages() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Featured Services',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('View All Images (placeholder)')),
                  );
                },
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1A73E8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 230,
            child: _featuredImagePaths.isEmpty
                ? const Center(
                child: Text(
                  'No featured images available.\nAdd paths to _featuredImagePaths in code.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                )
            )
                : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _featuredImagePaths.length,
              itemBuilder: (context, index) {
                return _buildFeaturedImageCard(_featuredImagePaths[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedImageCard(String imagePath) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ZoomableImageScreen(imagePath: imagePath),
          ),
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Image.asset(
            imagePath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              if (kDebugMode) {
                print('Error loading image $imagePath: $error');
              }
              return Container(
                color: Colors.grey[200],
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, color: Colors.grey, size: 40),
                      SizedBox(height: 4),
                      Text('No Image', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCategoriesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Service Categories',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryItem(Icons.local_car_wash, 'Exterior Wash'),
                _buildCategoryItem(
                  Icons.airline_seat_recline_normal,
                  'Interior',
                ),
                _buildCategoryItem(Icons.brush, 'Detailing'),
                _buildCategoryItem(Icons.shield, 'Waxing'),
                _buildCategoryItem(Icons.invert_colors_on, 'Polishing'),
                _buildCategoryItem(Icons.directions_car, 'Mobile'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(IconData icon, String label) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: const Color(0xFF1A73E8)),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              overflow: TextOverflow.ellipsis,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileServiceOption() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1A73E8), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF1A73E8).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_car,
              size: 30,
              color: Color(0xFF1A73E8),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mobile Car Wash Service',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  'We come to your location. Perfect for busy schedules!',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (_currentUserId == null) {
                _showSignInRequiredSnackBar(context);
              } else {
                Navigator.pushNamed(context, '/booking');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A73E8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Book'),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer Reviews',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildReviewCard(
            'John D.',
            'The mobile service was convenient! They arrived on time and did a fantastic job.',
            4.9,
          ),
          const SizedBox(height: 12),
          _buildReviewCard(
            'Sarah M.',
            'Booking through the app was so easy. I love how I can track the status of my car.',
            4.7,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildReviewCard(String name, String review, double rating) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF1A73E8),
                radius: 16,
                child: Text(
                  name[0],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.star, size: 16, color: Colors.amber[700]),
                  Text(
                    ' $rating',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            overflow: TextOverflow.ellipsis,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildSignInButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      child: TextButton(
        onPressed: () {
          Navigator.pushNamed(context, '/sign-in');
        },
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFF1A73E8),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
        ),
        child: const Text(
          'Sign In',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }
}
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:discovery_app/pages/dashboard_screen.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_service.dart';
import '../components/CustomBottomNavBar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  late Map<String, dynamic> _userData = {};
  late List<Map<String, dynamic>> _userVehicles = [];
  late List<Map<String, dynamic>> _recentBookings = [];

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _vehicleNameController = TextEditingController();
  final TextEditingController _plateNumberController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  int _selectedIndex = 3;
  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadVehicles();
    _loadRecentBookings();
  }


  Future<void> _loadUserData() async {
    try {
      final response = await _supabase
          .from('customers')
          .select()
          .eq('user_id', _supabase.auth.currentUser!.id)
          .single();

      setState(() {
        _userData = response;
        _fullNameController.text = _userData['full_name'] ?? '';
        _phoneController.text = _userData['phone'] ?? '';
        _emailController.text = _userData['email'] ?? '';
        _passwordController.clear();
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user data: $e');
      }
    }
  }

  Future<void> _loadVehicles() async {
    final response = await _supabase
        .from('vehicles')
        .select()
        .eq('user_id', _supabase.auth.currentUser!.id);

    setState(() {
      _userVehicles = response;
    });
  }

  Future<void> _loadRecentBookings() async {
    final response = await _supabase
        .from('appointments')
        .select('''*, 
        branches(name), 
        vehicles(name, plate_number),
        service:services(name) 
      ''')
        .eq('user_id', _supabase.auth.currentUser!.id)
        .order('appointment_date', ascending: false)
        .limit(5);

    setState(() {
      _recentBookings = response;
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Color(0xFF1A73E8),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.black),
            onPressed: _showEditProfileDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProfileHeader(),
            _buildLoyaltyCard(),
            _buildSectionTitle('My Vehicles'),
            _buildVehiclesList(),
            _buildSectionTitle('Recent Bookings'),
            _buildRecentBookings(),
            _buildActionButtons(),
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
            Navigator.pushNamed(context, routes[index]);
          }
        },
      ),
    );
  }

  void _showEditProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
              ),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'New Password (optional)'),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              const Text(
                'Leave the password field empty if you don\'t want to change it.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _updateUserEmailAndPassword();
                await _updateUserProfileData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated successfully!')),
                  );
                }
              } on AuthException catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Auth Error: ${e.message}')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              } finally {
                if (mounted) Navigator.pop(context);
                await _loadUserData();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  Future<void> _updateUserEmailAndPassword() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    final newEmail = _emailController.text.trim();
    final newPassword = _passwordController.text.trim();

    final attributes = UserAttributes();

    if (newEmail.isNotEmpty && newEmail != currentUser.email) {
      attributes.email = newEmail;
    }
    if (newPassword.isNotEmpty) {
      attributes.password = newPassword;
    }

    if (attributes.email != null || attributes.password != null) {
      await _supabase.auth.updateUser(attributes);
      await _supabase.auth.refreshSession();

      if (kDebugMode) {
        print('Auth updated: ${_supabase.auth.currentUser?.email}');
      }
    }
  }

  Future<void> _updateUserProfileData() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');
      final updates = {
        'full_name': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
      };

      final response = await _supabase
          .from('customers')
          .update(updates)
          .eq('user_id', userId)
          .select();

      if (kDebugMode) {
        print('Customers table updated: ${updates['email']}');
      }
    } catch (e) {
      if (kDebugMode) print('Profile update error: $e');
      rethrow;
    }
  }
  Future<void> _deleteVehicle(String vehicleId) async {
    try {
      await _supabase.from('vehicles').delete().eq('id', vehicleId);
      _loadVehicles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle deleted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete vehicle: $e')),
        );
      }
    }
  }

  void _showDeleteVehicleConfirmationDialog(String vehicleId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this vehicle?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _deleteVehicle(vehicleId);
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
  Widget _buildProfileHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 50,
            backgroundColor: Color(0xFF1A73E8),
            child: Text(
              'AR',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _userData['full_name'] ?? 'No Name',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const SizedBox(height: 4),
          Text(
            _userData['email'] ?? 'No Email',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            _userData['phone'] ?? 'No Phone Number',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1A73E8).withValues(alpha: (0.1 * 255).toDouble()),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _userData['membership_type'] ?? 'Regular Member',
              style: const TextStyle(
                color: Color(0xFF1A73E8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _userData['member_since'] != null
                ? 'Member since ${DateFormat('MMMM y').format(DateTime.parse(_userData['member_since']))}'
                : 'Member since 2023',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
  void _showAddVehicleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Vehicle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _vehicleNameController,
              decoration: const InputDecoration(labelText: 'Vehicle Name'),
            ),
            TextField(
              controller: _plateNumberController,
              decoration: const InputDecoration(labelText: 'Plate Number'),
            ),
            TextField(
              controller: _typeController,
              decoration: const InputDecoration(labelText: 'Type'),
            ),
            TextField(
              controller: _colorController,
              decoration: const InputDecoration(labelText: 'Color'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _supabase.from('vehicles').insert({
                'user_id': _supabase.auth.currentUser!.id,
                'name': _vehicleNameController.text,
                'plate_number': _plateNumberController.text,
                'type': _typeController.text,
                'color': _colorController.text,
              });
              _loadVehicles();
              Navigator.pop(context);
              _vehicleNameController.clear();
              _plateNumberController.clear();
              _typeController.clear();
              _colorController.clear();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  Widget _buildLoyaltyCard() {
    final int currentPoints = (_userData['loyalty_points'] as int?) ?? 0;
    final String currentLevel = _userData['loyalty_level'] as String? ?? 'Bronze';
    final Map<String, Map<String, dynamic>> loyaltyTiers = {
      'Bronze': {'minPoints': 0, 'nextMinPoints': 101, 'nextLevelName': 'Silver', 'badgeColor': const Color(0xFFCD7F32)}, // Bronze color
      'Silver': {'minPoints': 101, 'nextMinPoints': 301, 'nextLevelName': 'Gold', 'badgeColor': Colors.grey[500]!},
      'Gold': {'minPoints': 301, 'nextMinPoints': 501, 'nextLevelName': 'Platinum', 'badgeColor': Colors.amber[700]!},
      'Platinum': {'minPoints': 501, 'nextMinPoints': null, 'nextLevelName': null, 'badgeColor': Colors.blueGrey[300]!}, // A platinum-like color
    };

    double progressValue = 0.0;
    String progressText = 'Welcome!';
    Color currentBadgeColor = loyaltyTiers['Bronze']!['badgeColor'];

    final currentTierData = loyaltyTiers[currentLevel] ?? loyaltyTiers['Bronze']!;
    currentBadgeColor = currentTierData['badgeColor'];

    if (currentTierData['nextMinPoints'] != null && currentTierData['nextLevelName'] != null) {
      final int minPointsForCurrentTier = currentTierData['minPoints'] as int;
      final int minPointsForNextTier = currentTierData['nextMinPoints'] as int;
      final int pointsEarnedInTier = currentPoints - minPointsForCurrentTier;
      final int pointsNeededForNextTierRange = minPointsForNextTier - minPointsForCurrentTier;

      if (pointsNeededForNextTierRange > 0) {
        progressValue = (pointsEarnedInTier.toDouble() / pointsNeededForNextTierRange.toDouble()).clamp(0.0, 1.0);
      } else {
        progressValue = currentPoints >= minPointsForNextTier ? 1.0 : 0.0;
      }

      final int pointsToNextLevel = minPointsForNextTier - currentPoints;
      if (pointsToNextLevel > 0) {
        progressText = '$pointsToNextLevel points to ${currentTierData['nextLevelName']}';
      } else {
        progressText = 'Almost at ${currentTierData['nextLevelName']}!';
        if(currentPoints >= minPointsForNextTier) {
          progressText = "You've reached ${currentTierData['nextLevelName']}!";
          progressValue = 1.0;
        }
      }
    } else {
      progressValue = 1.0;
      progressText = 'You are at the highest level: Platinum!';
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A73E8), Color(0xFF0D47A1)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'M Speed Loyalty',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: currentBadgeColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  currentLevel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Points',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$currentPoints',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () {
                  if (currentPoints > 0) {
                    _showRedeemPointsModal();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('You have no points to redeem')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1A73E8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Redeem Points'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progressValue,
            backgroundColor: Colors.white30,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            progressText,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _showRedeemPointsModal() {
    final int currentPoints = (_userData['loyalty_points'] as int?) ?? 0;


    final discounts = [
      {'points': 100, 'discount': '10% Off', 'description': 'Basic Wash Package'},
      {'points': 200, 'discount': '20% Off', 'description': 'Premium Detailing'},
      {'points': 300, 'discount': '30% Off', 'description': 'Full Service Package'},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Redeem Loyalty Points'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Available Discounts:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...discounts.map((discountMap) {
              final int pointsRequired = discountMap['points'] as int;
              final String discountName = discountMap['discount'] as String;
              final String discountDescription = discountMap['description'] as String;

              return ListTile(
                title: Text(discountName),
                subtitle: Text(discountDescription),
                trailing: Text('$pointsRequired pts'),
                enabled: currentPoints >= pointsRequired,
                onTap: () {
                  _redeemDiscount(pointsRequired, discountName);
                },
              );
            }),
            const SizedBox(height: 20),
            const Text(
              'Disclaimer: Redeemed discounts must be claimed in-person at any MSpeed branch. Digital redemption not available. \nPresent the redemption process upon arrival to the branch.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _redeemDiscount(int pointsToRedeem, String discountName) async {
    final currentAuthUserId = _supabase.auth.currentUser?.id;
    if (currentAuthUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated.')),
        );
      }
      return;
    }

    final dynamic rawCustomerId = _userData['id'];
    if (rawCustomerId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer ID not found in user data.')),
        );
      }
      return;
    }
    final String customerId;
    try {
      customerId = rawCustomerId as String;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid customer ID format in user data: $rawCustomerId')),
        );
      }
      return;
    }

    final dynamic rawLoyaltyPoints = _userData['loyalty_points'];
    final int currentPoints = (rawLoyaltyPoints as int?) ?? 0;

    if (currentPoints < pointsToRedeem) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not enough points for this discount')),
        );
      }
      return;
    }


    try {
      await _supabase.rpc('adjust_customer_loyalty_points', params: {
        'p_customer_id': customerId,
        'p_points_to_add': -pointsToRedeem,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$discountName redeemed successfully!'),
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
        await _loadUserData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Redemption failed: ${e.toString()}')),
        );
      }
    } finally {

    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildVehiclesList() {
    if (_userVehicles.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No vehicles registered'),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _userVehicles.length,
      itemBuilder: (context, index) {
        final vehicle = _userVehicles[index];
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: (0.1 * 255).toDouble()),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _userVehicles[index]['type'] == 'SUV'
                        ? Icons.directions_car_filled
                        : Icons.directions_car,
                    size: 30,
                    color: const Color(0xFF1A73E8),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle['name'] ?? 'Unnamed Vehicle',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Plate: ${vehicle['plate_number'] ?? 'N/A'}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 12,
                            color: _userVehicles[index]['color'] != null
                                ? _parseColor(_userVehicles[index]['color'])
                                : Colors.black,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${vehicle['color'] ?? 'Unknown'} • ${vehicle['type'] ?? 'Unknown'}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => _showDeleteVehicleConfirmationDialog(vehicle['id'] as String),
                      child: const Icon(
                        Icons.close,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Last Wash',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vehicle['last_service_date'] != null
                          ? DateFormat('MMM d').format(
                          DateTime.parse(vehicle['last_service_date']))
                          : 'Never',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A73E8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A73E8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(fontSize: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('Book Wash'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentBookings() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentBookings.length,
      itemBuilder: (context, index) {
        final booking = _recentBookings[index];
        final branchName = booking['branches']?['name'] ?? 'Mobile Service';
        final serviceType = booking['service']?['name'] ?? 'Unknown Service';
        final status = booking['status'] ?? 'Pending';
        final dateString = booking['appointment_date'] != null
            ? DateFormat('MMM d, y').format(
            DateTime.parse(booking['appointment_date']))
            : 'No date';
        Color statusColor;
        if (_recentBookings[index]['status'] == 'Completed') {
          statusColor = Colors.green;
        } else if (_recentBookings[index]['status'] == 'Upcoming') {
          statusColor = Colors.blue;
        } else {
          statusColor = Colors.orange;
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: (0.1 * 255).toDouble()),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A73E8).withValues(alpha: (0.1 * 255).toDouble()),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.local_car_wash,
                    color: Color(0xFF1A73E8),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serviceType,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateString,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        branchName,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: (0.1 * 255).toDouble()),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildActionButton(Icons.add_circle_outline, 'Add New Vehicle', _showAddVehicleDialog),
          const SizedBox(height: 24),
          _buildActionButton(Icons.help_outline, 'Help & Support', () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Help & Support'),
                content: const Text(
                    'For assistance, please contact our support team at:\n\n'
                        'Email: support@mspeed.com\n'
                        'Phone: +63 912 345 6789\n\n'
                        'Or visit our FAQ section in the app settings.'
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () async {
              try {
                await AuthService().signOut();
                Navigator.pushReplacementNamed(context, '/');
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Logout failed: $e')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout),
                SizedBox(width: 8),
                Text(
                  'Sign Out',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Color _parseColor(String colorString) {
    switch (colorString.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'pink':
        return Colors.pink;
      case 'purple':
        return Colors.purple;
      case 'deepPurple':
      case 'deeppurple':
        return Colors.deepPurple;
      case 'indigo':
        return Colors.indigo;
      case 'blue':
        return Colors.blue;
      case 'lightBlue':
      case 'lightblue':
        return Colors.lightBlue;
      case 'cyan':
        return Colors.cyan;
      case 'teal':
        return Colors.teal;
      case 'green':
        return Colors.green;
      case 'lightGreen':
      case 'lightgreen':
        return Colors.lightGreen;
      case 'lime':
        return Colors.lime;
      case 'yellow':
        return Colors.yellow;
      case 'amber':
        return Colors.amber;
      case 'orange':
        return Colors.orange;
      case 'deepOrange':
      case 'deeporange':
        return Colors.deepOrange;
      case 'brown':
        return Colors.brown;
      case 'grey':
      case 'gray':
        return Colors.grey;
      case 'blueGrey':
      case 'bluegray':
        return Colors.blueGrey;
      case 'black':
        return Colors.black;
      case 'white':
        return Colors.white;
      case 'transparent':
        return Colors.transparent;
      default:
        try {
          final hex = colorString.replaceAll('#', '');
          if (hex.length == 6) {
            return Color(int.parse('FF$hex', radix: 16));
          } else if (hex.length == 8) {
            return Color(int.parse(hex, radix: 16));
          }
        } catch (e) {
          if (kDebugMode) {
            print('Invalid color string: $colorString. Error: $e');
          }
        }
        return Colors.black;
    }
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    VoidCallback onPressed,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: (0.1 * 255).toDouble()),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF1A73E8)),
              const SizedBox(width: 16),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

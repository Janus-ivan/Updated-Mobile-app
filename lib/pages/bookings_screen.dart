import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../components/CustomBottomNavBar.dart';


class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}
class _BookingsScreenState extends State<BookingsScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  int _selectedIndex = 1;
  late TabController _tabController;
  List<Map<String, dynamic>> _todayBookings = [];
  List<Map<String, dynamic>> _recentBookings = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBookings();
  }
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  void _handleBookAgain(Map<String, dynamic> booking) async {
    Navigator.pushNamed(context, '/booking', arguments: {
      'service': booking['service']['name'],
      'vehicleModel': booking['vehicle'],
      'service_id': booking['service']['id'],
      'vehicleType': booking['vehicle_type'],
      'plateNumber': booking['plateNumber'],
      'vehicleColor': booking['vehicle_color'],
    });
  }
  Future<void> _submitReport({
    required String bookingId,
    required String issueType,
    required String description,
    String? staffId,
    String? riderId,
  }) async {
    try {
      await _supabase.from('reports').insert({
        'booking_id': bookingId,
        'user_id': _supabase.auth.currentUser!.id,
        'staff_id': staffId,
        'rider_id': riderId,
        'issue_type': issueType,
        'description': description,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting report: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  Future<void> _loadBookings() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('appointments')
          .select('''
        id, 
        appointment_date, 
        status, 
        service:services(name, price),
        branch:branches(name),
        service_address, 
        vehicle:vehicles(name, plate_number, type, color),
        payment_method,
        notes,
        staff_id,
        rider_id,
        staff:staff!appointments_staff_id_fkey(
          id, 
          full_name, 
          position, 
          photo_url, 
          rating, 
          phone, 
          experience, 
          specialties
        ),
        rider:riders(
          id,
          name,
          vehicle_type,
          plate_number,
          status,
          branch:branches(name) 
        )
      ''')
          .eq('user_id', userId)
          .order('appointment_date', ascending: false);

      final List<Map<String, dynamic>> processedResponse = response.map<Map<String, dynamic>>((booking) {

        final Map<String, dynamic> processedBooking = Map<String, dynamic>.from(booking);
        if (booking['branch'] == null && booking['service_address'] != null) {
          String address = booking['service_address'];
          if (address.length > 12) {
            address = '${address.substring(0, 12)}...';
          }
          processedBooking['branch'] = {'name': 'Mobile Service: $address'};
        } else if (booking['branch'] != null && booking['branch']['name'] != null) {
          String branchName = booking['branch']['name'];
          if (branchName.length > 12) {
            processedBooking['branch'] = {'name': '${branchName.substring(0, 12)}...'};
          }
        }

        return processedBooking;
      }).toList();

      final now = DateTime.now();
      _todayBookings = processedResponse
          .where((booking) {
        final appointmentDate = DateTime.parse(booking['appointment_date']);
        return DateUtils.isSameDay(appointmentDate, now);
      })
          .toList();

      _recentBookings = processedResponse
          .where((booking) {
        final appointmentDate = DateTime.parse(booking['appointment_date']);
        return !DateUtils.isSameDay(appointmentDate, now);
      })
          .toList();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load bookings: ${e.toString()}';
      });
    }
  }
  Map<String, dynamic> _formatBooking(Map<String, dynamic> booking) {

    final appointmentDate = DateTime.parse(booking['appointment_date']).toLocal();

    final dynamic staffData = booking['staff'];
    final branchData = booking['branch'] ?? {};

    final dynamic serviceData = booking['service'];
    String serviceName = 'Unknown Service';
    dynamic servicePrice = 0.0;
    final dynamic vehicleData = booking['vehicle'];
    String vehicleName = 'Unknown Vehicle';
    String plateNumber = 'N/A';
    String vehicleType = 'Unknown Type';
    String vehicleColor = 'Unknown Color';

    String staffPhoto = 'assets/images/default_avatar.png';
    if (staffData != null) {
      if (staffData['photo_url'] != null && staffData['photo_url'].isNotEmpty) {
        staffPhoto = staffData['photo_url'];
      }
    }

    final dynamic riderData = booking['rider'];
    Map<String, dynamic> riderInfo = {
      'photo': 'assets/images/default_rider.png',
      'name': 'Rider',
      'vehicle_type': 'Motorcycle',
      'plate_number': 'N/A',
      'phone': 'N/A'
    };

    if (riderData != null && riderData is Map && riderData.isNotEmpty) {
      riderInfo.update('id', (value) => riderData['id'], ifAbsent: () => '');
      riderInfo['name'] = riderData['name'] ?? 'Rider';
      riderInfo['vehicle_type'] = riderData['vehicle_type'] ?? 'Motorcycle';
      riderInfo['plate_number'] = riderData['plate_number'] ?? 'N/A';
      riderInfo['phone'] = riderData['phone'] ?? 'N/A';
      final branchData = riderData['branch'] ?? {};
      riderInfo['branch'] = branchData['name'] ?? 'No branch assigned';
    }

    final showRider = staffData == null && riderData != null;

    Map<String, dynamic> staffInfo = {
      'photo': 'assets/images/default_avatar.png',
      'name': 'Staff Member',
      'position': 'Car Wash Specialist',
      'rating': 4.5,
      'phone': 'N/A',
      'experience': 'N/A',
      'specialties': 'N/A',
    };

    if (staffData != null && staffData is Map && staffData.isNotEmpty) {
      if (staffData['photo_url'] != null && staffData['photo_url'].isNotEmpty) {
        staffPhoto = staffData['photo_url'];
      }
      staffInfo.update('id', (value) => staffData['id'], ifAbsent: () => '');
      staffInfo['name'] = staffData['full_name'] ?? 'Staff Member';
      staffInfo['position'] = staffData['position'] ?? 'Car Wash Specialist';
      staffInfo['photo'] = staffPhoto;
      staffInfo['rating'] = (staffData['rating'] ?? 4.5).toDouble();
      staffInfo['phone'] = staffData['phone'] ?? 'N/A';
      staffInfo['experience'] = staffData['experience'] ?? 'N/A';
      staffInfo['specialties'] = staffData['specialties'] is List
          ? (staffData['specialties'] as List).join(', ')
          : 'N/A';
    }

    if (vehicleData is List) {
      if (vehicleData.isNotEmpty) {
        vehicleName = vehicleData[0]['name'] ?? 'Unknown Vehicle';
        plateNumber = vehicleData[0]['plate_number'] ?? 'N/A';
        vehicleType = vehicleData[0]['type'] ?? 'Unknown Type';
        vehicleColor = vehicleData[0]['color'] ?? 'Unknown Color';
      }
    } else if (vehicleData is Map) {
      vehicleName = vehicleData['name'] ?? 'Unknown Vehicle';
      plateNumber = vehicleData['plate_number'] ?? 'N/A';
      vehicleType = vehicleData['type'] ?? 'Unknown Type';
      vehicleColor = vehicleData['color'] ?? 'Unknown Color';
    }

    if (serviceData is List) {
      if (serviceData.isNotEmpty) {
        serviceName = serviceData[0]['name'] ?? 'Unknown Service';
        servicePrice = serviceData[0]['price'] ?? 0.0;
      }
    } else if (serviceData is Map) {
      serviceName = serviceData['name'] ?? 'Unknown Service';
      servicePrice = serviceData['price'] ?? 0.0;
    }


    return {
      'id': booking['id'],
      'service': {
        'name': serviceName,
        'price': servicePrice,
      },
      'price': _formatPrice(servicePrice),
      'branch': branchData['name'] ?? 'Mobile Service',
      'date': appointmentDate,
      'status': _mapStatus(booking['status']),
      'vehicle': vehicleName,
      'plateNumber': plateNumber,
      'vehicle_type': vehicleType,
      'phone': staffInfo['phone'] ?? 'N/A',
      'vehicle_color': vehicleColor,
      'payment_method': booking['payment_method'] ?? 'Cash',
      'staff_id': booking['staff_id'],
      'staff': staffInfo,
      'rider': riderInfo,
      'show_rider': showRider,
      'can_rebook': _canRebook(appointmentDate),
    };
  }
  String _formatPrice(dynamic price) {
    if (price == null) return '₱0.00';
    final parsedPrice = double.tryParse(price.toString()) ?? 0.0;
    return '₱${parsedPrice.toStringAsFixed(2)}';
  }


  String _mapStatus(String dbStatus) {
    switch (dbStatus.toLowerCase()) {
      case 'in_progress': return 'In Progress';
      case 'confirmed': return 'Confirmed';
      case 'pending': return 'Pending';
      case 'completed': return 'Completed';
      case 'cancelled': return 'Cancelled';
      default: return 'Unknown';
    }
  }

  bool _canRebook(DateTime appointmentDate) {
    return appointmentDate.isBefore(DateTime.now().subtract(const Duration(days: 1)));
  }
  Future<void> _cancelBooking(String bookingId) async {
    try {
      await _supabase
          .from('appointments')
          .update({'status': 'cancelled'})
          .eq('id', bookingId)
          .select();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking cancelled successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadBookings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling booking: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  void _showReportIssueDialog(Map<String, dynamic> booking) {
    String? selectedIssueType;
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Report an Issue'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedIssueType,
                      items: const [
                        DropdownMenuItem(value: 'Billing', child: Text('Billing')),
                        DropdownMenuItem(value: 'Service Quality', child: Text('Service Quality')),
                        DropdownMenuItem(value: 'Staff Behaviour', child: Text('Staff Behaviour')),
                        DropdownMenuItem(value: 'Rider Issue', child: Text('Rider Issue')),
                        DropdownMenuItem(value: 'Technical Delay', child: Text('Technical')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (value) => setState(() => selectedIssueType = value),
                      decoration: const InputDecoration(labelText: 'Issue Type'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
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
                    if (selectedIssueType == null || descriptionController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all fields')),
                      );
                      return;
                    }

                    await _submitReport(
                      bookingId: booking['id'],
                      issueType: selectedIssueType!,
                      description: descriptionController.text,
                      staffId: booking['show_rider'] ? null : booking['staff_id'],
                      riderId: booking['show_rider'] ? booking['rider']['id'] : null,
                    );
                    Navigator.of(context, rootNavigator: true).pop();
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  void _showStaffDetailsDialog(Map<String, dynamic> staff) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Staff Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: staff['photo'].startsWith('http')
                      ? NetworkImage(staff['photo'])
                      : AssetImage(staff['photo']) as ImageProvider,
                ),
                const SizedBox(height: 16),
                Text(
                  staff['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  staff['position'],
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${staff['rating']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.phone),
                  title: const Text('Contact'),
                  subtitle: Text(staff['phone'] ?? 'N/A'),
                ),
                ListTile(
                  leading: const Icon(Icons.work),
                  title: const Text('Experience'),
                  subtitle: Text(staff['experience'] ?? 'N/A'),
                ),
                ListTile(
                  leading: const Icon(Icons.star_border),
                  title: const Text('Specialties'),
                  subtitle: Text(staff['specialties'] ?? 'N/A'),
                )
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/staff-directory');
              },
              child: const Text('View All Staff'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Bookings',
          style: TextStyle(
            color: Color(0xFF1A73E8),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1A73E8),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF1A73E8),
          tabs: const [
            Tab(text: 'Today\'s Bookings'),
            Tab(text: 'Recent Bookings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildTodayBookingsList(), _buildRecentBookingsList()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/booking');
        },
        backgroundColor: const Color(0xFF1A73E8),
        icon: const Icon(Icons.add),
        label: const Text('New Booking'),
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

  Widget _buildTodayBookingsList() {
    if (_isLoading) return _buildLoadingState();
    if (_errorMessage.isNotEmpty) return _buildErrorState();
    if (_todayBookings.isEmpty) return _buildEmptyState('No bookings for today', 'Book a car wash service now');

    return RefreshIndicator(
      onRefresh: _loadBookings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _todayBookings.length,
        itemBuilder: (context, index) {
          return _buildBookingCard(_formatBooking(_todayBookings[index]), true);
        },
      ),
    );
  }
  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
  Widget _buildRecentBookingsList() {
    if (_isLoading) return _buildLoadingState();
    if (_errorMessage.isNotEmpty) return _buildErrorState();
    if (_recentBookings.isEmpty) return _buildEmptyState('No recent bookings', 'Your booking history will appear here');

    return RefreshIndicator(
      onRefresh: _loadBookings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _recentBookings.length,
        itemBuilder: (context, index) {
          return _buildBookingCard(_formatBooking(_recentBookings[index]), false);
        },
      ),
    );
  }
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 50),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadBookings,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/booking');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A73E8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text('Book Now'),
          ),
        ],
      ),
    );
  }
  void _showRiderDetailsDialog(Map<String, dynamic> rider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Rider Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: AssetImage(rider['photo']),
                ),
                const SizedBox(height: 16),
                Text(
                  rider['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'Vehicle: ${rider['vehicle_type']}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.directions_bike),
                  title: const Text('Vehicle Plate'),
                  subtitle: Text(rider['plate_number'] ?? 'N/A'),
                ),
                ListTile(
                  leading: const Icon(Icons.phone),
                  title: const Text('Contact'),
                  subtitle: Text(rider['phone'] ?? 'N/A'),
                ),
                ListTile(
                  leading: const Icon(Icons.business),
                  title: const Text('Assigned Branch'),
                  subtitle: Text(rider['branch'] ?? 'No branch assigned'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking, bool isToday) {
    Color statusColor;
    IconData statusIcon;

    switch (booking['status']) {
      case 'Cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'Confirmed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'In Progress':
        statusColor = Colors.blue;
        statusIcon = Icons.autorenew;
        break;
      case 'Pending':
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
      case 'Completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
    }
    final isRider = booking['show_rider'];
    final person = isRider ? booking['rider'] : booking['staff'];
    final photo = person['photo'];
    final isNetworkImage = !isRider && (photo?.startsWith('http') ?? false);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          isRider ? _showRiderDetailsDialog(person) : _showStaffDetailsDialog(person);
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A73E8).withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking['service']['name'] ?? 'Unknown Service',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking['branch'],
                        style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      ),
                    ],
                  ),
                  Text(
                    _formatPrice(booking['service']['price']),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1A73E8),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.directions_car, color: Colors.grey[700], size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '${booking['vehicle']} (${booking['plateNumber']})',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.event, color: Colors.grey[700], size: 18),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('MMM dd, HH:mm').format(booking['date']),
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(statusIcon, color: statusColor, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            booking['status'],
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (_shouldShowCancelButton(booking))
                        ElevatedButton(
                          onPressed: () => _showCancelConfirmationDialog(booking['id']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[50],
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () {
                          isRider ? _showRiderDetailsDialog(person) : _showStaffDetailsDialog(person);
                        },
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: isNetworkImage
                                  ? NetworkImage(photo)
                                  : AssetImage(photo ?? 'assets/images/default_avatar.png') as ImageProvider,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  person['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  isRider
                                      ? '${person['vehicle_type']} • ${person['branch']}'
                                      : person['position'],
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          if (!isRider && person.containsKey('rating'))
                            Row(
                              children: [
                                Icon(Icons.star, color: Colors.amber[700], size: 16),
                                const SizedBox(width: 2),
                                Text(
                                  person['rating'].toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                          TextButton(
                            onPressed: () => _showReportIssueDialog(booking),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Report Issue',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF1A73E8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (booking['status'] == 'Completed' && !isToday)
              InkWell(
                onTap: () => _handleBookAgain(booking),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  ),
                  child: const Center(
                    child: Text(
                      'Book Again',
                      style: TextStyle(
                        color: Color(0xFF1A73E8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  bool _shouldShowCancelButton(Map<String, dynamic> booking) {
    final status = booking['status'];
    if (status != 'Pending') return false;

    final appointmentDate = booking['date'] as DateTime;
    final now = DateTime.now();

    return DateUtils.isSameDay(appointmentDate, now) ||
        appointmentDate.isAfter(now);
  }



  void _showCancelConfirmationDialog(String bookingId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Cancellation'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _cancelBooking(bookingId);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }
}
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:geocoding/geocoding.dart' as geo;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../components/CustomBottomNavBar.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {



  List<Map<String, dynamic>> _userVehicles = [];
  bool _isLoadingVehicles = true;
  String? _selectedVehicleId;
  List<Map<String, dynamic>> _availableRiders = [];
  String? _selectedRiderId;
  bool _isLoadingRiders = true;
  final SupabaseClient _supabase = Supabase.instance.client;
  int _selectedIndex = 1;
  String? _selectedBranchId;
  List<Map<String, dynamic>> _branchOptionsData = [];
  bool _isLoadingBranches = true;
  List<Map<String, dynamic>> _availableStaff = [];
  String? _selectedStaffId;
  String _selectedService = '';
  late final MapController _mapController;
  latlng.LatLng? _selectedLocation;
  final List<Marker> _markers = [];
  String _selectedVehicleType = 'Sedan';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isMobileService = false;
  String _selectedPaymentMethod = 'Cash';
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _plateNumberController = TextEditingController();
  final TextEditingController _vehicleModelController = TextEditingController();
  final TextEditingController _vehicleColorController = TextEditingController();
  final TextEditingController _vehicleTypeController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  final List<String> _paymentMethods = [
    'Cash',
    'Bank Transfer',
    'GCash',
  ];

  List<Map<String, dynamic>> _services = [];
  bool _isLoadingServices = true;
  String? _selectedServiceId;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _mapController = MapController();
    _selectedLocation = const latlng.LatLng(14.5995, 120.9842);
    _vehicleTypeController.text = _selectedVehicleType;

    _loadInitialData().then((_) {
      if (_branchOptionsData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No branches available - mobile service only')),
        );
        setState(() => _isMobileService = true);
      }
      if (_isMobileService) {
        _fetchRiders();
      }
    });
    _loadUserVehicles();
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    if (status.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is recommended for mobile services'),
          ),
        );
      }
    }
  }

  String _generateRandomQRData() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(10, (index) => chars[random.nextInt(chars.length)]).join();
  }
  Future<latlng.LatLng?> _getActualCurrentDeviceLocation() async {
    try {

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable location services')),
          );
        }
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are required')),
            );
          }
          return null;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return latlng.LatLng(position.latitude, position.longitude);
    } catch (e) {
      if (kDebugMode) print("Error getting location: $e");
      return null;
    }
  }
  Future<void> _fetchRiders() async {
    try {
      final response = await _supabase
          .from('riders')
          .select('id, name, vehicle_type, plate_number')
          .eq('status', 'active');

      setState(() {
        _availableRiders = List<Map<String, dynamic>>.from(response);
        _isLoadingRiders = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading riders: ${e.toString()}')),
      );
    }
  }
  Future<void> _loadInitialData() async {
    await _loadBranchesData();
    await _loadServices();
  }
  Future<void> _loadUserVehicles() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await _supabase
          .from('vehicles')
          .select('id, plate_number, name, type, color')
          .eq('user_id', userId);

      setState(() {
        _userVehicles = List<Map<String, dynamic>>.from(response);
        _isLoadingVehicles = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading vehicles: ${e.toString()}')),
      );
    }
  }
  Future<void> _fetchStaffForBranch(String branchId) async {
    final response = await _supabase
        .from('staff')
        .select('id, full_name, position, rating')
        .eq('branch_id', branchId)
        .eq('status', 'active')
        .order('full_name');

    setState(() {
      _availableStaff = List<Map<String, dynamic>>.from(response);
      _selectedStaffId = _availableStaff.isNotEmpty ? _availableStaff.first['id'] : null;
    });
  }

  void _handleBranchSelection(String? branchId) {
    if (branchId != null) {
      _fetchStaffForBranch(branchId);
    } else {
      setState(() {
        _availableStaff = [];
        _selectedStaffId = null;
      });
    }
  }
  Future<void> _loadServices() async {
    setState(() => _isLoadingServices = true);
    try {
      final response = await _supabase
          .from('services')
          .select('id, name, price');

      setState(() {
        _services = List<Map<String, dynamic>>.from(response);
        if (_services.isNotEmpty) {
          _selectedService = _services.first['name'] as String;
          _selectedServiceId = _services.first['id'] as String;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading services: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoadingServices = false);
    }
  }
  Future<void> _loadBranchesData() async {
    setState(() => _isLoadingBranches = true);
    try {
      final response = await _supabase
          .from('branches')
          .select('id, name, status, capacity, utilization')
          .eq('status', 'open');

      final data = List<Map<String, dynamic>>.from(response);
      if (data.isEmpty) {
        if (kDebugMode) print('No open branches found');
      }

      setState(() => _branchOptionsData = data);
    } catch (e) {
      if (kDebugMode) print('Branch load error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading branches: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoadingBranches = false);
    }
  }
  Marker _createMarker(latlng.LatLng point) {
    return Marker(
      width: 40,
      height: 40,
      point: point,
      child: const Icon(
        Icons.location_pin,
        color: Colors.red,
        size: 40,
      ),
    );
  }


  Future<void> _updateAddress(latlng.LatLng position) async {
    try {
      _mapController.move(position, 15);
      final places = await geo.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (places.isNotEmpty) {
        final place = places.first;
        setState(() {
          _addressController.text = [
            place.street,
            place.locality,
            place.administrativeArea,
            place.postalCode
          ].where((part) => part?.isNotEmpty ?? false).join(', ');
          _selectedLocation = position;
          _markers.clear();
          _markers.add(_createMarker(position));
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error getting address: $e");
      }
    }
  }
  Future<void> _validateAndSubmit() async {
    bool isInvalid = false;
    String errorMessage = 'Please fill all required fields';

    if ((!_isMobileService && _selectedBranchId == null) ||
        (_isMobileService &&
            (_addressController.text.isEmpty || _selectedLocation == null)) ||
        _plateNumberController.text.isEmpty ||
        _vehicleModelController.text.isEmpty ||
        _vehicleTypeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
      return;
    }
    if (!_isMobileService && _selectedBranchId != null) {
      final selectedBranchData = _branchOptionsData.firstWhere(
            (branch) => branch['id'] == _selectedBranchId,
        orElse: () => {},
      );

      if (selectedBranchData.isNotEmpty) {
        final int capacity = selectedBranchData['capacity'] ?? 0;
        final int utilization = selectedBranchData['utilization'] ?? 0;

        if (utilization >= capacity) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected branch is at full capacity. Please choose another branch or time.')),
          );
          return;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not verify branch capacity. Please try again.')),
        );
        return;
      }
    }


    if (_isMobileService) {
      if (_availableRiders.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No available riders for mobile service')),
        );
        return;
      }
      if (_selectedRiderId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a rider')),
        );
        return;
      }
    } else {
      if (_branchOptionsData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No available branches')),
        );
        return;
      }
      if (_availableStaff.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No available staff at selected branch')),
        );
        return;
      }
    }

    bool hasVehicle = _selectedVehicleId != null ||
        (_plateNumberController.text.isNotEmpty &&
            _vehicleModelController.text.isNotEmpty &&
            _vehicleTypeController.text.isNotEmpty);

    if (!hasVehicle) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide vehicle details')),
      );
      return;
    }

    try {
      if (_selectedPaymentMethod == 'GCash') {
        final qrData = _generateRandomQRData();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Scan GCash QR Code',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                      errorStateBuilder: (context, error) => Text(
                        'QR Error: $error',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text(
                    'Processing payment...',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );

        await Future.delayed(const Duration(seconds: 5));
        if (mounted) Navigator.of(context).pop();
      }

      String? vehicleId = _selectedVehicleId;
      if (_selectedVehicleId == null) {
        final vehicleResponse = await _supabase
            .from('vehicles')
            .insert({
          'user_id': _supabase.auth.currentUser!.id,
          'name': _vehicleModelController.text,
          'plate_number': _plateNumberController.text,
          'type': _selectedVehicleType,
          'color': _vehicleColorController.text,
        })
            .select('id')
            .single();
        vehicleId = vehicleResponse['id'] as String;
      }

      final customerResponse = await _supabase
          .from('customers')
          .select('id')
          .eq('user_id', _supabase.auth.currentUser!.id)
          .single();

      final serviceResponse = await _supabase
          .from('services')
          .select('id')
          .eq('name', _selectedService)
          .single();

      final appointmentDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      await _supabase.from('appointments').insert({
        'appointment_date': appointmentDate.toIso8601String(),
        'branch_id': _isMobileService ? null : _selectedBranchId,
        'customer_id': customerResponse['id'],
        'service_id': serviceResponse['id'],
        'vehicle_id': vehicleId,
        'payment_method': _selectedPaymentMethod,
        'notes': _instructionsController.text,
        'user_id': _supabase.auth.currentUser!.id,
        'service_location': _isMobileService
            ? 'POINT(${_selectedLocation!.longitude} ${_selectedLocation!.latitude})'
            : null,
        'service_address': _isMobileService ? _addressController.text : null,
        'staff_id': _isMobileService ? null : _selectedStaffId,
        'rider_id': _isMobileService ? _selectedRiderId : null,
        'status': 'pending',
      });

      _showBookingConfirmation();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking failed: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _plateNumberController.dispose();
    _vehicleModelController.dispose();
    _vehicleColorController.dispose();
    _vehicleTypeController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }
  String _formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    final dateTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    final format = DateFormat.jm();
    return format.format(dateTime);
  }
  Future<void> _selectDate() async {
    DateTime _getFirstAvailableDate() {
      final now = DateTime.now();
      return now.weekday == DateTime.sunday ? now.add(const Duration(days: 1)) : now;
    }

    final firstDate = _getFirstAvailableDate();
    final initialDate = _selectedDate.isBefore(firstDate) ? firstDate : _selectedDate;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 30)),
      selectableDayPredicate: (DateTime date) {

        return date.weekday != DateTime.sunday;
      },
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;

        final now = DateTime.now();
        if (pickedDate.year == now.year &&
            pickedDate.month == now.month &&
            pickedDate.day == now.day) {
          _selectedTime = TimeOfDay.fromDateTime(now);
        }
      });
    }
  }

  Future<void> _selectTime() async {
  final TimeOfDay? pickedTime = await showTimePicker(
    context: context,
    initialTime: _selectedTime,
    builder: (BuildContext context, Widget? child) {
      return Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1A73E8),
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.black,
          ),
          dialogBackgroundColor: Colors.white,
        ),
        child: child!,
      );
    },
  );

  if (pickedTime != null) {
    // Validate that the selected time is within business hours (7am-6pm)
    final now = DateTime.now();
    final selectedDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // Check if selected time is in the past for today
    if (_selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day &&
        selectedDateTime.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time in the future')),
      );
      return;
    }

    // Check business hours (7am-6pm)
    if (pickedTime.hour < 7 || pickedTime.hour >= 18) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select time between 7am and 6pm')),
      );
      return;
    }

    setState(() {
      _selectedTime = pickedTime;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Book Appointment',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LinearProgressIndicator(
              value: 0.5,
              backgroundColor: Color(0xFFE0E0E0),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A73E8)),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                  _isMobileService
                      ? const Color(0xFF1A73E8)
                      : Colors.grey[300]!,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_car, color: Color(0xFF1A73E8)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mobile Service',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'We come to your location',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isMobileService,
                    activeColor: const Color(0xFF1A73E8),
                    onChanged: _branchOptionsData.isNotEmpty ? (value) async {
                      setState(() => _isMobileService = value);

                      if (_isMobileService) {
                        _fetchRiders();
                        final deviceLocation = await _getActualCurrentDeviceLocation();

                        if (deviceLocation != null && mounted) {
                          setState(() {
                            _selectedLocation = deviceLocation;
                            _mapController.move(deviceLocation, 15);
                            _markers.clear();
                            _markers.add(_createMarker(deviceLocation));
                          });
                          _updateAddress(deviceLocation);
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not get current location')),
                          );
                        }
                      } else {
                        setState(() {
                          _addressController.clear();
                          _markers.clear();
                          _selectedLocation = null;
                        });
                      }
                    }:null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_isMobileService) ...[
              const Text(
                'Select Location on Map',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 300,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLocation ?? const latlng.LatLng(14.5995, 120.9842),
                    initialZoom: 15.0,
                    onTap: (tapPosition, latLng) {
                      _updateAddress(latLng);
                      _mapController.move(latLng, _mapController.camera.zoom);
                    },
                  ),
                  children: [
                    TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.app'
                    ),
                    MarkerLayer(
                      markers: _markers.cast<Marker>(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Selected Address',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  suffixIcon: _addressController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _addressController.clear();
                        _selectedLocation = null;
                        _markers.clear();
                      });
                    },
                  )
                      : null,
                ),
                readOnly: true,
                maxLines: null,
              ),
              const SizedBox(height: 24),
              const Text(
                'Select Rider',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: _isLoadingRiders
                    ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
                    : _availableRiders.isEmpty
                    ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No available riders',
                    style: TextStyle(color: Colors.red),
                  ),
                )
                    : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRiderId,
                    isExpanded: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    hint: const Text('Choose a rider'),
                    items: _availableRiders.map((rider) {
                      return DropdownMenuItem<String>(
                        value: rider['id'] as String,
                        child: Text(
                          '${rider['name']} (${rider['vehicle_type']} - ${rider['plate_number']})',
                        ),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      setState(() => _selectedRiderId = value);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (!_isMobileService) ...[
              const Text(
                'Select Branch',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              if (_isLoadingBranches)
                const CircularProgressIndicator(),
              if (!_isLoadingBranches)
                _branchOptionsData.isEmpty
                    ? const Text('No available branches', style: TextStyle(color: Colors.red))
                    : Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedBranchId,
                      isExpanded: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      hint: const Text('Choose branch location'),
                      items: _branchOptionsData.map((branch) {
                        return DropdownMenuItem<String>(
                          value: branch['id'] as String,
                          child: Text(
                            branch['name']?.toString() ?? 'Unnamed Branch',
                            style: const TextStyle(fontSize: 16),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        setState(() => _selectedBranchId = value);
                        _handleBranchSelection(value);
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
            const Text(
              'Select Service',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: _isLoadingServices
                  ? const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
                  : DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedService.isNotEmpty ? _selectedService : null,
                  isExpanded: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  items: _services.map((service) {
                    return DropdownMenuItem<String>(
                      value: service['name'] as String,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(service['name'] as String),
                          Text(
                            '₱${(service['price'] as num).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A73E8),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      final selected = _services.firstWhere(
                            (s) => s['name'] == newValue,
                        orElse: () => {},
                      );

                      if (selected.isNotEmpty) {
                        setState(() {
                          _selectedService = newValue;
                          _selectedServiceId = selected['id'] as String;
                        });
                      }
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            Visibility(
              visible: !_isMobileService && _selectedBranchId != null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Staff', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedStaffId,
                    items: _availableStaff.map((staff) {
                      return DropdownMenuItem<String>(
                        value: staff['id'],
                        child: Text('${staff['full_name']} (${staff['position']})'),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedStaffId = value),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    validator: (value) => value == null ? 'Please select staff' : null,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Select Date',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Color(0xFF1A73E8)),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Select Time',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
InkWell(
  onTap: _selectTime,
  child: Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey[300]!),
    ),
    child: Row(
      children: [
        const Icon(Icons.access_time, color: Color(0xFF1A73E8)),
        const SizedBox(width: 12),
        Text(
          _formatTimeOfDay(_selectedTime),
          style: const TextStyle(fontSize: 16),
        ),
      ],
    ),
  ),
),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vehicle Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                if (_isLoadingVehicles)
                  const CircularProgressIndicator()
                else if (_userVehicles.isNotEmpty)
                  Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedVehicleId,
                            isExpanded: true,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            hint: const Text('Select your vehicle'),
                            items: _userVehicles.map((vehicle) {
                              return DropdownMenuItem<String>(
                                value: vehicle['id'] as String,
                                child: Text(vehicle['plate_number']),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedVehicleId = value;
                                final selected = _userVehicles.firstWhere((v) => v['id'] == value);
                                _vehicleTypeController.text = selected['type'];
                                _plateNumberController.text = selected['plate_number'];
                                _vehicleModelController.text = selected['name'];
                                _vehicleColorController.text = selected['color'];
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  )
                else
                  Column(
                    children: [
                      TextField(
                        controller: _plateNumberController,
                        decoration: InputDecoration(
                          labelText: 'Plate Number',
                          hintText: 'e.g., ABC-1234',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _vehicleModelController,
                              decoration: InputDecoration(
                                labelText: 'Vehicle Model',
                                hintText: 'e.g., Toyota Vios',
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _vehicleColorController,
                              decoration: InputDecoration(
                                labelText: 'Vehicle Color',
                                hintText: 'e.g., Black',
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _vehicleTypeController,
                        decoration: InputDecoration(
                          labelText: 'Vehicle Type',
                          hintText: 'e.g., Sedan, SUV, Van',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Payment Method',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: _paymentMethods.map((method) {
                  return RadioListTile<String>(
                    title: Row(
                      children: [
                        Icon(
                          method == 'Cash' ? Icons.money : 
                          method == 'Bank Transfer' ? Icons.account_balance : 
                          Icons.smartphone,
                          color: const Color(0xFF1A73E8),
                        ),
                        const SizedBox(width: 12),
                        Text(method),
                      ],
                    ),
                    value: method,
                    groupValue: _selectedPaymentMethod,
                    activeColor: const Color(0xFF1A73E8),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() {
                          _selectedPaymentMethod = value;
                        });
                      }
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Additional Instructions (Optional)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _instructionsController,
              decoration: InputDecoration(
                hintText: 'Any special requests or notes',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Booking Summary',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow('Service Type:', _selectedService),
                  _buildSummaryRow(
                    'Date & Time:',
                    '${DateFormat('MMM d, yyyy').format(_selectedDate)} at ${_formatTimeOfDay(_selectedTime)}',
                  ),
                  _buildSummaryRow(
                    'Location:',
                    _isMobileService
                        ? (_addressController.text.isNotEmpty
                        ? (_addressController.text.length > 15
                        ? '${_addressController.text.substring(0, 18)}...'
                        : _addressController.text)
                        : "Mobile Service - No address selected")
                        : (() {
                      final branchName = _branchOptionsData.firstWhere(
                            (b) => b['id'] == _selectedBranchId,
                        orElse: () => {'name': 'No branch selected'},
                      )['name'] ?? 'No branch selected';
                      return branchName.length > 15 ? '${branchName.substring(0, 18)}...' : branchName;
                    })(),
                  ),
                  _buildSummaryRow('Vehicle:', _vehicleModelController.text),
                  _buildSummaryRow('Payment Method:', _selectedPaymentMethod),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Price:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _services.isNotEmpty
                            ? '₱${(_services.firstWhere(
                              (s) => s['name'] == _selectedService,
                          orElse: () => {'price': 0.0},
                        )['price'] as num).toStringAsFixed(2)}'
                            : 'Loading...',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF1A73E8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _validateAndSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A73E8),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Proceed with Booking',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
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

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
  void _showBookingConfirmation() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Column(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 60),
                SizedBox(height: 16),
                Text(
                  'Booking Confirmed!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Your appointment has been scheduled for ${DateFormat('MMM d').format(_selectedDate)} at ${_formatTimeOfDay(_selectedTime)}.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'You will receive a confirmation message shortly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }
}
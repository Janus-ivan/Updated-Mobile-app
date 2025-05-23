import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../components/CustomBottomNavBar.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  int _selectedIndex = 2;
  late TabController _tabController;
  List<Map<String, dynamic>> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadServices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    try {
      final response = await _supabase
          .from('services')
          .select('*')
          .order('created_at', ascending: true);

      setState(() {
        _services = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
  List<Map<String, dynamic>> _getServicesByType(String type) {
    return _services.where((s) => s['service_type'] == type).toList();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildServiceTab('car_wash'),
                _buildServiceTab('detailing'),
                _buildServiceTab('coating'),
                _buildServiceTab('maintenance'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _handleNavTap,
      ),
    );
  }
  void _handleNavTap(int index) {
    setState(() => _selectedIndex = index);
    final routes = ['/dashboard', '/bookings', '/services', '/profile'];
    if (index < routes.length) Navigator.pushNamed(context, routes[index]);
  }

  FloatingActionButton _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () => Navigator.pushNamed(context, '/booking'),
      backgroundColor: const Color(0xFF1A73E8),
      icon: const Icon(Icons.add),
      label: const Text('Book Now'),
    );
  }
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'M Speed Services',
        style: TextStyle(
          color: Color(0xFF1A73E8),
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      bottom: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF1A73E8),
        unselectedLabelColor: Colors.grey,
        indicatorColor: const Color(0xFF1A73E8),
        tabs: const [
          Tab(text: 'Car Wash'),
          Tab(text: 'Detailing'),
          Tab(text: 'Coating'),
          Tab(text: 'Maintenance'),
        ],
      ),
    );
  }

  Widget _buildServiceTab(String serviceType) {
    final services = _getServicesByType(serviceType);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ...services.map((service) => serviceType == 'car_wash'
              ? _buildPackageCard(service)
              : serviceType == 'maintenance'
              ? _buildMaintenanceCard(service)
              : _buildServiceCard(service)),
        ],
      ),
    );
  }

  Widget _buildPackageCard(Map<String, dynamic> service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A73E8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    service['name'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                _buildPriceChip(service),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPriceGrid(service),
                const SizedBox(height: 16),
                _buildServiceInclusions(service),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceGrid(Map<String, dynamic> service) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildPriceColumn('S', service['price_s']),
        _buildPriceColumn('M', service['price_m']),
        _buildPriceColumn('L', service['price_l']),
        _buildPriceColumn('XL', service['price_xl']),
      ],
    );
  }

  Widget _buildServiceInclusions(Map<String, dynamic> service) {
    final inclusions = List<String>.from(service['inclusions'] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Services included:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: inclusions
              .map((inclusion) => Chip(
            label: Text(inclusion),
          ))
              .toList(),
        ),
      ],
    );
  }


  Widget _buildPriceChip(Map<String, dynamic> service) {
    if (service['is_price_upon_assessment'] == true) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Inquire',
          style: TextStyle(
            color: Color(0xFF1A73E8),
          ),
        ),
      );
    }

    return Text(
      'From ₱${service['price_s']?.toStringAsFixed(0) ?? '0'}',
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
  }


  Widget _buildPriceColumn(String size, dynamic price) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              size,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '₱${(price as num? ?? 0).toInt()}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    Map<String, dynamic> prices = service['prices'] ?? {};
    
    bool isPriceUponAssessment =
        service['note'] != null &&
        service['note'].toString().contains('assessment');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.local_car_wash,
                    color: Colors.blue[800],
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (service['description'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          service['description'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      if (service['duration'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          service['duration'],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1A73E8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (service['note'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          service['note'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
            ),
            child:
                isPriceUponAssessment
                    ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Price upon assessment',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/booking');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A73E8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                          ),
                          child: const Text('Inquire'),
                        ),
                      ],
                    )
                    : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _buildPriceGrid(service),
                            const SizedBox(height: 16),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/booking');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A73E8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                          ),
                          child: const Text('Select'),
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizePrice(String size, int price) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                size,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            price > 0 ? '₱${price.toString()}' : '-',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceCard(Map<String, dynamic> service) {
    double price = (service['price'] as num).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1A73E8),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    service['name'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '₱${price.toInt()}',
                    style: const TextStyle(
                      color: Color(0xFF1A73E8),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service['description'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                if (service['note'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    service['note'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (service['inclusions'] != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Inclusions:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (service['inclusions'] as List).map<Widget>((inclusion) {
                      return Chip(
                        backgroundColor: Colors.grey[100],
                        label: Text(
                          inclusion,
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Fixed price for all vehicle sizes',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/booking');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: const Text('Book Now'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

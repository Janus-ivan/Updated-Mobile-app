import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class StaffDirectoryScreen extends StatefulWidget {
  const StaffDirectoryScreen({super.key});

  @override
  State<StaffDirectoryScreen> createState() => _StaffDirectoryScreenState();
}

class _StaffDirectoryScreenState extends State<StaffDirectoryScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String _searchQuery = '';
  String _selectedBranch = 'All';
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _staffMembers = [];

  @override
  void initState() {
    super.initState();
    _selectedBranch = 'all';
    _loadData();
  }

  Future<void> _loadData() async {
    await _fetchBranches();
    await _fetchStaff();
  }

  Future<void> _fetchStaff() async {
    var query = _supabase
        .from('staff')
        .select('*, branch:branches!staff_branch_id_fkey(id, name, status)');

    if (_selectedBranch != 'all') {
      query = query.eq('branch_id', _selectedBranch);
    }

    if (_searchQuery.isNotEmpty) {
      query = query.or(
        'full_name.ilike.%${_searchQuery}%,position.ilike.%${_searchQuery}%',
      );
    }

    final response = await query;
    setState(() => _staffMembers = List<Map<String, dynamic>>.from(response));
  }

  Future<void> _fetchBranches() async {
    final response = await _supabase
        .from('branches')
        .select('id, name')
        .eq('status', 'active')
        .order('name', ascending: true);

    setState(() {
      _branches = List<Map<String, dynamic>>.from(response);
    });
  }
  void _showStaffDetails(Map<String, dynamic> staff) {
    final specialties = (staff['specialties'] as List<dynamic>?)?.cast<String>() ?? [];
    final joinDate = staff['join_date'] != null
        ? DateFormat('MMM y').format(DateTime.parse(staff['join_date']))
        : 'N/A';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundImage: staff['photo_url'] != null && staff['photo_url'].isNotEmpty
                    ? NetworkImage(staff['photo_url'])
                    : const AssetImage('assets/default_avatar.png') as ImageProvider,
              ),
            ),
            const SizedBox(height: 20),
            _buildDetailRow('Name', staff['full_name']),
            _buildDetailRow('Position', staff['position']),
            _buildDetailRow('Branch', staff['branch']?['name'] ?? 'No branch assigned'),
            _buildDetailRow('Status', staff['status']),
            _buildDetailRow('Rating', staff['rating'] != null
                ? '★ ${(staff['rating'] as num).toStringAsFixed(1)}'
                : 'No ratings'),
            _buildDetailRow('Experience', staff['experience'] ?? 'Not specified'),
            _buildDetailRow('Completed Washes', '${staff['completed_washes']}'),
            _buildDetailRow('Join Date', joinDate),
            _buildDetailRow('Contact', staff['phone']),
            _buildDetailRow('Email', staff['email']),
            const SizedBox(height: 16),
            const Text('Specialties:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: specialties.isNotEmpty
                  ? specialties.map((spec) => Chip(label: Text(spec))).toList()
                  : [const Text('No specialties listed')],
            ),
            const SizedBox(height: 16),
            const Text('Bio:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(staff['bio']?.isNotEmpty == true
                ? staff['bio']
                : 'No bio available'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value.toString())),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Staff Directory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              value: _selectedBranch,
              items: [
                const DropdownMenuItem(
                  value: 'all',
                  child: Text('All Branches'),
                ),
                ..._branches.map((branch) => DropdownMenuItem(
                  value: branch['id'] as String,
                  child: Text(branch['name'] as String),
                ))
              ],
              onChanged: (value) {
                setState(() => _selectedBranch = value ?? 'all');
                _fetchStaff();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (value) {
                _searchQuery = value;
                _fetchStaff();
              },
              decoration: InputDecoration(
                hintText: 'Search by name or position...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _staffMembers.length,
              itemBuilder: (context, index) {
                final staff = _staffMembers[index];
                final branchName = staff['branch']?['name'] ?? 'No branch assigned';
                final rating = staff['rating'] != null
                    ? (staff['rating'] as num).toStringAsFixed(1)
                    : '–';
                final joinDate = staff['join_date'] != null
                    ? DateFormat('MMM y').format(DateTime.parse(staff['join_date']))
                    : 'N/A';

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 30,
                      backgroundImage: staff['photo_url'] != null && staff['photo_url'].isNotEmpty
                          ? NetworkImage(staff['photo_url'])
                          : const AssetImage('assets/default_avatar.png') as ImageProvider,
                    ),
                    title: Text(staff['full_name']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(staff['position']),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          children: [
                            Chip(
                              label: Text('★ $rating'),
                              backgroundColor: Colors.amber[100],
                            ),
                            Chip(
                              label: Text(branchName),
                              backgroundColor: Colors.blue[50],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${staff['completed_washes']} washes • Joined $joinDate',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => _showStaffDetails(staff),
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
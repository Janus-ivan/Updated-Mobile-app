import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BranchesScreen extends StatefulWidget {
  const BranchesScreen({super.key});

  @override
  State<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends State<BranchesScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _branches = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final response = await _supabase
          .from('branches')
          .select('''id, name, address, status, hours, phone''')
          .order('name', ascending: true);

      setState(() {
        _branches = response;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print("Error loading branches: $e");
      }
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading branches: $e')),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredBranches {
    return _branches.where((branch) {
      final name = branch['name']?.toLowerCase() ?? '';
      final address = branch['address']?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || address.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Our Branches'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBranches,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search branches...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildBranchesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchesList() {
    if (_filteredBranches.isEmpty) {
      return const Center(child: Text('No branches found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredBranches.length,
      itemBuilder: (context, index) => _buildBranchCard(_filteredBranches[index]),
    );
  }

  Widget _buildBranchCard(Map<String, dynamic> branch) {
    Color statusColor;
    switch (branch['status']) {
      case 'open':
        statusColor = Colors.green;
        break;
      case 'closed':
        statusColor = Colors.red;
        break;
      case 'maintenance':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.store, color: Color(0xFF1A73E8)),
        ),
        title: Text(
          branch['name']?.toString() ?? 'Unknown Branch',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (branch['address']?.toString() ?? 'No address').length > 18
                  ? '${(branch['address']?.toString() ?? 'No address').substring(0, 18)}...'
                  : (branch['address']?.toString() ?? 'No address'),
            ),
            const SizedBox(height: 4),
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
                const SizedBox(width: 8),
                Text(
                  '${(branch['status']?.toString() ?? '').substring(0, (branch['status']?.toString() ?? '').length > 18 ? 18 : (branch['status']?.toString() ?? '').length)} • ${(branch['hours']?.toString() ?? '').substring(0, (branch['hours']?.toString() ?? '').length > 18 ? 18 : (branch['hours']?.toString() ?? '').length)}',
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showBranchDetails(branch),
      ),
    );
  }

  void _showBranchDetails(Map<String, dynamic> branch) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(branch['name']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Address: ${branch['address']}'),
            Text('Phone: ${branch['phone']}'),
            Text('Hours: ${branch['hours']}'),
            Text('Status: ${branch['status']}'),
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
}
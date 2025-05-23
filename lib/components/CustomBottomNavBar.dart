import 'package:flutter/material.dart';
import '../auth/auth_service.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool showBackButton;

  const CustomBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    this.showBackButton = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final routes = ['/dashboard', '/bookings', '/services', '/profile'];

    return BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: const Color(0xFF1A73E8),
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      onTap: (index) async {
        if (index == 0) {
          // If going to dashboard, remove all routes and make it the only one
          Navigator.pushNamedAndRemoveUntil(context, routes[index], (route) => false);
          return;
        }
        
        final authService = AuthService();
        if (!authService.isLoggedIn()) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in to access this feature'),
            ),
          );
          return;
        } else {
          Navigator.pushNamed(context, routes[index]);
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Bookings'),
        BottomNavigationBarItem(icon: Icon(Icons.local_car_wash), label: 'Services'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}
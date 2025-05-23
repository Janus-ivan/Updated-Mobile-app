import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dashboard_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  late AnimationController _buttonController;
  late Animation<double> _buttonScaleAnimation;
  bool _isButtonPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(
      begin: 0,
      end: 10,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _rotateAnimation = Tween<double>(
      begin: -0.03,
      end: 0.03,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _buttonController.dispose();
    super.dispose();
  }
  void _handleButtonPress() async {
    setState(() {
      _isButtonPressed = true;
    });

    _buttonController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder:
              (context, animation, secondaryAnimation) =>
                  const DashboardScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;

            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A73E8), Color(0xFF0D47A1)],
              ),
            ),
          ),
          Positioned(top: 80, left: 40, child: _buildAnimatedCircle(70, 0.7)),
          Positioned(top: 50, right: 60, child: _buildAnimatedCircle(40, 0.5)),
          Positioned(
            bottom: 200,
            left: 30,
            child: _buildAnimatedCircle(60, 0.6),
          ),
          Positioned(
            bottom: 140,
            right: 50,
            child: _buildAnimatedCircle(50, 0.4),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Text(
                        "Experience the",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        "Discovery",
                        style: TextStyle(
                          color: Color(0xFFFFAB40),
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),
                _buildBubblyText(),
                const SizedBox(height: 20),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(
                    left: 40,
                    right: 40,
                    bottom: 30,
                  ),
                  child: AnimatedBuilder(
                    animation: _buttonScaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _buttonScaleAnimation.value,
                        child: Container(
                          height: 50,
                          width: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFAB40).withOpacity(0.4),
                                blurRadius: _isButtonPressed ? 5 : 10,
                                spreadRadius: _isButtonPressed ? 0 : 2,
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed:
                                _isButtonPressed ? null : _handleButtonPress,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFAB40),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              elevation: _isButtonPressed ? 0 : 5,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "GET STARTED",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  transform: Matrix4.translationValues(
                                    _isButtonPressed ? 10.0 : 0.0,
                                    0.0,
                                    0.0,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubblyText() {
    final text = "M Speed On The Go!";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(text.length, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final delayedValue = (_controller.value - (index * 0.05)) % 1.0;
              final delayedAnimation = delayedValue < 0 ? 0.0 : delayedValue;

              return Transform.scale(
                scale: 1.0 + (math.sin(delayedAnimation * math.pi) * 0.3),
                child: Text(
                  text[index],
                  style: TextStyle(
                    color: Color(0xFFFFAB40),
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 2,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildAnimatedCircle(double size, double opacity) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.9 + (_controller.value * 0.2),
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}
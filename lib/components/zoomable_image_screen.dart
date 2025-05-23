import 'package:flutter/material.dart';

class ZoomableImageScreen extends StatelessWidget {
  final String imagePath;

  const ZoomableImageScreen({Key? key, required this.imagePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          boundaryMargin: const EdgeInsets.all(20.0),
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {

              return const Center(
                child: Text(
                  'Image not found',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
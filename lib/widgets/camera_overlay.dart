// File: lib/widgets/camera_overlay.dart

import 'package:flutter/material.dart';

class EyeCameraOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. The Darkened Background (Focus effect)
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.5), 
            BlendMode.srcOut
          ),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              // The "Safe Area" Cutout
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 300,
                  height: 120, // Wide enough for both eyes
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. The Green Guide Border
        Align(
          alignment: Alignment.center,
          child: Container(
            width: 300,
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.greenAccent, width: 3),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),

        // 3. Orientation Labels (Handling Mirror Mode)
        // In selfie mode, the right side of the screen is the user's LEFT eye.
        Positioned(
          top: MediaQuery.of(context).size.height / 2 - 80, 
          left: 40,
          child: Text("YOUR RIGHT EYE", 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height / 2 - 80, 
          right: 40,
          child: Text("YOUR LEFT EYE", 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
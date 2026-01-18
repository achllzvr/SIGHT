# SIGHT: Feasibility Prototype
**System for Integrated Global Eye Health Tracking**

> **Capstone Project 2026** > *Status: Technical Feasibility Verified (Modules A, B, C)*

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter) ![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android) ![AI](https://img.shields.io/badge/AI-TensorFlow%20Lite-FF6F00?logo=tensorflow)

## 📋 Overview

**SIGHT** is a mobile application designed to democratize eye health monitoring using standard smartphone hardware. This repository contains the **Feasibility Prototype**, a "Lab" application built to validate the core technical risks of the project before full-scale development.

The prototype proves that mid-range Android devices (specifically tested on **Samsung Galaxy A26**, Android 16) can perform real-time computer vision and offline AI inference without external sensors like LiDAR.

---

## 🔬 Feasibility Modules

The app is divided into three isolated test environments:

### **Module A: Distance Monitor (Vision-Based)**
* **Goal:** Calculate user-to-screen distance using a standard 2D front camera.
* **Tech:** Google ML Kit (Face Mesh) + Triangle Similarity Principle.
* **Result:** Accurate distance estimation (±2cm) calibrated at 30cm. Alerts user when "Harmful Zone" (<30cm) is breached.

### **Module B: Blink Rate Analysis**
* **Goal:** Detect blink frequency in real-time to monitor eye fatigue.
* **Tech:** Eye Aspect Ratio (EAR) calculation via Facial Landmarks.
* **Result:** Successfully distinguishes between "Looking Down" and "Blinking" using probability thresholds (Open > 0.5, Closed < 0.2).

### **Module C: AI Symptom Screening**
* **Goal:** execute offline neural network inference on the device.
* **Tech:** TensorFlow Lite (Quantized MobileNet V1).
* **Result:** ~100ms inference time on standard CPU. Successfully processes raw image bytes, resizes to 224x224, and outputs classification labels locally.

---

## 🛠️ Technical Stack

* **Framework:** Flutter (Dart)
* **Computer Vision:** `google_mlkit_face_detection`
* **AI Inference:** `tflite_flutter` (TensorFlow Lite)
* **Camera:** `camera` (CameraX)
* **Utilities:** `image_picker`, `permission_handler`, `image` (processing)

---

## 📱 Device Compatibility & Fixes

This prototype was engineered to overcome specific hardware fragmentation issues found in mid-range Android devices (Samsung Exynos).

### **Key Patches Implemented:**
1.  **Samsung Camera Padding Fix:**
    * *Issue:* Raw camera streams on Samsung devices add invisible padding bytes, causing AI model crashes (Input Size Mismatch).
    * *Fix:* Forced `ImageFormatGroup.nv21` and wrote a custom byte-buffer concatenator to strip padding before inference.
2.  **Impeller Rendering Engine:**
    * *Issue:* The new Flutter Impeller engine causes camera preview glitches on some Exynos chips.
    * *Fix:* Run with `--no-enable-impeller` flag recommended for debugging.
3.  **TFLite Quantization:**
    * *Issue:* Type mismatch between Double (0.0) inputs and Uint8 (0) model requirements.
    * *Fix:* Full quantization-aware preprocessing pipeline implemented.

---

## 🔮 Future Roadmap

* [ ] **Custom Model Training:** Replace MobileNet with a custom Eye Disease Detection model.
* [ ] **User Profiles:** Save eye health data over time.
* [ ] **Gamification:** Rewards for maintaining healthy eye habits.
* [ ] **Background Service:** Run distance monitoring while other apps are open.

---

## 📄 License & Credits

**Author:** Achilles Vonn Rabina
**Institution:** National University - Lipa
**Project:** Capstone 2026  

This project is for educational and research purposes.

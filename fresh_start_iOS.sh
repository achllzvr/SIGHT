#!/bin/bash

# Stop the script if any command fails
set -e

echo "🚀 SIGHT: Starting Nuclear Reset Sequence..."

# 1. Flutter Clean
echo "🧹 Step 1: Cleaning Flutter Build..."
flutter clean

# 2. Pub Get
echo "📦 Step 2: Fetching Dart Dependencies..."
flutter pub get

# 3. iOS Pod Reset (The crucial part for your Mesh/AI issues)
echo "🍎 Step 3: Re-linking iOS Native Binaries..."
cd ios
rm -rf Pods
rm Podfile.lock
pod install --repo-update
cd ..

echo "✅ Build Environment Reset Complete."
echo "▶️  Step 4: Launching App..."

# 4. Run the App
flutter run -d "Achilles"
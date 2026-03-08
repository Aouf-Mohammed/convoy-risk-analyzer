#!/bin/bash
cd frontend
flutter clean
flutter pub get
flutter analyze
if [ $? -ne 0 ]; then
    echo "✗ FLUTTER ANALYZE FAILED. Stopping."
    exit 1
fi
flutter test test/unit/
if [ $? -ne 0 ]; then
    echo "✗ FLUTTER UNIT TESTS FAILED. Stopping."
    exit 1
fi
flutter run -d chrome --web-port 3000 || flutter run

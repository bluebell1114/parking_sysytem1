import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyB2fr0MbQYyrJINgKO_si3BU1pVTUc-13Q",
    authDomain: "parking-3922f.firebaseapp.com",
    projectId: "parking-3922f",
    storageBucket: "parking-3922f.firebasestorage.app",
    messagingSenderId: "214141385001",
    appId: "1:214141385001:web:5ca3b53845203af3551f38",
    measurementId: "G-0H5EKX5CSV",
  );
}

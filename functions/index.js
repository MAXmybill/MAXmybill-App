const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Native Firebase Phone Authentication handles all OTPs directly on device.
// Custom SMS providers (Twilio, Didit, etc.) have been completely removed.

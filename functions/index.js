const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();

const TWILIO_ACCOUNT_SID = "ACa5cc4defa65eed6491dfdda0701a95bd";
const TWILIO_AUTH_TOKEN = "44e9af4ab65e63925e9aadf77606eb99";
const TWILIO_FROM_NUMBER = "+16895296541";

exports.sendTwilioOtp = functions.https.onCall(async (data, context) => {
    const phone = data.phone;
    if (!phone) {
        throw new functions.https.HttpsError('invalid-argument', 'Phone number is required.');
    }

    try {
        // Generate a 6-digit random OTP
        const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
        const messageBody = `Your MaxMyBill verification code is: ${otpCode}`;

        // Save OTP to Firestore for verification later
        await admin.firestore().collection('otp_codes').doc(phone).set({
            code: otpCode,
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // Send SMS via Twilio
        const twilioUrl = `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Messages.json`;
        const authHeader = `Basic ${Buffer.from(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`).toString('base64')}`;

        const params = new URLSearchParams();
        params.append('To', phone);
        params.append('From', TWILIO_FROM_NUMBER);
        params.append('Body', messageBody);

        const response = await axios.post(twilioUrl, params, {
            headers: {
                'Authorization': authHeader,
                'Content-Type': 'application/x-www-form-urlencoded'
            }
        });
        
        return { success: true, sid: response.data.sid };
    } catch (error) {
        console.error("Twilio send OTP error:", error.response?.data || error.message);
        throw new functions.https.HttpsError('internal', 'Failed to send OTP via Twilio.');
    }
});

exports.verifyTwilioOtp = functions.https.onCall(async (data, context) => {
    const phone = data.phone;
    const code = data.code;

    if (!phone || !code) {
        throw new functions.https.HttpsError('invalid-argument', 'Phone number and code are required.');
    }

    try {
        // Fetch saved OTP from Firestore
        const docRef = admin.firestore().collection('otp_codes').doc(phone);
        const docSnap = await docRef.get();

        if (!docSnap.exists) {
            throw new functions.https.HttpsError('permission-denied', 'OTP expired or not found.');
        }

        const savedData = docSnap.data();
        if (savedData.code !== code) {
            throw new functions.https.HttpsError('permission-denied', 'Invalid OTP code.');
        }

        // Delete the OTP code so it can't be reused
        await docRef.delete();

        // OTP verified! Mint a Firebase Custom Token for this phone number.
        let uid = phone;
        try {
            const userRecord = await admin.auth().getUserByPhoneNumber(phone);
            uid = userRecord.uid;
        } catch (e) {
            // User doesn't exist, create one
            const newUser = await admin.auth().createUser({
                phoneNumber: phone
            });
            uid = newUser.uid;
        }

        const customToken = await admin.auth().createCustomToken(uid);

        return {
            success: true,
            customToken: customToken
        };
    } catch (error) {
        console.error("Twilio verify OTP error:", error);
        throw new functions.https.HttpsError('internal', error.message || 'Failed to verify OTP.');
    }
});

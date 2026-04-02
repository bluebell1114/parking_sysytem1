// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getAnalytics } from "firebase/analytics";
// TODO: Add SDKs for Firebase products that you want to use
// https://firebase.google.com/docs/web/setup#available-libraries

// Your web app's Firebase configuration
// For Firebase JS SDK v7.20.0 and later, measurementId is optional
const firebaseConfig = {
apiKey: "AIzaSyArWSOkNMRgn2D191YVv7zrKY0SBR7IJi8",
authDomain: "greenpark-admin.firebaseapp.com",
projectId: "greenpark-admin",
storageBucket: "greenpark-admin.firebasestorage.app",
messagingSenderId: "1078223438500",
appId: "1:1078223438500:web:1fa440ad6109aacdac9c31",
measurementId: "G-S38K459PMZ"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const analytics = getAnalytics(app);
var admin = require("firebase-admin");

var serviceAccount = require("path/to/serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
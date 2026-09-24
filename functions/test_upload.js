const { initializeApp } = require("firebase/app");
const { getFunctions, httpsCallable } = require("firebase/functions");
const fs = require('fs');

// Initialize Firebase (dummy config is fine since we use emulator or we just need the functions endpoint)
const app = initializeApp({
  projectId: "calligro-bcfb2",
});

// Create a dummy video file
fs.writeFileSync("dummy.mp4", "fake video content");

// We can't easily call the real Firebase function without auth...

const https = require('https');
const fs = require('fs');
const path = require('path');

const API_KEY = "sk_2d4bbbf46c87ecf1f7d31529a94b33428566de47cf760656";
const VOICE_ID = "pNInz6obpgDQGcFmaJgB"; // Adam

const text = "أَهْلاً بِكَ كَمُعَلِّمٍ فِي مَنَصَّةِ كَالِيجْرُو. دَعْنَا نُوَضِّحَ لَكَ كَيْفَ تَعْمَلُ خُطْوَةً بِخُطْوَةٍ.";

async function generateAudio() {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({
      text: text,
      model_id: "eleven_multilingual_v2",
      voice_settings: {
        stability: 0.5,
        similarity_boost: 0.75
      }
    });

    const options = {
      hostname: 'api.elevenlabs.io',
      path: `/v1/text-to-speech/${VOICE_ID}`,
      method: 'POST',
      headers: {
        'Accept': 'audio/mpeg',
        'xi-api-key': API_KEY,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data)
      }
    };

    const req = https.request(options, (res) => {
      if (res.statusCode !== 200) {
        console.error(`Error: Status Code ${res.statusCode}`);
        res.on('data', d => process.stdout.write(d));
        reject(new Error(`Status ${res.statusCode}`));
        return;
      }
      
      const file = fs.createWriteStream(path.join(__dirname, 'public', 'audio', `eleven_vo_1.mp3`));
      res.pipe(file);
      file.on('finish', () => {
        console.log(`Generated eleven_vo_1.mp3 successfully.`);
        file.close(resolve);
      });
    });

    req.on('error', (e) => {
      console.error(`Request error: ${e}`);
      reject(e);
    });

    req.write(data);
    req.end();
  });
}

generateAudio();

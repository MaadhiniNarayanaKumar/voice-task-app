const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {GoogleAuth} = require('google-auth-library');

admin.initializeApp();

function cors(res) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
}

function geminiKey() {
  return process.env.GEMINI_API_KEY || process.env.GCP_API_KEY || '';
}

async function requireAuth(req, res) {
  const header = req.get('Authorization') || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  if (!token) {
    res.status(401).json({error: 'unauthenticated'});
    return null;
  }
  try {
    return await admin.auth().verifyIdToken(token);
  } catch (error) {
    res.status(401).json({error: 'unauthenticated'});
    return null;
  }
}

exports.transcribeSpeech = functions.https.onRequest(async (req, res) => {
  cors(res);
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).send('POST only');
    return;
  }
  if (!(await requireAuth(req, res))) return;

  try {
    const audioContent = req.body.audioContent;
    if (!audioContent) {
      res.status(400).json({error: 'audioContent required'});
      return;
    }

    const auth = new GoogleAuth({
      scopes: ['https://www.googleapis.com/auth/cloud-platform'],
    });
    const client = await auth.getClient();
    const token = await client.getAccessToken();
    const response = await fetch(
      'https://speech.googleapis.com/v1/speech:recognize',
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token.token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          config: {
            encoding: 'LINEAR16',
            sampleRateHertz: 16000,
            languageCode: 'en-US',
            enableAutomaticPunctuation: true,
          },
          audio: {content: audioContent},
        }),
      },
    );
    const data = await response.json();
    if (!response.ok) {
      res.status(response.status).json(data);
      return;
    }
    const transcript = (data.results || [])
      .map((result) => (result.alternatives && result.alternatives[0].transcript) || '')
      .join(' ')
      .trim();
    res.json({transcript});
  } catch (error) {
    res.status(500).json({error: String(error)});
  }
});

exports.enrichTask = functions.https.onRequest(async (req, res) => {
  cors(res);
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).send('POST only');
    return;
  }
  if (!(await requireAuth(req, res))) return;

  try {
    const rawText = (req.body.rawText || '').trim();
    if (!rawText) {
      res.status(400).json({error: 'rawText required'});
      return;
    }
    const key = geminiKey();
    if (!key) {
      res.status(500).json({error: 'GEMINI_API_KEY not set on the function'});
      return;
    }

    const now = new Date().toISOString();
    const prompt = `You extract structured task info from spoken voice input.
Current date/time: ${now}
Return ONLY valid JSON in this exact shape:
{"title": "short imperative title under 8 words", "dueDate": "ISO 8601 datetime or null", "priority": "low" | "medium" | "high"}
Voice input: "${rawText}"`;

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${key}`,
      {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({
          contents: [{parts: [{text: prompt}]}],
          generationConfig: {responseMimeType: 'application/json'},
        }),
      },
    );
    const data = await response.json();
    if (!response.ok) {
      res.status(response.status).json(data);
      return;
    }
    const text = data.candidates[0].content.parts[0].text
      .replace(/```json|```/g, '')
      .trim();
    res.json(JSON.parse(text));
  } catch (error) {
    res.status(500).json({error: String(error)});
  }
});

require('dotenv').config();
const { generateVoiceToken } = require('./src/services/livekitService');

async function test() {
  try {
    const token = await generateVoiceToken('TEST_ROOM', 'test_identity', 'Test User');
    console.log('Token payload verified:');
    const base64Url = token.split('.')[1];
    const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
    const jsonPayload = decodeURIComponent(atob(base64).split('').map(function(c) {
        return '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2);
    }).join(''));
    console.log(jsonPayload);
  } catch (error) {
    console.error('Token generation failed:', error);
  }
}

test();

const { generateVoiceToken } = require('./src/services/livekitService');
require('dotenv').config();

async function test() {
  try {
    const token = await generateVoiceToken('TEST_ROOM', 'test_identity', 'Test User');
    console.log('Token successfully generated:');
    console.log(token);
  } catch (error) {
    console.error('Token generation failed:', error);
  }
}

test();

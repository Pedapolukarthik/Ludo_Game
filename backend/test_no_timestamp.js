const jwt = require('jsonwebtoken');
require('dotenv').config();

const apiKey = process.env.LIVEKIT_API_KEY;
const apiSecret = process.env.LIVEKIT_API_SECRET;

function test() {
  const payload = {
    iss: apiKey,
    sub: 'test_user',
    name: 'Test Name',
    video: {
      roomJoin: true,
      room: 'test_room',
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
      audio: true,
      video: false,
      screenshare: false,
    },
    nbf: 1704067200, // Jan 1, 2024
    exp: 1893456000  // Jan 1, 2030
  };

  const token = jwt.sign(payload, apiSecret, {
    algorithm: 'HS256',
    noTimestamp: true
  });

  console.log('Manually Signed Token (noTimestamp):', token);
  const decoded = jwt.decode(token, { complete: true });
  console.log('Decoded Payload:', JSON.stringify(decoded.payload));
}

test();

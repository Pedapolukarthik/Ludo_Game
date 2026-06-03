const { AccessToken } = require('livekit-server-sdk');
require('dotenv').config();
const jwt = require('jsonwebtoken');

const apiKey = process.env.LIVEKIT_API_KEY;
const apiSecret = process.env.LIVEKIT_API_SECRET;

async function test() {
  const at = new AccessToken(apiKey, apiSecret, {
    identity: 'test_user',
    name: 'Test Name',
  });

  at.addGrant({
    roomJoin: true,
    room: 'test_room',
    canPublish: true,
    canSubscribe: true,
    canPublishData: true,
    audio: true,
    video: false,
    screenshare: false,
  });

  const token = await at.toJwt();
  console.log('Original SDK Token:', token);
  const decoded = jwt.decode(token, { complete: true });
  console.log('Decoded Header:', decoded.header);
  console.log('Decoded Payload:', JSON.stringify(decoded.payload));
}

test();

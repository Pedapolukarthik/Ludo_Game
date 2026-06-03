const { RoomServiceClient } = require('livekit-server-sdk');
require('dotenv').config();

const apiKey = process.env.LIVEKIT_API_KEY;
const apiSecret = process.env.LIVEKIT_API_SECRET;
const host = process.env.LIVEKIT_HOST;

console.log('Testing LiveKit Connection...');
console.log('Host:', host);
console.log('API Key:', apiKey ? 'Present' : 'Missing');
console.log('API Secret:', apiSecret ? 'Present' : 'Missing');

if (!apiKey || !apiSecret || !host) {
  console.error('Error: Missing LiveKit configuration in .env');
  process.exit(1);
}

// Convert wss:// to https:// or http:// for the RoomServiceClient
const apiHost = host.replace('wss://', 'https://').replace('ws://', 'http://');
console.log('Normalized API Host for RoomServiceClient:', apiHost);

const svc = new RoomServiceClient(apiHost, apiKey, apiSecret);

async function test() {
  try {
    const rooms = await svc.listRooms();
    console.log('Connection Successful! Active Rooms:', rooms.length);
    rooms.forEach(r => console.log(`- Room: ${r.name}, Participants: ${r.numParticipants}`));
  } catch (error) {
    console.error('Connection Failed:', error.message);
  }
}

test();

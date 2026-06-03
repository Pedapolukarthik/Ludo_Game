const express = require('express');
const { protect } = require('../middlewares/authMiddleware');
const livekitConfig = require('../config/livekit');
const { generateVoiceToken } = require('../services/livekitService');

const router = express.Router();

/** Public health check — no secrets exposed */
router.get('/health', async (req, res) => {
  let credentialsValid = livekitConfig.credentialsValid;
  if (credentialsValid === null && livekitConfig.isConfigured) {
    credentialsValid = await livekitConfig.validateLiveKitCredentials();
  }

  res.json({
    success: true,
    configured: livekitConfig.isConfigured,
    credentialsValid: credentialsValid === true,
    wsUrl: livekitConfig.wsUrl,
    usingEnvCredentials: livekitConfig.usingEnvCredentials,
  });
});

/** REST fallback for voice token (same grants as Socket.IO) */
router.post('/token', protect, async (req, res) => {
  try {
    const roomCode = (req.body.roomCode || '').toString().trim().toUpperCase();
    if (!roomCode) {
      return res.status(400).json({ success: false, message: 'roomCode is required' });
    }

    if (!livekitConfig.isConfigured) {
      return res.status(503).json({
        success: false,
        message: 'LiveKit is not configured on the server',
      });
    }

    const { token, roomName, expiresIn } = await generateVoiceToken(
      roomCode,
      req.user._id.toString(),
      req.user.name
    );

    res.json({
      success: true,
      token,
      url: livekitConfig.wsUrl,
      roomName,
      expiresIn,
    });
  } catch (err) {
    console.error('[Voice API] Token error:', err.message);
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;

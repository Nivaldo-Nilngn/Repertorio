require('dotenv').config();
const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const { S3Client, PutObjectCommand, GetObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const ytDlp = require('yt-dlp-exec');
const crypto = require('crypto');

const app = express();
app.use(cors());
app.use(express.json());

// B2 (S3 API) Config
const b2Endpoint = process.env.B2_ENDPOINT || 'https://s3.us-east-005.backblazeb2.com';
const b2Bucket = process.env.B2_BUCKET || 'KordApp';

const s3Client = new S3Client({
  endpoint: b2Endpoint,
  region: 'us-east-005',
  credentials: {
    accessKeyId: process.env.B2_KEY_ID,
    secretAccessKey: process.env.B2_APPLICATION_KEY,
  },
});

app.post('/api/download', async (req, res) => {
  const { youtubeUrl } = req.body;
  if (!youtubeUrl) {
    return res.status(400).json({ error: 'YouTube URL is required' });
  }

  const tmpDir = path.join(__dirname, 'tmp');
  if (!fs.existsSync(tmpDir)) fs.mkdirSync(tmpDir);

  const fileId = crypto.randomBytes(8).toString('hex');
  const filename = `${fileId}.mp3`;
  const fileKey = `audio/${filename}`;
  const outputPath = path.join(tmpDir, filename);

  try {
    console.log(`Downloading audio from: ${youtubeUrl}`);
    
    const ytDlpArgs = {
      format: 'bestaudio',
      output: outputPath,
      noPlaylist: true,
      jsRuntimes: 'node',
    };
    
    if (fs.existsSync(path.join(__dirname, 'cookies.txt'))) {
      ytDlpArgs.cookies = path.join(__dirname, 'cookies.txt');
    }

    // Download using yt-dlp (best audio format, no ffmpeg needed)
    await ytDlp(youtubeUrl, ytDlpArgs);

    console.log('Download complete. Uploading to B2...');

    // Upload to B2
    const fileStream = fs.createReadStream(outputPath);
    const uploadParams = {
      Bucket: b2Bucket,
      Key: fileKey,
      Body: fileStream,
      ContentType: 'audio/mpeg',
    };

    await s3Client.send(new PutObjectCommand(uploadParams));

    console.log('Upload complete!');
    
    // Clean up local file
    fs.unlinkSync(outputPath);

    // Generate a Presigned URL (valid for 1 day) since bucket is Private
    const command = new GetObjectCommand({ Bucket: b2Bucket, Key: fileKey });
    const signedUrl = await getSignedUrl(s3Client, command, { expiresIn: 86400 });
    
    res.json({ success: true, url: signedUrl, id: fileId });

  } catch (error) {
    console.error('Error processing video:', error);
    if (fs.existsSync(outputPath)) fs.unlinkSync(outputPath);
    res.status(500).json({ error: 'Failed to process audio', details: error.message });
  }
});

// Endpoint to get a new signed URL for an existing file
app.get('/api/stream/:fileId', async (req, res) => {
  try {
    const fileKey = `audio/${req.params.fileId}.mp3`;
    const command = new GetObjectCommand({ Bucket: b2Bucket, Key: fileKey });
    const signedUrl = await getSignedUrl(s3Client, command, { expiresIn: 86400 });
    res.json({ success: true, url: signedUrl });
  } catch (error) {
    res.status(500).json({ error: 'Failed to generate URL' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Musicifras Backend running on port ${PORT}`);
  console.log('Make sure you have set B2_KEY_ID and B2_APPLICATION_KEY in .env file');
});

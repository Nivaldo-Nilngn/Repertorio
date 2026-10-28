require('dotenv').config();
const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const ytDlp = require('yt-dlp-exec');
const crypto = require('crypto');
const ytSearch = require('yt-search');

const app = express();
app.use(cors());
app.use(express.json());

const tmpDir = path.join(__dirname, 'tmp');
if (!fs.existsSync(tmpDir)) fs.mkdirSync(tmpDir);

// Serve the tmp directory statically
app.use('/audio', express.static(tmpDir));

app.post('/api/search', async (req, res) => {
  const { query } = req.body;
  if (!query) return res.status(400).json({ error: 'Query is required' });
  try {
    const r = await ytSearch(query);
    const videos = r.videos.slice(0, 10).map(v => ({
      title: v.title,
      author: v.author.name,
      url: v.url,
      thumbnail: v.thumbnail,
    }));
    res.json({ success: true, videos });
  } catch(e) {
    res.status(500).json({ error: 'Search failed' });
  }
});

app.post('/api/download', async (req, res) => {
  const { youtubeUrl } = req.body;
  if (!youtubeUrl) {
    return res.status(400).json({ error: 'YouTube URL is required' });
  }

  const fileId = crypto.randomBytes(8).toString('hex');
  const filename = `${fileId}.mp3`;
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

    // Download using yt-dlp
    await ytDlp(youtubeUrl, ytDlpArgs);

    console.log('Download complete!');
    
    // Return local URL
    const localUrl = `http://localhost:3000/audio/${filename}`;
    res.json({ success: true, url: localUrl, id: fileId });

  } catch (error) {
    console.error('Error processing video:', error);
    if (fs.existsSync(outputPath)) fs.unlinkSync(outputPath);
    res.status(500).json({ error: 'Failed to process audio', details: error.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Musicifras Backend running on port ${PORT}`);
});

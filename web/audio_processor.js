// Advanced Audio Player with Pitch Shifting using Tone.js
window.AdvancedAudioPlayerJS = {
  player: null,
  pitchShift: null,
  isInitialized: false,
  isPlaying: false,

  init: function (url, onLoad) {
    if (this.isInitialized) {
      this.player.dispose();
      this.pitchShift.dispose();
    }

    // Initialize Tone.js components
    this.pitchShift = new Tone.PitchShift().toDestination();
    
    // We use Tone.Player
    this.player = new Tone.Player({
      url: url,
      onload: () => {
        this.isInitialized = true;
        if (onLoad) onLoad();
      },
      onerror: (e) => console.error("Error loading audio:", e),
      loop: false
    }).connect(this.pitchShift);

    // Sync state
    this.player.onstop = () => {
      this.isPlaying = false;
    };
  },

  play: function () {
    if (!this.isInitialized) return;
    Tone.start(); // Required by browsers to start audio context
    this.player.start();
    this.isPlaying = true;
  },

  pause: function () {
    if (!this.isInitialized) return;
    this.player.stop();
    this.isPlaying = false;
  },

  setPitch: function (semitones) {
    if (!this.isInitialized) return;
    this.pitchShift.pitch = semitones;
  },

  setSpeed: function (rate) {
    if (!this.isInitialized) return;
    this.player.playbackRate = rate;
  },

  seek: function (timeInSeconds) {
    if (!this.isInitialized) return;
    // Tone.Player start method takes the offset
    if (this.isPlaying) {
      this.player.stop();
      this.player.start(0, timeInSeconds);
    }
  },
  
  setLoop: function(start, end) {
    if (!this.isInitialized) return;
    if (start !== null && end !== null) {
      this.player.loop = true;
      this.player.loopStart = start;
      this.player.loopEnd = end;
    } else {
      this.player.loop = false;
    }
  },
  
  getProgress: function() {
    if (!this.isInitialized || !this.isPlaying) return 0;
    // Tone.Player state tracking
    // There isn't a direct get currentTime on Player, so we calculate
    // We will implement basic state mapping if needed
    // But usually Dart can manage its own timer if needed, or we expose context time.
    return this.player.state === "started" ? this.player.context.currentTime : 0; 
  }
};

// Real-time Microphone Capture and Spectrum Analyzer for Chord AI
window.ChordAiAudioJS = {
  audioContext: null,
  mediaStream: null,
  analyser: null,
  buffer: null,
  isCapturing: false,

  start: async function() {
    if (this.isCapturing) return true;
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: false,
          noiseSuppression: false,
          autoGainControl: false
        }
      });
      this.mediaStream = stream;
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      this.audioContext = new AudioCtx();
      if (this.audioContext.state === 'suspended') {
        await this.audioContext.resume();
      }
      const source = this.audioContext.createMediaStreamSource(stream);
      this.analyser = this.audioContext.createAnalyser();
      this.analyser.fftSize = 2048;
      this.analyser.smoothingTimeConstant = 0.6;
      source.connect(this.analyser);
      this.buffer = new Uint8Array(this.analyser.frequencyBinCount);
      this.isCapturing = true;
      return true;
    } catch (e) {
      console.error("[ChordAiAudioJS] start error:", e);
      return false;
    }
  },

  getSampleRate: function() {
    return this.audioContext ? this.audioContext.sampleRate : 44100;
  },

  getFrequencyData: function() {
    if (!this.isCapturing || !this.analyser) return null;
    this.analyser.getByteFrequencyData(this.buffer);
    return this.buffer;
  },

  stop: function() {
    this.isCapturing = false;
    if (this.mediaStream) {
      try {
        this.mediaStream.getTracks().forEach(t => t.stop());
      } catch (_) {}
      this.mediaStream = null;
    }
    if (this.audioContext) {
      try {
        this.audioContext.close();
      } catch (_) {}
      this.audioContext = null;
    }
    this.analyser = null;
    this.buffer = null;
  }
};


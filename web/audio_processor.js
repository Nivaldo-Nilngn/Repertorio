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
    Tone.start(); 
    this.player.start(0, this.pauseOffset || 0);
    this.playbackStartTime = this.player.context.currentTime - (this.pauseOffset || 0);
    this.isPlaying = true;
  },

  pause: function () {
    if (!this.isInitialized) return;
    this.player.stop();
    this.isPlaying = false;
    if (this.playbackStartTime !== undefined) {
      this.pauseOffset = this.player.context.currentTime - this.playbackStartTime;
    }
  },

  setPitch: function (semitones) {
    if (!this.isInitialized) return;
    this.pitchShift.pitch = semitones;
  },

  setSpeed: function (rate) {
    if (!this.isInitialized) return;
    this.player.playbackRate = rate;
    // We would need to update playbackStartTime relative to speed changes for perfect sync,
    // but for now let's just apply the speed.
  },

  seek: function (timeInSeconds) {
    if (!this.isInitialized) return;
    this.pauseOffset = timeInSeconds;
    if (this.isPlaying) {
      this.player.stop();
      this.player.start(0, timeInSeconds);
      this.playbackStartTime = this.player.context.currentTime - timeInSeconds;
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
    if (!this.isInitialized) return 0;
    if (!this.isPlaying) return this.pauseOffset || 0;
    return this.player.context.currentTime - this.playbackStartTime; 
  },

  getRawPCMData: function () {
    if (!this.isInitialized || !this.player || !this.player.buffer) return null;
    const audioBuffer = this.player.buffer.get();
    if (!audioBuffer) return null;
    return audioBuffer.getChannelData(0); // Float32Array, canal 0 (mono/esquerdo)
  },

  getSampleRateOfBuffer: function () {
    if (!this.isInitialized || !this.player || !this.player.buffer) return 44100;
    const audioBuffer = this.player.buffer.get();
    return audioBuffer ? audioBuffer.sampleRate : 44100;
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
      this.analyser.fftSize = 8192;
      this.analyser.smoothingTimeConstant = 0.6;
      this.analyser.minDecibels = -70;
      this.analyser.maxDecibels = 0;
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
    // Only close audioContext if it was created by us for microphone
    if (this.audioContext && !this.usingToneContext) {
      try {
        this.audioContext.close();
      } catch (_) {}
    }
    this.usingToneContext = false;
    this.audioContext = null;
    this.analyser = null;
    this.buffer = null;
  },

  startFromTone: async function() {
    if (this.isCapturing) return true;
    try {
      if (!window.Tone || !window.Tone.getContext()) return false;
      
      this.audioContext = window.Tone.getContext().rawContext;
      this.usingToneContext = true;
      this.analyser = this.audioContext.createAnalyser();
      this.analyser.fftSize = 8192;
      this.analyser.smoothingTimeConstant = 0.6;
      this.analyser.minDecibels = -70;
      this.analyser.maxDecibels = 0;
      
      // Connect directly from the player to avoid PitchShift artifacts in the FFT
      if (window.AdvancedAudioPlayerJS && window.AdvancedAudioPlayerJS.player) {
        window.AdvancedAudioPlayerJS.player.connect(this.analyser);
      } else {
        window.Tone.getDestination().connect(this.analyser);
      }
      
      this.buffer = new Uint8Array(this.analyser.frequencyBinCount);
      this.isCapturing = true;
      return true;
    } catch(e) {
      console.error("[ChordAiAudioJS] startFromTone error:", e);
      return false;
    }
  }
};


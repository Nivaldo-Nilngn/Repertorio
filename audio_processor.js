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

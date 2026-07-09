let midiAccess = null;
let dartMidiMessageCallback = null;
let dartMidiStateChangeCallback = null;

async function initWebMidi() {
  if (navigator.requestMIDIAccess) {
    try {
      midiAccess = await navigator.requestMIDIAccess();
      midiAccess.onstatechange = onStateChange;
      
      // Initialize inputs
      for (let input of midiAccess.inputs.values()) {
        input.onmidimessage = getMIDIMessage;
      }
      return true;
    } catch (e) {
      console.error("No access to MIDI devices or your browser doesn't support it.", e);
      return false;
    }
  } else {
    console.warn("Web MIDI API not supported in this browser.");
    return false;
  }
}

function onStateChange(event) {
  // A device was connected or disconnected
  const port = event.port;
  if (port.type === 'input') {
    if (port.state === 'connected') {
      port.onmidimessage = getMIDIMessage;
    }
  }
  
  if (dartMidiStateChangeCallback) {
    // Notify Dart
    dartMidiStateChangeCallback(port.id, port.name, port.state, port.connection);
  }
}

function getMIDIMessage(midiMessage) {
  const data = midiMessage.data; // Uint8Array
  // Pass to Dart
  if (dartMidiMessageCallback) {
    dartMidiMessageCallback(data, midiMessage.currentTarget.id);
  }
}

function getMidiInputs() {
  if (!midiAccess) return [];
  const inputs = [];
  for (let input of midiAccess.inputs.values()) {
    inputs.push({
      id: input.id,
      name: input.name,
      manufacturer: input.manufacturer,
      state: input.state,
      connection: input.connection
    });
  }
  return inputs;
}

function setDartCallbacks(messageCallback, stateChangeCallback) {
  dartMidiMessageCallback = messageCallback;
  dartMidiStateChangeCallback = stateChangeCallback;
}

// Export for Dart JS interop
window.kordMidiInterop = {
  initWebMidi,
  getMidiInputs,
  setDartCallbacks
};

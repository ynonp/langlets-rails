import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.initializeAudioContext()
    console.log('Audio feedback controller connected')
  }

  disconnect() {
    if (this.audioContext) {
      this.audioContext.close()
    }
  }

  initializeAudioContext() {
    try {
      this.audioContext = new (window.AudioContext || window.webkitAudioContext)()
      console.log('Audio context initialized')
    } catch (error) {
      console.warn('Web Audio API not supported:', error)
      this.audioContext = null
    }
  }

  // Stimulus action methods
  handleCorrect(event) {
    console.log('Handling correct sound')
    this.playCorrectSound()
  }

  handleIncorrect(event) {
    console.log('Handling incorrect sound')
    this.playIncorrectSound()
  }

  handleComplete(event) {
    console.log('Handling complete sound')
    this.playCompleteSound()
  }

  // Generate and play a pleasant "correct" sound (uplifting chime)
  playCorrectSound() {
    if (!this.audioContext) return

    // Resume audio context if needed (browser security requirement)
    if (this.audioContext.state === 'suspended') {
      this.audioContext.resume()
    }

    const now = this.audioContext.currentTime
    const duration = 0.4

    // Create a more engaging sound: quick ascending notes + harmonics
    const melody = [
      { freq: 523.25, time: 0.0, dur: 0.15 },    // C5
      { freq: 659.25, time: 0.08, dur: 0.15 },   // E5
      { freq: 783.99, time: 0.16, dur: 0.24 }    // G5 (longer)
    ]
    
    melody.forEach((note, index) => {
      const startTime = now + note.time
      
      // Main note (triangle wave for warmth)
      const mainOsc = this.audioContext.createOscillator()
      const mainGain = this.audioContext.createGain()
      
      mainOsc.connect(mainGain)
      mainGain.connect(this.audioContext.destination)
      
      mainOsc.frequency.setValueAtTime(note.freq, startTime)
      mainOsc.type = 'triangle'
      
      // Bell-like envelope with sparkle
      mainGain.gain.setValueAtTime(0, startTime)
      mainGain.gain.linearRampToValueAtTime(0.15, startTime + 0.02)
      mainGain.gain.exponentialRampToValueAtTime(0.001, startTime + note.dur)
      
      mainOsc.start(startTime)
      mainOsc.stop(startTime + note.dur)
      
      // Add harmonic sparkle (octave higher, quieter)
      const harmOsc = this.audioContext.createOscillator()
      const harmGain = this.audioContext.createGain()
      
      harmOsc.connect(harmGain)
      harmGain.connect(this.audioContext.destination)
      
      harmOsc.frequency.setValueAtTime(note.freq * 2, startTime)
      harmOsc.type = 'sine'
      
      // Sparkle envelope
      harmGain.gain.setValueAtTime(0, startTime)
      harmGain.gain.linearRampToValueAtTime(0.06, startTime + 0.01)
      harmGain.gain.exponentialRampToValueAtTime(0.001, startTime + note.dur * 0.7)
      
      harmOsc.start(startTime)
      harmOsc.stop(startTime + note.dur)
    })
  }

  // Generate and play a "incorrect" sound (dissonant tone)
  playIncorrectSound() {
    if (!this.audioContext) return

    if (this.audioContext.state === 'suspended') {
      this.audioContext.resume()
    }

    const now = this.audioContext.currentTime
    const duration = 0.3

    // Create a dissonant sound with slightly detuned frequencies
    const frequencies = [220, 226, 233] // Slightly detuned low frequencies
    
    frequencies.forEach((freq, index) => {
      const oscillator = this.audioContext.createOscillator()
      const gainNode = this.audioContext.createGain()
      
      oscillator.connect(gainNode)
      gainNode.connect(this.audioContext.destination)
      
      oscillator.frequency.setValueAtTime(freq, now)
      oscillator.type = 'sawtooth'
      
      // Quick attack, sharp decay
      gainNode.gain.setValueAtTime(0, now)
      gainNode.gain.linearRampToValueAtTime(0.15, now + 0.02)
      gainNode.gain.exponentialRampToValueAtTime(0.001, now + duration)
      
      oscillator.start(now)
      oscillator.stop(now + duration)
    })
  }

  // Generate and play a "completion" sound (ascending arpeggio)
  playCompleteSound() {
    if (!this.audioContext) return

    if (this.audioContext.state === 'suspended') {
      this.audioContext.resume()
    }

    const now = this.audioContext.currentTime
    
    // Ascending major arpeggio (C-E-G-C)
    const frequencies = [523.25, 659.25, 783.99, 1046.5] // C5, E5, G5, C6
    const noteDuration = 0.15
    const totalDuration = frequencies.length * noteDuration

    frequencies.forEach((freq, index) => {
      const startTime = now + (index * noteDuration)
      
      const oscillator = this.audioContext.createOscillator()
      const gainNode = this.audioContext.createGain()
      
      oscillator.connect(gainNode)
      gainNode.connect(this.audioContext.destination)
      
      oscillator.frequency.setValueAtTime(freq, startTime)
      oscillator.type = 'triangle'
      
      // Bell-like envelope
      gainNode.gain.setValueAtTime(0, startTime)
      gainNode.gain.linearRampToValueAtTime(0.2, startTime + 0.02)
      gainNode.gain.exponentialRampToValueAtTime(0.001, startTime + noteDuration)
      
      oscillator.start(startTime)
      oscillator.stop(startTime + noteDuration)
    })
  }

  // Public methods that can be called from other controllers
  correct() {
    this.playCorrectSound()
  }

  incorrect() {
    this.playIncorrectSound()
  }

  complete() {
    this.playCompleteSound()
  }
}
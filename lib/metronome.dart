import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Metronome {
  static final AudioPlayer _player = AudioPlayer();
  static final AudioPlayer _accentPlayer = AudioPlayer();
  Timer? _timer;
  
  int _beatsPerBar = 4;
  int _currentBeat = 0;
  int _repeatCount = 0;
  int _maxRepeats = 0;
  bool _isPlaying = false;
  DateTime? _lastTapTime;
  List<int> _tapIntervals = [];
  int _currentBpm = 120;
  
  Function(bool isFirstBeat)? _tickCallback;
  Function(int)? _onBpmChange;

  /// Configurações avançadas
  int _subdivision = 1;
  bool _enableVibration = false;
  String _mainPath = '';
  String? _accentPath;
  int _volume = 50;

  /// Lista de batidas que devem ser puladas (0-based)
  List<int> _skipBeats = [];

  /// Configurações de progressão de BPM
  int _bpmIncrement = 0;
  int _loopsToIncrement = 0;
  int _currentLoopCount = 0;
  int _maxBpm = 300;

  /// Initialize the metronome
  /// ```
  /// @param mainPath: the path of the normal beat sound file
  /// @param accentedPath: the path of the accented (first) beat sound file
  /// @param bpm: initial tempo in beats per minute (default: 120)
  /// @param volume: initial volume 0-100 (default: 50)
  /// @param timeSignature: beats per bar (default: 4)
  /// @param maxRepeats: number of bars before stopping (0 = infinite, default: 0)
  /// @param subdivision: beats subdivision (1 = normal, 2 = eighth notes, etc.) (default: 1)
  /// @param enableVibration: enable vibration on first beat (default: false)
  /// @param skipBeats: list of beats to skip (0-based)
  /// @param bpmIncrement: BPM increment between loops
  /// @param loopsToIncrement: Number of loops before incrementing BPM
  /// @param maxBpm: Maximum BPM for the progression
  /// ```
  Future<void> init(
    String mainPath, {
    String? accentedPath,
    int bpm = 120,
    int volume = 50,
    int timeSignature = 4,
    int maxRepeats = 0,
    int subdivision = 1,
    bool enableVibration = false,
    List<int> skipBeats = const [],
    int bpmIncrement = 0,
    int loopsToIncrement = 0,
    int maxBpm = 300,
  }) async {
    _beatsPerBar = timeSignature;
    _maxRepeats = maxRepeats;
    _currentBpm = bpm;
    _subdivision = subdivision;
    _enableVibration = enableVibration;
    _mainPath = mainPath;
    _accentPath = accentedPath;
    _volume = volume;
    _skipBeats = skipBeats.where((beat) => beat < timeSignature).toList();
    _bpmIncrement = bpmIncrement;
    _loopsToIncrement = loopsToIncrement;
    _maxBpm = maxBpm;
    _currentLoopCount = 0;
    
    await _player.setAsset(mainPath);
    await _player.setVolume(volume / 100);
    
    if (accentedPath != null) {
      await _accentPlayer.setAsset(accentedPath);
      await _accentPlayer.setVolume(volume / 100);
    }
  }

  /// Set callback for BPM changes
  void setOnBpmChange(Function(int) callback) {
    _onBpmChange = callback;
  }

  /// Update BPM while playing
  Future<void> updateBpm(int bpm) async {
    if (bpm < 30 || bpm > 300) return;
    _currentBpm = bpm;
    _onBpmChange?.call(bpm);
    
    if (_isPlaying) {
      _timer?.cancel();
      // Calcula o intervalo base para o BPM atual
      final interval = Duration(milliseconds: (60000 / (_currentBpm * _subdivision)).round());
      _timer = Timer.periodic(interval, _onTick);
    }
  }

  Future<void> _onTick(Timer timer) async {
    // Simplificado para focar na precisão do timing
    if (!_skipBeats.contains(_currentBeat)) {
      if (_currentBeat == 0 && _enableVibration) {
        HapticFeedback.heavyImpact();
      }

      if (_currentBeat == 0 && _accentPlayer.audioSource != null) {
        await _accentPlayer.seek(Duration.zero);
        await _accentPlayer.play();
      } else {
        await _player.seek(Duration.zero);
        await _player.play();
      }
    }
    
    _tickCallback?.call(_currentBeat == 0);
    _currentBeat = (_currentBeat + 1) % _beatsPerBar;
    
    if (_currentBeat == 0) {
      if (_maxRepeats > 0) {
        _repeatCount++;
        if (_repeatCount >= _maxRepeats) {
          stop();
          return;
        }
      }
      
      // Incrementa BPM após número definido de loops
      if (_bpmIncrement > 0 && _loopsToIncrement > 0) {
        _currentLoopCount++;
        if (_currentLoopCount >= _loopsToIncrement) {
          _currentLoopCount = 0;
          final newBpm = _currentBpm + _bpmIncrement;
          if (newBpm <= _maxBpm) {
            updateBpm(newBpm);
          }
        }
      }
    }
  }

  /// Start playing at the specified BPM
  Future<void> play(int bpm) async {
    if (_isPlaying) return;
    _isPlaying = true;
    _currentBeat = 0;
    _repeatCount = 0;
    await updateBpm(bpm);
  }

  /// Stop playing
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _isPlaying = false;
    _currentBeat = 0;
    _repeatCount = 0;
    await _player.stop();
    await _accentPlayer.stop();
  }

  /// Set volume (0-100)
  Future<void> setVolume(int volume) async {
    await _player.setVolume(volume / 100);
    await _accentPlayer.setVolume(volume / 100);
  }

  /// Set time signature (beats per bar)
  void setTimeSignature(int beats) {
    _beatsPerBar = beats;
    _currentBeat = 0;
  }

  /// Set number of bars to play before stopping (0 = infinite)
  void setMaxRepeats(int repeats) {
    _maxRepeats = repeats;
    _repeatCount = 0;
  }

  /// Tap to detect tempo
  void tap() {
    final now = DateTime.now();
    if (_lastTapTime != null) {
      final interval = now.difference(_lastTapTime!).inMilliseconds;
      if (interval < 2000) { // Ignora intervalos muito longos
        _tapIntervals.add(interval);
        if (_tapIntervals.length > 3) {
          _tapIntervals.removeAt(0);
        }
        
        if (_tapIntervals.length >= 2) {
          final avgInterval = _tapIntervals.reduce((a, b) => a + b) / _tapIntervals.length;
          final newBpm = (60000 / avgInterval).round();
          if (newBpm >= 30 && newBpm <= 300) {
            updateBpm(newBpm);
          }
        }
      } else {
        _tapIntervals.clear();
      }
    }
    _lastTapTime = now;
  }

  /// Reset tap tempo detection
  void resetTap() {
    _lastTapTime = null;
    _tapIntervals.clear();
  }

  /// Set callback for beat events
  /// ```dart
  /// metronome.setTickCallback((isFirstBeat) {
  ///   print(isFirstBeat ? 'First beat!' : 'Normal beat');
  /// });
  /// ```
  void setTickCallback(Function(bool isFirstBeat) callback) {
    _tickCallback = callback;
  }

  /// Get current BPM
  int getBPM() => _currentBpm;

  /// Check if metronome is playing
  bool isPlaying() => _isPlaying;

  /// Get current beat in the bar (0 to beatsPerBar-1)
  int getCurrentBeat() => _currentBeat;

  /// Clean up resources
  Future<void> dispose() async {
    await stop();
    await _player.dispose();
    await _accentPlayer.dispose();
  }

  /// Define subdivisões por tempo
  void setSubdivision(int subdivision) {
    if (subdivision > 0 && subdivision <= 4) {
      _subdivision = subdivision;
      if (_isPlaying) {
        updateBpm(_currentBpm);
      }
    }
  }

  /// Salva preset de configuração
  Future<void> savePreset(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final preset = {
      'bpm': _currentBpm,
      'timeSignature': _beatsPerBar,
      'subdivision': _subdivision,
      'volume': _volume,
      'enableVibration': _enableVibration,
      'mainPath': _mainPath,
      'accentPath': _accentPath,
      'skipBeats': _skipBeats,
    };
    await prefs.setString('preset_$name', jsonEncode(preset));
  }

  /// Carrega preset de configuração
  Future<void> loadPreset(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final presetJson = prefs.getString('preset_$name');
    if (presetJson != null) {
      final preset = jsonDecode(presetJson) as Map<String, dynamic>;
      await init(
        preset['mainPath'],
        accentedPath: preset['accentPath'],
        bpm: preset['bpm'],
        timeSignature: preset['timeSignature'],
        subdivision: preset['subdivision'],
        volume: preset['volume'],
        enableVibration: preset['enableVibration'],
        skipBeats: preset['skipBeats'],
      );
    }
  }

  /// Lista todos os presets salvos
  Future<List<String>> listPresets() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getKeys()
        .where((key) => key.startsWith('preset_'))
        .map((key) => key.substring(7))
        .toList();
  }

  void setVibration(bool enable) {
    _enableVibration = enable;
  }

  /// Define quais batidas devem ser puladas
  void setSkipBeats(List<int> beats) {
    _skipBeats = beats.where((beat) => beat < _beatsPerBar).toList();
  }

  /// Retorna lista de batidas que estão sendo puladas
  List<int> getSkipBeats() => List.from(_skipBeats);

  /// Configura incremento progressivo de BPM
  void setBpmProgression(int increment, int loops, {int maxBpm = 300}) {
    _bpmIncrement = increment;
    _loopsToIncrement = loops;
    _maxBpm = maxBpm;
    _currentLoopCount = 0;
  }

  /// Retorna configurações atuais de progressão
  Map<String, int> getBpmProgression() => {
    'increment': _bpmIncrement,
    'loops': _loopsToIncrement,
    'maxBpm': _maxBpm,
  };
}

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Metronome {
  AudioPlayer? _player;
  AudioPlayer? _accentPlayer;
  Timer? _timer;
  bool _isInitialized = false;
  
  int _beatsPerBar = 4;
  int _currentBeat = 0;
  int _repeatCount = 0;
  int _maxRepeats = 0;
  bool _isPlaying = false;
  DateTime? _lastTapTime;
  List<int> tapIntervals = [];
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

  DateTime? _startTime;
  int _tickCount = 0;

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
    // Limpa recursos anteriores se existirem
    await dispose();
    
    _player = AudioPlayer();
    _accentPlayer = AudioPlayer();
    
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

    try {      
      debugPrint('Inicializando com mainPath: $mainPath');
      if (mainPath.startsWith('http://') || mainPath.startsWith('https://')) {
        final decodedPath = Uri.decodeFull(mainPath);
        debugPrint('URL decodificada: $decodedPath');
        await _player!.setAudioSource(
          AudioSource.uri(Uri.parse(decodedPath), headers: {
            'Access-Control-Allow-Origin': '*',
          }),
          preload: true,
        );
      } else {
        await _player!.setAudioSource(
          AudioSource.asset(mainPath),
          preload: true,
        );
      }
      await _player!.setVolume(volume / 100);

      if (accentedPath != null) {
        debugPrint('Inicializando accentPath: $accentedPath');
        if (accentedPath.startsWith('http://') || accentedPath.startsWith('https://')) {
          final decodedPath = Uri.decodeFull(accentedPath);
          debugPrint('URL de acento decodificada: $decodedPath');
          await _accentPlayer!.setAudioSource(
            AudioSource.uri(Uri.parse(decodedPath), headers: {
              'Access-Control-Allow-Origin': '*',
            }),
            preload: true,
          );
        } else {
          await _accentPlayer!.setAudioSource(
            AudioSource.asset(accentedPath),
            preload: true,
          );
        }
        await _accentPlayer!.setVolume(volume / 100);
      }

      // Pré-carrega os sons
      debugPrint('Iniciando pré-carregamento dos sons');
      await Future.wait([
        _player!.load(),
        if (accentedPath != null) _accentPlayer!.load(),
      ]);
      debugPrint('Pré-carregamento concluído com sucesso');

      _isInitialized = true;
    } catch (e) {
      debugPrint('Erro ao inicializar metrônomo: $e');
      _isInitialized = false;
      rethrow;
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
      _startTime = DateTime.now();
      _tickCount = 0;
      
      // Usa um intervalo menor para maior precisão
      const baseInterval = Duration(milliseconds: 1);
      _timer = Timer.periodic(baseInterval, (timer) {
        if (_startTime == null) return;
        
        final now = DateTime.now();
        final expectedInterval = 60000000 / (_currentBpm * _subdivision); // em microssegundos
        final elapsedMicros = now.difference(_startTime!).inMicroseconds;
        final expectedTicks = (elapsedMicros / expectedInterval).floor();
        
        if (expectedTicks > _tickCount) {
          _tickCount = expectedTicks;
          _onTick(timer);
        }
      });
    }
  }

  Future<void> _onTick(Timer timer) async {
    if (!_isInitialized) return;

    try {
      if (!_skipBeats.contains(_currentBeat)) {
        if (_currentBeat == 0 && _enableVibration) {
          HapticFeedback.heavyImpact();
        }

        if (_currentBeat == 0 && _accentPlayer != null) {
          try {
            await _accentPlayer!.stop();
            await _accentPlayer!.seek(Duration.zero);
            await _accentPlayer!.play();
          } catch (e) {
            // Se falhar, tenta recriar o player
            debugPrint('Recriando accent player após erro: $e');
            await _accentPlayer!.dispose();
            _accentPlayer = AudioPlayer();
            if (_accentPath != null) {
              if (_accentPath!.startsWith('http')) {
                await _accentPlayer!.setAudioSource(
                  AudioSource.uri(Uri.parse(Uri.decodeFull(_accentPath!)), headers: {
                    'Access-Control-Allow-Origin': '*',
                  }),
                  preload: true,
                );
              } else {
                await _accentPlayer!.setAudioSource(
                  AudioSource.asset(_accentPath!),
                  preload: true,
                );
              }
              await _accentPlayer!.setVolume(_volume / 100);
              await _accentPlayer!.play();
            }
          }
        } else if (_player != null) {
          try {
            await _player!.stop();
            await _player!.seek(Duration.zero);
            await _player!.play();
          } catch (e) {
            // Se falhar, tenta recriar o player
            debugPrint('Recriando main player após erro: $e');
            await _player!.dispose();
            _player = AudioPlayer();
            await _player!.setAudioSource(
              _mainPath.startsWith('http') 
                ? AudioSource.uri(Uri.parse(Uri.decodeFull(_mainPath)), headers: {
                    'Access-Control-Allow-Origin': '*',
                  })
                : AudioSource.asset(_mainPath),
              preload: true,
            );
            await _player!.setVolume(_volume / 100);
            await _player!.play();
          }
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
    } catch (e) {
      debugPrint('Erro durante tick: $e');
    }
  }


  /// Start playing at the specified BPM
  Future<void> play(int bpm) async {
    if (!_isInitialized || _isPlaying) return;
    
    try {
      _isPlaying = true;
      _currentBeat = 0;
      _repeatCount = 0;
      _startTime = null;
      _tickCount = 0;
      await updateBpm(bpm);
    } catch (e) {
      debugPrint('Erro ao iniciar reprodução: $e');
      _isPlaying = false;
    }
  }


  /// Stop playing
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _isPlaying = false;
    _currentBeat = 0;
    _repeatCount = 0;
    _startTime = null;
    _tickCount = 0;
    
    try {
      await _player?.stop();
      await _accentPlayer?.stop();
    } catch (e) {
      debugPrint('Erro ao parar reprodução: $e');
    }
  }


  /// Set volume (0-100)
  Future<void> setVolume(int volume) async {
    await _player?.setVolume(volume / 100);
    await _accentPlayer?.setVolume(volume / 100);
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
        tapIntervals.add(interval);
        if (tapIntervals.length > 3) {
          tapIntervals.removeAt(0);
        }
        
        if (tapIntervals.length >= 2) {
          final avgInterval = tapIntervals.reduce((a, b) => a + b) / tapIntervals.length;
          final newBpm = (60000 / avgInterval).round();
          if (newBpm >= 30 && newBpm <= 300) {
            updateBpm(newBpm);
          }
        }
      } else {
        tapIntervals.clear();
      }
    }
    _lastTapTime = now;
  }

  /// Reset tap tempo detection
  void resetTap() {
    _lastTapTime = null;
    tapIntervals.clear();
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
    try {
      await _player?.dispose();
      await _accentPlayer?.dispose();
      _player = null;
      _accentPlayer = null;
      _isInitialized = false;
    } catch (e) {
      debugPrint('Erro ao liberar recursos: $e');
    }
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
      'skipBeats': _skipBeats.toList(),
      'bpmIncrement': _bpmIncrement,
      'loopsToIncrement': _loopsToIncrement,
      'maxBpm': _maxBpm,
    };
    await prefs.setString('preset_$name', jsonEncode(preset));
  }

  /// Carrega preset de configuração
  Future<void> loadPreset(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final presetJson = prefs.getString('preset_$name');
    if (presetJson != null) {
      final preset = jsonDecode(presetJson) as Map<String, dynamic>;
      
      // Converte skipBeats de List<dynamic> para List<int>
      final skipBeats = (preset['skipBeats'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [];

      await init(
        preset['mainPath'] as String,
        accentedPath: preset['accentPath'] as String?,
        bpm: preset['bpm'] as int,
        timeSignature: preset['timeSignature'] as int,
        subdivision: preset['subdivision'] as int,
        volume: preset['volume'] as int,
        enableVibration: preset['enableVibration'] as bool,
        skipBeats: skipBeats,
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

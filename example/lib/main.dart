import 'package:flutter/material.dart';
import 'package:metronome/metronome.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Metrônomo Profissional',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MetronomeDemo(),
    );
  }
}

class MetronomeDemo extends StatefulWidget {
  const MetronomeDemo({Key? key}) : super(key: key);

  @override
  State<MetronomeDemo> createState() => _MetronomeDemoState();
}

class _MetronomeDemoState extends State<MetronomeDemo> {
  final Metronome _metronome = Metronome();
  bool _isPlaying = false;
  int _bpm = 120;
  int _timeSignature = 8;
  int _maxRepeats = 0;
  int _volume = 100;
  bool _isFirstBeat = false;
  int? _currentBeat;
  int _subdivision = 1;
  bool _enableVibration = false;
  List<String> _presets = [];
  String? _currentPreset;
  List<int> skipBeats = [];

  @override
  void initState() {
    super.initState();
    _initMetronome();
  }

  Future<void> _initMetronome() async {
    await _metronome.init(
      'assets/audio/digital/click.wav',
      accentedPath: 'assets/audio/digital/accent.wav',
      bpm: _bpm,
      volume: _volume,
      timeSignature: _timeSignature,
      maxRepeats: _maxRepeats,
      subdivision: _subdivision,
      enableVibration: _enableVibration,
      skipBeats: skipBeats,
    );

    _metronome.setTickCallback((isFirstBeat) {
      setState(() {
        _isFirstBeat = isFirstBeat;
        _currentBeat = _metronome.getCurrentBeat();
      });
    });

    _metronome.setOnBpmChange((bpm) {
      setState(() {
        _bpm = bpm;
      });
    });

    _loadPresets();
  }

  Future<void> _loadPresets() async {
    final presets = await _metronome.listPresets();
    setState(() {
      _presets = presets;
    });
  }

  Widget _buildBeatVisualizer() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_timeSignature, (index) {
          final isCurrentBeat = _isPlaying && index == _currentBeat;
          final isFirstBeat = index == 0;
          final isSkipped = skipBeats.contains(index);
          
          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSkipped) {
                  skipBeats.remove(index);
                } else {
                  skipBeats.add(index);
                }
                skipBeats.sort();
                _metronome.setSkipBeats(skipBeats);
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSkipped
                    ? Colors.grey.withOpacity(0.1)
                    : isCurrentBeat
                        ? (isFirstBeat ? Colors.red : Colors.blue)
                        : Colors.grey.withOpacity(0.3),
                border: Border.all(
                  color: isSkipped
                      ? Colors.grey
                      : isFirstBeat
                          ? Colors.red
                          : Colors.blue,
                  width: 2,
                ),
              ),
              child: isSkipped
                  ? const Icon(Icons.remove, size: 16, color: Colors.grey)
                  : null,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAdvancedControls() {
    return ExpansionTile(
      title: const Text('Configurações Avançadas'),
      children: [
        ListTile(
          title: const Text('Subdivisão'),
          trailing: DropdownButton<int>(
            value: _subdivision,
            items: [1, 2, 3, 4]
                .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e == 1 ? 'Normal' : '$e subdivisões'),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _subdivision = value;
                  _metronome.setSubdivision(value);
                });
              }
            },
          ),
        ),
        SwitchListTile(
          title: const Text('Vibração no Primeiro Tempo'),
          value: _enableVibration,
          onChanged: (value) {
            setState(() {
              _enableVibration = value;
              _metronome.setVibration(value);
            });
          },
        ),
        ListTile(
          title: const Text('Presets'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: _currentPreset,
                hint: const Text('Selecionar'),
                items: _presets
                    .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e),
                        ))
                    .toList(),
                onChanged: (value) async {
                  if (value != null) {
                    await _metronome.loadPreset(value);
                    setState(() {
                      _currentPreset = value;
                    });
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: () => _showSavePresetDialog(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showSavePresetDialog() async {
    final controller = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salvar Preset'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nome do Preset',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await _metronome.savePreset(controller.text);
                await _loadPresets();
                Navigator.pop(context);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Metrônomo Profissional')),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isFirstBeat ? Colors.red : Colors.blue,
                ),
              ),
              const SizedBox(height: 20),
              _buildBeatVisualizer(),
              Text(
                '$_bpm BPM',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Slider(
                value: _bpm.toDouble(),
                min: 30,
                max: 300,
                onChanged: (value) {
                  final newBpm = value.round();
                  _metronome.updateBpm(newBpm);
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isPlaying = !_isPlaying;
                        if (_isPlaying) {
                          _metronome.play(_bpm);
                        } else {
                          _metronome.stop();
                        }
                      });
                    },
                    child: Text(_isPlaying ? 'Parar' : 'Tocar'),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: () {
                      _metronome.tap();
                    },
                    child: const Text('Tap Tempo'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Compasso: '),
                  DropdownButton<int>(
                    value: _timeSignature,
                    items: [2, 3, 4, 5, 6, 7, 8]
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text('$e/4'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _timeSignature = value;
                          _metronome.setTimeSignature(value);
                          _currentBeat = null;
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Repetições: '),
                  DropdownButton<int>(
                    value: _maxRepeats,
                    items: [0, 2, 4, 8, 16]
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e == 0 ? 'Infinito' : '$e'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _maxRepeats = value;
                          _metronome.setMaxRepeats(value);
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Volume: '),
                  Slider(
                    value: _volume.toDouble(),
                    min: 0,
                    max: 100,
                    onChanged: (value) {
                      setState(() {
                        _volume = value.round();
                        _metronome.setVolume(_volume);
                      });
                    },
                  ),
                ],
              ),
              _buildAdvancedControls(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _metronome.dispose();
    super.dispose();
  }
}

# Metrônomo Profissional

[English version below]

## Descrição
Um metrônomo profissional para Flutter com recursos avançados para músicos e educadores musicais.

## Recursos

### Básicos
- 🎵 Controle preciso de BPM (30-300)
- 🎯 Tap tempo para definição intuitiva da velocidade
- 🔊 Controle de volume (0-100%)
- 📝 Diferentes fórmulas de compasso (2/4 até 8/4)
- 🔄 Número configurável de repetições

### Avançados
- 🎼 Sons personalizáveis para tempos fortes e fracos
- ⏭️ Possibilidade de pular batidas específicas
- 🎯 Subdivisões rítmicas (1-4 subdivisões por tempo)
- 📈 Progressão automática de BPM
- 📱 Vibração opcional no primeiro tempo
- 💾 Sistema de presets para salvar/carregar configurações
- ⚡ Correção automática de latência
- 👁️ Feedback visual do andamento

## Como Usar

### Configuração Básica
```dart
final metronome = Metronome();
await metronome.init(
  'assets/click.wav',
  accentedPath: 'assets/accent.wav',
  bpm: 120,
  timeSignature: 4,
);

// Iniciar
metronome.play(120);

// Parar
metronome.stop();
```

### Pular Batidas Específicas
```dart
// Pular segundo e quarto tempos
metronome.setSkipBeats([1, 3]);
```

### Progressão Automática de BPM
```dart
// Aumentar 5 BPM a cada 4 compassos até 180 BPM
metronome.setBpmProgression(
  increment: 5,
  loops: 4,
  maxBpm: 180,
);
```

### Presets
```dart
// Salvar configuração atual
await metronome.savePreset('Exercício 1');

// Carregar preset
await metronome.loadPreset('Exercício 1');

// Listar presets
final presets = await metronome.listPresets();
```

### Recursos Avançados
```dart
// Configurar subdivisões
metronome.setSubdivision(2); // Colcheias

// Habilitar vibração
metronome.setVibration(true);

// Callback para cada batida
metronome.setTickCallback((isFirstBeat) {
  print(isFirstBeat ? 'Tempo forte!' : 'Tempo fraco');
});
```

---

# Professional Metronome

## Description
A professional metronome for Flutter with advanced features for musicians and music educators.

## Features

### Basic
- 🎵 Precise BPM control (30-300)
- 🎯 Tap tempo for intuitive speed setting
- 🔊 Volume control (0-100%)
- 📝 Different time signatures (2/4 to 8/4)
- 🔄 Configurable number of repetitions

### Advanced
- 🎼 Customizable sounds for strong and weak beats
- ⏭️ Ability to skip specific beats
- 🎯 Rhythmic subdivisions (1-4 subdivisions per beat)
- 📈 Automatic BPM progression
- 📱 Optional vibration on first beat
- 💾 Preset system for saving/loading settings
- ⚡ Automatic latency correction
- 👁️ Visual tempo feedback

## How to Use

### Basic Setup
```dart
final metronome = Metronome();
await metronome.init(
  'assets/click.wav',
  accentedPath: 'assets/accent.wav',
  bpm: 120,
  timeSignature: 4,
);

// Start
metronome.play(120);

// Stop
metronome.stop();
```

### Skip Specific Beats
```dart
// Skip second and fourth beats
metronome.setSkipBeats([1, 3]);
```

### Automatic BPM Progression
```dart
// Increase 5 BPM every 4 bars up to 180 BPM
metronome.setBpmProgression(
  increment: 5,
  loops: 4,
  maxBpm: 180,
);
```

### Presets
```dart
// Save current configuration
await metronome.savePreset('Exercise 1');

// Load preset
await metronome.loadPreset('Exercise 1');

// List presets
final presets = await metronome.listPresets();
```

### Advanced Features
```dart
// Set subdivisions
metronome.setSubdivision(2); // Eighth notes

// Enable vibration
metronome.setVibration(true);

// Callback for each beat
metronome.setTickCallback((isFirstBeat) {
  print(isFirstBeat ? 'Strong beat!' : 'Weak beat');
});
```

## Installation
Add to your pubspec.yaml:
```yaml
dependencies:
  metronome: ^1.0.0
```

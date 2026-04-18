// lib/models/mascot_dna.dart
import 'dart:convert';
import 'package:flutter/material.dart';

enum MascotMood {
  thriving,
  chill,
  stressed,
  overspent,
  celebrating,
  sleeping,
  curious,
}

extension MascotMoodX on MascotMood {
  String get label {
    switch (this) {
      case MascotMood.thriving:    return 'thriving ✨';
      case MascotMood.chill:       return 'cruising 🌊';
      case MascotMood.stressed:    return 'stressed ⚠️';
      case MascotMood.overspent:   return 'budget blown 🔥';
      case MascotMood.celebrating: return 'vibes are high 🎉';
      case MascotMood.sleeping:    return 'waiting for data 💤';
      case MascotMood.curious:     return 'curious 👀';
    }
  }

  Color get chipColor {
    switch (this) {
      case MascotMood.thriving:    return const Color(0xFF33AAB0); // teal
      case MascotMood.chill:       return const Color(0xFF85CCD0); // light teal
      case MascotMood.stressed:    return const Color(0xFFBC8D4B); // sand amber
      case MascotMood.overspent:   return const Color(0xFFD46586); // rose red
      case MascotMood.celebrating: return const Color(0xFF33AAB0); // teal
      case MascotMood.sleeping:    return const Color(0xFF7D7378); // muted grey
      case MascotMood.curious:     return const Color(0xFF595155); // dark muted
    }
  }

  double get breatheTempo {
    switch (this) {
      case MascotMood.stressed:    return 1.6;
      case MascotMood.overspent:   return 1.4;
      case MascotMood.celebrating: return 0.8;
      case MascotMood.sleeping:    return 4.5;
      case MascotMood.thriving:    return 2.8;
      default:                     return 3.2;
    }
  }
}

/// Pastel fills — slightly richer than page washes so the body still reads on
/// lavender / cream / white (avoids “light blob on light ground”).
const Map<String, Color> blobColorMap = {
  'lime':   Color(0xFFC8E88A),
  'pink':   Color(0xFFFFB8D6),
  'royal':  Color(0xFFB8D4F5),
  'amber':  Color(0xFFFFD9B0),
  'mint':   Color(0xFFB8E8D4),
  'violet': Color(0xFFD4CCF0),
};

const List<Map<String, String>> blobColorOptions = [
  {'id': 'lime',   'name': 'Butter'},
  {'id': 'pink',   'name': 'Blush'},
  {'id': 'royal',  'name': 'Sky'},
  {'id': 'amber',  'name': 'Peach'},
  {'id': 'mint',   'name': 'Mist'},
  {'id': 'violet', 'name': 'Lilac'},
];

const List<Map<String, String>> blobAccessoryOptions = [
  {'id': 'none',   'emoji': '✨', 'name': 'Plain'},
  {'id': 'bow',    'emoji': '🎀', 'name': 'Bow'},
  {'id': 'clip',   'emoji': '⭐', 'name': 'Star clip'},
  {'id': 'petals', 'emoji': '🌸', 'name': 'Blossom'},
  {'id': 'hearts', 'emoji': '💕', 'name': 'Hearts'},
  {'id': 'ribbon', 'emoji': '🎗️', 'name': 'Ribbon'},
];

const Set<String> _validAccessoryIds = {
  'none',
  'bow',
  'clip',
  'petals',
  'hearts',
  'ribbon',
};

/// Maps older accessory ids so saved buddies still load.
String normalizeBlobAccessoryId(String? raw) {
  const legacy = {
    'crown': 'bow',
    'cap': 'clip',
    'monocle': 'petals',
    'headphones': 'hearts',
    'scarf': 'ribbon',
  };
  final a = raw ?? 'none';
  if (legacy.containsKey(a)) return legacy[a]!;
  if (_validAccessoryIds.contains(a)) return a;
  return 'none';
}

class MascotDna {
  final String name;
  final String color;
  final String accessory;

  const MascotDna({
    required this.name,
    required this.color,
    required this.accessory,
  });

  factory MascotDna.defaults() => const MascotDna(
    name: 'Blobby',
    color: 'lime',
    accessory: 'none',
  );

  MascotDna copyWith({String? name, String? color, String? accessory}) {
    return MascotDna(
      name:      name      ?? this.name,
      color:     color     ?? this.color,
      accessory: accessory ?? this.accessory,
    );
  }

  Color get colorValue => blobColorMap[color] ?? const Color(0xFFD4FF3D);

  Map<String, dynamic> toJson() => {
    'name': name,
    'color': color,
    'accessory': accessory,
  };

  factory MascotDna.fromJson(Map<String, dynamic> j) => MascotDna(
    name:      j['name']      as String? ?? 'Blobby',
    color:     j['color']     as String? ?? 'lime',
    accessory: normalizeBlobAccessoryId(j['accessory'] as String?),
  );

  String toJsonString() => jsonEncode(toJson());
  factory MascotDna.fromJsonString(String s) =>
      MascotDna.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

/// Spend intensity from [debitToCreditRatio] = totalDebit / totalCredit (credit > 0).
MascotMood moodFromBudgetPct(double debitToCreditRatio, {bool hasData = true}) {
  if (!hasData) return MascotMood.sleeping;
  if (debitToCreditRatio >= 1.0) return MascotMood.overspent;
  if (debitToCreditRatio >= 0.8) return MascotMood.stressed;
  if (debitToCreditRatio >= 0.5) return MascotMood.chill;
  return MascotMood.thriving;
}

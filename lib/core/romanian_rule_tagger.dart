/// Conservative Romanian token analysis for linear, no-loss semantic fusion.
///
/// Only closed-class/function words and punctuation are assigned grammatical
/// operators with high confidence. Open-class words remain `LEXEM`, rather than
/// being guessed from suffixes. This keeps ambiguity explicit and prevents the
/// engine from inventing grammar that is not justified by the current input.
final class RomanianTokenAnalysis {
  const RomanianTokenAnalysis({
    required this.surface,
    required this.normalized,
    required this.category,
    required this.explicitMeaning,
    this.modifiesPrevious = false,
    this.isPunctuation = false,
  });

  final String surface;
  final String normalized;
  final String category;
  final String explicitMeaning;
  final bool modifiesPrevious;
  final bool isPunctuation;

  bool get isOpenClass => category == RomanianRuleTagger.lexemeTag;
}

final class RomanianRuleTagger {
  const RomanianRuleTagger();

  static const String lexemeTag = 'LEXEM';
  static const String prepositionTag = 'PREPOZIȚIE';
  static const String conjunctionTag = 'CONJUNCȚIE';
  static const String determinerTag = 'DETERMINANT';
  static const String possessiveTag = 'POSESIV';
  static const String pronounTag = 'PRONUME';
  static const String negationTag = 'NEGAȚIE';
  static const String quantifierTag = 'CUANTIFICATOR';
  static const String auxiliaryTag = 'AUXILIAR';
  static const String copulaTag = 'COPULĂ';
  static const String ambiguousTag = 'AMBIGUU';
  static const String numeralTag = 'NUMERAL';
  static const String punctuationTag = 'PUNCTUAȚIE';

  static final RegExp _numeral = RegExp(r'^\d+(?:[.,]\d+)?$');
  static final RegExp _punctuation = RegExp(r'^[.,;:!?…()\[\]{}„”"«»—–-]$');

  static const Map<String, _Rule> _rules = <String, _Rule>{
    // Prepositions: explicit relational contribution.
    'în': _Rule(prepositionTag, 'interioritate/localizare'),
    'din': _Rule(prepositionTag, 'origine/sursă'),
    'de': _Rule(prepositionTag, 'relație/dependență'),
    'cu': _Rule(prepositionTag, 'asociere/instrument'),
    'pe': _Rule(prepositionTag, 'contact/țintă'),
    'la': _Rule(prepositionTag, 'localizare/direcție'),
    'prin': _Rule(prepositionTag, 'traversare/mijloc'),
    'pentru': _Rule(prepositionTag, 'destinație/scop'),
    'asupra': _Rule(prepositionTag, 'raport-supra'),
    'sub': _Rule(prepositionTag, 'inferioritate'),
    'peste': _Rule(prepositionTag, 'superioritate/traversare'),
    'între': _Rule(prepositionTag, 'intermediere'),
    'fără': _Rule(prepositionTag, 'absență/excludere'),
    'către': _Rule(prepositionTag, 'direcție'),
    'spre': _Rule(prepositionTag, 'direcție'),
    'despre': _Rule(prepositionTag, 'temă'),
    'dintre': _Rule(prepositionTag, 'selecție-din-grup'),
    'după': _Rule(prepositionTag, 'posterioritate/urmărire'),
    'lângă': _Rule(prepositionTag, 'proximitate'),
    'contra': _Rule(prepositionTag, 'opoziție'),

    // Connectors. Slash-separated labels deliberately retain unresolved senses.
    'și': _Rule(conjunctionTag, 'coordonare-aditivă'),
    'sau': _Rule(conjunctionTag, 'alternativă'),
    'dar': _Rule(conjunctionTag, 'contrast'),
    'iar': _Rule(conjunctionTag, 'coordonare/contrast'),
    'ci': _Rule(conjunctionTag, 'corecție-contrastivă'),
    'deci': _Rule(conjunctionTag, 'consecință'),
    'că': _Rule(conjunctionTag, 'subordonare/conținut'),
    'dacă': _Rule(conjunctionTag, 'condiție'),
    'fiindcă': _Rule(conjunctionTag, 'cauză'),
    'deoarece': _Rule(conjunctionTag, 'cauză'),
    'încât': _Rule(conjunctionTag, 'rezultat'),
    'deși': _Rule(conjunctionTag, 'concesie'),
    'ca': _Rule(conjunctionTag, 'comparație/rol/subordonare'),
    'să': _Rule(conjunctionTag, 'marcaj-conjunctiv/subordonare'),

    // Negation.
    'nu': _Rule(negationTag, 'negație'),
    'nici': _Rule(negationTag, 'negație-aditivă'),

    // Articles/determiners whose contribution is explicit before a nominal.
    'un': _Rule(determinerTag, 'indefinit-singular'),
    'unei': _Rule(determinerTag, 'indefinit-genitiv/dativ'),
    'unui': _Rule(determinerTag, 'indefinit-genitiv/dativ'),
    'niște': _Rule(determinerTag, 'indefinit-plural'),
    'acest': _Rule(determinerTag, 'deixis-proximal'),
    'această': _Rule(determinerTag, 'deixis-proximal'),
    'acești': _Rule(determinerTag, 'deixis-proximal'),
    'aceste': _Rule(determinerTag, 'deixis-proximal'),
    'acel': _Rule(determinerTag, 'deixis-distal'),
    'acea': _Rule(determinerTag, 'deixis-distal'),
    'acei': _Rule(determinerTag, 'deixis-distal'),
    'acele': _Rule(determinerTag, 'deixis-distal'),

    // Possessives normally modify the already present nominal expression.
    'meu': _Rule(possessiveTag, 'posesie-p1-singular', true),
    'mea': _Rule(possessiveTag, 'posesie-p1-singular', true),
    'mei': _Rule(possessiveTag, 'posesie-p1-singular', true),
    'mele': _Rule(possessiveTag, 'posesie-p1-singular', true),
    'tău': _Rule(possessiveTag, 'posesie-p2-singular', true),
    'ta': _Rule(possessiveTag, 'posesie-p2-singular', true),
    'tăi': _Rule(possessiveTag, 'posesie-p2-singular', true),
    'tale': _Rule(possessiveTag, 'posesie-p2-singular', true),
    'său': _Rule(possessiveTag, 'posesie-p3-singular', true),
    'sa': _Rule(possessiveTag, 'posesie-p3-singular', true),
    'săi': _Rule(possessiveTag, 'posesie-p3-singular', true),
    'sale': _Rule(possessiveTag, 'posesie-p3-singular', true),
    'nostru': _Rule(possessiveTag, 'posesie-p1-plural', true),
    'noastră': _Rule(possessiveTag, 'posesie-p1-plural', true),
    'voastră': _Rule(possessiveTag, 'posesie-p2-plural', true),
    'vostru': _Rule(possessiveTag, 'posesie-p2-plural', true),

    // Pronouns / explicit reference markers.
    'eu': _Rule(pronounTag, 'referință-p1-singular'),
    'tu': _Rule(pronounTag, 'referință-p2-singular'),
    'el': _Rule(pronounTag, 'referință-p3-singular-masculin'),
    'ea': _Rule(pronounTag, 'referință-p3-singular-feminin'),
    'noi': _Rule(pronounTag, 'referință-p1-plural'),
    'voi': _Rule(ambiguousTag, 'referință-p2-plural/auxiliar-viitor'),
    'ei': _Rule(pronounTag, 'referință-p3-plural-masculin'),
    'ele': _Rule(pronounTag, 'referință-p3-plural-feminin'),
    'mă': _Rule(pronounTag, 'referință-clitică-p1'),
    'te': _Rule(pronounTag, 'referință-clitică-p2'),
    'se': _Rule(pronounTag, 'referință-reflexivă/impersonală'),
    'ne': _Rule(pronounTag, 'referință-clitică-p1-plural'),
    'vă': _Rule(pronounTag, 'referință-clitică-p2-plural'),

    // Quantification/degree operators.
    'toți': _Rule(quantifierTag, 'totalitate'),
    'toate': _Rule(quantifierTag, 'totalitate'),
    'tot': _Rule(quantifierTag, 'totalitate/continuitate'),
    'fiecare': _Rule(quantifierTag, 'distribuție-universală'),
    'mulți': _Rule(quantifierTag, 'cantitate-mare'),
    'multe': _Rule(quantifierTag, 'cantitate-mare'),
    'puțini': _Rule(quantifierTag, 'cantitate-mică'),
    'puține': _Rule(quantifierTag, 'cantitate-mică'),
    'foarte': _Rule(quantifierTag, 'grad-intens'),
    'mai': _Rule(quantifierTag, 'grad/comparație', true),

    // Closed-class verbal operators with stable explicit contributions.
    'este': _Rule(copulaTag, 'copulă/existență'),
    'e': _Rule(copulaTag, 'copulă/existență'),
    'sunt': _Rule(copulaTag, 'copulă/existență'),
    'era': _Rule(copulaTag, 'copulă/existență-trecut'),
    'erau': _Rule(copulaTag, 'copulă/existență-trecut'),
    'fi': _Rule(copulaTag, 'copulă/existență-infinitiv'),
    'va': _Rule(auxiliaryTag, 'auxiliar-viitor'),
    'vor': _Rule(auxiliaryTag, 'auxiliar-viitor'),
    'ar': _Rule(auxiliaryTag, 'auxiliar-condițional'),

    // Forms that are genuinely ambiguous without more text. Do not resolve.
    'a': _Rule(ambiguousTag, 'articol/posesiv/marcaj-infinitiv/auxiliar'),
    'ai': _Rule(ambiguousTag, 'posesiv/auxiliar'),
    'ale': _Rule(ambiguousTag, 'posesiv/articol'),
    'al': _Rule(ambiguousTag, 'posesiv/articol'),
    'o': _Rule(ambiguousTag, 'articol/pronume/auxiliar'),
    'am': _Rule(auxiliaryTag, 'auxiliar-perfect-compus'),
    'avem': _Rule(auxiliaryTag, 'auxiliar-perfect-compus'),
    'aveți': _Rule(auxiliaryTag, 'auxiliar-perfect-compus'),
    'au': _Rule(auxiliaryTag, 'auxiliar-perfect-compus'),
  };

  RomanianTokenAnalysis analyzeToken(String token) {
    final surface = token.trim();
    final normalized = surface.toLowerCase();

    if (_punctuation.hasMatch(surface)) {
      return RomanianTokenAnalysis(
        surface: surface,
        normalized: normalized,
        category: punctuationTag,
        explicitMeaning: _punctuationMeaning(surface),
        isPunctuation: true,
      );
    }

    final rule = _rules[normalized];
    if (rule != null) {
      return RomanianTokenAnalysis(
        surface: surface,
        normalized: normalized,
        category: rule.category,
        explicitMeaning: rule.meaning,
        modifiesPrevious: rule.modifiesPrevious,
      );
    }

    if (_numeral.hasMatch(normalized)) {
      return RomanianTokenAnalysis(
        surface: surface,
        normalized: normalized,
        category: numeralTag,
        explicitMeaning: normalized,
      );
    }

    // Open-class lexical items are deliberately not guessed by suffix.
    return RomanianTokenAnalysis(
      surface: surface,
      normalized: normalized,
      category: lexemeTag,
      explicitMeaning: normalized,
    );
  }

  /// Backward-compatible API. The returned tag is conservative by design.
  String tagWord(String word) => analyzeToken(word).category;

  String eticheteazaCuvant(String cuvant) => tagWord(cuvant);

  static String _punctuationMeaning(String punctuation) {
    switch (punctuation) {
      case '.':
        return 'închidere-enunț';
      case ',':
        return 'segmentare-continuativă';
      case ';':
        return 'segmentare-majoră';
      case ':':
        return 'deschidere-explicitare';
      case '?':
        return 'interogație';
      case '!':
        return 'exclamație';
      case '…':
        return 'suspendare';
      case '(':
      case '[':
      case '{':
        return 'deschidere-inciză';
      case ')':
      case ']':
      case '}':
        return 'închidere-inciză';
      case '„':
      case '«':
      case '"':
        return 'marcaj-citare';
      case '”':
      case '»':
        return 'marcaj-citare';
      case '—':
      case '–':
      case '-':
        return 'legătură/separare';
      default:
        return 'punctuație:$punctuation';
    }
  }
}

final class _Rule {
  const _Rule(this.category, this.meaning, [this.modifiesPrevious = false]);

  final String category;
  final String meaning;
  final bool modifiesPrevious;
}

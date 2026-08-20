# Drujba Semantică

Aplicație Android Flutter pentru OCR local și fuziune sintactico-lexicală
deterministă. Textul camerei este citit pe dispozitiv, cuvânt cu cuvânt, și
transformat într-un monolit semantic de forma:

```text
[Substanță-Substanță] ➔ [Dinamică] [atribut]
```

Aplicația nu folosește LLM-uri, servicii cloud sau API-uri externe. APK-ul de
release nu declară permisiunea Android `INTERNET`.

## Funcții

- OCR continuu din fluxul camerei, prin modelul Latin ML Kit inclus local.
- Stabilizare pe două cadre pentru a evita reintroducerea aceluiași text.
- Procesare liniară și clasificare locală pe reguli fixe.
- Categorii vizibile: Substanță `[Ce]`, Dinamică `➔`, Atribute `[Cum]`.
- Zăvor/dezăvorâre prin atingerea unui concept.
- Frecvențe păstrate determinist și ordine de inserție stabilă.
- Intrare manuală offline, utilă când nu există cameră sau pentru verificare.
- Resetarea completă a sesiunii.

## Utilizare

1. Deschide aplicația și apasă **Scanează Pagina Liniar (OCR Continuous)**.
2. Acordă permisiunea pentru cameră.
3. Ține pagina lizibilă în cadru. Textul este confirmat după două cadre
   consecutive stabile și absorbit în ordinea detectată.
4. Atinge un concept pentru a-i comuta Zăvorul `LOCK`.
5. Oprește scanarea sau resetează sesiunea din bara de sus.

Panoul **Introducere manuală offline** permite testarea aceluiași motor fără
cameră.

## Arhitectură

```text
lib/core/                         motor pur, determinist și testabil
lib/ocr/                          cameră + conversie cadre + OCR local
lib/features/semantic_home_page.dart  interfața în timp real
test/                             teste unitare și widget
android/                          configurația APK Android
.github/workflows/android.yml     analiză, teste și build release
```

Motorul păstrează fidel regulile din specificația PDF. Euristica gramaticală
este intenționat rigidă: sufixele `re`/`a` indică verb, `ic`/`al` indică
adjectiv, iar orice alt cuvânt util devine substantiv. Nu există inferență sau
parafrazare.

## Compilare locală

Cerințe: Flutter 3.47.0, Dart 3.12+, JDK 17 și Android SDK 36.

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

APK-ul rezultat este:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Pentru instalarea pe un dispozitiv conectat:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## Build automat pe GitHub

Workflow-ul **Android APK** rulează formatarea, analiza statică, testele,
compilarea release și o verificare a manifestului pentru a confirma că APK-ul
nu are permisiunea `INTERNET`. APK-ul este publicat ca artifact al rulării.

## Confidențialitate

- Sunt solicitate doar camera și capabilitatea hardware aferentă.
- Cadrele sunt procesate în memorie pe dispozitiv.
- Nu se păstrează fotografii și nu se trimit date în rețea.
- Oprirea scanării eliberează camera imediat.

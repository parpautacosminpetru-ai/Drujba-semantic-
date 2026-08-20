# Drujba Semantică v2.0

Aplicație Android Flutter pentru sinteză axiomatică integrativă semantică.
Transformă local un flux liniar de forme într-un singur sens brut
compozițional. Fiecare formă este integrată în ordine; când o axiomă
direcțională există în matricea semantică, operanzii se topesc într-un concept
nou. De exemplu:

```text
SISTEM + POLITIC -> GUVERNANȚĂ
GUVERNANȚĂ + EȘUAT -> ANOMIE
```

Arborele semantic păstrează toate formele originale ca proveniență și fiecare
fuziune păstrează ID-ul axiomei folosite (`AX-002`, apoi `AX-003` în exemplu),
chiar dacă interfața proiectează doar monolitul compact `[ANOMIE]`. O
combinație fără axiomă nu este interpretată sau ghicită: rămâne o compoziție
ordonată cu `-` și este marcată explicit drept nerezolvată.

Aplicația nu folosește LLM-uri, servicii cloud, API-uri externe ori inferență
generativă. APK-ul release nu declară permisiunea Android `INTERNET`.

## Matricea v2 inclusă

| Sens curent | Forma următoare | Sens compus |
|---|---|---|
| sistem | eșuat | Colaps |
| sistem | politic | Guvernanță |
| guvernanță | eșuat | Anomie |
| guvernanță | corupt | Cleptocrație |
| tehnologie | rapid | Hiper-Evoluție |
| tehnologie | control | Cibernetică |

Matricea este direcțională. Formele necunoscute, cuvintele funcționale,
punctuația și repetițiile nu sunt eliminate; ele rămân în flux și în
proveniență. Pentru acoperire lingvistică mai largă trebuie adăugate reguli
locale explicite, nu un fallback probabilistic.

## Funcții

- OCR continuu prin modelul Latin ML Kit inclus pe dispozitiv.
- Stabilizare tolerantă pe două observații înaintea confirmării unui cadru.
- Reconciliere OCR pozițională: extensiile sunt anexate, iar inserțiile sau
  corecțiile declanșează reconstruirea deterministă a fluxului activ.
- Reactor semantic pur, testabil și extensibil printr-o matrice injectabilă.
- Dovadă axiomatică vizibilă pentru fiecare colaps semantic.
- Panou superior cu un singur sens brut curent.
- Zăvor prin atingerea monolitului: sensul curent este înghețat, iar scanările
  următoare pornesc o sinteză separată.
- Intrare manuală offline pentru verificare fără cameră.
- Reset complet al fluxului activ și al zăvoarelor.
- Diagnostic vizibil pentru textul OCR brut și cadre incompatibile.

## Utilizare

1. Apasă **Scanează Pagina Liniar (OCR Continuous)** și acordă accesul la
   cameră.
2. Ține textul lizibil în cadru. Formele sunt procesate în ordinea OCR.
3. Atinge monolitul verde pentru a aplica Zăvorul și a porni un segment nou.
4. Atinge un sens din lista de zăvoare pentru a-l elimina.
5. Folosește butonul de resetare din bara de sus pentru o sesiune complet nouă.

Panoul **Introducere manuală offline** folosește exact același reactor.

## Arhitectură

```text
lib/semantic_reactor.dart             reactor + AST + matrice semantică v2
lib/core/ocr_frame_accumulator.dart   stabilizare și reconciliere OCR
lib/ocr/                              cameră + conversie cadre + ML Kit local
lib/features/semantic_home_page.dart  monolit, zăvor și controale
test/                                 teste unitare și widget
android/                              configurația APK Android
.github/workflows/android.yml         analiză, teste și build release
```

## Compilare locală

Cerințe: Flutter 3.47.0, Dart 3.12+, JDK 17 și Android SDK 36.

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

APK-ul rezultat este `build/app/outputs/flutter-apk/app-release.apk`.

## Build automat pe GitHub

Workflow-ul **Android CI** formatează sursele, rulează analiza și testele,
construiește APK-ul release și verifică manifestul: `CAMERA` trebuie să existe,
iar `INTERNET` trebuie să lipsească. APK-ul este apoi publicat ca artifact.

## Confidențialitate

- Sunt solicitate numai camera și capabilitatea hardware aferentă.
- Cadrele sunt procesate în memorie pe dispozitiv.
- Nu se păstrează fotografii și nu se trimit date în rețea.
- Oprirea scanării eliberează camera imediat.

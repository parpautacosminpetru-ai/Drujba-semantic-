# Drujba Semantică v2.0

Aplicație Android Flutter pentru sinteză axiomatică integrativă semantică.
Transformă local un flux liniar de forme într-un singur sens brut
compozițional. Fiecare formă este integrată în ordine; când o axiomă
direcțională există în matricea semantică, operanzii se topesc într-un concept
nou. De exemplu:

```text
SISTEM + POLITIC -> STAT
STAT + EȘUAT -> PRĂBUȘIRE
```

Operația este strict binară la fiecare pas:

```text
cuvânt₁ ⊗ cuvânt₂ -> concept₁
concept₁ ⊗ cuvânt₃ -> concept₂
concept₂ ⊗ cuvânt₄ -> concept₃
```

Aceasta este **sinteză integrativă, nu rezumare**: reactorul nu selectează,
nu elimină și nu parafrazează formele. Fiecare cuvânt nou este al doilea
operand al întregului concept curent, iar arborele rezultat păstrează prefixul
complet deja integrat.

Reducerul nu sare peste conceptul curent pentru a topi doar un sufix. Astfel,
în orice moment există o singură rădăcină semantică activă și un singur monolit
afișat.

Arborele semantic păstrează toate formele originale ca proveniență și fiecare
fuziune păstrează ID-ul axiomei folosite (`CIN-001`, apoi `CIN-003` în
exemplu), chiar dacă interfața proiectează doar monolitul compact
`[PRABUSIRE]`. O
combinație fără axiomă nu este interpretată sau ghicită: rămâne o compoziție
ordonată cu `-` și este marcată explicit drept nerezolvată.

Aplicația nu folosește LLM-uri, servicii cloud, API-uri externe ori inferență
generativă. APK-ul release nu declară permisiunea Android `INTERNET`.

## Matricea v2 inclusă

| Sens curent | Forma următoare | Sens compus |
|---|---|---|
| sistem | politic | Stat |
| sistem | social | Societate |
| stat | eșuat | Prăbușire |
| stat | corupt | Degradare |

Matricea este direcțională. Formele necunoscute, cuvintele funcționale,
punctuația și repetițiile nu sunt eliminate; ele rămân în flux și în
proveniență. Pentru acoperire lingvistică mai largă trebuie adăugate reguli
locale explicite, nu un fallback probabilistic.

## Funcții

- OCR continuu prin modelul Latin ML Kit inclus pe dispozitiv.
- Stabilizare strictă pe două observații identice înaintea confirmării unui
  cadru.
- Ledger OCR no-loss: formele confirmate nu sunt eliminate; inserțiile pot
  reconstrui fluxul numai dacă toate formele anterioare rămân în aceeași
  ordine.
- Reactor semantic pur, testabil și extensibil printr-o matrice injectabilă.
- Dovadă axiomatică vizibilă pentru fiecare colaps semantic.
- Film semantic local: patru scene WebP incluse în APK, mapate strict prin
  ID-ul axiomei, cu fade, mișcare lentă și cuvânt-concept pulsatoriu.
- Pentru o compoziție nerezolvată, proiecția rămâne neagră; aplicația nu
  inventează o imagine sau un sens.
- Zăvor prin atingerea monolitului: sensul și cadrul curent sunt înghețate,
  iar scanările următoare pornesc o sinteză separată.
- Buton local play/pause pentru animația proiecției, independent de reactor.
- Intrare manuală offline pentru verificare fără cameră.
- Reset complet al fluxului activ și al zăvoarelor.
- Diagnostic vizibil pentru textul OCR brut și cadre incompatibile.

## Utilizare

1. Apasă **Scanează Pagina Liniar (OCR Continuous)** și acordă accesul la
   cameră.
2. Ține textul lizibil în cadru. Formele sunt procesate în ordinea OCR.
3. Pentru o axiomă cinematografică, imaginea locală apare automat și se
   schimbă prin crossfade odată cu sensul.
4. Atinge monolitul pentru a îngheța sensul și cadrul; butonul Play reia
   proiecția segmentului activ.
5. Atinge un sens din lista de zăvoare pentru a-l elimina sau folosește Reset
   pentru o sesiune complet nouă.

Panoul **Introducere manuală offline** folosește exact același reactor.

## Arhitectură

```text
lib/semantic_reactor.dart             reactor + AST + matrice semantică v2
lib/fuzer_atomic.dart                 API-ul românesc AtomicSemanticReactor
lib/cinema/                            profil CIN + catalog + proiector pur
lib/core/ocr_frame_accumulator.dart   stabilizare și reconciliere OCR
lib/ocr/                              cameră + conversie cadre + ML Kit local
lib/features/cinematic_stage.dart     scenă WebP, puls și playback
lib/features/semantic_home_page.dart  film, monolit, zăvor și controale
assets/cinema/scenes/                 patru scene WebP locale
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

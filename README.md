# Drujba Semantică — NO-LOSS

Aplicație Android Flutter offline pentru OCR local și sinteză semantică
integrativă liniară. Motorul păstrează un singur obiect semantic în evoluție:

```text
S₀ = ∅
Sₙ = F(Sₙ₋₁, Cₙ)
```

Fiecare contribuție `Cₙ` este integrată strict în ordinea textului. Rezultatul
afișat este sensul brut integrat al stării curente, nu un rezumat și nu o listă
de cuvinte-cheie.

Aplicația nu folosește LLM-uri, servicii cloud sau API-uri externe. APK-ul de
release nu declară permisiunea Android `INTERNET`.

## Principii NO-LOSS

- Nu există stop-words: prepozițiile, conjuncțiile, articolele, pronumele,
  negațiile, auxiliarele și cuantificatorii contribuie semantic.
- Fiecare apariție este păstrată; conceptele nu sunt deduplicate.
- Punctuația este tokenizată separat și integrată ca limită/forță semantică.
- Formele funcționale stabile sunt reprezentate ca operatori relaționali,
  unari sau de conectare.
- Ambiguitatea reală nu este ghicită; alternativele rămân explicite.
- Cuvintele din clase deschise rămân atomi lexicali dacă gramatica lor nu poate
  fi stabilită sigur local. Motorul nu inventează definiții sau completări.
- OCR-ul reconciliat pozițional poate reveni la `S_(k-1)` și relua calculul de
  la primul token corectat, eliminând reziduul unei citiri OCR greșite.

## Utilizare

1. Deschide aplicația și pornește scanarea OCR locală.
2. Acordă permisiunea pentru cameră.
3. Ține textul lizibil în cadru; un cadru este acceptat după stabilizare.
4. Urmărește panoul **SENS BRUT INTEGRAT** și formula stării curente.
5. Extinde **Trasare NO-LOSS** pentru a vedea contribuțiile `C₁...Cₙ`.
6. Pentru text introdus manual, oprește scanarea și folosește panoul offline.

## Arhitectură

```text
lib/core/romanian_rule_tagger.dart      analiză conservatoare a contribuțiilor
lib/core/pure_semantic_fuzer.dart       starea unică Sₙ și operatorul F
lib/core/ocr_frame_accumulator.dart     stabilizare + corecție pozițională OCR
lib/ocr/                                cameră + OCR ML Kit local
lib/features/semantic_home_page.dart    vizualizare sens brut în timp real
test/                                   teste unitare și widget
.github/workflows/android.yml            analiză, teste și build release
```

Contractul semantic detaliat este în [`SEMANTIC-SPEC.md`](SEMANTIC-SPEC.md).

## Compilare locală

Cerințe: Flutter 3.47.0, Dart 3.12+, JDK 17 și Android SDK 36.

```bash
flutter pub get
flutter analyze
fluttter test
flutter build apk --release
```

APK-ul rezultat este:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Build automat pe GitHub

Workflow-ul Android CI rulează formatarea, analiza statică, testele, compilarea
release și verificarea manifestului. APK-ul rezultat este publicat ca artifact
al rulării.

## Confidențialitate

- Sunt solicitate doar camera și capabilitatea hardware aferentă.
- Cadrele sunt procesate în memorie pe dispozitiv.
- Nu se păstrează fotografii și nu se trimit date în rețea.
- Oprirea scanării eliberează camera.

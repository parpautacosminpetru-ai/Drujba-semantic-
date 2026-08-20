# Semantic state contract — v1.1 NO-LOSS

For token contributions `C₁ ... Cₙ`, the engine maintains exactly one evolving
object:

`S₀ = ∅`

`Sₙ = F(Sₙ₋₁, Cₙ)`

`F` is deterministic and left-to-right. A contribution is never skipped because
it is a function word, never deduplicated because it appeared before, and never
completed from future text.

Closed-class Romanian forms become explicit operators when their grammatical
contribution is stable enough to state locally: prepositions become relations,
conjunctions become connectors, negation becomes a unary operator, determiners
open a modifier scope, possessives modify the current right edge, and punctuation
is retained as a semantic boundary/force contribution. Genuine ambiguity is
serialized as alternatives separated by `/` rather than resolved by prediction.

Open-class words are preserved as lexical atoms. This patch intentionally does
not invent dictionary definitions or POS tags from weak suffix heuristics.

For OCR, a stable corrected frame is reconciled by longest common prefix. If the
first changed token is `k`, the engine restores `S_(k-1)` and replays the corrected
suffix in original order. This prevents semantic residue from an earlier OCR
misread.

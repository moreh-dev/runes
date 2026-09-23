This repository contains moreh-specific agent skills.

The initial skills in `plugins/runes/skills/` and hook bootstrap files in `plugins/runes/hooks/` were copied or adapted from `obra/superpowers`:
https://github.com/obra/superpowers

Skills copied from upstream commit:
f2cbfbefebbfef77321e4c9abc9e949826bea9d7

Hook bootstrap files adapted from upstream commit:
6fd4507659784c351abbd2bc264c7162cfd386dc

Original Superpowers material:
Copyright (c) 2025 Jesse Vincent
Licensed under the MIT License. See `third_party/superpowers/LICENSE`.

Moreh modifications and original Moreh skills:
Copyright (c) 2026 Moreh

The `review-with-google-mind` skill in `skills/review-with-google-mind/` and `plugins/runes/skills/review-with-google-mind/`
bundles material adapted from Google's Engineering Practices documentation
(the Code Reviewer's Guide and the CL Author's Guide):
https://github.com/google/eng-practices

Original Google material:
Copyright (c) Google LLC
Licensed under the Creative Commons Attribution 3.0 License (CC BY 3.0):
https://creativecommons.org/licenses/by/3.0/

The bundled SKILL.md summary and `references/` guides are adapted/distilled from the
originals, not verbatim reproductions.

The `writing-korean` skill in `skills/writing-korean/` and `plugins/runes/skills/writing-korean/`
combines and adapts writing rules from two projects. It is not a verbatim reproduction of
either: a subset of rules was selected, merged, and adjusted where the two conflict.

`SKILL.md` adapts the writing guidelines of the `fluent-korean` output style:
https://github.com/snflkd/fluent-korean
Adapted from upstream commit:
ce8683f0eba8cddb91de4dcd151425ff73e60498
Copyright (c) 2026 snflkd
Licensed under the MIT License. See `third_party/fluent-korean/LICENSE`.
Not included: the Sino-Korean vocabulary clause and the subagent prompt check clause.

`SKILL.md` (revision rules) and `ai-tell-patterns.md` adapt the pattern taxonomy and
revision rules of the `humanize-korean` skill in `im-not-ai`:
https://github.com/epoko77-ai/im-not-ai
Adapted from upstream commit:
fe02c9cf34ae0cd40228932d758f1cf94d689c99
Copyright (c) 2026 epoko77-ai
Licensed under the MIT License. See `third_party/im-not-ai/LICENSE`.
Only the rule text is adapted. The scoring scripts, subagent pipeline, change-rate gate,
quality grades, and column/essay-only patterns are not included.
Sections of `ai-tell-patterns.md` map to these pattern IDs in upstream
`skills/humanize-korean/references/quick-rules.md`:
- 번역투: A-1, A-3, A-5, A-7, A-8, A-9, A-11, A-15, A-18, A-19, A-21
- 영어 용어: B-1, B-2
- 구조: C-7, C-8, C-11
- 상투구: D-1, D-2, D-3, D-8, D-9, D-11, D-12
- 완곡과 형식명사: G-1, G-2, I-2, I-3, I-7
- 시각 장식: C-5, J-1, J-2, J-3

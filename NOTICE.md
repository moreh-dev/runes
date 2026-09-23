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

The `fluent-korean` output style in `plugins/runes/output-styles/fluent-korean.md`
was copied from `snflkd/fluent-korean`:
https://github.com/snflkd/fluent-korean

Output style copied from upstream commit:
ce8683f0eba8cddb91de4dcd151425ff73e60498

The only modification is the added `force-for-plugin: true` frontmatter field,
which applies the style automatically whenever runes is enabled.

Original fluent-korean material:
Copyright (c) 2026 snflkd
Licensed under the MIT License. See `third_party/fluent-korean/LICENSE`.

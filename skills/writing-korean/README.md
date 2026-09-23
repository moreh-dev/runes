# writing-korean

이 문서는 스킬을 관리하는 사람을 위한 설명입니다. 에이전트가 읽는 지시문은 `SKILL.md`와 `ai-tell-patterns.md`에 있습니다.

## 출처

이 스킬은 두 프로젝트의 규칙을 합치고, 두 규칙이 충돌하는 지점을 조정한 것입니다. 두 프로젝트 모두 MIT 라이선스이며, 라이선스 원문은 `third_party/`에, 저작권 표기는 저장소 루트의 `NOTICE.md`에 있습니다.

| 원본 | 기준 커밋 | 가져온 것 | 들어간 곳 |
|---|---|---|---|
| [snflkd/fluent-korean](https://github.com/snflkd/fluent-korean)의 `fluent-korean.md` output style | `ce8683f` | 문장 성분과 조사, 어미를 생략하지 않는 규칙, 비유적 어휘와 엠대시를 자제하는 규칙, 외국어와 코드 텍스트의 적용 범위 | `SKILL.md`의 "쓸 때의 규칙" |
| [epoko77-ai/im-not-ai](https://github.com/epoko77-ai/im-not-ai)의 `humanize-korean` 스킬 | `fe02c9c` | AI 티 패턴 분류와 처방, 서법 보존, 원문에 없는 내용을 넣지 않는 규칙, 다듬은 뒤 점검 항목 | `SKILL.md`의 "남의 글을 다듬을 때의 규칙", `ai-tell-patterns.md` |

im-not-ai에서는 규칙 문구만 가져왔습니다. Python 채점 스크립트, 서브에이전트 파이프라인, `_workspace/` 작업 폴더는 포함하지 않습니다.

## 두 원본이 충돌하는 지점과 조정 결과

| 쟁점 | fluent-korean | humanize-korean | 이 스킬 |
|---|---|---|---|
| 목록 | 헤더와 목록에는 문장 종결 규칙을 강제하지 않습니다. | 해당 없음 | 서술을 담은 항목은 문장으로 끝내고, 이름과 값만 나열하는 항목은 명사로 끝내도 됩니다. |
| "짧게" 요청 | 문장 성분을 생략하지 않습니다. | 군더더기를 뺍니다. | 문장의 개수를 줄이고, 남긴 문장은 온전하게 씁니다. |
| 부사와 수식어 | 적극적으로 활용합니다. | 과하게 쓰지 않습니다. | 정보를 더할 때만 씁니다. |
| 격식 | 사용자의 어조를 따라 하지 않습니다. | 원문의 격식을 보존합니다. | 직접 쓸 때는 한 문서 안에서 문체를 하나로 유지하고, 다듬을 때는 원문의 격식을 따릅니다. |

## 포함하지 않은 것

- fluent-korean의 한자어 활용 조항과 서브에이전트 프롬프트 점검 조항
- im-not-ai의 칼럼과 에세이 전용 패턴(문장 리듬, 에세이 결말, 감각 술어 등)과 정량 채점 기준(변경률 게이트, 품질 등급)

## `ai-tell-patterns.md`와 원본 패턴 ID의 대응

`ai-tell-patterns.md`의 각 절은 im-not-ai `skills/humanize-korean/references/quick-rules.md`의 다음 패턴에서 옮겼습니다. upstream이 바뀌면 이 ID를 기준으로 비교합니다.

| 절 | 원본 패턴 ID |
|---|---|
| 번역투 | A-1, A-3, A-5, A-7, A-8, A-9, A-11, A-15, A-18, A-19, A-21 |
| 영어 용어 | B-1, B-2 |
| 구조 | C-7, C-8, C-11 |
| 상투구 | D-1, D-2, D-3, D-8, D-9, D-11, D-12 |
| 완곡과 형식명사 | G-1, G-2, I-2, I-3, I-7 |
| 시각 장식 | C-5, J-1, J-2, J-3 |

## 고칠 때

`skills/writing-korean/`과 `plugins/runes/skills/writing-korean/`은 같은 내용이어야 합니다. 한쪽을 고치면 다른 쪽에도 반영하고 `scripts/check-skills-sync.sh`로 확인합니다.

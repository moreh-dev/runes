# Agent Conventions

이 저장소는 Claude Code 의 skills (custom sub-agents) 모음입니다. Claude 가 이
저장소 또는 이 skills 를 사용하는 다운스트림 저장소에서 작업할 때 아래 문서
역할 분리를 따라야 합니다.

## 세 디렉토리의 역할

| Directory | Role | Author | Naming | Decay |
|-----------|------|--------|--------|-------|
| `docs/PRDs/` | business logic only — 우리가 무엇을 원하고 왜 원하는가 | Human-curated | `<주제>.md` | Evergreen — 항상 최신 상태로 유지 |
| `docs/specs/` | business logic + implementation snapshot at a point in time | Claude (사람 승인) | `YYYY-MM-DD-<주제>.md` | 허용 — stale 해지면 새 dated 파일 생성 |
| `docs/plans/` | 작업 실행 순서 (ordered task list) | Claude | `YYYY-MM-DD-<feature-name>.md` | 허용 — 실행 완료 후 archive |

## 작성 원칙

1. **PRD 는 read-mostly.** 파일 경로, 함수 시그니처, status 필드 shape 같은
   implementation detail 은 PRD 에 적지 않습니다. 이런 내용은 `docs/specs/` 의
   dated 파일에 적습니다.
2. **PRD 에 drift history 를 남기지 않습니다.** "used to do A, now B" 식 변경
   이력을 PRD 에 누적시키지 않습니다. PRD 는 현재 target 만 기술하고, 변경
   이력은 dated `docs/specs/` 가 진원입니다.
3. **Dated snapshot 은 stale 하면 새 파일을 만듭니다.** 기존 파일은 frozen
   snapshot 으로 두고, 최신 사고는 새 dated 파일에 적습니다. 옛 파일을
   덮어쓰지 않습니다.
4. **Skill 별 산출물 위치**:
   - `skills/brainstorming/` → `docs/specs/YYYY-MM-DD-<topic>-design.md`
   - `skills/writing-plans/` → `docs/plans/YYYY-MM-DD-<feature-name>.md`
   - `docs/PRDs/` 는 어떤 skill 도 자동 생성하지 않습니다 (human-curated).

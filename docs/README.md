# rentcar00_OPS docs

## 바로 볼 문서
1. `docs/current/rentcar00_OPS-current.md`
   - 지금 실제로 실행 중인 작업 1건
2. `docs/current/rentcar00_OPS-main.md`
   - 프로젝트 전체 구조 / 정책 / 운영 기준 / 현재 baseline
3. `docs/completed/rentcar00_OPS-completed.md`
   - 완료된 기능의 운영/검증/장애 대응 누적

## 폴더 역할
- `docs/current/`
  - active 문서만 둔다
  - `current`: 현재 실행 작업 1건
  - `main`: 전체 기준 문서 1건
- `docs/completed/`
  - 완료 기능 단일 누적 문서
- `docs/past/`
  - 과거 설계 / 아이디어 / 스냅샷 / 구버전 문서 보관

## past 하위 정리 기준
- `root-current-2026-05-12/`
  - 예전 root 기준 문서 묶음
- `consolidated-2026-05-06/`
  - 초반 통폐합 전후 설계 초안 묶음
- `doc-slim-2026-05-10/`
  - 레이어별 세부 설계/런북 구버전 묶음
- `snapshots-current-2026-05-14/`
  - 교체된 current 스냅샷 묶음
- `snapshots-current-2026-05-15/`
  - raw 재구성 실행문서 스냅샷
- `roadmap-archives-2026-05-14/`
  - 완료된 roadmap archive
- `legacy-setup/`
  - 초기 셋업/과거 진행 정리

## 잠금 규칙
- current에는 실행 문서 1개만 유지한다.
- main에는 현재 유효한 기준만 남긴다.
- completed에는 완료 사실만 누적한다.
- 더 이상 안 쓰는 설계, 스냅샷, 아이디어 문서는 새로 current/main에 두지 않고 `past`로 보낸다.

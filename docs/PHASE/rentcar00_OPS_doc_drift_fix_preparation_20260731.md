# rentcar00_OPS 전체 상태 문서 드리프트 수정 준비

- Date: 2026-07-31
- Status: prepared
- Scope: 문서 기준점 정리 준비. 코드/DB/deploy/commit 범위 아님

## 목적
현재 repo의 실제 상태와 active 문서 기준이 일부 어긋나 있다.
이 문서는 전체 문서 드리프트를 한 번에 정리하기 전, 확인된 사실과 수정 후보를 고정한다.

## 확인된 현재 상태
- repository: `rentcar00_OPS`
- branch: `fix/ops-return-complete-end-at`
- HEAD: `b8c87cb fix: refresh cancellation notices in realtime`
- `pubspec.yaml`: `version: 1.0.0+58`
- 최신 완료 배포 기록: b57
  - 문서: `docs/COMPLETED/rentcar00_OPS-completed.md`
  - APK: `rentcar00_ops-app-release-arm64-b57-5d4183b.apk`
- 2026-07-31 parser runtime:
  - 이전 PID: `22718`
  - final active PID: `53630`
  - bind: `127.0.0.1:43110`
  - health: OK
- 2026-07-31 parser hotfix:
  - IMS 보험배차 claim list row에 반납일이 없으면 detail API의 `expect_return_date`를 사용
  - 실확인: `2026-07-31 / 20하3779 / claimId 3136931`
  - 결과: `returnAt = 2026-08-07 15:42`

## 확인된 드리프트 후보

### 1. GOAL current의 앱/APK 기준
`docs/GOAL/rentcar00_OPS-current.md`에 과거 b55 기준이 남아 있었다.
이번 hotfix 문서화에서 현재 기준점은 다음으로 갱신했다.

```txt
HEAD: b8c87cb
working tree app version/build: 1.0.0+58
latest completed APK record: b57
parser runtime: final active PID 53630
```

### 2. PHASE README의 최신 배포 표기
`docs/PHASE/README.md` 일부 항목이 최신 직원 배포를 b55로 설명한다.
완료 문서 기준 최신 완료 배포는 b57이다.

수정 준비:
- `최신 직원 배포본은 b55다` 표현을 b57 기준으로 정리
- Parser API Auth Hardening PM은 완료 기록과 active PM 상태가 섞여 있으므로 완료/보류 범위를 재분류

### 3. HARNESS 문서의 오래된 기준점
`docs/HARNESS/PM_HARNESS_CHECK.md`는 HEAD `f0ea3c1`, 앱 `1.0.0+49`를 현재 기준으로 들고 있다.

수정 준비:
- HARNESS 폴더가 현재 문서 구조 규칙(`GOAL / PHASE / COMPLETED / ARCHIVE`) 밖에 있으므로 active 기준으로 계속 쓸지 결정 필요
- 계속 쓰면 현재 HEAD/build/runtime 기준으로 갱신
- 더 이상 active가 아니면 ARCHIVE 이동 후보

### 4. 과거 GOAL snapshot
`docs/GOAL/rentcar00_OPS-and-homepage-implementation-status-2026-06-11.md`는 `1.0.0+49` 기준의 날짜별 snapshot이다.

수정 준비:
- active current 문서가 아니면 ARCHIVE 이동 후보
- 남길 경우 상단에 `historical snapshot` 표시

### 5. PHASE에 남은 완료성 문서
Parser API Auth Hardening은 완료 문서에 b56으로 기록되어 있지만 PHASE에도 operational pending 설명이 남아 있다.

수정 준비:
- 완료 범위는 `docs/COMPLETED/rentcar00_OPS-completed.md` 기준으로 유지
- 남은 보안/Cloudflare 후속만 별도 PHASE로 남기거나 기존 PM을 ARCHIVE 이동

### 6. 2026-07-30 IMS 반납예정일 write issue
`docs/PHASE/rentcar00_OPS_ims_linked_return_date_update_issue_20260730.md`는 OPS에서 반납일을 바꿀 때 IMS 반납예정일을 같이 write해야 하는 별도 issue다.

이번 `2026-07-31` hotfix와 구분:
- 이번 완료: 보험배차 import 조회 시 반납예정일 read fallback
- 남은 issue: OPS 반납일 수정 시 IMS 반납예정일 write 동기화

## 다음 수정안
전체 드리프트 정리는 별도 승인 후 아래 순서로 진행한다.

1. active current 문서 1개만 남기고 오래된 GOAL snapshot을 ARCHIVE 후보로 이동
2. PHASE README에서 완료/진행/보류 상태를 현재 완료 문서 기준으로 재분류
3. HARNESS 문서의 유지 여부 결정 후 갱신 또는 ARCHIVE 이동
4. Parser/Auth 완료 상태와 Cloudflare 후속 상태 분리
5. IMS read hotfix와 IMS write issue를 서로 다른 문서로 명확히 분리
6. `rg -n "1\\.0\\.0\\+49|1\\.0\\.0\\+55|최신 직원 배포본은 b55|HEAD \`f0ea3c1\`|APK code commit"` 결과 기준으로 남은 stale 표현 정리

## 금지
- 문서 드리프트 정리 중 코드, DB, parser runtime, APK, 외부 저장소 상태를 변경하지 않는다.
- 과거 완료 문서를 현재 기준처럼 덮어쓰지 않는다. 완료 당시 사실은 보존한다.
- historical snapshot은 삭제보다 ARCHIVE 이동 또는 historical 표시를 우선한다.

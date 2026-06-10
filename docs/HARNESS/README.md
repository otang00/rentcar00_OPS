# HARNESS 문서

이 폴더는 `rentcar00_OPS`를 상태·이벤트·owner·runtime 경계 기준으로 정리한다.

기본 문서:
- `PM_HARNESS_CHECK.md`
- `CURRENT_STATE_MAP.md`
- `CURRENT_EVENT_FLOW_MAP.md`
- `CURRENT_GUARDRAIL_LOG.md`

파생 문서:
- `CURRENT_RUNTIME_LOOP_MAP.md`
- `CURRENT_UI_API_BOUNDARY_MAP.md`

현재 판단:
- OPS 앱 자체는 운영 MVP 수준까지 구현되어 있다.
- 다음 위험 지점은 홈페이지 실제 송신부 확인, 가격 정책 owner 확정, 미커밋 변경 포함 여부, IMS live command 보상 흐름이다.

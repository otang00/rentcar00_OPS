# rentcar00_OPS Master Checklist

## 1. 기준 잠금
- [x] 제품 기준 문서 정리
- [x] 설계 기준 문서 정리
- [x] Supabase 구조 초안 정리
- [x] 네이밍/키 규칙 정리
- [x] Google Sheets write 금지 원칙 반영

## 2. 앱 골격
- [x] Flutter 프로젝트 생성
- [x] go_router 기반 메인 라우팅 구성
- [x] Riverpod 기반 상태 주입 구조 구성
- [x] 메인 5탭 구조 구성
- [x] 공용 상세 화면 골격 구성
- [x] Sync/Search 화면 골격 구성
- [x] Mock repository 기반 샘플 흐름 연결

## 3. 메인 리스트 UI
- [x] 탭별 리스트 렌더링
- [x] 한 줄 중심의 얇은 카드 형태 적용
- [x] 핵심 배지 1~2개 축약 노출
- [x] 상세 진입 연결

## 4. Supabase 준비
- [x] Supabase 프로젝트 생성 (`rentcar00-ops`)
- [x] 프로젝트 ref / URL 확보
- [x] 앱용 env 와 작업용 secret env 분리
- [x] Flutter dotenv 연결
- [x] Supabase client 초기화
- [x] Supabase 연결 검증
- [x] 로컬 Supabase 프로젝트 link 완료

## 5. 데이터 계층
- [x] DB 생성 순서 기준 문서 작성
- [x] Supabase 스키마 SQL 초안 실제화
- [x] migration 뼈대 생성
- [x] `rc00_ops_sheet_sync_runs` 생성 SQL 작성
- [x] raw reservations 테이블 생성 SQL 작성
- [x] raw schedules 테이블 생성 SQL 작성
- [x] reservations projection 테이블 생성 SQL 작성
- [x] reservation_states 테이블 생성 SQL 작성
- [x] action_logs / outbox 테이블 생성 SQL 작성
- [x] 원격 DB migration 적용
- [x] repository 를 mock → supabase 로 교체
- [x] `status_raw + tab_key` 기준으로 projection/state 구조 단순화

## 6. Sync
- [x] Google Sheets read-only importer 설계 확정
- [x] 수동 sync 진입점 구성
- [x] raw import 실행
- [x] 정규화 mapper 연결
- [x] 실제 리스트 데이터 반영
- [x] 새 규칙 기준 재정규화 실행

## 7. 이후 단계
- [ ] action / check / status 로직 연결
- [ ] outbox dry-run 연결
- [ ] 운영 테스트 기준 정리
- [ ] 최종 승인 전까지 Sheets write 금지 유지

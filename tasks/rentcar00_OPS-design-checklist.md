# rentcar00_OPS Design Checklist

## 현재 잠긴 결정
- [x] 메인 탭은 5개 고정
- [x] 상세 화면은 공용 1개 구조
- [x] 상태 source of truth 는 `rc00_ops_reservation_states`
- [x] 시트 원본은 `예약` + `일정`
- [x] 예약 원장 생성 기준은 `예약` 탭 only
- [x] 일정 연결 우선순위는 `reservation_id -> reservation_number unique -> orphan`
- [x] 메인 카드는 한 줄 중심 얇은 카드
- [x] 배지는 리스트에서 약어 중심으로 축약
- [x] 앱은 시트를 직접 실시간 조회하지 않고 Supabase를 경유
- [x] 앱은 공개 key 만 사용하고 secret 은 작업/서버용으로 분리

## 다음 구현 전 확인할 것
- [ ] Flutter에서 env 로드 방식 확정
- [ ] Supabase 초기화 위치 확정
- [ ] 공개 env 항목 최소셋 확정
- [ ] 스키마 생성 순서 확정
- [ ] 첫 연결 검증 방식 확정

## 다음 착수 순서
1. dotenv 연결
2. Supabase client 초기화
3. 연결 확인
4. 스키마 생성
5. repository 교체
6. sync read-only importer 착수

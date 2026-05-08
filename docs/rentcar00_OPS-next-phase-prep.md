# rentcar00_OPS Next Phase Prep

## 목표
다음 작업은 Flutter 앱이 Supabase 공개 설정을 읽고, 실제 Supabase client 를 초기화한 뒤, 스키마 작업으로 넘어갈 준비를 끝내는 것이다.

## 현재 기준
- Supabase 프로젝트 생성 완료
  - name: `rentcar00-ops`
  - ref: `wojisucidqzjrqbuiikl`
  - region: `ap-northeast-2 (Seoul)`
- 앱용 공개 env 와 작업용 secret env 를 분리했다.
- 앱 메인 리스트는 한 줄 중심 카드로 축약 완료했다.
- 현재 데이터 공급자는 mock repository 다.

## 다음 phase 범위
1. `flutter_dotenv` 연결
2. 공개 env 로드
3. Supabase Flutter client 초기화
4. analyze / test 통과
5. 연결 확인 후 스키마 생성 phase 로 이동

## 공개 env 원칙
앱 번들에 포함 가능한 값만 앱용 env 에 둔다.
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_PUBLISHABLE_KEY`

앱 번들에 넣지 말아야 하는 값은 작업/서버용으로만 둔다.
- DB password
- service role
- Google service account / API secret

## 완료 조건
- 앱 시작 시 공개 env 로드 성공
- Supabase client 초기화 성공
- analyze / test 통과
- 이후 스키마 작업에 바로 들어갈 수 있는 상태 확보

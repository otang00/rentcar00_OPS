# rentcar00_OPS 환경구성 실행 계획

## 목적
- Flutter 기반 Android 앱 개발 환경 구성
- 워크스페이스 `projects/rentcar00_OPS` 생성
- GitHub 저장소 `otang00/rentcar00_OPS` 연결
- Android 실기기 또는 에뮬레이터에서 기본 앱 실행 가능한 상태 확보

## 기준점
- 작업공간: `/Users/otang_server/.openclaw/workspace`
- 프로젝트 경로: `/Users/otang_server/.openclaw/workspace/projects/rentcar00_OPS`
- GitHub 저장소: `https://github.com/otang00/rentcar00_OPS`
- 현재 확인 상태
  - Flutter 3.41.9 설치 완료
  - Android Studio 설치 완료
  - Android Studio 내장 JBR 사용 가능
  - Android SDK root: `/opt/homebrew/share/android-commandlinetools`
  - 프로젝트 로컬 폴더 생성 완료
  - GitHub remote 연결 완료

## Phase 1. 로컬 도구 설치
### 작업
- Flutter 설치
- Android Studio 설치
- 이후 Android SDK / emulator / platform-tools 설치 준비

### 종료 조건
- `flutter --version` 성공
- `/Applications/Android Studio.app` 존재

## Phase 2. Flutter 진단
### 작업
- `flutter doctor -v`
- 부족 항목 식별
- Android license / SDK 관련 수동 단계 분리

### 종료 조건
- 자동 설치 가능한 항목과 수동 항목 분리 완료

## Phase 3. 프로젝트 워크스페이스 구성
### 작업
- `projects/rentcar00_OPS` clone
- git remote 확인
- 빈 저장소 여부 확인

### 종료 조건
- 로컬 저장소 준비 완료

## Phase 4. Flutter 앱 초기 생성
### 작업
- 저장소가 비어 있으면 `flutter create . --org com.rentcar00 --platforms=android`
- 기본 구조 생성

### 종료 조건
- `pubspec.yaml`, `lib/`, `android/` 생성

## Phase 5. 실행 검증 준비
### 작업
- `flutter pub get` 완료
- `flutter devices` 확인
- Android Studio 내 SDK/AVD 또는 실기기 연결 단계 안내
- 현재 Android toolchain / licenses 완료

### 종료 조건
- Android 실기기 또는 에뮬레이터 1대 인식 시 `flutter run` 가능한 상태

## 리스크
- Android Studio 설치 시간이 김
- SDK/License 일부는 GUI 또는 추가 승인 필요 가능성
- GitHub 저장소가 비어 있지 않으면 초기 생성 방식 조정 필요

## 검증
- `flutter --version`
- `flutter doctor -v`
- `git remote -v`
- 프로젝트 파일 구조 확인

## 되돌리기
- `projects/rentcar00_OPS` 삭제
- brew cask 제거
- 생성 파일 git reset

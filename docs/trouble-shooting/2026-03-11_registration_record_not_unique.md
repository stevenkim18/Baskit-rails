# 회원가입 중복 요청 시 RecordNotUnique 문제

## 발생할 수 있는 문제

같은 이메일로 회원가입 요청이 거의 동시에 두 번 들어오면 서버가 `500 Internal Server Error`를 반환할 수 있다.

## 재현 조건

- 동일한 이메일 주소로 회원가입 요청이 동시에 들어온다.
- 애플리케이션 레벨 validation을 두 요청이 모두 통과한다.
- DB unique index 저장 시점에 한 요청이 뒤늦게 충돌한다.

## 원인

애플리케이션 레벨의 `validates :email, uniqueness: true`는 경쟁 상태를 완전히 막지 못한다.

최종 보장은 DB unique index가 하게 되는데, 여기서 `ActiveRecord::RecordNotUnique`가 발생하면 현재 구현은 이를 처리하지 못하고 `500`으로 흘러간다.

## 해결 방법

`ActiveRecord::RecordNotUnique`를 잡아서 클라이언트가 이해할 수 있는 `422 validation_error` 응답으로 변환한다.

## 수정 포인트

- `app/controllers/api/v1/auth/email_registrations_controller.rb`

## 확인 방법

1. 이미 존재하는 이메일로 다시 회원가입 요청
2. 또는 동시 요청 시뮬레이션으로 unique index 충돌 유도
3. 응답이 `500`이 아니라 `422 validation_error`인지 확인

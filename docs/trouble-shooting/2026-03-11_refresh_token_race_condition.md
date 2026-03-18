# refresh token 회전 동시성 문제

## 발생할 수 있는 문제

같은 refresh token으로 거의 동시에 두 번 `POST /api/v1/auth/refresh` 요청이 들어오면, 두 요청이 모두 성공할 수 있다.

## 재현 조건

- 아직 만료되지 않았고 revoke되지 않은 refresh token이 있다.
- 같은 token 값으로 refresh 요청이 매우 짧은 간격으로 2번 이상 들어온다.

## 원인

기존 구현은 아래 순서였다.

1. token digest로 refresh token 조회
2. active 상태 확인
3. revoke 처리
4. 새 refresh token 발급

문제는 1번과 3번 사이에 다른 요청이 끼어들 수 있다는 점이다.

즉, 두 요청이 모두 active 상태를 본 뒤 각각 새 토큰을 발급할 수 있다.

## 해결 방법

트랜잭션 안에서 refresh token row를 잠그고 처리한다.

예시:

- `lock` 또는 `SELECT ... FOR UPDATE`
- 잠금 이후 active 상태를 다시 확인
- 그 다음 revoke 및 새 token 발급

이렇게 하면 한 요청이 처리되는 동안 다른 요청은 같은 row를 동시에 회전시킬 수 없다.

## 수정 포인트

- `app/services/auth/refresh_token_rotator.rb`

## 확인 방법

1. 같은 refresh token으로 두 번 연속 refresh 호출
2. 첫 요청만 성공하고, 이후 재사용 요청은 실패하는지 확인
3. DB에 활성 refresh token이 의도한 개수만 남는지 확인

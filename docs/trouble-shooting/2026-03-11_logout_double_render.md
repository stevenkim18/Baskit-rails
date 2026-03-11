# 로그아웃 API 이중 렌더링 문제

## 발생할 수 있는 문제

`DELETE /api/v1/auth/session` 호출 시 Rails에서 `AbstractController::DoubleRenderError`가 발생할 수 있다.

## 재현 조건

- 로그인된 사용자가 `Authorization: Bearer <access_token>`를 보낸다.
- 본인 것이 아닌 다른 사용자의 `refresh_token`을 함께 보낸다.

## 원인

`SessionsController#destroy`에서 `revoke_one_token!`이 먼저 `render_unauthorized`를 호출해도, 메서드가 계속 진행되어 마지막에 `head :no_content`를 다시 호출한다.

즉, 한 요청에서 응답을 두 번 보내려고 해서 이중 렌더링이 발생한다.

## 해결 방법

아래 둘 중 하나로 막는다.

1. `revoke_one_token!` 이후 `performed?`를 확인하고 즉시 종료한다.
2. 권한 불일치 시 예외를 발생시키고 상위에서 한 번만 처리한다.

이번 수정에서는 구현이 단순한 `performed?` 방식으로 처리한다.

## 수정 포인트

- `app/controllers/api/v1/auth/sessions_controller.rb`

## 확인 방법

1. 다른 사용자 소유의 `refresh_token`을 넣어 `DELETE /api/v1/auth/session` 호출
2. 응답이 `401 unauthorized` 하나만 내려오는지 확인
3. 서버 로그에 `DoubleRenderError`가 없는지 확인

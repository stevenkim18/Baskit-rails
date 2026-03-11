# 로그인 기능 구현 가이드

이 문서는 Rails API에서 이메일 로그인 기능을 처음 구현할 때 따라갈 순서를 정리한 것이다.

대상 범위:

- 이메일 회원가입
- 이메일 로그인
- access token 재발급
- 로그아웃

이번 단계에서는 소셜 로그인은 다루지 않는다.

## 1. 먼저 만들 기능 흐름 이해하기

로그인 기능은 아래 순서로 동작한다.

1. 사용자가 이메일과 비밀번호로 회원가입한다.
2. 서버가 `User`를 만들고 이메일 로그인용 `Identity`를 만든다.
3. 사용자가 로그인하면 access token과 refresh token을 발급한다.
4. access token이 만료되면 refresh token으로 새 토큰을 발급한다.
5. 로그아웃하면 refresh token을 무효화한다.

핵심은 `User` 하나만으로 끝나는 구조가 아니라는 점이다.

- `User`: 사용자 계정 본체
- `Identity`: 로그인 수단 정보
- `RefreshToken`: 로그인 세션 정보

## 2. 모델 관계 먼저 이해하기

관계는 아래와 같다.

- `User` has_many `identities`
- `User` has_many `refresh_tokens`
- `Identity` belongs_to `user`
- `RefreshToken` belongs_to `user`

즉, `User`가 중심이고 `Identity`, `RefreshToken`이 `user_id`로 연결된다.

예시:

- 같은 사용자가 이메일 로그인 하나만 쓰면 `identities`는 1개
- 나중에 Apple 로그인까지 붙이면 `identities`는 2개
- 같은 사용자가 iPhone, iPad 두 기기에서 로그인하면 `refresh_tokens`는 2개

## 3. 만들 엔드포인트 정리

이번 범위에서 만들 엔드포인트는 4개다.

### 3-1. 회원가입

- `POST /api/v1/auth/email/register`

역할:

- 이메일 중복 검사
- 사용자 생성
- 이메일 로그인용 identity 생성

### 3-2. 로그인

- `POST /api/v1/auth/email/login`

역할:

- 이메일/비밀번호 검증
- access token 발급
- refresh token 발급

### 3-3. 토큰 재발급

- `POST /api/v1/auth/refresh`

역할:

- refresh token 검증
- 새 access token 발급
- 새 refresh token 발급
- 기존 refresh token 회전 처리

### 3-4. 로그아웃

- `DELETE /api/v1/auth/session`

역할:

- 현재 refresh token 무효화

## 4. 구현 순서

Rails에서는 아래 순서로 만드는 것이 가장 덜 헷갈린다.

1. 마이그레이션 작성
2. 모델 작성
3. 토큰 서비스 작성
4. 인증용 base controller 작성
5. 라우트 작성
6. auth controller 작성
7. request spec 작성

컨트롤러부터 바로 만들면 중간에 모델과 토큰 구조가 자꾸 바뀌어서 비효율적이다.

## 5. 1단계: 마이그레이션 만들기

먼저 아래 3개 테이블을 만든다.

- `users`
- `identities`
- `refresh_tokens`

권장 명령어:

```bash
bin/rails generate migration CreateUsers
bin/rails generate migration CreateIdentities
bin/rails generate migration CreateRefreshTokens
```

### 5-1. users 테이블에 필요한 컬럼

- `display_name`
- `email`
- `password_digest`
- `email_verified`
- `deleted_at`
- timestamps

중요한 점:

- `password_digest`는 `has_secure_password`용이다.
- 실제 비밀번호를 저장하면 안 된다.
- `email`은 unique index가 필요하다.

### 5-2. identities 테이블에 필요한 컬럼

- `user_id`
- `provider`
- `provider_uid`
- `email`
- `profile`
- `last_used_at`
- timestamps

중요한 점:

- `(provider, provider_uid)`는 unique index가 필요하다.
- 이메일 로그인도 `provider: "email"`로 저장한다.

### 5-3. refresh_tokens 테이블에 필요한 컬럼

- `user_id`
- `token_digest`
- `device_name`
- `last_used_ip`
- `expires_at`
- `revoked_at`
- timestamps

중요한 점:

- 평문 refresh token은 저장하지 않는다.
- DB에는 digest만 저장한다.

### 5-4. 마이그레이션 적용

```bash
bin/rails db:migrate
```

## 6. 2단계: 모델 작성

파일 위치:

- `app/models/user.rb`
- `app/models/identity.rb`
- `app/models/refresh_token.rb`

### 6-1. User 모델

필요한 내용:

- `has_many :identities`
- `has_many :refresh_tokens`
- `has_secure_password`
- 이메일 validation

### 6-2. Identity 모델

필요한 내용:

- `belongs_to :user`
- `provider`, `provider_uid` validation

### 6-3. RefreshToken 모델

필요한 내용:

- `belongs_to :user`
- 만료 여부 확인 메서드
- revoke 여부 확인 메서드

예를 들면 나중에 아래 같은 메서드가 생긴다.

- `expired?`
- `revoked?`
- `active?`

## 7. 3단계: 토큰 관련 서비스 작성

JWT와 refresh token 로직은 컨트롤러에 직접 넣지 않는 편이 낫다.

권장 파일:

- `app/services/auth/access_token.rb`
- `app/services/auth/refresh_token_issuer.rb`
- `app/services/auth/refresh_token_rotator.rb`

### 7-1. access token 서비스

역할:

- JWT 발급
- JWT decode
- payload에 `user_id`, `exp` 포함

### 7-2. refresh token 발급 서비스

역할:

- 랜덤 토큰 생성
- digest 계산
- DB 저장
- 평문 토큰은 클라이언트 응답으로만 사용

### 7-3. refresh token 회전 서비스

역할:

- 기존 refresh token 검증
- 새 refresh token 발급
- 기존 token revoke 처리

## 8. 4단계: 인증용 베이스 컨트롤러 만들기

권장 파일:

- `app/controllers/api/v1/base_controller.rb`

여기에 먼저 넣을 것:

- `authenticate_user!`
- `current_user`
- Authorization 헤더 파싱
- 인증 실패 시 `401` JSON 응답

이 파일을 만들어두면 이후 다른 API에서도 그대로 재사용할 수 있다.

## 9. 5단계: 라우트 작성

권장 구조:

```ruby
namespace :api do
  namespace :v1 do
    namespace :auth do
      post "email/register", to: "email_registrations#create"
      post "email/login", to: "email_sessions#create"
      post "refresh", to: "token_refreshes#create"
      delete "session", to: "sessions#destroy"
    end
  end
end
```

처음부터 모든 액션을 하나의 컨트롤러에 몰아넣는 것보다 역할별로 나누는 편이 읽기 쉽다.

## 10. 6단계: 컨트롤러 구현

추천 컨트롤러:

- `Api::V1::Auth::EmailRegistrationsController`
- `Api::V1::Auth::EmailSessionsController`
- `Api::V1::Auth::TokenRefreshesController`
- `Api::V1::Auth::SessionsController`

### 10-1. EmailRegistrationsController

할 일:

- 파라미터 받기
- 이메일 중복 검사
- `User` 생성
- `Identity` 생성
- 성공 시 `201`
- 실패 시 `422`

### 10-2. EmailSessionsController

할 일:

- 이메일로 `User` 찾기
- `authenticate`로 비밀번호 확인
- 성공 시 access token, refresh token 반환
- 실패 시 `401`

### 10-3. TokenRefreshesController

할 일:

- refresh token 받기
- digest 계산
- DB에서 토큰 찾기
- 활성 상태 확인
- 새 토큰 발급
- 기존 토큰 revoke

### 10-4. SessionsController

할 일:

- 현재 refresh token revoke
- 성공 시 `204`

## 11. 7단계: 응답 포맷 맞추기

로그인 API는 초반에 응답 포맷을 통일하는 것이 중요하다.

### 11-1. 로그인 성공 응답 예시

```json
{
  "access_token": "token",
  "refresh_token": "token",
  "user": {
    "id": "uuid",
    "display_name": "string",
    "email": "user@example.com",
    "providers": ["email"],
    "created_at": "ISO8601"
  }
}
```

### 11-2. 로그인 실패 응답 예시

```json
{
  "error": "invalid_credentials",
  "message": "이메일 또는 비밀번호가 올바르지 않습니다."
}
```

### 11-3. Validation 실패 응답 예시

```json
{
  "error": "validation_error",
  "errors": {
    "email": ["이미 사용 중입니다."]
  }
}
```

## 12. 8단계: 테스트 작성

처음에는 request spec 위주로 작성하는 것이 가장 이해하기 쉽다.

권장 파일:

- `spec/requests/api/v1/auth/email_registrations_spec.rb`
- `spec/requests/api/v1/auth/email_sessions_spec.rb`
- `spec/requests/api/v1/auth/token_refreshes_spec.rb`
- `spec/requests/api/v1/auth/sessions_spec.rb`

최소 테스트 케이스:

- 회원가입 성공
- 회원가입 실패: 중복 이메일
- 로그인 성공
- 로그인 실패: 잘못된 비밀번호
- refresh 성공
- refresh 실패: 만료/취소된 토큰
- logout 성공

## 13. 9단계: Swagger 문서 연결

`rswag`를 쓰고 있으므로 request spec에서 문서도 같이 관리하는 것이 좋다.

처음에는 아래 4개만 연결하면 충분하다.

- register
- login
- refresh
- logout

## 14. 실제 작업 체크리스트

아래 순서로 하면 된다.

1. `CreateUsers`, `CreateIdentities`, `CreateRefreshTokens` 마이그레이션 작성
2. `bin/rails db:migrate`
3. `User`, `Identity`, `RefreshToken` 모델 작성
4. `has_secure_password` 연결
5. JWT 발급 서비스 작성
6. refresh token 발급/회전 서비스 작성
7. `Api::V1::BaseController` 작성
8. auth 라우트 작성
9. auth 컨트롤러 작성
10. request spec 작성
11. rswag 문서 연결

## 15. 지금 바로 다음에 할 일

가장 먼저 시작할 작업은 이것이다.

1. `users` 마이그레이션 작성
2. `identities` 마이그레이션 작성
3. `refresh_tokens` 마이그레이션 작성

이 3개가 정리되어야 이후 모델, 컨트롤러, 토큰 로직이 흔들리지 않는다.

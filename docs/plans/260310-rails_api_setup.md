# Rails API 초기 세팅 가이드

이 문서는 Baskit 서버를 Rails API 모드로 시작할 때 필요한 최소 설정 순서를 정리한 것이다.

## 목표

- Rails API 모드 사용
- PostgreSQL 연결
- 로그인 기능 구현을 위한 최소 인증 기반 준비

## 1. 프로젝트 생성

새 프로젝트를 만드는 경우:

```bash
rails new baskit-api --api --database=postgresql
```

이미 Rails 프로젝트가 있다면 아래 항목을 점검한다.

## 2. API 모드 확인

`config/application.rb`에서 아래 설정이 있는지 확인한다.

```ruby
config.api_only = true
```

이 설정이 있으면 Rails가 JSON API 중심으로 동작한다.

## 3. Gem 추가

초기 인증 기능 기준 최소 권장 gem:

```ruby
gem "pg"
gem "jwt"
gem "bcrypt"
gem "rack-attack"
gem "rack-cors"
gem "rswag-api"
gem "rswag-ui"
gem "rspec-rails", group: [:development, :test]
gem "rswag-specs", group: [:development, :test]
```

설치 예시:

```bash
bundle add jwt bcrypt rack-attack rack-cors rswag-api rswag-ui
bundle add rspec-rails rswag-specs --group "development,test"
```

소셜 로그인까지 바로 하지 않을 경우 `omniauth-*` 계열은 나중에 추가하는 편이 낫다.

`rswag`는 로그인 API를 테스트와 문서로 같이 관리할 때 유용하다. `register`, `login`, `refresh`, `logout` 같은 인증 엔드포인트부터 먼저 붙이는 방식이 적당하다.

## 4. PostgreSQL 설정

확인할 항목:

- `Gemfile`에 `pg`가 있는지
- `config/database.yml`이 PostgreSQL 기준인지
- 로컬 PostgreSQL이 실행 중인지

초기 DB 생성:

```bash
bin/rails db:create
```

## 5. Gem 추가 후 초기 설정

gem을 `Gemfile`에 추가했다고 바로 기능이 완성되지는 않는다. 아래 항목은 설치 후 별도 초기 설정이 필요하다.

### 5-1. RSpec

```bash
bin/rails generate rspec:install
```

생성되는 주요 파일:

- `spec/spec_helper.rb`
- `spec/rails_helper.rb`

### 5-2. Rswag

```bash
bin/rails generate rswag:install
```

추가로 확인할 항목:

- Swagger UI 라우트 연결
- OpenAPI 문서 경로 설정
- 인증 API request spec 작성

### 5-3. Rack CORS

`config/initializers/cors.rb`를 만들고 허용할 origin을 설정해야 실제로 동작한다.

### 5-4. Rack Attack

`config/initializers/rack_attack.rb`를 만들고 로그인 엔드포인트 rate limit 규칙을 정의해야 한다.

### 5-5. BCrypt

`User` 모델에서 `has_secure_password`를 사용한다. 전제 조건은 `users.password_digest` 컬럼이다.

### 5-6. JWT

별도 generator는 없고, 직접 아래 요소를 구현한다.

- access token 발급기
- access token 검증기
- 만료 처리
- `Authorization: Bearer <token>` 파싱

## 6. 기본 API 구조

권장 컨트롤러 구조:

- `app/controllers/api/v1/base_controller.rb`
- `app/controllers/api/v1/auth/...`

권장 라우팅 구조:

```ruby
namespace :api do
  namespace :v1 do
    namespace :auth do
      post "email/register"
      post "email/login"
      post "refresh"
      delete "session"
    end
  end
end
```

## 7. 로그인 구현 전 먼저 만들 것

로그인 기능 전에 아래 3개 모델부터 준비한다.

- `User`
- `Identity`
- `RefreshToken`

문서 기준 핵심 컬럼:

- `users.email`
- `users.password_digest`
- `users.email_verified`
- `identities.provider`
- `identities.provider_uid`
- `refresh_tokens.token_digest`
- `refresh_tokens.expires_at`
- `refresh_tokens.revoked_at`

## 8. 인증 방식 권장안

1차 구현 기준:

- Access token: JWT
- Refresh token: DB 저장 + rotation
- 비밀번호 해시: bcrypt

이 조합이면 이메일 로그인부터 소셜 로그인 확장까지 무리 없이 이어갈 수 있다.

## 9. 먼저 구현할 API

순서는 아래처럼 간다.

1. `POST /api/v1/auth/email/register`
2. `POST /api/v1/auth/email/login`
3. `POST /api/v1/auth/refresh`
4. `DELETE /api/v1/auth/session`

## 10. 공통 인증 처리

초기에 같이 만들면 좋은 것:

- `Authorization: Bearer <token>` 파싱
- `current_user`
- 만료/위조 토큰 `401` 처리
- 공통 에러 응답 포맷

응답 포맷은 초반에 통일하지 않으면 나중에 수정 비용이 커진다.

## 11. 테스트 세팅

RSpec 설치:

```bash
bin/rails generate rspec:install
```

최소 테스트 범위:

- 회원가입 성공/실패
- 로그인 성공/실패
- refresh token 재발급
- 로그아웃 후 refresh token 무효화
- 만료된 access token 요청 처리

## 12. 추천 작업 순서

1. Rails API 모드 확인
2. PostgreSQL 연결
3. `jwt`, `bcrypt`, `rspec-rails`, `rswag` 추가
4. `rspec`, `rswag` 초기 설정
5. `rack-cors`, `rack-attack` initializer 작성
6. 인증 모델 마이그레이션 작성
7. 토큰 발급/검증 서비스 작성
8. 회원가입/로그인 API 작성
9. refresh/logout 작성
10. 인증 테스트 작성
11. 인증 API Swagger 문서 연결

## 메모

- 1차 범위는 이메일 로그인만 구현한다.
- Apple/Google/Kakao 소셜 로그인은 후속 작업으로 분리한다.

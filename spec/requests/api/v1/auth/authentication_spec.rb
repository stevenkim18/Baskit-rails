require "swagger_helper"

RSpec.describe "Authentication API", type: :request do
  path "/api/v1/auth/email/register" do
    post "Register with email" do
      tags "Auth"
      consumes "application/json"
      produces "application/json"

      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string },
          password: { type: :string },
          password_confirmation: { type: :string },
          display_name: { type: :string, nullable: true }
        },
        required: %w[email password password_confirmation]
      }

      response "201", "created" do
        let(:payload) do
          {
            email: "new-user@example.com",
            password: "password123",
            password_confirmation: "password123",
            display_name: "New User"
          }
        end

        run_test! do |response|
          body = JSON.parse(response.body)

          expect(body["message"]).to eq("회원가입이 완료되었습니다.")
          expect(User.find_by(email: "new-user@example.com")).to be_present
          expect(Identity.find_by(provider: "email", provider_uid: "new-user@example.com")).to be_present
        end
      end

      response "422", "validation error" do
        before do
          User.create!(email: "taken@example.com", password: "password123", password_confirmation: "password123")
        end

        let(:payload) do
          {
            email: "taken@example.com",
            password: "password123",
            password_confirmation: "password123",
            display_name: "Taken"
          }
        end

        run_test! do |response|
          body = JSON.parse(response.body)

          expect(body["error"]).to eq("validation_error")
          expect(body["errors"]).to have_key("email")
        end
      end

      response "422", "password too short" do
        let(:payload) do
          {
            email: "short-password@example.com",
            password: "short",
            password_confirmation: "short"
          }
        end

        run_test! do |response|
          body = JSON.parse(response.body)

          expect(body["error"]).to eq("validation_error")
          expect(body["errors"]).to have_key("password")
        end
      end

      response "422", "password confirmation mismatch" do
        let(:payload) do
          {
            email: "mismatch@example.com",
            password: "password123",
            password_confirmation: "password124"
          }
        end

        run_test! do |response|
          body = JSON.parse(response.body)

          expect(body["error"]).to eq("validation_error")
          expect(body["errors"]).to have_key("password_confirmation")
        end
      end
    end
  end

  path "/api/v1/auth/email/login" do
    post "Login with email" do
      tags "Auth"
      consumes "application/json"
      produces "application/json"

      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string },
          password: { type: :string },
          device_name: { type: :string, nullable: true }
        },
        required: %w[email password]
      }

      let!(:user) do
        User.create!(
          email: "login@example.com",
          password: "password123",
          password_confirmation: "password123",
          display_name: "Login User"
        )
      end

      let!(:identity) do
        user.identities.create!(provider: "email", provider_uid: user.email, email: user.email)
      end

      response "200", "ok" do
        let(:payload) do
          {
            email: "login@example.com",
            password: "password123",
            device_name: "iPhone"
          }
        end

        run_test! do |response|
          body = JSON.parse(response.body)

          expect(body["access_token"]).to be_present
          expect(body["refresh_token"]).to be_present
          expect(body.dig("user", "email")).to eq("login@example.com")
        end
      end

      response "401", "invalid credentials" do
        let(:payload) do
          {
            email: "login@example.com",
            password: "wrong-password"
          }
        end

        run_test! do |response|
          body = JSON.parse(response.body)

          expect(body["error"]).to eq("invalid_credentials")
        end
      end

      response "401", "deleted user" do
        before do
          user.update!(deleted_at: Time.current)
        end

        let(:payload) do
          {
            email: "login@example.com",
            password: "password123"
          }
        end

        run_test! do |response|
          body = JSON.parse(response.body)

          expect(body["error"]).to eq("invalid_credentials")
        end
      end
    end
  end

  path "/api/v1/auth/refresh" do
    post "Refresh access token" do
      tags "Auth"
      consumes "application/json"
      produces "application/json"

      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          refresh_token: { type: :string },
          device_name: { type: :string, nullable: true }
        },
        required: ["refresh_token"]
      }

      let!(:user) do
        User.create!(
          email: "refresh@example.com",
          password: "password123",
          password_confirmation: "password123"
        )
      end

      response "200", "ok" do
        let(:issued_refresh_token) { ::Auth::RefreshTokenIssuer.issue(user: user, device_name: "iPhone") }
        let(:payload) do
          {
            refresh_token: issued_refresh_token.token,
            device_name: "iPhone"
          }
        end

        run_test! do |response|
          body = JSON.parse(response.body)

          expect(body["access_token"]).to be_present
          expect(body["refresh_token"]).to be_present
          expect(user.refresh_tokens.active.count).to eq(1)
        end
      end

      response "401", "invalid refresh token" do
        let(:payload) { { refresh_token: "bad-token" } }

        run_test! do |response|
          body = JSON.parse(response.body)

          expect(body["error"]).to eq("invalid_refresh_token")
        end
      end

      response "401", "expired refresh token" do
        let!(:expired_record) do
          user.refresh_tokens.create!(
            token_digest: ::Auth::RefreshTokenIssuer.digest("expired-token"),
            expires_at: 1.minute.ago
          )
        end
        let(:payload) { { refresh_token: "expired-token" } }

        run_test! do |response|
          body = JSON.parse(response.body)

          expect(body["error"]).to eq("invalid_refresh_token")
          expect(expired_record.reload).not_to be_active
        end
      end

      response "401", "reused revoked refresh token" do
        let!(:revoked_result) { ::Auth::RefreshTokenIssuer.issue(user: user, device_name: "iPhone") }
        let(:payload) { { refresh_token: revoked_result.token } }

        before do
          ::Auth::RefreshTokenRotator.rotate!(token: revoked_result.token, device_name: "iPhone")
        end

        run_test! do |response|
          body = JSON.parse(response.body)

          expect(body["error"]).to eq("invalid_refresh_token")
        end
      end
    end
  end

  path "/api/v1/auth/session" do
    delete "Logout" do
      tags "Auth"
      consumes "application/json"
      produces "application/json"
      security [bearerAuth: []]

      parameter name: :Authorization, in: :header, type: :string, required: true

      let!(:user) do
        User.create!(
          email: "logout@example.com",
          password: "password123",
          password_confirmation: "password123"
        )
      end

      let!(:refresh_token) { ::Auth::RefreshTokenIssuer.issue(user: user, device_name: "iPhone") }

      response "204", "no content" do
        let(:Authorization) { "Bearer #{::Auth::AccessToken.issue(user: user)}" }

        run_test! do |_response|
          expect(user.refresh_tokens.where(revoked_at: nil)).to be_empty
        end
      end

      response "401", "unauthorized" do
        let(:Authorization) { "Bearer bad-token" }

        run_test! do |response|
          body = JSON.parse(response.body)

          expect(body["error"]).to eq("unauthorized")
        end
      end
    end
  end
end

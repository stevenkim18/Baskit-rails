module Api
  module V1
    module Auth
      class EmailSessionsController < BaseController
        def create
          user = User.find_by(email: normalized_email, deleted_at: nil)

          unless user&.authenticate(params[:password].to_s)
            return render json: {
              error: "invalid_credentials",
              message: "이메일 또는 비밀번호가 올바르지 않습니다."
            }, status: :unauthorized
          end

          identity = user.identities.find_or_initialize_by(provider: "email", provider_uid: user.email)
          identity.email = user.email
          identity.last_used_at = Time.current
          identity.save!

          refresh_token = ::Auth::RefreshTokenIssuer.issue(
            user: user,
            device_name: params[:device_name],
            ip: request.remote_ip
          )

          render json: auth_payload(user: user, refresh_token: refresh_token.token)
        rescue ActiveRecord::RecordInvalid => error
          render_validation_error(error.record)
        end

        private

        def normalized_email
          params[:email].to_s.strip.downcase
        end

        def auth_payload(user:, refresh_token:)
          {
            access_token: ::Auth::AccessToken.issue(user: user),
            refresh_token: refresh_token,
            user: serialized_user(user)
          }
        end

        def serialized_user(user)
          {
            id: user.id,
            display_name: user.display_name,
            email: user.email,
            providers: user.identities.pluck(:provider),
            created_at: user.created_at.iso8601
          }
        end
      end
    end
  end
end

module Api
  module V1
    module Auth
      class SessionsController < BaseController
        before_action :authenticate_user!

        def destroy
          if params[:refresh_token].present?
            revoke_one_token!
            return if performed?
          else
            current_user.refresh_tokens.where(revoked_at: nil).update_all(revoked_at: Time.current, updated_at: Time.current)
          end

          head :no_content
        rescue ::Auth::RefreshTokenRotator::InvalidToken
          render json: {
            error: "invalid_refresh_token",
            message: "Refresh token이 유효하지 않습니다."
          }, status: :unauthorized
        end

        private

        def revoke_one_token!
          refresh_token = ::Auth::RefreshTokenRotator.find_active_token!(params[:refresh_token].to_s)

          unless refresh_token.user_id == current_user.id
            return render_unauthorized
          end

          refresh_token.revoke!
        end
      end
    end
  end
end

module Api
  module V1
    module Auth
      class TokenRefreshesController < BaseController
        def create
          refresh_token = ::Auth::RefreshTokenRotator.rotate!(
            token: params[:refresh_token].to_s,
            device_name: params[:device_name],
            ip: request.remote_ip
          )

          render json: {
            access_token: ::Auth::AccessToken.issue(user: refresh_token.record.user),
            refresh_token: refresh_token.token
          }
        rescue ::Auth::RefreshTokenRotator::InvalidToken
          render json: {
            error: "invalid_refresh_token",
            message: "Refresh token이 유효하지 않습니다."
          }, status: :unauthorized
        end
      end
    end
  end
end

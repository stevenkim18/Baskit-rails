module Api
  module V1
    class BaseController < ApplicationController
      rescue_from ::Auth::AccessToken::InvalidToken, with: :render_unauthorized

      private

      def authenticate_user!
        current_user || render_unauthorized
      end

      def current_user
        return @current_user if defined?(@current_user)

        token = bearer_token
        return @current_user = nil if token.blank?

        payload = ::Auth::AccessToken.decode(token)
        @current_user = User.find_by(id: payload[:user_id], deleted_at: nil)
      end

      def bearer_token
        authorization = request.headers["Authorization"].to_s
        scheme, token = authorization.split(" ", 2)
        return if scheme != "Bearer"

        token
      end

      def render_unauthorized
        render json: {
          error: "unauthorized",
          message: "Authentication is required."
        }, status: :unauthorized
      end

      def render_validation_error(record)
        render json: {
          error: "validation_error",
          errors: record.errors.to_hash(true)
        }, status: :unprocessable_entity
      end
    end
  end
end

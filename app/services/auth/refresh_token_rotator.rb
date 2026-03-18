module Auth
  class RefreshTokenRotator
    InvalidToken = Class.new(StandardError)

    class << self
      def rotate!(token:, device_name: nil, ip: nil)
        ApplicationRecord.transaction do
          refresh_token = find_active_token!(token, lock: true)
          refresh_token.revoke!

          RefreshTokenIssuer.issue(
            user: refresh_token.user,
            device_name: device_name || refresh_token.device_name,
            ip: ip
          )
        end
      end

      def find_active_token!(token, lock: false)
        refresh_token = RefreshToken.find_by(token_digest: RefreshTokenIssuer.digest(token))
        refresh_token = refresh_token.lock! if lock && refresh_token

        raise InvalidToken, "Refresh token not found" unless refresh_token
        raise InvalidToken, "Refresh token is no longer active" unless refresh_token.active?

        refresh_token
      end
    end
  end
end

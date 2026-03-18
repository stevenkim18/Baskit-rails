require "digest"
require "securerandom"

module Auth
  class RefreshTokenIssuer
    TTL = 30.days

    Result = Struct.new(:record, :token, keyword_init: true)

    class << self
      def issue(user:, device_name: nil, ip: nil)
        token = generate_token
        record = user.refresh_tokens.create!(
          token_digest: digest(token),
          device_name: device_name,
          last_used_ip: ip,
          expires_at: TTL.from_now
        )

        Result.new(record: record, token: token)
      end

      def digest(token)
        Digest::SHA256.hexdigest(token)
      end

      private

      def generate_token
        SecureRandom.urlsafe_base64(48)
      end
    end
  end
end

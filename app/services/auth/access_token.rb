module Auth
  class AccessToken
    ALGORITHM = "HS256".freeze
    TTL = 7.days

    InvalidToken = Class.new(StandardError)

    class << self
      def issue(user:)
        JWT.encode(payload_for(user), secret_key, ALGORITHM)
      end

      def decode(token)
        payload, = JWT.decode(token, secret_key, true, algorithm: ALGORITHM)
        payload.with_indifferent_access
      rescue JWT::DecodeError => error
        raise InvalidToken, error.message
      end

      private

      def payload_for(user)
        {
          user_id: user.id,
          exp: TTL.from_now.to_i
        }
      end

      def secret_key
        Rails.application.secret_key_base
      end
    end
  end
end

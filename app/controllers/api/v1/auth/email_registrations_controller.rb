module Api
  module V1
    module Auth
      class EmailRegistrationsController < BaseController
        def create
          user = nil

          ApplicationRecord.transaction do
            user = User.create!(registration_params)
            user.identities.create!(
              provider: "email",
              provider_uid: user.email,
              email: user.email
            )
          end

          render json: { message: "회원가입이 완료되었습니다." }, status: :created
        rescue ActiveRecord::RecordInvalid => error
          render_validation_error(error.record)
        end

        private

        def registration_params
          params.permit(:email, :password, :password_confirmation, :display_name)
        end
      end
    end
  end
end

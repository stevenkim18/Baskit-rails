Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      namespace :auth do
        post "email/register", to: "email_registrations#create"
        post "email/login", to: "email_sessions#create"
        post "refresh", to: "token_refreshes#create"
        delete "session", to: "sessions#destroy"
      end
    end
  end
end

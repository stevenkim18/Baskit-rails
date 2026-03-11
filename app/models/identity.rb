class Identity < ApplicationRecord
  PROVIDERS = %w[email apple google kakao].freeze

  belongs_to :user

  before_validation :normalize_email

  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :provider_uid, presence: true, length: { maximum: 255 }
  validates :email, length: { maximum: 255 }, allow_blank: true

  private

  def normalize_email
    self.email = email.to_s.strip.downcase.presence
  end
end

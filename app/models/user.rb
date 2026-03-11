class User < ApplicationRecord
  has_many :identities, dependent: :destroy
  has_many :refresh_tokens, dependent: :destroy

  has_secure_password

  before_validation :normalize_email

  validates :email,
    presence: true,
    length: { maximum: 255 },
    format: { with: URI::MailTo::EMAIL_REGEXP },
    uniqueness: { case_sensitive: false, conditions: -> { where(deleted_at: nil) } }
  validates :display_name, length: { maximum: 100 }, allow_blank: true

  private

  def normalize_email
    self.email = email.to_s.strip.downcase.presence
  end
end

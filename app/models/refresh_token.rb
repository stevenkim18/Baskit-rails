class RefreshToken < ApplicationRecord
  belongs_to :user

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  validates :token_digest, presence: true, length: { maximum: 255 }
  validates :device_name, length: { maximum: 100 }, allow_blank: true
  validates :expires_at, presence: true

  def expired?
    expires_at <= Time.current
  end

  def revoked?
    revoked_at.present?
  end

  def active?
    !expired? && !revoked?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end
end

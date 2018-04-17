class ConfirmToken < VerifyToken
  before_create :update_token

  def update_token
    self.token = SecureRandom.uuid
    self.expired_at = 10.minutes.since
  end

end

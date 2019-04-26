##
# Usually used for access api request
#--
# this not docs
#++
# test
module RailsAuth::VerifyToken::AccessToken

  def update_token
    self.user_id = self.account.user_id
    self.expired_at = 1.weeks.since
    self.token = user.generate_auth_token(sub: 'auth', exp: expired_at.to_i)
    self
  end

end
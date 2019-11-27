##
# Usually used for access api request
#--
# this not docs
#++
# test
module RailsAuth::AuthorizedToken
  extend ActiveSupport::Concern
  included do
    attribute :token, :string, index: { unique: true }
    attribute :expire_at, :datetime
    attribute :session_key, :string, comment: '目前在小程序下用到'
    attribute :access_counter, :integer, default: 0
    
    belongs_to :user, optional: true
    belongs_to :oauth_user, optional: true
    belongs_to :account, optional: true

    scope :valid, -> { where('expire_at >= ?', Time.now).order(access_counter: :asc) }
    validates :token, presence: true
    before_validation :sync_user, if: -> { account_id_changed? }
    before_validation :update_token, if: -> { new_record? }
  end

  def sync_user
    if account
      self.user_id = account.user_id
    else
      self.user_id = nil
    end
  end

  def verify_token?(now = Time.now)
    return false if self.expire_at.blank?
    if now > self.expire_at
      self.errors.add(:token, 'The token has expired')
      return false
    end
  
    true
  end
  
  def update_token
    self.expire_at = 1.weeks.since
    self.token = generate_token
    self
  end
  
  def generate_token
    if user
      xbb = [user_id, user.password_digest]
      options = { sub: 'User', column: 'password_digest' }
    elsif oauth_user
      xbb = [oauth_user_id, oauth_user.access_token]
      options = { sub: 'OauthUser', column: 'access_token' }
    elsif account
      xbb = [account_id, account.identity]
      options = { sub: 'Account', column: 'identity' }
    else
      xbb = []
      options = {}
    end
    
    JwtHelper.generate_jwt_token(*xbb, exp: expire_at.to_i, **options)
  end

end

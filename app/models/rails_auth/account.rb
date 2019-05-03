module RailsAuth::Account
  extend ActiveSupport::Concern

  included do
    belongs_to :user, optional: true
    has_one :access_token, -> { valid }
    has_one :reset_token, -> { valid }
    has_many :reset_tokens, dependent: :delete_all
    has_many :access_tokens, dependent: :delete_all
    has_many :verify_tokens, dependent: :delete_all
    has_many :oauth_users, dependent: :nullify

    after_initialize if: :new_record? do
      if self.identity.include?('@')
        self.type ||= 'EmailAccount'
      else
        self.type ||= 'MobileAccount'
      end
    end
    after_update :set_primary, if: -> { self.primary? && saved_change_to_primary? }
    after_update :sync_user, if: -> { saved_change_to_user_id? }
  end

  def set_primary
    self.class.base_class.unscoped.where.not(id: self.id).where(user_id: self.user_id).update_all(primary: false)
    sync_identity
  end
  
  def sync_identity
    if self.identity.include?('@')
      user.update(email: self.identity) if user.email.blank?
    else
      user.update(mobile: self.identity) if user.mobile.blank?
    end
  end
  
  def sync_user
    self.oauth_users.update_all(user_id: self.user_id)
    sync_identity
  end

  def can_login?(params = {})
    if user.nil?
      join
    end

    if user&.restrictive?
      return false
    end

    if params[:password].present? && user.password_digest?
      if user.authenticate(params[:password])
        user
      else
        user.errors.add :base, :wrong_name_or_password
        return false
      end
    elsif params[:token].present?
      if authenticate_by_token(params[:token])
        user
      else
        user.errors.add :base, :wrong_token
        return false
      end
    else
      user.errors.add :base, :token_blank
      false
    end
  end

  def authenticate_by_token(token)
    verify_token = self.verify_tokens.valid.find_by(token: token)
    if verify_token
      self.update(confirmed: true)
    else
      false
    end
  end

  def join(params = {})
    user || build_user
    user.assign_attributes params.slice(
      :name,
      :password,
      :password_confirmation
    )
    save
  end

  def verify_token
    if check_token
      check_token
    else
      VerifyToken.transaction do
        self.check_tokens.delete_all
        create_check_token
      end
    end
  end

  def access_token
    if super
      super
    else
      VerifyToken.transaction do
        self.access_tokens.delete_all
        create_access_token
      end
    end
  end

  def auth_token
    access_token.token
  end

  def reset_token
    if super
      super
    else
      VerifyToken.transaction do
        self.reset_tokens.delete_all
        create_reset_token
      end
    end
  end
  
  def reset_notice
    p 'Should implement in subclass'
  end

end

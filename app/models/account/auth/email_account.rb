module Auth
  class EmailAccount < Account
    include AuthModel::Account::EmailAccount
  end
end
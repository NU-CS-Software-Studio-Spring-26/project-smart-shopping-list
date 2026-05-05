class RemoveEmailVerificationFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :email_verified_at, :datetime, if_exists: true
    remove_column :users, :email_verification_code_digest, :string, if_exists: true
    remove_column :users, :email_verification_sent_at, :datetime, if_exists: true
  end
end

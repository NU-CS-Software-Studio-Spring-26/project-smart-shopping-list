class AddExpirationToSessions < ActiveRecord::Migration[8.1]
  def up
    add_column :sessions, :expires_at, :datetime
    execute "UPDATE sessions SET expires_at = created_at + interval '30 days' WHERE expires_at IS NULL"
    change_column_null :sessions, :expires_at, false
    add_index :sessions, :expires_at
  end

  def down
    remove_index :sessions, :expires_at
    remove_column :sessions, :expires_at
  end
end

class AddOmniauthToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :provider, :string unless column_exists?(:users, :provider)
    add_column :users, :uid, :string unless column_exists?(:users, :uid)
    add_column :users, :name, :string unless column_exists?(:users, :name)
    add_column :users, :avatar_url, :string unless column_exists?(:users, :avatar_url)

    add_index :users, [ :provider, :uid ], unique: true unless index_exists?(:users, [ :provider, :uid ])
  end
end

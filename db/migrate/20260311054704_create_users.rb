class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :users, id: :uuid do |t|
      t.string :display_name, limit: 100
      t.string :email, limit: 255
      t.string :password_digest, limit: 255
      t.boolean :email_verified, null: false, default: false
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :users, :email, unique: true, where: "deleted_at IS NULL"
    add_index :users, :deleted_at
  end
end

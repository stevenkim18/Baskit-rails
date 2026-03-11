class CreateIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :identities, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :provider, null: false, limit: 30
      t.string :provider_uid, null: false, limit: 255
      t.string :email, limit: 255
      t.jsonb :profile, null: false, default: {}
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :identities, [ :provider, :provider_uid ], unique: true
    add_index :identities, :email
  end
end

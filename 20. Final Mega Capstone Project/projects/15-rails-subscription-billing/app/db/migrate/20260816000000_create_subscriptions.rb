class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions, id: :uuid do |table|
      table.string :account_name, null: false, limit: 120
      table.string :owner_email, null: false, limit: 254
      table.string :plan, null: false, limit: 24
      table.string :status, null: false, limit: 24, default: "active"
      table.string :idempotency_key, null: false, limit: 128
      table.timestamps
    end
    add_index :subscriptions, :idempotency_key, unique: true
  end
end

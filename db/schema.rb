# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_08_26_050100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "achievements", force: :cascade do |t|
    t.string "name", null: false
    t.string "description", null: false
    t.string "badge_type", null: false
    t.string "category"
    t.string "icon"
    t.string "color", default: "#FFD700"
    t.integer "points", default: 0
    t.string "rarity", default: "common"
    t.json "criteria"
    t.boolean "active", default: true
    t.integer "earned_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_achievements_on_active"
    t.index ["badge_type"], name: "index_achievements_on_badge_type"
    t.index ["category"], name: "index_achievements_on_category"
    t.index ["rarity"], name: "index_achievements_on_rarity"
  end

  create_table "blueprints", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.date "target_date"
    t.string "status"
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "habits", force: :cascade do |t|
    t.string "title", limit: 100, null: false
    t.text "description"
    t.string "frequency", default: "daily", null: false
    t.string "status", default: "pending", null: false
    t.string "priority", default: "medium", null: false
    t.datetime "last_completed_at"
    t.bigint "milestone_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["frequency"], name: "index_habits_on_frequency"
    t.index ["last_completed_at"], name: "index_habits_on_last_completed_at"
    t.index ["milestone_id", "frequency"], name: "index_habits_on_milestone_id_and_frequency"
    t.index ["milestone_id"], name: "index_habits_on_milestone_id"
    t.index ["priority"], name: "index_habits_on_priority"
    t.index ["status"], name: "index_habits_on_status"
  end

  create_table "milestones", force: :cascade do |t|
    t.string "title", limit: 100, null: false
    t.text "description"
    t.date "target_date", null: false
    t.string "status", default: "pending", null: false
    t.string "priority", default: "medium", null: false
    t.bigint "blueprint_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["blueprint_id", "target_date"], name: "index_milestones_on_blueprint_id_and_target_date"
    t.index ["blueprint_id"], name: "index_milestones_on_blueprint_id"
    t.index ["priority"], name: "index_milestones_on_priority"
    t.index ["status"], name: "index_milestones_on_status"
    t.index ["target_date"], name: "index_milestones_on_target_date"
  end

  create_table "user_achievements", force: :cascade do |t|
    t.bigint "achievement_id", null: false
    t.string "user_identifier"
    t.bigint "blueprint_id"
    t.bigint "milestone_id"
    t.bigint "habit_id"
    t.datetime "earned_at", null: false
    t.json "context"
    t.integer "streak_count"
    t.boolean "notified", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["achievement_id"], name: "index_user_achievements_on_achievement_id"
    t.index ["blueprint_id"], name: "index_user_achievements_on_blueprint_id"
    t.index ["earned_at"], name: "index_user_achievements_on_earned_at"
    t.index ["habit_id"], name: "index_user_achievements_on_habit_id"
    t.index ["milestone_id"], name: "index_user_achievements_on_milestone_id"
    t.index ["notified"], name: "index_user_achievements_on_notified"
    t.index ["user_identifier", "achievement_id"], name: "index_user_achievements_on_user_identifier_and_achievement_id"
    t.index ["user_identifier"], name: "index_user_achievements_on_user_identifier"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "jti"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["jti"], name: "index_users_on_jti"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "habits", "milestones"
  add_foreign_key "milestones", "blueprints"
  add_foreign_key "user_achievements", "achievements"
  add_foreign_key "user_achievements", "blueprints"
  add_foreign_key "user_achievements", "habits"
  add_foreign_key "user_achievements", "milestones"
end

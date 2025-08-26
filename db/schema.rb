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

ActiveRecord::Schema[8.0].define(version: 2025_08_25_120900) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  add_foreign_key "habits", "milestones"
  add_foreign_key "milestones", "blueprints"
end

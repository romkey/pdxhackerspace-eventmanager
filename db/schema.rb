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

ActiveRecord::Schema[7.0].define(version: 2025_11_02_051601) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "event_hosts", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "user_id"], name: "index_event_hosts_on_event_id_and_user_id", unique: true
    t.index ["event_id"], name: "index_event_hosts_on_event_id"
    t.index ["user_id"], name: "index_event_hosts_on_user_id"
  end

  create_table "event_journals", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "user_id", null: false
    t.string "action", null: false
    t.jsonb "change_data", default: {}
    t.integer "occurrence_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_event_journals_on_created_at"
    t.index ["event_id", "created_at"], name: "index_event_journals_on_event_id_and_created_at"
    t.index ["event_id"], name: "index_event_journals_on_event_id"
    t.index ["occurrence_id"], name: "index_event_journals_on_occurrence_id"
    t.index ["user_id"], name: "index_event_journals_on_user_id"
  end

  create_table "event_occurrences", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.datetime "occurs_at", null: false
    t.string "status", default: "active", null: false
    t.datetime "postponed_until"
    t.text "cancellation_reason"
    t.text "custom_description"
    t.integer "duration_override"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "occurs_at"], name: "index_event_occurrences_on_event_id_and_occurs_at"
    t.index ["event_id"], name: "index_event_occurrences_on_event_id"
    t.index ["occurs_at"], name: "index_event_occurrences_on_occurs_at"
    t.index ["status"], name: "index_event_occurrences_on_status"
  end

  create_table "events", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.text "description"
    t.datetime "start_time", null: false
    t.integer "duration", default: 60
    t.text "recurrence_rule"
    t.string "recurrence_type"
    t.string "status", default: "active"
    t.datetime "postponed_until"
    t.text "cancellation_reason"
    t.string "ical_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "visibility", default: "public", null: false
    t.string "open_to", default: "public", null: false
    t.string "more_info_url"
    t.integer "max_occurrences", default: 5, null: false
    t.index ["ical_token"], name: "index_events_on_ical_token", unique: true
    t.index ["open_to"], name: "index_events_on_open_to"
    t.index ["status"], name: "index_events_on_status"
    t.index ["user_id"], name: "index_events_on_user_id"
    t.index ["visibility"], name: "index_events_on_visibility"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "name"
    t.string "role", default: "user", null: false
    t.string "provider"
    t.string "uid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "event_hosts", "events"
  add_foreign_key "event_hosts", "users"
  add_foreign_key "event_journals", "events"
  add_foreign_key "event_journals", "users"
  add_foreign_key "event_occurrences", "events"
  add_foreign_key "events", "users"
end

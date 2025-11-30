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

ActiveRecord::Schema[7.2].define(version: 2025_11_30_164645) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_trgm"
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
    t.bigint "occurrence_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_event_journals_on_action"
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
    t.bigint "location_id"
    t.text "reminder_7d_short"
    t.text "reminder_1d_short"
    t.string "slug"
    t.text "reminder_7d_long"
    t.text "reminder_1d_long"
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_event_occurrences_on_deleted_at"
    t.index ["event_id", "occurs_at"], name: "index_event_occurrences_on_event_id_and_occurs_at"
    t.index ["event_id"], name: "index_event_occurrences_on_event_id"
    t.index ["location_id"], name: "index_event_occurrences_on_location_id"
    t.index ["occurs_at"], name: "index_event_occurrences_on_occurs_at"
    t.index ["slug"], name: "index_event_occurrences_on_slug", unique: true
    t.index ["status", "occurs_at"], name: "index_event_occurrences_on_status_and_occurs_at"
    t.index ["status"], name: "index_event_occurrences_on_status"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'postponed'::character varying::text, 'cancelled'::character varying::text])", name: "event_occurrences_status_check"
  end

  create_table "events", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.text "description"
    t.datetime "start_time", null: false
    t.integer "duration", default: 60
    t.text "recurrence_rule"
    t.string "recurrence_type", null: false
    t.string "status", default: "active", null: false
    t.datetime "postponed_until"
    t.text "cancellation_reason"
    t.string "ical_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "visibility", default: "public", null: false
    t.string "open_to", default: "public", null: false
    t.string "more_info_url"
    t.integer "max_occurrences", default: 5, null: false
    t.bigint "location_id"
    t.boolean "requires_mask", default: false, null: false
    t.boolean "draft", default: false, null: false
    t.boolean "slack_announce", default: true, null: false
    t.boolean "social_reminders", default: true, null: false
    t.string "slug"
    t.text "reminder_7d_short"
    t.text "reminder_1d_short"
    t.text "reminder_7d_long"
    t.text "reminder_1d_long"
    t.datetime "deleted_at"
    t.integer "event_occurrences_count", default: 0, null: false
    t.index ["deleted_at"], name: "index_events_on_deleted_at"
    t.index ["description"], name: "index_events_on_description_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["ical_token"], name: "index_events_on_ical_token", unique: true
    t.index ["location_id"], name: "index_events_on_location_id"
    t.index ["open_to"], name: "index_events_on_open_to"
    t.index ["recurrence_type"], name: "index_events_on_recurrence_type"
    t.index ["slug"], name: "index_events_on_slug", unique: true
    t.index ["start_time"], name: "index_events_on_start_time"
    t.index ["status", "start_time"], name: "index_events_on_status_and_start_time"
    t.index ["status", "visibility"], name: "index_events_on_status_and_visibility"
    t.index ["status"], name: "index_events_on_status"
    t.index ["title"], name: "index_events_on_title_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["user_id"], name: "index_events_on_user_id"
    t.index ["visibility"], name: "index_events_on_visibility"
    t.check_constraint "open_to::text = ANY (ARRAY['public'::character varying::text, 'members'::character varying::text, 'private'::character varying::text])", name: "events_open_to_check"
    t.check_constraint "recurrence_type::text = ANY (ARRAY['once'::character varying::text, 'weekly'::character varying::text, 'monthly'::character varying::text, 'custom'::character varying::text])", name: "events_recurrence_type_check"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'postponed'::character varying::text, 'cancelled'::character varying::text])", name: "events_status_check"
    t.check_constraint "visibility::text = ANY (ARRAY['public'::character varying::text, 'members'::character varying::text, 'private'::character varying::text])", name: "events_visibility_check"
  end

  create_table "locations", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_locations_on_name", unique: true
  end

  create_table "site_configs", force: :cascade do |t|
    t.string "organization_name"
    t.string "contact_email"
    t.string "contact_phone"
    t.text "footer_text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "website_url"
    t.text "location_info"
    t.string "address"
    t.boolean "slack_enabled", default: false, null: false
    t.boolean "social_reminders_enabled", default: false, null: false
    t.text "ai_reminder_prompt", default: "Create a short, friendly reminder for {{event_title}} happening on {{event_date}} at {{event_time}} at PDX Hackerspace.", null: false
    t.string "ai_model"
    t.integer "short_reminder_max_length", default: 300, null: false
    t.integer "long_reminder_max_length", default: 800, null: false
    t.boolean "matomo_enabled", default: false, null: false
    t.string "matomo_url"
    t.string "matomo_site_id"
    t.boolean "host_email_reminders_enabled", default: true, null: false
    t.boolean "email_test_mode_enabled", default: false, null: false
    t.string "email_test_mode_address"
    t.check_constraint "id = 1", name: "site_configs_singleton"
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
    t.boolean "can_create_events", default: false, null: false
    t.boolean "email_reminders_enabled", default: true, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true, where: "((provider IS NOT NULL) AND (uid IS NOT NULL))"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.check_constraint "role::text = ANY (ARRAY['user'::character varying::text, 'admin'::character varying::text])", name: "users_role_check"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "event_hosts", "events"
  add_foreign_key "event_hosts", "users"
  add_foreign_key "event_journals", "event_occurrences", column: "occurrence_id", on_delete: :nullify
  add_foreign_key "event_journals", "events"
  add_foreign_key "event_journals", "users"
  add_foreign_key "event_occurrences", "events"
  add_foreign_key "event_occurrences", "locations"
  add_foreign_key "events", "locations"
  add_foreign_key "events", "users"
end

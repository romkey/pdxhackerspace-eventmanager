class AddAiReminderPromptToSiteConfigs < ActiveRecord::Migration[7.1]
  def change
    add_column :site_configs, :ai_reminder_prompt, :text, default: "Create a short, friendly reminder for {{event_title}} happening on {{event_date}} at {{event_time}} at PDX Hackerspace.", null: false
  end
end


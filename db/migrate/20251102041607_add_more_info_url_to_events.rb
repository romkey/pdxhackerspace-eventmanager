class AddMoreInfoUrlToEvents < ActiveRecord::Migration[7.0]
  def change
    add_column :events, :more_info_url, :string
  end
end

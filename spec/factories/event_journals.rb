FactoryBot.define do
  factory :event_journal do
    association :event
    association :user
    action { "updated" }
    change_data { { "title" => { "from" => "Old Title", "to" => "New Title" } } }

    trait :created do
      action { "created" }
      change_data { { "title" => "New Event" } }
    end

    trait :cancelled do
      action { "cancelled" }
      change_data { { "status" => "cancelled", "reason" => "Test reason" } }
    end

    trait :postponed do
      action { "postponed" }
      change_data { { "status" => "postponed", "postponed_until" => 1.week.from_now.to_s } }
    end

    trait :for_occurrence do
      association :occurrence, factory: :event_occurrence
      action { "updated" }
      change_data { { "custom_description" => { "from" => nil, "to" => "Custom" } } }
    end

    trait :host_added do
      action { "host_added" }
      change_data { { "added_host" => "user@example.com" } }
    end

    trait :banner_added do
      action { "banner_added" }
      change_data { { "banner_image" => { "filename" => "test.jpg", "size" => "150 KB" } } }
    end
  end
end


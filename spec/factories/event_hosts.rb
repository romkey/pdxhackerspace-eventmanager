FactoryBot.define do
  factory :event_host do
    association :event
    association :user
  end
end

FactoryBot.define do
  factory :event do
    association :user
    sequence(:title) { |n| "Event #{n}" }
    description { Faker::Lorem.paragraph }
    start_time { 2.days.from_now }
    duration { 120 }
    recurrence_type { "once" }
    status { "active" }
    visibility { "public" }
    open_to { "public" }
    max_occurrences { 5 }

    trait :weekly do
      recurrence_type { "weekly" }
      after(:build) do |event|
        schedule = Event.build_schedule(event.start_time, 'weekly', { days: [event.start_time.wday] })
        event.recurrence_rule = schedule.to_yaml
      end
    end

    trait :monthly do
      recurrence_type { "monthly" }
      after(:build) do |event|
        schedule = Event.build_schedule(event.start_time, 'monthly', {})
        event.recurrence_rule = schedule.to_yaml
      end
    end

    trait :members_only do
      visibility { "members" }
      open_to { "members" }
    end

    trait :private do
      visibility { "private" }
      open_to { "private" }
    end

    trait :postponed do
      status { "postponed" }
      postponed_until { 1.week.from_now }
      cancellation_reason { "Venue unavailable" }
    end

    trait :cancelled do
      status { "cancelled" }
      cancellation_reason { "Insufficient registrations" }
    end

    trait :with_banner do
      after(:create) do |event|
        event.banner_image.attach(
          io: StringIO.new("fake image content"),
          filename: "banner.jpg",
          content_type: "image/jpeg"
        )
      end
    end

    trait :with_more_info do
      more_info_url { Faker::Internet.url }
    end
  end
end

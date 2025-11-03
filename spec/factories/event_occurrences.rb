FactoryBot.define do
  factory :event_occurrence do
    association :event
    occurs_at { 1.week.from_now }
    status { "active" }

    trait :with_custom_description do
      custom_description { Faker::Lorem.paragraph }
    end

    trait :with_duration_override do
      duration_override { 180 }
    end

    trait :postponed do
      status { "postponed" }
      postponed_until { 2.weeks.from_now }
      cancellation_reason { "Speaker unavailable" }
    end

    trait :cancelled do
      status { "cancelled" }
      cancellation_reason { "Weather conditions" }
    end

    trait :past do
      occurs_at { 1.week.ago }
    end

    trait :with_banner do
      after(:build) do |occurrence|
        occurrence.banner_image.attach(
          io: StringIO.new("fake image content"),
          filename: "occurrence_banner.jpg",
          content_type: "image/jpeg"
        )
      end
    end
  end
end

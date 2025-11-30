# frozen_string_literal: true

FactoryBot.define do
  factory :reminder_posting do
    association :event
    association :event_occurrence
    platform { 'slack' }
    message { Faker::Lorem.paragraph }
    posted_at { Time.current }

    trait :slack do
      platform { 'slack' }
    end

    trait :bluesky do
      platform { 'bluesky' }
      sequence(:post_uid) { |n| "at://did:plc:example/app.bsky.feed.post/#{n}" }
      sequence(:post_url) { |n| "https://bsky.app/profile/example.bsky.social/post/#{n}" }
    end

    trait :instagram do
      platform { 'instagram' }
      sequence(:post_uid) { |n| "insta_post_#{n}" }
    end

    trait :deleted do
      deleted_at { 1.hour.ago }
      association :deleted_by, factory: :user
    end
  end
end

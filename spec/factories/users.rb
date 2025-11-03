FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    sequence(:name) { |n| "User #{n}" }
    role { "user" }

    trait :admin do
      role { "admin" }
      sequence(:name) { |n| "Admin #{n}" }
    end

    trait :with_oauth do
      provider { "authentik" }
      sequence(:uid) { |n| "authentik-#{n}" }
    end
  end
end

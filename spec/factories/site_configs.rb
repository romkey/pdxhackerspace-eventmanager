FactoryBot.define do
  factory :site_config do
    # Always use id: 1 to satisfy the singleton constraint
    id { 1 }
    organization_name { "Test Hackerspace" }
    contact_email { "info@testhackerspace.org" }
    contact_phone { "(555) 123-4567" }
    footer_text { "© 2025 Test Hackerspace - All Rights Reserved" }

    # Use find_or_create to ensure we don't violate singleton constraint
    initialize_with do
      SiteConfig.find_by(id: 1) || new(**attributes)
    end

    trait :with_favicon do
      after(:build) do |config|
        config.favicon.attach(
          io: StringIO.new("fake favicon"),
          filename: "favicon.ico",
          content_type: "image/x-icon"
        )
      end
    end

    trait :with_banner do
      after(:build) do |config|
        config.banner_image.attach(
          io: StringIO.new("fake banner"),
          filename: "banner.jpg",
          content_type: "image/jpeg"
        )
      end
    end

    trait :minimal do
      contact_email { nil }
      contact_phone { nil }
      footer_text { nil }
    end
  end
end

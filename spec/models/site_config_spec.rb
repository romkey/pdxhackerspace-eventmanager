require 'rails_helper'

RSpec.describe SiteConfig, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:organization_name) }

    it 'validates email format' do
      config = build(:site_config, contact_email: 'invalid-email')
      expect(config).not_to be_valid
      expect(config.errors[:contact_email]).to include('must be a valid email')
    end

    it 'allows blank email' do
      config = build(:site_config, contact_email: '')
      expect(config).to be_valid
    end

    it 'accepts valid email' do
      config = build(:site_config, contact_email: 'contact@example.com')
      expect(config).to be_valid
    end
  end

  describe 'attachments' do
    it { is_expected.to have_one_attached(:favicon) }
    it { is_expected.to have_one_attached(:banner_image) }
  end

  describe '.instance' do
    it 'creates a site config if none exists' do
      expect(SiteConfig.count).to eq(0)
      config = SiteConfig.instance
      expect(config).to be_persisted
      expect(SiteConfig.count).to eq(1)
    end

    it 'returns existing site config' do
      existing = create(:site_config)
      config = SiteConfig.instance
      expect(config.id).to eq(existing.id)
    end

    it 'creates with default organization name' do
      config = SiteConfig.instance
      expect(config.organization_name).to eq('EventManager')
    end
  end

  describe '.current' do
    it 'is an alias for .instance' do
      config = SiteConfig.current
      expect(config).to eq(SiteConfig.instance)
    end
  end

  describe 'singleton pattern' do
    it 'maintains only one record' do
      create(:site_config)
      SiteConfig.instance

      expect(SiteConfig.count).to eq(1)
    end
  end

  describe 'factory' do
    it 'creates a valid site config' do
      config = build(:site_config)
      expect(config).to be_valid
    end

    it 'creates config with favicon' do
      config = build(:site_config, :with_favicon)
      expect(config.favicon).to be_attached
    end

    it 'creates config with banner' do
      config = build(:site_config, :with_banner)
      expect(config.banner_image).to be_attached
    end

    it 'creates minimal config' do
      config = build(:site_config, :minimal)
      expect(config).to be_valid
      expect(config.contact_email).to be_nil
      expect(config.footer_text).to be_nil
    end
  end
end

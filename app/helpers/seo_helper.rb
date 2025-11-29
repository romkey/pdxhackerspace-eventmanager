# rubocop:disable Rails/HelperInstanceVariable, Rails/OutputSafety
module SeoHelper
  # Set page title - call from views
  def page_title(title)
    content_for(:page_title) { title }
  end

  # Set page description
  def page_description(description)
    content_for(:page_description) { description&.truncate(160) }
  end

  # Set Open Graph image
  def og_image(image_url)
    content_for(:og_image) { image_url }
  end

  # Set canonical URL
  def canonical_url(url)
    content_for(:canonical_url) { url }
  end

  # Set page type for Open Graph
  def og_type(type)
    content_for(:og_type) { type }
  end

  # Generate full title with site name
  def full_page_title
    site_name = @site_config&.organization_name || 'EventManager'
    content_for?(:page_title) ? "#{content_for(:page_title)} | #{site_name}" : "#{site_name} - Hackerspace Event Management"
  end

  # Get page description with fallback
  def meta_description
    return content_for(:page_description) if content_for?(:page_description)

    "#{@site_config&.organization_name || 'EventManager'} - Find and manage hackerspace events, workshops, and meetups."
  end

  # Get Open Graph image URL
  def meta_og_image
    return content_for(:og_image) if content_for?(:og_image)

    url_for(@site_config.banner_image) if @site_config&.banner_image&.attached?
  end

  # Get canonical URL
  def meta_canonical_url
    content_for?(:canonical_url) ? content_for(:canonical_url) : request.original_url.split('?').first
  end

  # Get Open Graph type
  def meta_og_type
    content_for?(:og_type) ? content_for(:og_type) : 'website'
  end

  # Generate JSON-LD for an event
  def event_json_ld(event, occurrence = nil)
    EventJsonLdBuilder.new(event, occurrence, @site_config, self).build.to_json.html_safe
  end

  # Generate JSON-LD for organization
  def organization_json_ld
    OrganizationJsonLdBuilder.new(@site_config, self).build.to_json.html_safe
  end

  # Generate breadcrumb JSON-LD
  def breadcrumb_json_ld(items)
    list_items = items.each_with_index.map do |item, index|
      { '@type': 'ListItem', position: index + 1, name: item[:name], item: item[:url] }
    end
    { '@context': 'https://schema.org', '@type': 'BreadcrumbList', itemListElement: list_items }.to_json.html_safe
  end
end

# Builder class for Event JSON-LD
class EventJsonLdBuilder
  def initialize(event, occurrence, site_config, helper)
    @event = event
    @occurrence = occurrence
    @site_config = site_config
    @helper = helper
  end

  def build
    start_time = @occurrence&.occurs_at || @event.start_time
    {
      '@context': 'https://schema.org',
      '@type': 'Event',
      name: @event.title,
      description: @event.description&.truncate(500),
      startDate: start_time.iso8601,
      endDate: (start_time + @event.duration.minutes).iso8601,
      eventStatus: event_status_schema,
      eventAttendanceMode: 'https://schema.org/OfflineEventAttendanceMode',
      location: location_schema,
      organizer: organizer_schema,
      url: @helper.event_url(@event),
      image: image_url,
      offers: offers_schema
    }.compact
  end

  private

  def event_status_schema
    status = (@occurrence || @event).status
    case status
    when 'cancelled' then 'https://schema.org/EventCancelled'
    when 'postponed' then 'https://schema.org/EventPostponed'
    else 'https://schema.org/EventScheduled'
    end
  end

  def location_schema
    location_name = @occurrence&.event_location&.name || @event.location&.name || site_name
    {
      '@type': 'Place',
      name: location_name,
      address: { '@type': 'PostalAddress', streetAddress: @site_config&.address || 'Portland, OR' }
    }
  end

  def organizer_schema
    { '@type': 'Organization', name: site_name, url: @site_config&.website_url || @helper.root_url }
  end

  def offers_schema
    { '@type': 'Offer', price: '0', priceCurrency: 'USD', availability: 'https://schema.org/InStock', url: @helper.event_url(@event) }
  end

  def image_url
    if @event.banner_image.attached?
      @helper.url_for(@event.banner_image)
    elsif @site_config&.banner_image&.attached?
      @helper.url_for(@site_config.banner_image)
    end
  end

  def site_name
    @site_config&.organization_name || 'PDX Hackerspace'
  end
end

# Builder class for Organization JSON-LD
class OrganizationJsonLdBuilder
  def initialize(site_config, helper)
    @site_config = site_config
    @helper = helper
  end

  def build
    schema = {
      '@context': 'https://schema.org',
      '@type': 'Organization',
      name: @site_config&.organization_name || 'EventManager',
      url: @site_config&.website_url || @helper.root_url
    }
    schema[:email] = @site_config.contact_email if @site_config&.contact_email.present?
    schema[:telephone] = @site_config.contact_phone if @site_config&.contact_phone.present?
    schema[:address] = { '@type': 'PostalAddress', streetAddress: @site_config.address } if @site_config&.address.present?
    schema[:logo] = @helper.url_for(@site_config.banner_image) if @site_config&.banner_image&.attached?
    schema
  end
end
# rubocop:enable Rails/HelperInstanceVariable, Rails/OutputSafety

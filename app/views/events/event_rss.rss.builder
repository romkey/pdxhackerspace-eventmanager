# frozen_string_literal: true

xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0", "xmlns:atom" => "http://www.w3.org/2005/Atom" do
  xml.channel do
    render_event_channel_info(xml)
    render_event_channel_image(xml)
    @occurrences.each { |occ| render_occurrence_item(xml, occ) }
  end
end

def render_event_channel_info(xml)
  xml.title "#{@event.title} - #{@site_config&.organization_name || 'EventManager'}"
  xml.description @event.description.present? ? @event.description.truncate(500) : "Upcoming dates for #{@event.title}"
  xml.link event_url(@event)
  xml.language "en-us"
  xml.lastBuildDate @event.updated_at.rfc2822
  xml.tag! "atom:link", href: rss_event_url(@event, format: :rss), rel: "self", type: "application/rss+xml"
end

def render_event_channel_image(xml)
  return unless @event.banner_image.attached?

  xml.image do
    xml.url url_for(@event.banner_image)
    xml.title @event.title
    xml.link event_url(@event)
  end
end

def render_occurrence_item(xml, occurrence)
  xml.item do
    xml.title "#{@event.title} - #{occurrence.occurs_at.strftime('%B %d, %Y')}"
    xml.link event_occurrence_url(occurrence)
    xml.guid event_occurrence_url(occurrence), isPermaLink: "true"
    xml.pubDate occurrence.created_at.rfc2822
    xml.description build_occurrence_description(occurrence)
    render_occurrence_enclosure(xml, occurrence)
    xml.category @event.recurrence_type.titleize
    xml.category occurrence.status.titleize if occurrence.status != 'active'
  end
end

def build_occurrence_description(occurrence)
  parts = ["<p><strong>Date:</strong> #{occurrence.occurs_at.strftime('%A, %B %d, %Y at %I:%M %p')}</p>"]
  parts << "<p><strong>Duration:</strong> #{occurrence.duration} minutes</p>"
  parts << "<p><strong>Location:</strong> #{occurrence.event_location.name}</p>" if occurrence.event_location.present?
  parts << "<p><strong>Status:</strong> #{occurrence.status.titleize}</p>" if occurrence.status != 'active'
  if occurrence.status == 'postponed' && occurrence.postponed_until.present?
    parts << "<p><strong>Rescheduled to:</strong> #{occurrence.postponed_until.strftime('%B %d, %Y at %I:%M %p')}</p>"
  end
  parts << "<p>#{h(occurrence.description.truncate(500))}</p>" if occurrence.description.present?
  parts << "<p><a href=\"#{@event.more_info_url}\">More information</a></p>" if @event.more_info_url.present?
  parts.join
end

def render_occurrence_enclosure(xml, occurrence)
  banner = occurrence.banner_image.attached? ? occurrence.banner_image : @event.banner_image
  return unless banner.attached?

  xml.enclosure url: url_for(banner), type: banner.content_type, length: banner.byte_size
end

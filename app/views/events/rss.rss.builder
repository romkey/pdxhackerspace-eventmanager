xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0", "xmlns:atom" => "http://www.w3.org/2005/Atom" do
  xml.channel do
    xml.title "#{@site_config&.organization_name || 'EventManager'} Events"
    xml.description "Upcoming events at #{@site_config&.organization_name || 'our hackerspace'}"
    xml.link events_url
    xml.language "en-us"
    xml.lastBuildDate Time.current.rfc2822
    xml.tag! "atom:link", href: events_rss_url, rel: "self", type: "application/rss+xml"

    if @site_config&.banner_image&.attached?
      xml.image do
        xml.url url_for(@site_config.banner_image)
        xml.title @site_config&.organization_name || 'EventManager'
        xml.link root_url
      end
    end

    @events.each do |event|
      xml.item do
        xml.title event.title
        xml.link event_url(event)
        xml.guid event_url(event), isPermaLink: "true"
        xml.pubDate event.created_at.rfc2822

        # Build description with event details
        description = ""
        
        # Next occurrence info
        next_occurrence = event.occurrences.upcoming.first
        if next_occurrence
          description += "<p><strong>Next:</strong> #{next_occurrence.occurs_at.strftime('%B %d, %Y at %I:%M %p')}</p>"
        end

        # Location
        if event.location.present?
          description += "<p><strong>Location:</strong> #{event.location.name}</p>"
        end

        # Event description
        if event.description.present?
          description += "<p>#{h(event.description.truncate(500))}</p>"
        end

        # More info link
        if event.more_info_url.present?
          description += "<p><a href=\"#{event.more_info_url}\">More information</a></p>"
        end

        xml.description description

        # Add enclosure for banner image if available
        if event.banner_image.attached?
          xml.enclosure url: url_for(event.banner_image),
                        type: event.banner_image.content_type,
                        length: event.banner_image.byte_size
        end

        # Categories
        xml.category event.recurrence_type.titleize
        xml.category event.open_to == 'public' ? 'Open to All' : 'Members Only'
      end
    end
  end
end


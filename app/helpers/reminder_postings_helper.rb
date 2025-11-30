# frozen_string_literal: true

module ReminderPostingsHelper
  def render_platform_badge(platform)
    case platform
    when 'slack'
      content_tag(:span, class: 'badge bg-purple') do
        safe_join([content_tag(:i, '', class: 'bi bi-slack', 'aria-hidden': true), ' Slack'])
      end
    when 'bluesky'
      content_tag(:span, class: 'badge', style: 'background-color: #0085ff;') do
        safe_join([content_tag(:i, '', class: 'bi bi-cloud', 'aria-hidden': true), ' Bluesky'])
      end
    when 'instagram'
      content_tag(:span, class: 'badge', style: 'background-color: #E1306C;') do
        safe_join([content_tag(:i, '', class: 'bi bi-instagram', 'aria-hidden': true), ' Instagram'])
      end
    else
      content_tag(:span, platform.titleize, class: 'badge bg-secondary')
    end
  end
end

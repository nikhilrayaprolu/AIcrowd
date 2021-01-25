class Notification::BadgesNotificationJob < ApplicationJob
  queue_as :default

  def perform(badge_id)
    badge = AicrowdUserBadge.with_badge_meta.find(badge_id)
    NotificationService.new(badge.participant_id, badge, 'badge').call
  end
end

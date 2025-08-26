class Habit < ApplicationRecord
  belongs_to :milestone

  validates :title, presence: true, length: { minimum: 3, maximum: 100 }
  validates :description, length: { maximum: 500 }
  validates :frequency, inclusion: { in: %w[daily weekly monthly] }
  validates :status, inclusion: { in: %w[pending in_progress completed] }
  validates :priority, inclusion: { in: %w[low medium high] }

  scope :by_priority, -> { order(Arel.sql("CASE priority WHEN 'high' THEN 1 WHEN 'medium' THEN 2 WHEN 'low' THEN 3 END")) }
  scope :by_frequency, -> { order(:frequency) }
  scope :active, -> { where(status: [ "pending", "in_progress" ]) }
  scope :completed, -> { where(status: "completed") }
  scope :daily, -> { where(frequency: "daily") }
  scope :weekly, -> { where(frequency: "weekly") }
  scope :monthly, -> { where(frequency: "monthly") }

  def completion_streak
    # This would be enhanced with actual completion tracking
    # For now, return a simple count based on status
    status == "completed" ? 1 : 0
  end

  def overdue?
    return false unless frequency == "daily"
    return false if status == "completed"

    last_completed_at.nil? || last_completed_at.to_date < Date.current
  end

  def next_due_date
    case frequency
    when "daily"
      Date.current + 1.day
    when "weekly"
      Date.current + 1.week
    when "monthly"
      Date.current + 1.month
    else
      Date.current
    end
  end

  def mark_completed!
    update!(status: 'completed', completed_at: Time.current)
    
    # Get celebration quote for motivation
    celebration_quote = QuotableService.completion_celebration_quote
    
    # Check for achievements (using demo user for now)
    user_identifier = 'demo_user' # In future, get from current_user
    earned_achievements = AchievementService.check_habit_achievements(
      user_identifier, 
      self, 
      { completed_at: Time.current }
    )
    
    {
      habit: self,
      quote: celebration_quote,
      message: "Congratulations! You've completed your habit: #{title}",
      achievements: earned_achievements.map(&:display_info),
      points_earned: earned_achievements.sum { |ua| ua.achievement.points }
    }
  end

  def reset_status!
    update!(status: "pending")
  end
end

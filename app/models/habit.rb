class Habit < ApplicationRecord
  belongs_to :milestone
  belongs_to :user
  has_many :user_achievements, dependent: :destroy

  validates :title, presence: true, length: { minimum: 3, maximum: 100 }
  validates :description, length: { maximum: 500 }
  validates :frequency, inclusion: { in: %w[daily weekly monthly] }
  validates :status, inclusion: { in: %w[pending in_progress completed active] }
  validates :priority, inclusion: { in: %w[low medium high] }

  scope :by_priority, -> { order(Arel.sql("CASE priority WHEN 'high' THEN 1 WHEN 'medium' THEN 2 WHEN 'low' THEN 3 END")) }
  scope :by_frequency, -> { order(:frequency) }
  scope :active, -> { where(status: [ "pending", "in_progress" ]) }
  scope :completed, -> { where(status: "completed") }
  scope :daily, -> { where(frequency: "daily") }
  scope :weekly, -> { where(frequency: "weekly") }
  scope :monthly, -> { where(frequency: "monthly") }

  # Enhanced streak tracking with completion history
  def current_streak
    return 0 if completion_history.empty?
    
    streak = 0
    current_date = Date.current
    
    case frequency
    when 'daily'
      # Check consecutive days backwards from today
      while completion_history.include?(current_date.to_s)
        streak += 1
        current_date -= 1.day
      end
    when 'weekly'
      # Check consecutive weeks backwards from this week
      current_week_start = current_date.beginning_of_week
      while completion_history.any? { |date| Date.parse(date).beginning_of_week == current_week_start }
        streak += 1
        current_week_start -= 1.week
      end
    when 'monthly'
      # Check consecutive months backwards from this month
      current_month_start = current_date.beginning_of_month
      while completion_history.any? { |date| Date.parse(date).beginning_of_month == current_month_start }
        streak += 1
        current_month_start -= 1.month
      end
    end
    
    streak
  end

  def longest_streak
    return 0 if completion_history.empty?
    
    sorted_dates = completion_history.map { |date| Date.parse(date) }.sort
    max_streak = 0
    current_streak = 1
    
    case frequency
    when 'daily'
      sorted_dates.each_cons(2) do |prev_date, curr_date|
        if curr_date == prev_date + 1.day
          current_streak += 1
        else
          max_streak = [max_streak, current_streak].max
          current_streak = 1
        end
      end
    when 'weekly'
      sorted_dates.each_cons(2) do |prev_date, curr_date|
        if curr_date.beginning_of_week == prev_date.beginning_of_week + 1.week
          current_streak += 1
        else
          max_streak = [max_streak, current_streak].max
          current_streak = 1
        end
      end
    when 'monthly'
      sorted_dates.each_cons(2) do |prev_date, curr_date|
        if curr_date.beginning_of_month == prev_date.beginning_of_month + 1.month
          current_streak += 1
        else
          max_streak = [max_streak, current_streak].max
          current_streak = 1
        end
      end
    end
    
    [max_streak, current_streak].max
  end

  def completion_rate
    return 0.0 if created_at.nil?
    
    days_since_creation = (Date.current - created_at.to_date).to_i + 1
    expected_completions = case frequency
                          when 'daily'
                            days_since_creation
                          when 'weekly'
                            (days_since_creation / 7.0).ceil
                          when 'monthly'
                            ((Date.current.year * 12 + Date.current.month) - 
                             (created_at.year * 12 + created_at.month) + 1)
                          else
                            1
                          end
    
    return 100.0 if expected_completions == 0
    
    actual_completions = completion_history.count
    [(actual_completions.to_f / expected_completions * 100), 100.0].min.round(1)
  end

  def completion_streak
    current_streak
  end

  def next_due_date
    return Date.current if completion_history.empty?
    
    last_completion = Date.parse(completion_history.max)
    
    case frequency
    when "daily"
      last_completion + 1.day
    when "weekly"
      last_completion.beginning_of_week + 1.week
    when "monthly"
      last_completion.beginning_of_month + 1.month
    else
      Date.current
    end
  end

  def overdue?
    return false if completion_history.empty?
    
    last_completion = Date.parse(completion_history.max)
    
    case frequency
    when 'daily'
      last_completion < Date.current - 1.day
    when 'weekly'
      last_completion.beginning_of_week < Date.current.beginning_of_week - 1.week
    when 'monthly'
      last_completion.beginning_of_month < Date.current.beginning_of_month - 1.month
    else
      false
    end
  end

  def mark_completed!(completion_date = Date.current)
    # Add completion to history
    history = completion_history || []
    date_string = completion_date.to_s
    
    unless history.include?(date_string)
      history << date_string
      update!(
        completion_history: history.sort,
        last_completed_at: Time.current,
        status: 'completed'
      )
    end
    
    # Check for achievements using proper user object
    earned_achievements = AchievementService.check_habit_achievements(user, self)
    
    {
      habit: self,
      message: "Congratulations! You've completed your habit: #{title}",
      achievements: earned_achievements.map(&:display_info),
      raw_achievements: earned_achievements,
      points_earned: earned_achievements.sum { |ua| ua.achievement.points },
      current_streak: current_streak,
      completion_rate: completion_rate
    }
  end

  def reset_status!
    update!(status: "pending")
  end

  def reset_streak!
    update!(completion_history: [])
  end

  # Calculate progress percentage based on completion history and frequency
  def progress_percentage
    completion_rate
  end

  # Get completion history as array of date strings
  def completion_history
    super || []
  end

  # Check if completed today/this week/this month based on frequency
  def completed_in_current_period?
    return false if completion_history.empty?
    
    case frequency
    when 'daily'
      completion_history.include?(Date.current.to_s)
    when 'weekly'
      current_week_start = Date.current.beginning_of_week
      completion_history.any? { |date| Date.parse(date).beginning_of_week == current_week_start }
    when 'monthly'
      current_month_start = Date.current.beginning_of_month
      completion_history.any? { |date| Date.parse(date).beginning_of_month == current_month_start }
    else
      false
    end
  end

  # Get streak statistics
  def streak_stats
    {
      current_streak: current_streak,
      longest_streak: longest_streak,
      completion_rate: completion_rate,
      total_completions: completion_history.count,
      completed_in_current_period: completed_in_current_period?,
      overdue: overdue?,
      next_due_date: next_due_date
    }
  end
end

class UserAchievement < ApplicationRecord
  belongs_to :user
  belongs_to :achievement
  belongs_to :blueprint, optional: true
  belongs_to :milestone, optional: true
  belongs_to :habit, optional: true
  
  validates :earned_at, presence: true
  validates :achievement_id, uniqueness: { 
    scope: [:user_id, :blueprint_id, :milestone_id, :habit_id],
    message: "Achievement already earned for this context"
  }, unless: :repeatable_achievement?
  
  scope :for_user, ->(user_id) { where(user: user_id) }
  scope :recent, -> { order(earned_at: :desc) }
  scope :unnotified, -> { where(notified: false) }
  scope :by_achievement_type, ->(type) { joins(:achievement).where(achievements: { badge_type: type }) }
  scope :by_rarity, ->(rarity) { joins(:achievement).where(achievements: { rarity: rarity }) }
  
  # Get total points earned by user
  def self.total_points_for_user(user)
    joins(:achievement)
      .where(user: user)
      .sum('achievements.points')
  end
  
  # Get achievement stats for user
  def self.stats_for_user(user_or_id)
    user_id = user_or_id.is_a?(User) ? user_or_id.id : user_or_id
    user_obj = user_or_id.is_a?(User) ? user_or_id : User.find(user_id)
    user_achievements = for_user(user_id).includes(:achievement)
    
    {
      total_achievements: user_achievements.count,
      total_points: total_points_for_user(user_obj),
      by_rarity: user_achievements.joins(:achievement).group('achievements.rarity').count,
      by_type: user_achievements.joins(:achievement).group('achievements.badge_type').count,
      recent_achievements: user_achievements.recent.limit(5).map(&:display_info),
      streak_achievements: user_achievements.by_achievement_type('habit_streak').count,
      completion_achievements: user_achievements.by_achievement_type('blueprint_completion').count
    }
  end
  
  # Get leaderboard (top users by points)
  def self.leaderboard(limit = 10)
    select(:user_id)
      .joins(:achievement)
      .group(:user_id)
      .order('SUM(achievements.points) DESC')
      .limit(limit)
      .sum('achievements.points')
      .map do |user_id, points|
        {
          user: User.find(user_id),
          total_points: points,
          achievement_count: for_user(user_id).count,
          latest_achievement: for_user(user_id).recent.first&.achievement&.name
        }
      end
  end
  
  # Mark as notified
  def mark_as_notified!
    update!(notified: true)
  end
  
  # Get display information
  def display_info
    {
      id: id,
      achievement: achievement.display_info,
      earned_at: earned_at,
      context: context,
      streak_count: streak_count,
      associated_item: associated_item_info
    }
  end
  
  # Get associated item information
  def associated_item_info
    if blueprint
      { type: 'blueprint', id: blueprint.id, title: blueprint.title }
    elsif milestone
      { type: 'milestone', id: milestone.id, title: milestone.title }
    elsif habit
      { type: 'habit', id: habit.id, title: habit.title }
    else
      nil
    end
  end
  
  # Check if this is a repeatable achievement (like daily streaks)
  def repeatable_achievement?
    achievement.badge_type == 'habit_streak' || 
    achievement.criteria&.dig('repeatable') == true
  end
  
  # Get celebration message
  def celebration_message
    base_message = "🎉 Achievement Unlocked: #{achievement.name}!"
    
    case achievement.rarity
    when 'legendary'
      "🌟 LEGENDARY #{base_message} This is incredibly rare!"
    when 'epic'
      "⭐ EPIC #{base_message} Amazing work!"
    when 'rare'
      "✨ RARE #{base_message} Well done!"
    else
      base_message
    end
  end
  
  # Get points earned message
  def points_message
    "You earned #{achievement.points} points! 🏆"
  end
end

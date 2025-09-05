class Achievement < ApplicationRecord
  has_many :user_achievements, dependent: :destroy
  
  validates :name, presence: true, uniqueness: true
  validates :description, presence: true
  validates :badge_type, presence: true, inclusion: { 
    in: %w[habit_streak milestone_progress blueprint_completion special],
    message: "must be one of: habit_streak, milestone_progress, blueprint_completion, special"
  }
  validates :category, inclusion: { 
    in: %w[fitness business education creative personal general],
    message: "must be one of: fitness, business, education, creative, personal, general"
  }, allow_nil: true
  validates :rarity, inclusion: { 
    in: %w[common rare epic legendary],
    message: "must be one of: common, rare, epic, legendary"
  }
  validates :points, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  scope :active, -> { where(active: true) }
  scope :by_type, ->(type) { where(badge_type: type) }
  scope :by_category, ->(category) { where(category: category) }
  scope :by_rarity, ->(rarity) { where(rarity: rarity) }
  
  # Define achievement types
  BADGE_TYPES = {
    'habit_streak' => 'Habit Streak',
    'milestone_progress' => 'Milestone Progress', 
    'blueprint_completion' => 'Blueprint Completion',
    'special' => 'Special Achievement'
  }.freeze
  
  RARITIES = {
    'common' => { points: 10, color: '#CD7F32' },    
    'rare' => { points: 25, color: '#C0C0C0' },      
    'epic' => { points: 50, color: '#FFD700' },      
    'legendary' => { points: 100, color: '#E6E6FA' } 
  }.freeze
  
  # Check if criteria is met for earning this achievement
  def criteria_met?(context = {})
    return false unless active? && criteria.present?
    
    case badge_type
    when 'habit_streak'
      check_habit_streak_criteria(context)
    when 'milestone_progress'
      check_milestone_progress_criteria(context)
    when 'blueprint_completion'
      check_blueprint_completion_criteria(context)
    when 'special'
      check_special_criteria(context)
    else
      false
    end
  end
  
  # Get achievement difficulty level
  def difficulty_level
    case rarity
    when 'common' then 1
    when 'rare' then 2
    when 'epic' then 3
    when 'legendary' then 4
    else 1
    end
  end
  
  # Get rarity configuration
  def rarity_config
    RARITIES[rarity] || RARITIES['common']
  end
  
  # Increment earned count
  def increment_earned_count!
    increment!(:earned_count)
  end
  
  # Get formatted display info
  def display_info
    {
      id: id,
      name: name,
      description: description,
      icon: icon,
      color: color,
      rarity: rarity,
      points: points,
      badge_type: badge_type,
      category: category,
      difficulty: difficulty_level,
      earned_count: earned_count
    }
  end
  
  private
  
  def check_habit_streak_criteria(context)
    return false unless context[:habit] && context[:streak_count]
    
    required_streak = criteria['streak_days'] || 1
    context[:streak_count] >= required_streak
  end
  
  def check_milestone_progress_criteria(context)
    return false unless context[:milestone]
    
    milestone = context[:milestone]
    required_progress = criteria['progress_percentage'] || 100
    
    milestone.progress_percentage >= required_progress
  end
  
  def check_blueprint_completion_criteria(context)
    return false unless context[:blueprint]
    
    blueprint = context[:blueprint]
    
    case criteria['completion_type']
    when 'full_completion'
      blueprint.status == 'completed'
    when 'early_completion'
      blueprint.status == 'completed' && blueprint.target_date > Date.current
    when 'on_time_completion'
      blueprint.status == 'completed' && blueprint.target_date >= Date.current
    else
      blueprint.status == 'completed'
    end
  end
  
  def check_special_criteria(context)
    case criteria['special_type']
    when 'early_bird'
      # Completed habit before 8 AM
      context[:completed_at]&.hour&.< 8
    when 'night_owl'
      # Completed habit after 10 PM
      context[:completed_at]&.hour&.>= 22
    when 'perfectionist'
      # Completed all habits in a milestone
      context[:milestone]&.habits&.all? { |h| h.status == 'completed' }
    when 'comeback_kid'
      # Completed habit after missing it for 3+ days
      context[:days_since_last_completion] && context[:days_since_last_completion] >= 3
    when 'weekend_warrior'
      # Completed habit on weekend
      context[:completed_at]&.saturday? || context[:completed_at]&.sunday?
    else
      false
    end
  end
end

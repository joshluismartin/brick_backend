class AchievementService
  # Award achievements based on context
  def self.check_and_award_achievements(user_identifier, context = {})
    earned_achievements = []
    
    # Get all active achievements
    achievements = Achievement.active
    
    achievements.each do |achievement|
      if achievement.criteria_met?(context)
        # Check if user already has this achievement (unless repeatable)
        existing = UserAchievement.find_by(
          user_identifier: user_identifier,
          achievement: achievement,
          blueprint: context[:blueprint],
          milestone: context[:milestone],
          habit: context[:habit]
        )
        
        # Skip if already earned and not repeatable
        next if existing && !achievement.criteria['repeatable']
        
        # Award the achievement
        user_achievement = award_achievement(user_identifier, achievement, context)
        earned_achievements << user_achievement if user_achievement
      end
    end
    
    earned_achievements
  end
  
  # Award a specific achievement to a user
  def self.award_achievement(user_identifier, achievement, context = {})
    user_achievement = UserAchievement.create!(
      user_identifier: user_identifier,
      achievement: achievement,
      blueprint: context[:blueprint],
      milestone: context[:milestone],
      habit: context[:habit],
      earned_at: Time.current,
      context: context.except(:blueprint, :milestone, :habit),
      streak_count: context[:streak_count]
    )
    
    # Increment the achievement's earned count
    achievement.increment_earned_count!
    
    user_achievement
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to award achievement #{achievement.name}: #{e.message}"
    nil
  end
  
  # Check for habit-related achievements
  def self.check_habit_achievements(user_identifier, habit, context = {})
    habit_context = {
      habit: habit,
      milestone: habit.milestone,
      blueprint: habit.milestone.blueprint,
      completed_at: context[:completed_at] || Time.current,
      streak_count: calculate_habit_streak(habit),
      days_since_last_completion: context[:days_since_last_completion]
    }
    
    check_and_award_achievements(user_identifier, habit_context)
  end
  
  # Check for milestone-related achievements
  def self.check_milestone_achievements(user_identifier, milestone)
    milestone_context = {
      milestone: milestone,
      blueprint: milestone.blueprint,
      progress_percentage: milestone.progress_percentage
    }
    
    check_and_award_achievements(user_identifier, milestone_context)
  end
  
  # Check for blueprint-related achievements
  def self.check_blueprint_achievements(user_identifier, blueprint)
    blueprint_context = {
      blueprint: blueprint,
      completion_date: blueprint.status == 'completed' ? Date.current : nil,
      early_completion: blueprint.target_date > Date.current && blueprint.status == 'completed'
    }
    
    check_and_award_achievements(user_identifier, blueprint_context)
  end
  
  # Seed default achievements
  def self.seed_default_achievements!
    default_achievements = [
      # Habit Streak Achievements
      {
        name: "First Steps",
        description: "Complete your first habit",
        badge_type: "habit_streak",
        category: "general",
        icon: "👶",
        color: "#CD7F32",
        points: 10,
        rarity: "common",
        criteria: { "streak_days" => 1 }
      },
      {
        name: "Getting Started",
        description: "Complete a habit for 3 days in a row",
        badge_type: "habit_streak",
        category: "general",
        icon: "🔥",
        color: "#CD7F32",
        points: 25,
        rarity: "common",
        criteria: { "streak_days" => 3 }
      },
      {
        name: "Week Warrior",
        description: "Complete a habit for 7 days in a row",
        badge_type: "habit_streak",
        category: "general",
        icon: "⚡",
        color: "#C0C0C0",
        points: 50,
        rarity: "rare",
        criteria: { "streak_days" => 7 }
      },
      {
        name: "Habit Master",
        description: "Complete a habit for 30 days in a row",
        badge_type: "habit_streak",
        category: "general",
        icon: "👑",
        color: "#FFD700",
        points: 100,
        rarity: "epic",
        criteria: { "streak_days" => 30 }
      },
      {
        name: "Legendary Streak",
        description: "Complete a habit for 100 days in a row",
        badge_type: "habit_streak",
        category: "general",
        icon: "🏆",
        color: "#E6E6FA",
        points: 250,
        rarity: "legendary",
        criteria: { "streak_days" => 100 }
      },
      
      # Milestone Progress Achievements
      {
        name: "Progress Maker",
        description: "Reach 50% progress on a milestone",
        badge_type: "milestone_progress",
        category: "general",
        icon: "📈",
        color: "#CD7F32",
        points: 20,
        rarity: "common",
        criteria: { "progress_percentage" => 50 }
      },
      {
        name: "Almost There",
        description: "Reach 90% progress on a milestone",
        badge_type: "milestone_progress",
        category: "general",
        icon: "🎯",
        color: "#C0C0C0",
        points: 40,
        rarity: "rare",
        criteria: { "progress_percentage" => 90 }
      },
      
      # Blueprint Completion Achievements
      {
        name: "Goal Crusher",
        description: "Complete your first blueprint",
        badge_type: "blueprint_completion",
        category: "general",
        icon: "💪",
        color: "#FFD700",
        points: 100,
        rarity: "epic",
        criteria: { "completion_type" => "full_completion" }
      },
      {
        name: "Speed Demon",
        description: "Complete a blueprint before the target date",
        badge_type: "blueprint_completion",
        category: "general",
        icon: "🚀",
        color: "#E6E6FA",
        points: 150,
        rarity: "legendary",
        criteria: { "completion_type" => "early_completion" }
      },
      
      # Special Achievements
      {
        name: "Early Bird",
        description: "Complete a habit before 8 AM",
        badge_type: "special",
        category: "general",
        icon: "🌅",
        color: "#FFD700",
        points: 15,
        rarity: "rare",
        criteria: { "special_type" => "early_bird", "repeatable" => true }
      },
      {
        name: "Night Owl",
        description: "Complete a habit after 10 PM",
        badge_type: "special",
        category: "general",
        icon: "🦉",
        color: "#FFD700",
        points: 15,
        rarity: "rare",
        criteria: { "special_type" => "night_owl", "repeatable" => true }
      },
      {
        name: "Perfectionist",
        description: "Complete all habits in a milestone",
        badge_type: "special",
        category: "general",
        icon: "✨",
        color: "#E6E6FA",
        points: 75,
        rarity: "epic",
        criteria: { "special_type" => "perfectionist" }
      },
      {
        name: "Comeback Kid",
        description: "Complete a habit after missing it for 3+ days",
        badge_type: "special",
        category: "general",
        icon: "💪",
        color: "#C0C0C0",
        points: 30,
        rarity: "rare",
        criteria: { "special_type" => "comeback_kid", "repeatable" => true }
      },
      {
        name: "Weekend Warrior",
        description: "Complete habits on weekends",
        badge_type: "special",
        category: "general",
        icon: "🏖️",
        color: "#FFD700",
        points: 20,
        rarity: "rare",
        criteria: { "special_type" => "weekend_warrior", "repeatable" => true }
      }
    ]
    
    default_achievements.each do |achievement_data|
      Achievement.find_or_create_by(name: achievement_data[:name]) do |achievement|
        achievement.assign_attributes(achievement_data)
      end
    end
    
    Rails.logger.info "Seeded #{default_achievements.length} default achievements"
  end
  
  private
  
  def self.calculate_habit_streak(habit)
    # Simple streak calculation - in a real app, you'd track completion history
    # For now, return a mock streak based on habit status
    case habit.status
    when 'completed'
      rand(1..10) # Mock streak for demo
    else
      0
    end
  end
end

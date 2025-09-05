class AchievementService
  def self.check_and_award_achievements(user, context_type, context_object = nil)
    return [] unless user

    awarded_achievements = []
    
    # Get all achievements that could be awarded
    active_achievements = Achievement.active
    
    active_achievements.each do |achievement|
      
      if user_already_has_achievement?(user, achievement, context_object)
        next
      end
      
      criteria_met = achievement_criteria_met?(user, achievement, context_type, context_object)
      
      if criteria_met
        user_achievement = award_achievement_to_user(user, achievement, context_object)
        awarded_achievements << user_achievement if user_achievement
      end
    end
    
    awarded_achievements
  end

  def self.award_achievement_to_user(user, achievement, context_object = nil)
    context_attributes = {}
    
    case context_object
    when Blueprint
      context_attributes[:blueprint] = context_object
    when Milestone
      context_attributes[:milestone] = context_object
    when Habit
      context_attributes[:habit] = context_object
    end

    user_achievement = UserAchievement.find_or_create_by(
      user: user,
      achievement: achievement
    ) do |ua|
      ua.earned_at = Time.current
      # Set context attributes on creation
      context_attributes.each { |key, value| ua.send("#{key}=", value) }
    end

    # If the record already existed, update context attributes if they're different
    if context_attributes.any?
      needs_update = context_attributes.any? { |key, value| user_achievement.send(key) != value }
      if needs_update
        user_achievement.update!(context_attributes)
      end
    end

    user_achievement
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "Failed to award achievement #{achievement.name}: #{e.message}"
    Rails.logger.warn "Validation errors: #{e.record.errors.full_messages}" if e.record
    nil
  end

  private

  def self.user_already_has_achievement?(user, achievement, context_object = nil)
    query = UserAchievement.where(user: user, achievement: achievement)
    
    # For context-specific achievements, check if they already have it for this context
    case context_object
    when Blueprint
      query = query.where(blueprint: context_object)
    when Milestone
      query = query.where(milestone: context_object)
    when Habit
      query = query.where(habit: context_object)
    end
    
    query.exists?
  end

  def self.achievement_criteria_met?(user, achievement, context_type, context_object = nil)
    criteria = achievement.criteria
    
    case achievement.badge_type
    when 'habit_streak'
      check_habit_streak_criteria(user, criteria, context_object)
    when 'milestone_progress'
      check_milestone_progress_criteria(user, criteria, context_object)
    when 'blueprint_completion'
      check_blueprint_completion_criteria(user, criteria, context_object)
    when 'special'
      check_special_criteria(user, criteria, context_type)
    else
      false
    end
  end

  def self.check_habit_streak_criteria(user, criteria, context_object = nil)
    required_streak = criteria['streak_days'] || 7
    
    # Special case for "First Steps" achievement (streak_days = 1)
    # Award immediately when habit is completed for the first time
    if required_streak == 1 && context_object.is_a?(Habit)
      # Check if this habit has any completions (including today)
      has_completions = context_object.completion_history.any?
      return has_completions
    end
    
    # Only check habit streaks if we have a habit context or checking user's habits
    case context_object
    when Habit
      # Check specific habit streak using enhanced tracking
      current_streak = context_object.current_streak
      result = current_streak >= required_streak
      result
    when Blueprint, Milestone
      # For blueprint/milestone context, check if user has any habits with required streak
      user.habits.any? { |habit| habit.current_streak >= required_streak }
    else
      # Check any habit streak for the user
      user.habits.any? { |habit| habit.current_streak >= required_streak }
    end
  end

  def self.check_milestone_progress_criteria(user, criteria, context_object = nil)
    required_percentage = criteria['progress_percentage'] || 50
    
    case context_object
    when Milestone
      # Check specific milestone progress
      current_progress = context_object.progress_percentage
      result = current_progress >= required_percentage
      result
    when Blueprint
      # Check if blueprint has milestones meeting criteria
      blueprint_milestones = context_object.milestones
      result = blueprint_milestones.any? { |milestone| milestone.progress_percentage >= required_percentage }
      result
    else
      # Check any milestone progress for the user
      result = user.milestones.any? { |milestone| milestone.progress_percentage >= required_percentage }
      result
    end
  end

  def self.check_blueprint_completion_criteria(user, criteria, context_object = nil)
    required_count = criteria['required_count'] || 1
    
    case context_object
    when Blueprint
      # Check specific blueprint criteria
      case criteria['completion_type']
      when 'creation'
        # Award for creating any blueprint if user doesn't already have this achievement
        # This should always return true since we're creating a blueprint
        true
      when 'full_completion'
        context_object.status == 'completed'
      when 'early_completion'
        context_object.status == 'completed' && context_object.target_date > Date.current
      when 'on_time_completion'
        context_object.status == 'completed' && context_object.target_date >= Date.current
      else
        context_object.status == 'completed'
      end
    else
      # Check completed blueprints count for user
      user.blueprints.where(status: 'completed').count >= required_count
    end
  end

  def self.check_special_criteria(user, criteria, context_type = nil)
    case criteria['type']
    when 'first_habit'
      user.habits.count >= 1
    when 'habit_master'
      # User has completed habits with total streak of 100+ days
      total_streak = user.habits.sum(&:longest_streak)
      total_streak >= (criteria['total_streak'] || 100)
    when 'consistency_champion'
      # User has habits with high completion rates
      high_rate_habits = user.habits.select { |h| h.completion_rate >= 80.0 }
      high_rate_habits.count >= (criteria['habit_count'] || 5)
    when 'streak_legend'
      # User has at least one habit with very long streak
      max_streak = user.habits.maximum(:current_streak) || 0
      max_streak >= (criteria['streak_days'] || 30)
    when 'milestone_achiever'
      user.milestones.where(status: 'completed').count >= (criteria['count'] || 10)
    when 'blueprint_architect'
      user.blueprints.where(status: 'completed').count >= (criteria['count'] || 3)
    when 'perfect_week'
      # All daily habits completed for 7 consecutive days
      daily_habits = user.habits.daily
      return false if daily_habits.empty?
      
      daily_habits.all? { |habit| habit.current_streak >= 7 }
    when 'comeback_kid'
      # User completed a habit after a break (had completions, then gap, then completed again)
      user.habits.any? { |habit| 
        habit.completed_in_current_period? && 
        habit.completion_history.count > 1 # Had previous completions
      }
    else
      false
    end
  end

  # Check for habit-related achievements
  def self.check_habit_achievements(user, habit)
    check_and_award_achievements(user, 'habit', habit)
  end

  # Check for milestone-related achievements
  def self.check_milestone_achievements(user, milestone)
    check_and_award_achievements(user, 'milestone', milestone)
  end

  # Check for blueprint-related achievements
  def self.check_blueprint_achievements(user, blueprint)
    check_and_award_achievements(user, 'blueprint', blueprint)
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
        icon: "",
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
        icon: "",
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
        icon: "",
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
        icon: "",
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
        icon: "",
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
        icon: "",
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
        icon: "",
        color: "#C0C0C0",
        points: 40,
        rarity: "rare",
        criteria: { "progress_percentage" => 90 }
      },
      
      # Blueprint Completion Achievements
      {
        name: "Blueprint Beginner",
        description: "Create your first blueprint",
        badge_type: "blueprint_completion",
        category: "general",
        icon: "",
        color: "#CD7F32",
        points: 25,
        rarity: "common",
        criteria: { "completion_type" => "creation" }
      },
      {
        name: "Goal Crusher",
        description: "Complete your first blueprint",
        badge_type: "blueprint_completion",
        category: "general",
        icon: "",
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
        icon: "",
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
        icon: "",
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
        icon: "",
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
        icon: "",
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
        icon: "",
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
        icon: "",
        color: "#FFD700",
        points: 20,
        rarity: "rare",
        criteria: { "special_type" => "weekend_warrior", "repeatable" => true }
      }
    ]
    
    default_achievements.each do |achievement_data|
      Achievement.find_or_create_by(name: achievement_data[:name]) do |achievement|
        achievement.assign_attributes(achievement_data.merge(active: true))
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

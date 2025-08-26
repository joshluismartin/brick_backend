class Api::V1::AchievementsController < Api::V1::BaseController
  before_action :set_user_identifier
  
  # GET /api/v1/achievements - Get all available achievements
  def index
    achievements = Achievement.active.includes(:user_achievements)
    
    # Add earned status for current user
    achievements_with_status = achievements.map do |achievement|
      user_earned = achievement.user_achievements.where(user_identifier: @user_identifier).exists?
      
      achievement.display_info.merge({
        earned: user_earned,
        earned_count_global: achievement.earned_count
      })
    end
    
    render_success({
      achievements: achievements_with_status,
      total_count: achievements.count,
      categories: achievements.pluck(:category).uniq.compact,
      rarities: Achievement::RARITIES.keys
    }, "Available achievements retrieved successfully")
  end

  # GET /api/v1/achievements/user - Get user's earned achievements
  def user_achievements
    user_achievements = UserAchievement.for_user(@user_identifier)
                                      .includes(:achievement, :blueprint, :milestone, :habit)
                                      .recent
    
    render_success({
      achievements: user_achievements.map(&:display_info),
      stats: UserAchievement.stats_for_user(@user_identifier),
      total_count: user_achievements.count
    }, "User achievements retrieved successfully")
  end

  # GET /api/v1/achievements/stats - Get user achievement statistics
  def stats
    stats = UserAchievement.stats_for_user(@user_identifier)
    
    # Add additional stats
    total_possible = Achievement.active.count
    completion_rate = total_possible > 0 ? (stats[:total_achievements].to_f / total_possible * 100).round(2) : 0
    
    render_success({
      **stats,
      completion_rate: completion_rate,
      total_possible_achievements: total_possible,
      user_rank: calculate_user_rank(@user_identifier)
    }, "Achievement statistics retrieved successfully")
  end

  # GET /api/v1/achievements/leaderboard - Get achievement leaderboard
  def leaderboard
    limit = params[:limit]&.to_i || 10
    leaderboard = UserAchievement.leaderboard(limit)
    
    # Add current user's position if not in top list
    user_position = find_user_position(@user_identifier)
    
    render_success({
      leaderboard: leaderboard,
      user_position: user_position,
      total_users: UserAchievement.select(:user_identifier).distinct.count
    }, "Achievement leaderboard retrieved successfully")
  end

  # POST /api/v1/achievements/check/:type - Manually trigger achievement check
  def check_achievements
    achievement_type = params[:type]
    context = achievement_params
    
    case achievement_type
    when 'habit'
      habit = Habit.find(context[:habit_id])
      earned = AchievementService.check_habit_achievements(@user_identifier, habit, context)
    when 'milestone'
      milestone = Milestone.find(context[:milestone_id])
      earned = AchievementService.check_milestone_achievements(@user_identifier, milestone)
    when 'blueprint'
      blueprint = Blueprint.find(context[:blueprint_id])
      earned = AchievementService.check_blueprint_achievements(@user_identifier, blueprint)
    else
      render_error("Invalid achievement type. Must be: habit, milestone, or blueprint", :bad_request)
      return
    end
    
    render_success({
      newly_earned: earned.map(&:display_info),
      count: earned.length,
      total_points_earned: earned.sum { |ua| ua.achievement.points }
    }, "Achievement check completed successfully")
  rescue ActiveRecord::RecordNotFound => e
    render_error("Record not found: #{e.message}", :not_found)
  end

  # GET /api/v1/achievements/progress - Get progress toward unearned achievements
  def progress
    all_achievements = Achievement.active
    earned_achievement_ids = UserAchievement.for_user(@user_identifier).pluck(:achievement_id)
    unearned_achievements = all_achievements.where.not(id: earned_achievement_ids)
    
    progress_data = unearned_achievements.map do |achievement|
      progress_info = calculate_achievement_progress(achievement)
      
      achievement.display_info.merge({
        progress: progress_info[:progress],
        progress_description: progress_info[:description],
        next_milestone: progress_info[:next_milestone]
      })
    end
    
    render_success({
      unearned_achievements: progress_data,
      total_unearned: progress_data.length,
      closest_achievements: progress_data.sort_by { |a| -a[:progress] }.first(5)
    }, "Achievement progress retrieved successfully")
  end

  # POST /api/v1/achievements/seed - Seed default achievements (admin endpoint)
  def seed
    AchievementService.seed_default_achievements!
    
    render_success({
      message: "Default achievements seeded successfully",
      total_achievements: Achievement.count
    }, "Achievements seeded successfully")
  end

  # GET /api/v1/achievements/recent - Get recent achievements across all users
  def recent
    limit = params[:limit]&.to_i || 20
    recent_achievements = UserAchievement.recent
                                        .includes(:achievement, :blueprint, :milestone, :habit)
                                        .limit(limit)
    
    # Anonymize user identifiers for privacy
    recent_data = recent_achievements.map do |ua|
      ua.display_info.merge({
        user_identifier: "User#{ua.user_identifier.hash.abs % 1000}",
        celebration_message: ua.celebration_message
      })
    end
    
    render_success({
      recent_achievements: recent_data,
      count: recent_data.length
    }, "Recent achievements retrieved successfully")
  end

  # GET /api/v1/achievements/categories/:category - Get achievements by category
  def by_category
    category = params[:category]
    achievements = Achievement.active.by_category(category)
    
    if achievements.empty?
      render_error("No achievements found for category: #{category}", :not_found)
      return
    end
    
    # Add earned status for current user
    achievements_with_status = achievements.map do |achievement|
      user_earned = achievement.user_achievements.where(user_identifier: @user_identifier).exists?
      
      achievement.display_info.merge({
        earned: user_earned
      })
    end
    
    render_success({
      achievements: achievements_with_status,
      category: category,
      count: achievements_with_status.length
    }, "Category achievements retrieved successfully")
  end

  private

  def set_user_identifier
    # For now, use a simple user identifier from headers or params
    # In the future, this will come from authenticated user
    @user_identifier = request.headers['X-User-Identifier'] || 
                      params[:user_identifier] || 
                      'demo_user'
  end

  def calculate_user_rank(user_identifier)
    user_points = UserAchievement.total_points_for_user(user_identifier)
    users_with_more_points = UserAchievement.joins(:achievement)
                                           .group(:user_identifier)
                                           .having('SUM(achievements.points) > ?', user_points)
                                           .count
    
    users_with_more_points.length + 1
  end

  def find_user_position(user_identifier)
    leaderboard = UserAchievement.leaderboard(1000) # Get extended leaderboard
    position = leaderboard.find_index { |entry| entry[:user_identifier] == user_identifier }
    
    if position
      {
        rank: position + 1,
        points: leaderboard[position][:total_points],
        achievement_count: leaderboard[position][:achievement_count]
      }
    else
      {
        rank: nil,
        points: UserAchievement.total_points_for_user(user_identifier),
        achievement_count: UserAchievement.for_user(user_identifier).count
      }
    end
  end

  def calculate_achievement_progress(achievement)
    # This is a simplified progress calculation
    # In a real app, you'd calculate actual progress based on user's current habits/milestones
    case achievement.badge_type
    when 'habit_streak'
      required_days = achievement.criteria['streak_days'] || 1
      # Mock current streak - in real app, calculate from habit completion history
      current_streak = rand(0..required_days-1)
      progress = (current_streak.to_f / required_days * 100).round(2)
      
      {
        progress: progress,
        description: "#{current_streak}/#{required_days} days completed",
        next_milestone: "Complete #{required_days - current_streak} more days"
      }
    when 'milestone_progress'
      {
        progress: 0,
        description: "Start working on milestones",
        next_milestone: "Create and work on a milestone"
      }
    when 'blueprint_completion'
      {
        progress: 0,
        description: "Complete a blueprint",
        next_milestone: "Finish your current blueprint"
      }
    else
      {
        progress: 0,
        description: "Special achievement",
        next_milestone: "Meet the special criteria"
      }
    end
  end

  def achievement_params
    params.permit(:habit_id, :milestone_id, :blueprint_id, :completed_at, :days_since_last_completion, :user_identifier, :limit, :category, :type)
  end
end

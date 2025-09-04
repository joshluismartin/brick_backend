class Api::V1::AchievementsController < Api::V1::BaseController
  before_action :set_user_id
  
  # GET /api/v1/achievements - Get all available achievements
  def index
    achievements = Achievement.active.includes(:user_achievements)
    
    # Add earned status for current user
    achievements_with_status = achievements.map do |achievement|
      user_earned = achievement.user_achievements.where(user_id: current_user.id).exists?
      
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
    Rails.logger.info "DEBUG: user_achievements endpoint called for user #{current_user.id}"
    
    user_achievements = UserAchievement.for_user(current_user.id)
                                      .includes(:achievement, :blueprint, :milestone, :habit)
                                      .recent
    
    Rails.logger.info "DEBUG: Found #{user_achievements.count} user achievements"
    user_achievements.each do |ua|
      Rails.logger.info "DEBUG: UserAchievement ID: #{ua.id}, Achievement: #{ua.achievement.name}, Earned: #{ua.earned_at}"
    end
    
    render_success({
      achievements: user_achievements.map(&:display_info),
      stats: UserAchievement.stats_for_user(current_user.id),
      total_count: user_achievements.count
    }, "User achievements retrieved successfully")
  end

  # GET /api/v1/achievements/stats - Get user achievement statistics
  def stats
    begin
      stats = UserAchievement.stats_for_user(current_user.id)
      
      # Add additional stats
      total_possible = Achievement.active.count
      completion_rate = total_possible > 0 ? (stats[:total_achievements].to_f / total_possible * 100).round(2) : 0
      
      render_success({
        **stats,
        completion_rate: completion_rate,
        total_possible_achievements: total_possible,
        user_rank: calculate_user_rank(current_user.id)
      }, "Achievement statistics retrieved successfully")
    rescue => e
      Rails.logger.error "Achievement stats error: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
      
      # Return empty stats to prevent dashboard failure
      render_success({
        total_achievements: 0,
        total_points: 0,
        by_rarity: {},
        by_type: {},
        recent_achievements: [],
        streak_achievements: 0,
        completion_achievements: 0,
        completion_rate: 0,
        total_possible_achievements: Achievement.active.count,
        user_rank: 1
      }, "Achievement statistics retrieved (with fallback)")
    end
  end

  # GET /api/v1/achievements/leaderboard - Get achievement leaderboard
  def leaderboard
    limit = params[:limit]&.to_i || 10
    leaderboard = UserAchievement.leaderboard(limit)
    
    # Add current user's position if not in top list
    user_position = find_user_position(current_user.id)
    
    render_success({
      leaderboard: leaderboard,
      user_position: user_position,
      total_users: UserAchievement.select(:user_id).distinct.count
    }, "Achievement leaderboard retrieved successfully")
  end

  # POST /api/v1/achievements/check/:type - Manually trigger achievement check
  def check_achievements
    achievement_type = params[:type]
    context = achievement_params
    
    case achievement_type
    when 'habit'
      habit = Habit.find(context[:habit_id])
      earned = AchievementService.check_habit_achievements(current_user, habit)
    when 'milestone'
      milestone = Milestone.find(context[:milestone_id])
      earned = AchievementService.check_milestone_achievements(current_user, milestone)
    when 'blueprint'
      blueprint = Blueprint.find(context[:blueprint_id])
      earned = AchievementService.check_blueprint_achievements(current_user, blueprint)
    else
      return render_error("Invalid achievement type", :bad_request)
    end
    
    render_success({
      achievements: earned.map do |ua|
        {
          id: ua.achievement.id,
          name: ua.achievement.name,
          description: ua.achievement.description,
          badge_type: ua.achievement.badge_type,
          points: ua.achievement.points,
          earned_at: ua.earned_at
        }
      end,
      total_points: earned.sum { |ua| ua.achievement.points }
    }, "Achievements checked successfully")
  rescue ActiveRecord::RecordNotFound => e
    render_error("Record not found: #{e.message}", :not_found)
  rescue => e
    render_error("Error checking achievements: #{e.message}", :internal_server_error)
  end

  # GET /api/v1/achievements/progress - Get progress toward unearned achievements
  def progress
    all_achievements = Achievement.active
    earned_achievement_ids = UserAchievement.for_user(current_user.id).pluck(:achievement_id)
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
                                        .includes(:achievement, :blueprint, :milestone, :habit, :user)
                                        .limit(limit)
    
    # Anonymize user identifiers for privacy
    recent_data = recent_achievements.map do |ua|
      ua.display_info.merge({
        user_identifier: "User#{ua.user_id.hash.abs % 1000}",
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
      user_earned = achievement.user_achievements.where(user_id: current_user.id).exists?
      
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

  # GET /api/v1/achievements/debug - Debug endpoint to check data
  def debug
    Rails.logger.info "DEBUG: Debug endpoint called for user #{current_user.id}"
    
    # Check raw database data
    raw_user_achievements = UserAchievement.where(user: current_user)
    raw_achievements = Achievement.all
    
    debug_info = {
      current_user_id: current_user.id,
      current_user_email: current_user.email,
      raw_user_achievements_count: raw_user_achievements.count,
      raw_achievements_count: raw_achievements.count,
      active_achievements_count: Achievement.active.count,
      
      # Raw user achievements data
      raw_user_achievements_data: raw_user_achievements.map do |ua|
        {
          id: ua.id,
          user_id: ua.user_id,
          achievement_id: ua.achievement_id,
          achievement_name: ua.achievement&.name,
          earned_at: ua.earned_at,
          context: ua.context,
          blueprint_id: ua.blueprint_id,
          milestone_id: ua.milestone_id,
          habit_id: ua.habit_id
        }
      end,
      
      # Test display_info method
      display_info_test: raw_user_achievements.first&.display_info,
      
      # Test scopes
      for_user_scope_count: UserAchievement.for_user(current_user.id).count,
      recent_scope_count: UserAchievement.for_user(current_user.id).recent.count,
      
      # Test includes
      with_includes_count: UserAchievement.for_user(current_user.id)
                                         .includes(:achievement, :blueprint, :milestone, :habit)
                                         .count
    }
    
    Rails.logger.info "DEBUG: Debug info: #{debug_info.to_json}"
    
    render_success(debug_info, "Debug information retrieved successfully")
  end

  private

  def set_user_id
    @user_id = current_user.id
  end

  def calculate_user_rank(user_id)
    user_points = UserAchievement.total_points_for_user(User.find(user_id))
    users_with_more_points = UserAchievement.joins(:achievement)
                                           .group(:user_id)
                                           .having('SUM(achievements.points) > ?', user_points)
                                           .count
    
    users_with_more_points.length + 1
  end

  def find_user_position(user_id)
    leaderboard = UserAchievement.leaderboard(1000) # Get extended leaderboard
    position = leaderboard.find_index { |entry| entry[:user].id == user_id }
    
    if position
      {
        rank: position + 1,
        points: leaderboard[position][:total_points],
        achievement_count: leaderboard[position][:achievement_count]
      }
    else
      {
        rank: nil,
        points: UserAchievement.total_points_for_user(User.find(user_id)),
        achievement_count: UserAchievement.for_user(user_id).count
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
    params.permit(:habit_id, :milestone_id, :blueprint_id, :completed_at, :days_since_last_completion, :limit, :category, :type)
  end
end

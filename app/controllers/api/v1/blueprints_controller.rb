class Api::V1::BlueprintsController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :set_blueprint, only: [:show, :update, :destroy, :complete]

  def index
    blueprints = current_user.blueprints.includes(:milestones, :user)
    
    render_success({
      blueprints: blueprints.map do |blueprint|
        {
          id: blueprint.id,
          title: blueprint.title,
          description: blueprint.description,
          status: blueprint.status,
          priority: blueprint.priority,
          category: blueprint.category,
          target_date: blueprint.target_date,
          progress_percentage: blueprint.progress_percentage,
          milestones_count: blueprint.milestones.count,
          created_at: blueprint.created_at,
          updated_at: blueprint.updated_at
        }
      end,
      total_count: blueprints.count
    }, "Blueprints loaded successfully")
  end

  def show
    render_success({
      blueprint: blueprint_json(@blueprint)
    }, "Blueprint loaded successfully")
  end

  def create
    blueprint = current_user.blueprints.build(blueprint_params)
    
    if blueprint.save
      Rails.logger.info "DEBUG: Blueprint created successfully, checking achievements..."
      
      # Quick check if achievements exist
      total_achievements = Achievement.count
      active_achievements = Achievement.active.count
      Rails.logger.info "DEBUG: Total achievements in DB: #{total_achievements}, Active: #{active_achievements}"
      
      if active_achievements == 0
        Rails.logger.warn "WARNING: No active achievements found! You need to seed achievements first."
        Rails.logger.warn "Run: POST /api/v1/achievements/seed"
      end
      
      # Check for achievements
      awarded_achievements = AchievementService.check_blueprint_achievements(current_user, blueprint)
      Rails.logger.info "DEBUG: Achievement check complete, awarded: #{awarded_achievements.count}"
      
      # Verify achievements were actually saved
      user_achievement_count = UserAchievement.where(user: current_user).count
      Rails.logger.info "DEBUG: Total user achievements in DB after creation: #{user_achievement_count}"
      
      render_success({
        blueprint: blueprint_json(blueprint),
        achievements: awarded_achievements.map(&:display_info)
      }, "Blueprint created successfully", :created)
    else
      render_error("Failed to create blueprint: #{blueprint.errors.full_messages.join(', ')}", :unprocessable_entity)
    end
  end

  def update
    if @blueprint.update(blueprint_params)
      render_success({
        blueprint: blueprint_json(@blueprint)
      }, "Blueprint updated successfully")
    else
      render_error("Failed to update blueprint: #{@blueprint.errors.full_messages.join(', ')}", :unprocessable_entity)
    end
  end

  def destroy
    @blueprint.destroy
    render_success({}, "Blueprint deleted successfully")
  end

  def complete
    if @blueprint.update(status: 'completed', completed_at: Time.current)
      # Check for blueprint completion achievements
      awarded_achievements = AchievementService.check_blueprint_achievements(current_user, @blueprint)
      
      render_success({
        blueprint: blueprint_json(@blueprint),
        achievements: awarded_achievements.map(&:display_info)
      }, "Blueprint completed successfully!")
    else
      render_error("Failed to complete blueprint: #{@blueprint.errors.full_messages.join(', ')}", :unprocessable_entity)
    end
  end

  private

  def set_blueprint
    @blueprint = current_user.blueprints.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error("Blueprint not found", :not_found)
  end

  def blueprint_params
    params.require(:blueprint).permit(:title, :description, :priority, :category, :target_date, :status)
  end

  def blueprint_json(blueprint)
    {
      id: blueprint.id,
      title: blueprint.title,
      description: blueprint.description,
      status: blueprint.status,
      priority: blueprint.priority,
      category: blueprint.category,
      target_date: blueprint.target_date,
      progress_percentage: blueprint.progress_percentage,
      milestones_count: blueprint.milestones.count,
      created_at: blueprint.created_at,
      updated_at: blueprint.updated_at
    }
  end
end

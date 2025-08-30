class Api::V1::MilestonesController < Api::V1::BaseController
  before_action :set_blueprint
  before_action :set_milestone, only: [:show, :update, :destroy, :complete]

  # GET /api/v1/blueprints/:blueprint_id/milestones
  def index
    @milestones = @blueprint.milestones.includes(:habits)
    
    render_success({
      milestones: @milestones.map do |milestone|
        {
          id: milestone.id,
          title: milestone.title,
          description: milestone.description,
          status: milestone.status,
          target_date: milestone.target_date,
          progress_percentage: milestone.progress_percentage,
          habits_count: milestone.habits.count,
          created_at: milestone.created_at,
          updated_at: milestone.updated_at
        }
      end,
      blueprint: {
        id: @blueprint.id,
        title: @blueprint.title
      },
      total_count: @milestones.count
    })
  end

  # GET /api/v1/blueprints/:blueprint_id/milestones/:id
  def show
    render_success({
      milestone: {
        id: @milestone.id,
        title: @milestone.title,
        description: @milestone.description,
        status: @milestone.status,
        target_date: @milestone.target_date,
        progress_percentage: @milestone.progress_percentage,
        habits: @milestone.habits.map do |habit|
          {
            id: habit.id,
            title: habit.title,
            status: habit.status,
            frequency: habit.frequency,
            current_streak: habit.current_streak
          }
        end,
        blueprint: {
          id: @blueprint.id,
          title: @blueprint.title
        },
        created_at: @milestone.created_at,
        updated_at: @milestone.updated_at
      }
    })
  end

  # POST /api/v1/blueprints/:blueprint_id/milestones
  def create
    @milestone = @blueprint.milestones.build(milestone_params)
    @milestone.user = current_user

    if @milestone.save
      # Check for achievements
      awarded_achievements = AchievementService.check_milestone_achievements(current_user, @milestone)
      
      render_success({
        milestone: @milestone,
        achievements: awarded_achievements.map(&:display_info)
      }, "Milestone created successfully", :created)
    else
      render_error(@milestone.errors.full_messages.join(', '))
    end
  end

  # PATCH/PUT /api/v1/blueprints/:blueprint_id/milestones/:id
  def update
    if @milestone.update(milestone_params)
      # Check for achievements if milestone progress changed significantly
      awarded_achievements = []
      if @milestone.progress_percentage_previously_changed?
        awarded_achievements = AchievementService.check_milestone_achievements(current_user, @milestone)
      end
      
      render_success({
        milestone: @milestone,
        achievements: awarded_achievements.map(&:display_info)
      }, "Milestone updated successfully")
    else
      render_error(@milestone.errors.full_messages.join(', '))
    end
  end

  # DELETE /api/v1/blueprints/:blueprint_id/milestones/:id
  def destroy
    @milestone.destroy
    render_success({}, "Milestone deleted successfully")
  end

  # PATCH /api/v1/blueprints/:blueprint_id/milestones/:id/complete
  def complete
    if @milestone.update(status: 'completed')
      # Check for achievements when milestone is completed
      awarded_achievements = AchievementService.check_milestone_achievements(current_user, @milestone)
      
      render_success({
        milestone: @milestone,
        achievements: awarded_achievements.map(&:display_info)
      }, "Milestone completed successfully! 🎉")
    else
      render_error(@milestone.errors.full_messages.join(', '))
    end
  end

  private

  def set_blueprint
    @blueprint = current_user.blueprints.find(params[:blueprint_id])
  rescue ActiveRecord::RecordNotFound
    render_error("Blueprint not found", :not_found)
  end

  def set_milestone
    @milestone = @blueprint.milestones.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error("Milestone not found", :not_found)
  end

  def milestone_params
    params.require(:milestone).permit(:title, :description, :status, :target_date)
  end
end

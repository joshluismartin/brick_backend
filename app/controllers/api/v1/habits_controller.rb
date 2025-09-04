class Api::V1::HabitsController < Api::V1::BaseController
  before_action :set_blueprint_and_milestone, only: [:index, :create]
  before_action :set_habit, only: [:show, :update, :destroy, :mark_completed, :reset]

  # GET /api/v1/blueprints/:blueprint_id/milestones/:milestone_id/habits
  # GET /api/v1/milestones/:milestone_id/habits
  def index
    @habits = @milestone.habits.includes(:milestone, milestone: :blueprint)
    
    render_success({
      habits: @habits.map do |habit|
        {
          id: habit.id,
          title: habit.title,
          description: habit.description,
          status: habit.status,
          frequency: habit.frequency,
          current_streak: habit.current_streak,
          last_completed_at: habit.last_completed_at,
          created_at: habit.created_at,
          updated_at: habit.updated_at
        }
      end,
      milestone: {
        id: @milestone.id,
        title: @milestone.title
      },
      blueprint: {
        id: @milestone.blueprint.id,
        title: @milestone.blueprint.title
      },
      total_count: @habits.count
    })
  end

  # GET /api/v1/blueprints/:blueprint_id/milestones/:milestone_id/habits/:id
  # GET /api/v1/milestones/:milestone_id/habits/:id
  # GET /api/v1/habits/:id
  def show
    render_success({
      habit: {
        id: @habit.id,
        title: @habit.title,
        description: @habit.description,
        status: @habit.status,
        frequency: @habit.frequency,
        current_streak: @habit.current_streak,
        last_completed_at: @habit.last_completed_at,
        milestone: {
          id: @habit.milestone.id,
          title: @habit.milestone.title
        },
        blueprint: {
          id: @habit.milestone.blueprint.id,
          title: @habit.milestone.blueprint.title
        },
        created_at: @habit.created_at,
        updated_at: @habit.updated_at
      }
    })
  end

  # POST /api/v1/blueprints/:blueprint_id/milestones/:milestone_id/habits
  # POST /api/v1/milestones/:milestone_id/habits
  def create
    @habit = @milestone.habits.build(habit_params)
    @habit.user = current_user

    if @habit.save
      # Check for achievements
      awarded_achievements = AchievementService.check_habit_achievements(current_user, @habit)
      
      render_success({
        habit: @habit,
        achievements: awarded_achievements.map(&:display_info)
      }, "Habit created successfully", :created)
    else
      render_error(@habit.errors.full_messages.join(', '))
    end
  end

  # PATCH/PUT /api/v1/blueprints/:blueprint_id/milestones/:milestone_id/habits/:id
  # PATCH/PUT /api/v1/milestones/:milestone_id/habits/:id
  # PATCH/PUT /api/v1/habits/:id
  def update
    if @habit.update(habit_params)
      render_success({
        habit: @habit
      }, "Habit updated successfully")
    else
      render_error(@habit.errors.full_messages.join(', '))
    end
  end

  # DELETE /api/v1/blueprints/:blueprint_id/milestones/:milestone_id/habits/:id
  # DELETE /api/v1/milestones/:milestone_id/habits/:id
  # DELETE /api/v1/habits/:id
  def destroy
    @habit.destroy
    render_success({}, "Habit deleted successfully")
  end

  # POST /api/v1/blueprints/:blueprint_id/milestones/:milestone_id/habits/:id/mark_completed
  # POST /api/v1/milestones/:milestone_id/habits/:id/mark_completed
  def mark_completed
    # Mark habit as completed
    @habit.update!(
      status: 'completed',
      last_completed_at: Time.current,
      completion_history: (@habit.completion_history || []) + [Date.current.to_s]
    )
    
    # Check for achievements
    awarded_achievements = AchievementService.check_habit_achievements(current_user, @habit)
    
    render_success({
      habit: @habit,
      message: "Congratulations! You've completed your habit: #{@habit.title}",
      achievements: awarded_achievements.map do |ua|
        {
          id: ua.achievement.id,
          name: ua.achievement.name,
          description: ua.achievement.description,
          badge_type: ua.achievement.badge_type,
          points: ua.achievement.points,
          earned_at: ua.earned_at
        }
      end,
      points_earned: awarded_achievements.sum { |ua| ua.achievement.points }
    }, "Habit marked as completed!")
  rescue => e
    render_error("Failed to mark habit as completed: #{e.message}")
  end

  # POST /api/v1/blueprints/:blueprint_id/milestones/:milestone_id/habits/:id/reset
  # POST /api/v1/milestones/:milestone_id/habits/:id/reset
  def reset
    @habit.update!(status: 'active', last_completed_at: nil, current_streak: 0)
    
    render_success({
      habit: @habit
    }, "Habit reset successfully")
  rescue => e
    render_error("Failed to reset habit: #{e.message}")
  end

  private

  def set_blueprint_and_milestone
    if params[:blueprint_id].present?
      # Nested route: /blueprints/:blueprint_id/milestones/:milestone_id/habits
      @blueprint = current_user.blueprints.find(params[:blueprint_id])
      @milestone = @blueprint.milestones.find(params[:milestone_id])
    else
      # Standalone route: /milestones/:milestone_id/habits
      @milestone = current_user.milestones.find(params[:milestone_id])
      @blueprint = @milestone.blueprint
    end
  rescue ActiveRecord::RecordNotFound => e
    if params[:blueprint_id].present?
      render_error("Blueprint or Milestone not found", :not_found)
    else
      render_error("Milestone not found", :not_found)
    end
  end

  def set_habit
    if params[:milestone_id].present?
      # Route with milestone: /milestones/:milestone_id/habits/:id or /blueprints/.../milestones/.../habits/:id
      set_blueprint_and_milestone unless @milestone
      @habit = @milestone.habits.find(params[:id])
    else
      # Standalone route: /habits/:id
      @habit = current_user.habits.find(params[:id])
    end
  rescue ActiveRecord::RecordNotFound
    if params[:milestone_id].present?
      render_error("Milestone or habit not found", :not_found)
    else
      render_error("Habit not found", :not_found)
    end
  end

  def habit_params
    params.require(:habit).permit(:title, :description, :frequency, :status)
  end
end

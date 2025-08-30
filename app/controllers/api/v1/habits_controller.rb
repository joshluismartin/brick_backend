class Api::V1::HabitsController < Api::V1::BaseController
  before_action :set_blueprint_and_milestone
  before_action :set_habit, only: [:show, :update, :destroy, :mark_completed, :reset]

  # GET /api/v1/blueprints/:blueprint_id/milestones/:milestone_id/habits
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
        id: @blueprint.id,
        title: @blueprint.title
      },
      total_count: @habits.count
    })
  end

  # GET /api/v1/blueprints/:blueprint_id/milestones/:milestone_id/habits/:id
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
          id: @milestone.id,
          title: @milestone.title
        },
        blueprint: {
          id: @blueprint.id,
          title: @blueprint.title
        },
        created_at: @habit.created_at,
        updated_at: @habit.updated_at
      }
    })
  end

  # POST /api/v1/blueprints/:blueprint_id/milestones/:milestone_id/habits
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
  def destroy
    @habit.destroy
    render_success({}, "Habit deleted successfully")
  end

  # POST /api/v1/blueprints/:blueprint_id/milestones/:milestone_id/habits/:id/mark_completed
  def mark_completed
    result = @habit.mark_completed!
    
    render_success({
      habit: result[:habit],
      quote: result[:quote],
      achievements: result[:achievements].map(&:display_info),
      points_earned: result[:achievements].sum { |ua| ua.achievement.points }
    }, "Habit marked as completed! ")
  rescue => e
    render_error("Failed to mark habit as completed: #{e.message}")
  end

  # POST /api/v1/blueprints/:blueprint_id/milestones/:milestone_id/habits/:id/reset
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
    @blueprint = current_user.blueprints.find(params[:blueprint_id])
    @milestone = @blueprint.milestones.find(params[:milestone_id])
  rescue ActiveRecord::RecordNotFound => e
    render_error("Blueprint or Milestone not found", :not_found)
  end

  def set_habit
    @habit = @milestone.habits.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error("Habit not found", :not_found)
  end

  def habit_params
    params.require(:habit).permit(:title, :description, :frequency, :status)
  end
end

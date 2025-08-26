class Api::V1::HabitsController < Api::V1::BaseController
  before_action :set_milestone
  before_action :set_habit, only: [ :show, :update, :destroy, :mark_completed, :reset ]

  # GET /api/v1/blueprints/:blueprint_id/milestones/:milestone_id/habits
  def index
    @habits = @milestone.habits.by_priority
    render_success(@habits.as_json(methods: [ :completion_streak, :overdue?, :next_due_date ]))
  end

  # GET /api/v1/blueprints/:blueprint_id/milestones/:milestone_id/habits/:id
  def show
    render_success(@habit.as_json(methods: [ :completion_streak, :overdue?, :next_due_date ]))
  end

  # POST /api/v1/blueprints/:blueprint_id/milestones/:milestone_id/habits
  def create
    @habit = @milestone.habits.build(habit_params)

    if @habit.save
      render_success(
        @habit.as_json(methods: [ :completion_streak, :overdue?, :next_due_date ]),
        "Habit created successfully"
      )
    else
      render_error(@habit.errors.full_messages.join(", "))
    end
  end

  # PATCH/PUT /api/v1/blueprints/:blueprint_id/milestones/:milestone_id/habits/:id
  def update
    if @habit.update(habit_params)
      render_success(
        @habit.as_json(methods: [ :completion_streak, :overdue?, :next_due_date ]),
        "Habit updated successfully"
      )
    else
      render_error(@habit.errors.full_messages.join(", "))
    end
  end

  # DELETE /api/v1/blueprints/:blueprint_id/milestones/:milestone_id/habits/:id
  def destroy
    @habit.destroy
    render_success(nil, "Habit deleted successfully")
  end

  # POST /api/v1/blueprints/:blueprint_id/milestones/:milestone_id/habits/:id/mark_completed
  def mark_completed
    @habit.mark_completed!
    render_success(
      @habit.as_json(methods: [ :completion_streak, :overdue?, :next_due_date ]),
      "Habit marked as completed"
    )
  end

  # POST /api/v1/blueprints/:blueprint_id/milestones/:milestone_id/habits/:id/reset
  def reset
    @habit.reset_status!
    render_success(
      @habit.as_json(methods: [ :completion_streak, :overdue?, :next_due_date ]),
      "Habit status reset"
    )
  end

  private

  def set_milestone
    @milestone = Milestone.find(params[:milestone_id])
  rescue ActiveRecord::RecordNotFound
    render_error("Milestone not found", :not_found)
  end

  def set_habit
    @habit = @milestone.habits.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error("Habit not found", :not_found)
  end

  def habit_params
    params.require(:habit).permit(:title, :description, :frequency, :status, :priority)
  end
end

class Api::V1::CalendarController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :set_calendar_service
  before_action :set_habit, only: [:create_habit_event, :create_recurring_habit_events]
  before_action :set_milestone, only: [:create_milestone_event]

  # GET /api/v1/calendar/events
  def events
    days_ahead = params[:days_ahead]&.to_i || 7
    
    result = @calendar_service.get_brick_events(days_ahead)
    
    if result[:success]
      render_success("Calendar events retrieved successfully", { 
        events: result[:events],
        count: result[:events].length,
        days_ahead: days_ahead
      })
    else
      render_error(result[:error] || "Failed to retrieve calendar events", 500)
    end
  end

  # POST /api/v1/calendar/habits/:habit_id/event
  def create_habit_event
    start_time = parse_datetime(params[:start_time])
    end_time = params[:end_time] ? parse_datetime(params[:end_time]) : nil
    
    unless start_time
      return render_error("Invalid start_time format. Use ISO 8601 format.", 400)
    end
    
    result = @calendar_service.create_habit_event(@habit, start_time, end_time)
    
    if result[:success]
      # Store calendar event ID in habit for future reference
      @habit.update(calendar_event_id: result[:event_id]) if @habit.respond_to?(:calendar_event_id)
      
      render_success(result[:message], {
        event_id: result[:event_id],
        event_link: result[:event_link],
        habit: format_habit_response(@habit)
      })
    else
      render_error(result[:error] || "Failed to create calendar event", 500)
    end
  end

  # POST /api/v1/calendar/habits/:habit_id/recurring_events
  def create_recurring_habit_events
    start_date = parse_date(params[:start_date])
    end_date = parse_date(params[:end_date])
    time_of_day = params[:time_of_day] || "09:00"
    
    unless start_date && end_date
      return render_error("Invalid date format. Use YYYY-MM-DD format.", 400)
    end
    
    if start_date >= end_date
      return render_error("End date must be after start date.", 400)
    end
    
    result = @calendar_service.create_recurring_habit_events(@habit, start_date, end_date, time_of_day)
    
    if result[:success]
      # Store recurring event ID in habit
      @habit.update(calendar_event_id: result[:event_id]) if @habit.respond_to?(:calendar_event_id)
      
      render_success(result[:message], {
        event_id: result[:event_id],
        event_link: result[:event_link],
        habit: format_habit_response(@habit),
        recurrence: {
          frequency: @habit.frequency,
          start_date: start_date,
          end_date: end_date,
          time_of_day: time_of_day
        }
      })
    else
      render_error(result[:error] || "Failed to create recurring events", 500)
    end
  end

  # POST /api/v1/calendar/milestones/:milestone_id/event
  def create_milestone_event
    due_date = parse_date(params[:due_date])
    
    unless due_date
      return render_error("Invalid due_date format. Use YYYY-MM-DD format.", 400)
    end
    
    result = @calendar_service.create_milestone_event(@milestone, due_date)
    
    if result[:success]
      # Store calendar event ID in milestone
      @milestone.update(calendar_event_id: result[:event_id]) if @milestone.respond_to?(:calendar_event_id)
      
      render_success(result[:message], {
        event_id: result[:event_id],
        event_link: result[:event_link],
        milestone: format_milestone_response(@milestone),
        due_date: due_date
      })
    else
      render_error(result[:error] || "Failed to create milestone event", 500)
    end
  end

  # PUT /api/v1/calendar/events/:event_id
  def update_event
    event_id = params[:event_id]
    updates = {}
    
    updates[:summary] = params[:summary] if params[:summary].present?
    updates[:description] = params[:description] if params[:description].present?
    updates[:start_time] = parse_datetime(params[:start_time]) if params[:start_time].present?
    updates[:end_time] = parse_datetime(params[:end_time]) if params[:end_time].present?
    
    result = @calendar_service.update_event(event_id, updates)
    
    if result[:success]
      render_success(result[:message], { event_id: event_id, updates: updates })
    else
      render_error(result[:error] || "Failed to update calendar event", 500)
    end
  end

  # DELETE /api/v1/calendar/events/:event_id
  def delete_event
    event_id = params[:event_id]
    result = @calendar_service.delete_event(event_id)
    
    if result[:success]
      render_success(result[:message], { event_id: event_id })
    else
      render_error(result[:error] || "Failed to delete calendar event", 500)
    end
  end

  # GET /api/v1/calendar/sync_status
  def sync_status
    habits_with_events = current_user.habits.where.not(calendar_event_id: nil).count
    milestones_with_events = current_user.milestones.where.not(calendar_event_id: nil).count
    total_habits = current_user.habits.count
    total_milestones = current_user.milestones.count
    
    render_success("Calendar sync status retrieved", {
      habits: {
        synced: habits_with_events,
        total: total_habits,
        sync_percentage: total_habits > 0 ? (habits_with_events.to_f / total_habits * 100).round(1) : 0
      },
      milestones: {
        synced: milestones_with_events,
        total: total_milestones,
        sync_percentage: total_milestones > 0 ? (milestones_with_events.to_f / total_milestones * 100).round(1) : 0
      },
      overall_sync_percentage: (total_habits + total_milestones) > 0 ? 
        ((habits_with_events + milestones_with_events).to_f / (total_habits + total_milestones) * 100).round(1) : 0
    })
  end

  # POST /api/v1/calendar/bulk_sync
  def bulk_sync
    sync_habits = params[:sync_habits] != false
    sync_milestones = params[:sync_milestones] != false
    force_sync = params[:force_sync] == true
    time_of_day = params[:default_time] || "09:00"
    days_ahead = params[:days_ahead]&.to_i || 30
    
    results = {
      habits: { success: 0, failed: 0, errors: [] },
      milestones: { success: 0, failed: 0, errors: [] }
    }
    
    if sync_habits
      habits_to_sync = force_sync ? 
        current_user.habits : 
        current_user.habits.where(calendar_event_id: nil)
      
      habits_to_sync.find_each do |habit|
        start_date = Date.current
        end_date = Date.current + days_ahead.days
        
        result = @calendar_service.create_recurring_habit_events(habit, start_date, end_date, time_of_day)
        
        if result[:success]
          if habit.respond_to?(:calendar_event_id)
            habit.update(calendar_event_id: result[:event_id])
          end
          results[:habits][:success] += 1
        else
          results[:habits][:failed] += 1
          results[:habits][:errors] << { habit_id: habit.id, error: result[:error] }
        end
      end
    end
    
    if sync_milestones
      milestones_to_sync = force_sync ? 
        current_user.milestones : 
        current_user.milestones.where(calendar_event_id: nil)
      
      milestones_to_sync.find_each do |milestone|
        due_date = milestone.respond_to?(:target_date) && milestone.target_date ? 
          milestone.target_date : Date.current + 2.weeks
        
        result = @calendar_service.create_milestone_event(milestone, due_date)
        
        if result[:success]
          if milestone.respond_to?(:calendar_event_id)
            milestone.update(calendar_event_id: result[:event_id])
          end
          results[:milestones][:success] += 1
        else
          results[:milestones][:failed] += 1
          results[:milestones][:errors] << { milestone_id: milestone.id, error: result[:error] }
        end
      end
    end
    
    total_success = results[:habits][:success] + results[:milestones][:success]
    total_failed = results[:habits][:failed] + results[:milestones][:failed]
    
    message = "Bulk sync completed: #{total_success} successful, #{total_failed} failed"
    
    render_success(results, message)
  end

  private

  def set_calendar_service
    @calendar_service = GoogleCalendarService.new(current_user)
  end

  def set_habit
    @habit = current_user.habits.find(params[:habit_id])
  rescue ActiveRecord::RecordNotFound
    render_error("Habit not found", 404)
  end

  def set_milestone
    @milestone = current_user.milestones.find(params[:milestone_id])
  rescue ActiveRecord::RecordNotFound
    render_error("Milestone not found", 404)
  end

  def parse_datetime(datetime_string)
    return nil if datetime_string.blank?
    
    begin
      DateTime.parse(datetime_string)
    rescue ArgumentError
      nil
    end
  end

  def parse_date(date_string)
    return nil if date_string.blank?
    
    begin
      Date.parse(date_string)
    rescue ArgumentError
      nil
    end
  end

  def format_habit_response(habit)
    {
      id: habit.id,
      title: habit.title,
      description: habit.description,
      frequency: habit.frequency,
      priority: habit.priority,
      status: habit.status,
      milestone_id: habit.milestone_id,
      calendar_event_id: habit.respond_to?(:calendar_event_id) ? habit.calendar_event_id : nil
    }
  end

  def format_milestone_response(milestone)
    {
      id: milestone.id,
      title: milestone.title,
      description: milestone.description,
      priority: milestone.priority,
      status: milestone.status,
      blueprint_id: milestone.blueprint_id,
      calendar_event_id: milestone.respond_to?(:calendar_event_id) ? milestone.calendar_event_id : nil
    }
  end
end

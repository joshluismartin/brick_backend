namespace :google_calendar do
  desc "Test Google Calendar API connection"
  task test_connection: :environment do
    puts "🔍 Testing Google Calendar API connection..."
    
    begin
      # Create a test user (you can use any existing user)
      user = User.first
      if user.nil?
        puts "❌ No users found. Create a user first with: rails console"
        puts "   User.create!(email: 'test@example.com', password: 'password123')"
        exit 1
      end
      
      puts "✅ Using user: #{user.email}"
      
      # Initialize calendar service
      calendar_service = GoogleCalendarService.new(user)
      
      # Test 1: Check authorization
      puts "\n📋 Test 1: Checking authorization..."
      if calendar_service.instance_variable_get(:@service).authorization
        puts "✅ Authorization successful"
      else
        puts "❌ Authorization failed"
        puts "   Make sure:"
        puts "   1. GOOGLE_APPLICATION_CREDENTIALS is set"
        puts "   2. Service account JSON file exists"
        puts "   3. Calendar is shared with service account"
        exit 1
      end
      
      # Test 2: List upcoming events
      puts "\n📅 Test 2: Fetching upcoming events..."
      result = calendar_service.get_brick_events(7)
      
      if result[:success]
        puts "✅ Successfully connected to Google Calendar"
        puts "📊 Found #{result[:events].count} BRICK events in next 7 days"
      else
        puts "❌ Failed to fetch events: #{result[:error]}"
        exit 1
      end
      
      # Test 3: Create a test event (optional)
      print "\n🎯 Test 3: Create a test event? (y/n): "
      response = STDIN.gets.chomp.downcase
      
      if response == 'y'
        puts "Creating test habit event..."
        
        # Create a test habit if none exists
        habit = user.habits.first
        if habit.nil?
          blueprint = user.blueprints.first || user.blueprints.create!(
            title: "Test Blueprint",
            description: "Test blueprint for calendar integration",
            category: "personal",
            priority: "medium"
          )
          
          milestone = blueprint.milestones.first || blueprint.milestones.create!(
            title: "Test Milestone",
            description: "Test milestone for calendar integration",
            priority: "medium",
            user: user
          )
          
          habit = milestone.habits.create!(
            title: "Test Habit",
            description: "Test habit for calendar integration",
            frequency: "daily",
            priority: "medium",
            user: user
          )
        end
        
        # Create calendar event
        start_time = Time.current + 1.hour
        result = calendar_service.create_habit_event(habit, start_time)
        
        if result[:success]
          puts "✅ Test event created successfully!"
          puts "🔗 Event link: #{result[:event_link]}"
          puts "📝 Event ID: #{result[:event_id]}"
        else
          puts "❌ Failed to create test event: #{result[:error]}"
        end
      end
      
      puts "\n🎉 Google Calendar API test completed successfully!"
      puts "\n📋 Next steps:"
      puts "   1. Test the calendar endpoints via API"
      puts "   2. Create habits and sync them to calendar"
      puts "   3. Check your Google Calendar for BRICK events"
      
    rescue => e
      puts "❌ Test failed with error: #{e.message}"
      puts "📋 Troubleshooting:"
      puts "   1. Check GOOGLE_APPLICATION_CREDENTIALS environment variable"
      puts "   2. Verify service account JSON file exists and is valid"
      puts "   3. Ensure calendar is shared with service account email"
      puts "   4. Check Google Cloud Console for API quotas/errors"
      exit 1
    end
  end
  
  desc "Show Google Calendar configuration"
  task show_config: :environment do
    puts "🔧 Google Calendar Configuration:"
    puts "   Application Name: #{Rails.application.config.google_calendar.application_name}"
    puts "   Credentials Path: #{Rails.application.config.google_calendar.credentials_path}"
    puts "   Default Timezone: #{Rails.application.config.google_calendar.default_timezone}"
    puts "   Scopes: #{Rails.application.config.google_calendar.scopes.join(', ')}"
    
    credentials_path = Rails.application.config.google_calendar.credentials_path
    if File.exist?(credentials_path)
      puts "✅ Credentials file exists"
      
      begin
        credentials = JSON.parse(File.read(credentials_path))
        puts "   Service Account Email: #{credentials['client_email']}"
        puts "   Project ID: #{credentials['project_id']}"
      rescue => e
        puts "❌ Error reading credentials: #{e.message}"
      end
    else
      puts "❌ Credentials file not found at: #{credentials_path}"
    end
  end
end

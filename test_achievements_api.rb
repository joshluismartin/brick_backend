#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'
require 'date'

# Configuration
BASE_URL = 'http://localhost:3000/api/v1'
EMAIL = 'test@example.com'
PASSWORD = 'password123'

class AchievementTester
  def initialize
    @token = nil
    @user_id = nil
  end

  def run_comprehensive_test
    puts "=== COMPREHENSIVE ACHIEVEMENT SYSTEM DEBUG ==="
    
    # Step 1: Authentication
    puts "\n1. Testing Authentication..."
    sign_up_user
    sign_in_user
    
    # Step 2: Check achievements exist and are active
    puts "\n2. Checking Achievement Database State..."
    seed_achievements
    check_achievement_status
    
    # Step 3: Test Blueprint Achievement
    puts "\n3. Testing Blueprint Achievement..."
    test_blueprint_achievement
    
    # Step 4: Test Habit Achievement
    puts "\n4. Testing Habit Achievement..."
    test_habit_achievement
    
    # Step 5: Test all achievement types
    puts "\n5. Testing all achievement types..."
    test_all_achievement_types
    
    # Step 6: Final verification
    puts "\n6. Final Verification..."
    check_user_achievements
    
    puts "\n=== TEST COMPLETE ==="
  end

  private

  def sign_up_user
    uri = URI("#{BASE_URL}/users")
    response = make_request(uri, 'POST', {
      user: {
        email: EMAIL,
        password: PASSWORD,
        password_confirmation: PASSWORD
      }
    })
    
    if response['success']
      puts "✅ Sign up successful"
      @user_id = response.dig('data', 'user', 'id')
    else
      puts "⚠️  Sign up failed (user might exist): #{response['message']}"
    end
  end

  def sign_in_user
    uri = URI("#{BASE_URL}/users/sign_in")
    response = make_request(uri, 'POST', {
      user: {
        email: EMAIL,
        password: PASSWORD
      }
    })
    
    if response['success']
      @token = response.dig('data', 'token')
      @user_id = response.dig('data', 'user', 'id')
      puts "✅ Sign in successful, token: #{@token[0..20]}..."
      puts "   User ID: #{@user_id}"
    else
      puts "❌ Sign in failed: #{response['message']}"
      puts "   Full response: #{response}"
      exit 1
    end
  end

  def seed_achievements
    uri = URI("#{BASE_URL}/achievements/seed")
    response = make_request(uri, 'POST', {}, @token)
    
    if response['success']
      puts "✅ Achievements seeded successfully"
    else
      puts "❌ Achievement seeding failed: #{response['message']}"
    end
  end

  def check_achievement_status
    # Check total achievements
    uri = URI("#{BASE_URL}/achievements")
    response = make_request(uri, 'GET', {}, @token)
    
    if response['success']
      total_achievements = response.dig('data', 'achievements')&.count || 0
      puts "📊 Total achievements in system: #{total_achievements}"
      
      # Check for specific achievements
      blueprint_beginner = response.dig('data', 'achievements')&.find { |a| a['name'] == 'Blueprint Beginner' }
      first_steps = response.dig('data', 'achievements')&.find { |a| a['name'] == 'First Steps' }
      
      if blueprint_beginner
        puts "✅ 'Blueprint Beginner' achievement found (Active: #{blueprint_beginner['active']})"
        puts "   Criteria: #{blueprint_beginner['criteria']}"
        puts "   Badge Type: #{blueprint_beginner['badge_type']}"
      else
        puts "❌ 'Blueprint Beginner' achievement NOT found"
      end
      
      if first_steps
        puts "✅ 'First Steps' achievement found (Active: #{first_steps['active']})"
        puts "   Criteria: #{first_steps['criteria']}"
        puts "   Badge Type: #{first_steps['badge_type']}"
      else
        puts "❌ 'First Steps' achievement NOT found"
      end
    else
      puts "❌ Failed to get achievements: #{response['message']}"
    end
  end

  def test_blueprint_achievement
    puts "Creating blueprint to test 'Blueprint Beginner' achievement..."
    
    uri = URI("#{BASE_URL}/blueprints")
    response = make_request(uri, 'POST', {
      blueprint: {
        title: "Test Blueprint for Achievement",
        description: "Testing blueprint creation achievement",
        category: "personal",
        priority: "medium",
        target_date: (Date.today + 30).to_s
      }
    }, @token)
    
    if response['success']
      puts "✅ Blueprint created successfully"
      blueprint_id = response.dig('data', 'blueprint', 'id')
      achievements = response.dig('data', 'achievements') || []
      
      puts "   Blueprint ID: #{blueprint_id}"
      puts "   Achievements returned: #{achievements.count}"
      
      if achievements.any?
        achievements.each do |achievement|
          puts "   🏆 Achievement: #{achievement['name']}"
        end
      else
        puts "   ⚠️  No achievements returned from blueprint creation"
      end
      
      return blueprint_id
    else
      puts "❌ Blueprint creation failed: #{response['message']}"
      return nil
    end
  end

  def test_habit_achievement
    puts "Creating and completing habit to test 'First Steps' achievement..."
    
    # First create a blueprint and milestone
    blueprint_id = test_blueprint_achievement if test_blueprint_achievement.nil?
    
    # Create milestone
    uri = URI("#{BASE_URL}/blueprints/#{blueprint_id}/milestones")
    milestone_response = make_request(uri, 'POST', {
      milestone: {
        title: "Test Milestone",
        description: "Test milestone for habit",
        target_date: (Date.today + 14).to_s,
        priority: "medium"
      }
    }, @token)
    
    if milestone_response['success']
      milestone_id = milestone_response.dig('data', 'milestone', 'id')
      puts "✅ Milestone created: #{milestone_id}"
      
      # Create habit
      uri = URI("#{BASE_URL}/blueprints/#{blueprint_id}/milestones/#{milestone_id}/habits")
      habit_response = make_request(uri, 'POST', {
        habit: {
          title: "Test Daily Habit",
          description: "Test habit for achievement",
          frequency: "daily",
          priority: "high"
        }
      }, @token)
      
      if habit_response['success']
        habit_id = habit_response.dig('data', 'habit', 'id')
        puts "✅ Habit created: #{habit_id}"
        
        # Complete the habit
        uri = URI("#{BASE_URL}/habits/#{habit_id}/mark_completed")
        completion_response = make_request(uri, 'POST', {}, @token)
        
        if completion_response['success']
          puts "✅ Habit marked as completed"
          achievements = completion_response.dig('data', 'achievements') || []
          
          puts "   Achievements returned: #{achievements.count}"
          if achievements.any?
            achievements.each do |achievement|
              puts "   🏆 Achievement: #{achievement['name']}"
            end
          else
            puts "   ⚠️  No achievements returned from habit completion"
          end
        else
          puts "❌ Habit completion failed: #{completion_response['message']}"
        end
      else
        puts "❌ Habit creation failed: #{habit_response['message']}"
      end
    else
      puts "❌ Milestone creation failed: #{milestone_response['message']}"
    end
  end

  def test_all_achievement_types
    puts "Testing all achievement types comprehensively..."
    
    # Test milestone progress achievement
    test_milestone_progress_achievement
    
    # Test blueprint completion achievement  
    test_blueprint_completion_achievement
    
    # Test special achievements
    test_special_achievements
    
    # Test habit streak achievements (multiple levels)
    test_habit_streak_achievements
  end

  def test_milestone_progress_achievement
    puts "\n--- Testing Milestone Progress Achievements ---"
    
    # Create blueprint and milestone first
    blueprint_id = create_test_blueprint
    milestone_id = create_test_milestone(blueprint_id)
    
    if milestone_id
      # Update milestone progress to 50% to trigger "Progress Maker"
      uri = URI("#{BASE_URL}/milestones/#{milestone_id}")
      response = make_request(uri, 'PUT', {
        milestone: {
          progress_percentage: 50
        }
      }, @token)
      
      if response['success']
        achievements = response.dig('data', 'achievements') || []
        puts "✅ Milestone updated to 50% progress"
        puts "   Achievements returned: #{achievements.count}"
        
        progress_maker = achievements.find { |a| a.dig('achievement', 'name') == 'Progress Maker' || a['name'] == 'Progress Maker' }
        if progress_maker
          puts "   🏆 Progress Maker achievement awarded!"
        else
          puts "   ⚠️  Progress Maker achievement not awarded"
        end
      else
        puts "❌ Failed to update milestone progress: #{response['message']}"
      end
    end
  end

  def test_blueprint_completion_achievement
    puts "\n--- Testing Blueprint Completion Achievements ---"
    
    blueprint_id = create_test_blueprint
    
    if blueprint_id
      # Complete the blueprint to trigger "Goal Crusher"
      uri = URI("#{BASE_URL}/blueprints/#{blueprint_id}/complete")
      response = make_request(uri, 'PATCH', {}, @token)
      
      if response['success']
        achievements = response.dig('data', 'achievements') || []
        puts "✅ Blueprint completed"
        puts "   Achievements returned: #{achievements.count}"
        
        goal_crusher = achievements.find { |a| a.dig('achievement', 'name') == 'Goal Crusher' || a['name'] == 'Goal Crusher' }
        if goal_crusher
          puts "   🏆 Goal Crusher achievement awarded!"
        else
          puts "   ⚠️  Goal Crusher achievement not awarded"
        end
      else
        puts "❌ Failed to complete blueprint: #{response['message']}"
      end
    end
  end

  def test_special_achievements
    puts "\n--- Testing Special Achievements ---"
    
    # Test based on current time
    current_hour = Time.now.hour
    
    if current_hour < 8
      puts "Testing Early Bird achievement (current hour: #{current_hour})"
      test_time_based_achievement("Early Bird")
    elsif current_hour >= 22
      puts "Testing Night Owl achievement (current hour: #{current_hour})"
      test_time_based_achievement("Night Owl")
    elsif [0, 6].include?(Date.current.wday)
      puts "Testing Weekend Warrior achievement (weekend)"
      test_time_based_achievement("Weekend Warrior")
    else
      puts "⚠️  Current time (#{current_hour}:00) and day don't match special achievement criteria"
      puts "   Early Bird: before 8 AM"
      puts "   Night Owl: after 10 PM"
      puts "   Weekend Warrior: Saturday or Sunday"
    end
  end

  def test_time_based_achievement(achievement_name)
    blueprint_id = create_test_blueprint
    milestone_id = create_test_milestone(blueprint_id)
    habit_id = create_test_habit(blueprint_id, milestone_id)
    
    if habit_id
      # Complete habit to potentially trigger time-based achievement
      uri = URI("#{BASE_URL}/habits/#{habit_id}/mark_completed")
      response = make_request(uri, 'POST', {}, @token)
      
      if response['success']
        achievements = response.dig('data', 'achievements') || []
        puts "✅ Habit completed at current time"
        puts "   Achievements returned: #{achievements.count}"
        
        special_achievement = achievements.find { |a| 
          (a.dig('achievement', 'name') == achievement_name) || (a['name'] == achievement_name)
        }
        
        if special_achievement
          puts "   🏆 #{achievement_name} achievement awarded!"
        else
          puts "   ⚠️  #{achievement_name} achievement not awarded"
        end
      else
        puts "❌ Failed to complete habit: #{response['message']}"
      end
    end
  end

  def test_habit_streak_achievements
    puts "\n--- Testing Habit Streak Achievements ---"
    
    blueprint_id = create_test_blueprint
    milestone_id = create_test_milestone(blueprint_id)
    habit_id = create_test_habit(blueprint_id, milestone_id)
    
    if habit_id
      # Complete habit multiple times to build streak
      (1..3).each do |day|
        puts "Completing habit for day #{day}..."
        
        uri = URI("#{BASE_URL}/habits/#{habit_id}/mark_completed")
        response = make_request(uri, 'POST', {}, @token)
        
        if response['success']
          achievements = response.dig('data', 'achievements') || []
          puts "   Day #{day} completion - Achievements: #{achievements.count}"
          
          achievements.each do |achievement|
            name = achievement.dig('achievement', 'name') || achievement['name'] || 'Unknown'
            puts "     🏆 #{name}"
          end
        else
          puts "   ❌ Failed to complete habit on day #{day}"
        end
        
        sleep(1) # Small delay between completions
      end
    end
  end

  def create_test_blueprint
    uri = URI("#{BASE_URL}/blueprints")
    response = make_request(uri, 'POST', {
      blueprint: {
        title: "Test Blueprint #{Time.now.to_i}",
        description: "Testing achievement system",
        category: "personal",
        priority: "medium",
        target_date: (Date.today + 30).to_s
      }
    }, @token)
    
    if response['success']
      blueprint_id = response.dig('data', 'blueprint', 'id')
      puts "✅ Test blueprint created: #{blueprint_id}"
      blueprint_id
    else
      puts "❌ Failed to create test blueprint: #{response['message']}"
      nil
    end
  end

  def create_test_milestone(blueprint_id)
    return nil unless blueprint_id
    
    uri = URI("#{BASE_URL}/blueprints/#{blueprint_id}/milestones")
    response = make_request(uri, 'POST', {
      milestone: {
        title: "Test Milestone #{Time.now.to_i}",
        description: "Testing milestone achievements",
        target_date: (Date.today + 14).to_s,
        priority: "medium"
      }
    }, @token)
    
    if response['success']
      milestone_id = response.dig('data', 'milestone', 'id')
      puts "✅ Test milestone created: #{milestone_id}"
      milestone_id
    else
      puts "❌ Failed to create test milestone: #{response['message']}"
      nil
    end
  end

  def create_test_habit(blueprint_id, milestone_id)
    return nil unless blueprint_id && milestone_id
    
    uri = URI("#{BASE_URL}/blueprints/#{blueprint_id}/milestones/#{milestone_id}/habits")
    response = make_request(uri, 'POST', {
      habit: {
        title: "Test Habit #{Time.now.to_i}",
        description: "Testing habit achievements",
        frequency: "daily",
        priority: "high"
      }
    }, @token)
    
    if response['success']
      habit_id = response.dig('data', 'habit', 'id')
      puts "✅ Test habit created: #{habit_id}"
      habit_id
    else
      puts "❌ Failed to create test habit: #{response['message']}"
      nil
    end
  end

  def check_user_achievements
    uri = URI("#{BASE_URL}/achievements/user")
    response = make_request(uri, 'GET', {}, @token)
    
    if response['success']
      user_achievements = response.dig('data', 'achievements') || []
      puts "📊 Total user achievements: #{user_achievements.count}"
      
      if user_achievements.any?
        user_achievements.each do |ua|
          achievement_name = ua.dig('achievement', 'name') || ua['name']
          earned_at = ua['earned_at']
          puts "   🏆 #{achievement_name} (earned: #{earned_at})"
        end
      else
        puts "   ⚠️  User has no achievements"
      end
    else
      puts "❌ Failed to get user achievements: #{response['message']}"
    end
  end

  def make_request(uri, method, data = {}, token = nil)
    http = Net::HTTP.new(uri.host, uri.port)
    
    case method.upcase
    when 'GET'
      request = Net::HTTP::Get.new(uri)
    when 'POST'
      request = Net::HTTP::Post.new(uri)
      request.body = data.to_json
    when 'PUT'
      request = Net::HTTP::Put.new(uri)
      request.body = data.to_json
    when 'DELETE'
      request = Net::HTTP::Delete.new(uri)
    when 'PATCH'
      request = Net::HTTP::Patch.new(uri)
    end
    
    request['Content-Type'] = 'application/json'
    request['Accept'] = 'application/json'
    request['Authorization'] = "Bearer #{token}" if token
    
    begin
      response = http.request(request)
      JSON.parse(response.body)
    rescue JSON::ParserError => e
      puts "JSON Parse Error: #{e.message}"
      puts "Response body: #{response.body}"
      { 'success' => false, 'message' => 'Invalid JSON response' }
    rescue => e
      puts "Request Error: #{e.message}"
      { 'success' => false, 'message' => e.message }
    end
  end
end

# Run the test
tester = AchievementTester.new
tester.run_comprehensive_test

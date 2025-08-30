# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create test user
test_user = User.find_or_create_by!(email: 'test@example.com') do |user|
  user.password = 'password123'
  user.password_confirmation = 'password123'
end

puts "Created test user: #{test_user.email}"

# Create sample blueprints for the test user
blueprint1 = test_user.blueprints.find_or_create_by!(title: 'Learn React Development') do |blueprint|
  blueprint.description = 'Master React.js and build modern web applications'
  blueprint.category = 'education'
  blueprint.priority = 'high'
  blueprint.status = 'active'
  blueprint.target_date = 6.months.from_now
end

blueprint2 = test_user.blueprints.find_or_create_by!(title: 'Get Fit and Healthy') do |blueprint|
  blueprint.description = 'Lose weight and build muscle through consistent exercise'
  blueprint.category = 'health'
  blueprint.priority = 'high'
  blueprint.status = 'active'
  blueprint.target_date = 8.months.from_now
end

blueprint3 = test_user.blueprints.find_or_create_by!(title: 'Start Side Business') do |blueprint|
  blueprint.description = 'Launch an online business selling handmade crafts'
  blueprint.category = 'business'
  blueprint.priority = 'medium'
  blueprint.status = 'paused'
  blueprint.target_date = 1.year.from_now
end

puts "Created #{test_user.blueprints.count} blueprints for test user"

# Create sample milestones (must have target dates before blueprint target dates)
milestone1 = blueprint1.milestones.find_or_create_by!(title: 'Complete React Basics Course') do |milestone|
  milestone.description = 'Finish the fundamentals course on React components and hooks'
  milestone.status = 'completed'
  milestone.priority = 'high'
  milestone.target_date = 1.month.from_now
  milestone.user = test_user
end

milestone2 = blueprint1.milestones.find_or_create_by!(title: 'Build First React App') do |milestone|
  milestone.description = 'Create a todo app using React and deploy it'
  milestone.status = 'in_progress'
  milestone.priority = 'high'
  milestone.target_date = 3.months.from_now
  milestone.user = test_user
end

milestone3 = blueprint2.milestones.find_or_create_by!(title: 'Join Gym Membership') do |milestone|
  milestone.description = 'Sign up for local gym and get fitness assessment'
  milestone.status = 'pending'
  milestone.priority = 'medium'
  milestone.target_date = 1.month.from_now
  milestone.user = test_user
end

puts "Created sample milestones"

# Create sample habits (must belong to milestones)
habit1 = milestone2.habits.find_or_create_by!(title: 'Code for 1 hour daily') do |habit|
  habit.description = 'Practice coding and work on React projects'
  habit.frequency = 'daily'
  habit.status = 'in_progress'
  habit.priority = 'high'
  habit.user = test_user
end

habit2 = milestone3.habits.find_or_create_by!(title: 'Daily 30-minute workout') do |habit|
  habit.description = 'Exercise for at least 30 minutes every day'
  habit.frequency = 'daily'
  habit.status = 'pending'
  habit.priority = 'high'
  habit.user = test_user
end

habit3 = milestone1.habits.find_or_create_by!(title: 'Read React documentation') do |habit|
  habit.description = 'Study React docs for 30 minutes daily'
  habit.frequency = 'daily'
  habit.status = 'completed'
  habit.priority = 'medium'
  habit.user = test_user
end

puts "Created sample habits"

# Create sample achievements
Achievement.find_or_create_by!(name: 'First Blueprint') do |achievement|
  achievement.description = 'Created your first goal blueprint'
  achievement.badge_type = 'blueprint_completion'
  achievement.category = 'general'
  achievement.icon = '🎯'
  achievement.color = '#FFD700'
  achievement.rarity = 'common'
  achievement.points = 10
  achievement.criteria = { completion_type: 'full_completion' }
end

Achievement.find_or_create_by!(name: 'Milestone Master') do |achievement|
  achievement.description = 'Completed 5 milestones'
  achievement.badge_type = 'milestone_progress'
  achievement.category = 'general'
  achievement.icon = '🏆'
  achievement.color = '#C0C0C0'
  achievement.rarity = 'rare'
  achievement.points = 25
  achievement.criteria = { progress_percentage: 100, milestone_count: 5 }
end

Achievement.find_or_create_by!(name: 'Habit Streak') do |achievement|
  achievement.description = 'Maintained a habit for 7 consecutive days'
  achievement.badge_type = 'habit_streak'
  achievement.category = 'general'
  achievement.icon = '🔥'
  achievement.color = '#FF6B35'
  achievement.rarity = 'common'
  achievement.points = 15
  achievement.criteria = { streak_days: 7 }
end

puts "Created sample achievements"

puts "Seed data creation completed!"
puts "Test user credentials: test@example.com / password123"

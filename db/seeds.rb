# Create admin user
admin = User.create!(
  email: 'admin@example.com',
  password: 'password123',
  password_confirmation: 'password123',
  name: 'Admin User',
  role: 'admin'
)

puts "Created admin user: #{admin.email}"

# Create regular users
user1 = User.create!(
  email: 'user1@example.com',
  password: 'password123',
  password_confirmation: 'password123',
  name: 'John Doe',
  role: 'user'
)

user2 = User.create!(
  email: 'user2@example.com',
  password: 'password123',
  password_confirmation: 'password123',
  name: 'Jane Smith',
  role: 'user'
)

puts "Created #{User.count} users"

# Create one-time public event
event1 = admin.events.create!(
  title: 'Intro to 3D Printing',
  description: 'Learn the basics of 3D printing with our Prusa printers. Bring your own designs or use one of ours!',
  start_time: 2.weeks.from_now.change(hour: 18, min: 0),
  duration: 120,
  recurrence_type: 'once',
  status: 'active',
  visibility: 'public'
)

puts "Created event: #{event1.title}"

# Create weekly event
weekly_schedule = Event.build_schedule(
  1.week.from_now.change(hour: 19, min: 0),
  'weekly',
  { days: [2, 4] } # Tuesday and Thursday
)

event2 = user1.events.create!(
  title: 'Open Hack Night',
  description: 'Come work on your projects with fellow hackers. All skill levels welcome!',
  start_time: 1.week.from_now.change(hour: 19, min: 0),
  duration: 180,
  recurrence_type: 'weekly',
  recurrence_rule: weekly_schedule.to_yaml,
  status: 'active',
  visibility: 'public'
)

puts "Created event: #{event2.title}"

# Create monthly event - first Tuesday
monthly_schedule = Event.build_schedule(
  3.weeks.from_now.change(hour: 18, min: 30),
  'monthly',
  { occurrence: :first, day: :tuesday }
)

event3 = user2.events.create!(
  title: 'Monthly Members Meeting',
  description: 'Our monthly gathering to discuss hackerspace business, upcoming events, and community updates.',
  start_time: 3.weeks.from_now.change(hour: 18, min: 30),
  duration: 90,
  recurrence_type: 'monthly',
  recurrence_rule: monthly_schedule.to_yaml,
  status: 'active',
  visibility: 'members',
  open_to: 'members'
)

puts "Created event: #{event3.title}"

# Create a postponed event
event4 = admin.events.create!(
  title: 'Laser Cutting Workshop',
  description: 'Introduction to our laser cutter. Safety training included.',
  start_time: 1.week.from_now.change(hour: 14, min: 0),
  duration: 120,
  recurrence_type: 'once',
  status: 'postponed',
  postponed_until: 3.weeks.from_now,
  cancellation_reason: 'Equipment maintenance required',
  visibility: 'public'
)

puts "Created event: #{event4.title} (postponed)"

# Create Saturday afternoon weekly events
saturday_schedule = Event.build_schedule(
  Time.now.next_week.end_of_week.advance(days: 1).change(hour: 14, min: 0),
  'weekly',
  { days: [6] } # Saturday
)

event5 = user1.events.create!(
  title: 'Weekend Workshop',
  description: 'Open workshop time every Saturday afternoon. Come build, tinker, and create!',
  start_time: Time.now.next_week.end_of_week.advance(days: 1).change(hour: 14, min: 0),
  duration: 240,
  recurrence_type: 'weekly',
  recurrence_rule: saturday_schedule.to_yaml,
  status: 'active',
  visibility: 'public'
)

puts "Created event: #{event5.title}"

# Create a members-only event
event6 = user2.events.create!(
  title: 'Board Game Night',
  description: 'Members-only social event. Bring your favorite board games!',
  start_time: 10.days.from_now.change(hour: 19, min: 0),
  duration: 180,
  recurrence_type: 'once',
  status: 'active',
  visibility: 'members',
  open_to: 'members'
)

puts "Created event: #{event6.title} (members-only)"

# Create a private event
event7 = admin.events.create!(
  title: 'Admin Planning Session',
  description: 'Private meeting for admins to discuss upcoming improvements and budget.',
  start_time: 5.days.from_now.change(hour: 20, min: 0),
  duration: 60,
  recurrence_type: 'once',
  status: 'active',
  visibility: 'private',
  open_to: 'private'
)

puts "Created event: #{event7.title} (private)"

puts "\n✅ Seed data created successfully!"
puts "\n📊 Summary:"
puts "  - #{User.count} users created"
puts "  - #{Event.count} events created"
puts "  - #{Event.public_events.count} public events"
puts "  - #{Event.members_events.count} members-only events"
puts "  - #{Event.private_events.count} private events"
puts "\n🔑 Login credentials:"
puts "  Admin: admin@example.com / password123"
puts "  User1: user1@example.com / password123"
puts "  User2: user2@example.com / password123"

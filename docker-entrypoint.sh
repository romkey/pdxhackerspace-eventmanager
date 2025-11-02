#!/bin/bash
set -e

# Remove a potentially pre-existing server.pid for Rails.
rm -f /app/tmp/pids/server.pid

# Wait for database to be ready
echo "Waiting for database..."
until PGPASSWORD=$DATABASE_PASSWORD psql -h "$DATABASE_HOST" -U "$DATABASE_USER" -d "postgres" -c '\q'; do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 1
done

echo "Database is ready!"

# Create database if it doesn't exist
bundle exec rails db:create 2>/dev/null || echo "Database already exists"

# Run migrations
echo "Running database migrations..."
bundle exec rails db:migrate

# Check if database is seeded (check if any users exist)
if bundle exec rails runner "exit(User.count > 0 ? 0 : 1)" 2>/dev/null; then
  echo "Database already seeded, skipping seed data"
else
  echo "Seeding database..."
  bundle exec rails db:seed
fi

# Execute the main command
exec "$@"


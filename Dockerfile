# Use Ruby 3.2.2 as base image
FROM ruby:3.2.2

# Install dependencies
RUN apt-get update -qq && apt-get install -y \
    postgresql-client \
    build-essential \
    libpq-dev \
    curl \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20.x LTS from NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Install Yarn (correct version, not cmdtest)
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update && apt-get install -y yarn && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install gems
RUN bundle install

# Copy package.json and yarn.lock (if it exists)
COPY package.json ./
COPY yarn.lock* ./

# Install node modules
RUN yarn install

# Copy the rest of the application
COPY . .

# Precompile assets for production
# This ensures CSS and JS are available when the container starts
RUN SECRET_KEY_BASE=dummy RAILS_ENV=production bundle exec rake assets:precompile

# Expose port 3000
EXPOSE 3000

# Create a script to handle database setup and start the server
COPY docker-entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]

# Start the server
CMD ["rails", "server", "-b", "0.0.0.0"]


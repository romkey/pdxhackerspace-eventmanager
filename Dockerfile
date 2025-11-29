# ========================================
# Stage 1: Builder - Install dependencies and build assets
# ========================================
FROM ruby:3.2.2 AS builder

# Install build dependencies
RUN apt-get update -qq && apt-get install -y \
    build-essential \
    libpq-dev \
    curl \
    gnupg \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20.x LTS
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Install Yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update && apt-get install -y yarn && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy dependency files
COPY Gemfile Gemfile.lock ./
COPY package.json yarn.lock* ./

# Install Ruby gems
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3

# Install Node modules
RUN yarn install --frozen-lockfile --production=false

# Copy application code
COPY . .

# VERSION file should be created by CI/CD before build
# If it doesn't exist (local builds), create it from git or use 'dev'
RUN if [ ! -f VERSION ]; then \
      git describe --tags --always 2>/dev/null > VERSION || echo "dev-local" > VERSION; \
    fi

# Build CSS and JS
RUN yarn build && yarn build:css

# Precompile assets for production
RUN SECRET_KEY_BASE=dummy RAILS_ENV=production bundle exec rake assets:precompile

# ========================================
# Stage 2: Runtime - Minimal production image
# ========================================
FROM ruby:3.2.2-slim AS runtime

# Install only runtime dependencies
RUN apt-get update -qq && apt-get install -y \
    postgresql-client \
    libpq-dev \
    curl \
    imagemagick \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy installed gems from builder
COPY --from=builder /usr/local/bundle /usr/local/bundle

# Copy application code and built assets
COPY --from=builder /app /app

# Expose port 3000
EXPOSE 3000

# Create a script to handle database setup and start the server
COPY docker-entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]

# Start the server
CMD ["rails", "server", "-b", "0.0.0.0"]

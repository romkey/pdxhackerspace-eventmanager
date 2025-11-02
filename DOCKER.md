# Docker Setup Guide

This guide will help you run EventManager using Docker and Docker Compose.

## Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+

## Quick Start

### 1. Build and Start Services

```bash
docker-compose up -d
```

This will:
- Build the Rails application container
- Start PostgreSQL database
- Run database migrations
- Seed the database with sample data
- Start the Rails server

### 2. Access the Application

Open your browser to: **http://localhost:3000**

Default credentials:
- **Admin**: admin@example.com / password123
- **User**: user1@example.com / password123

### 3. View Logs

```bash
# All services
docker-compose logs -f

# Just the web app
docker-compose logs -f web

# Just the database
docker-compose logs -f db
```

## Common Commands

### Start Services

```bash
docker-compose up -d
```

### Stop Services

```bash
docker-compose down
```

### Stop Services and Remove Volumes (Complete Reset)

```bash
docker-compose down -v
```

### Rebuild After Code Changes

```bash
docker-compose build
docker-compose up -d
```

### Run Rails Console

```bash
docker-compose exec web rails console
```

### Run Database Migrations

```bash
docker-compose exec web rails db:migrate
```

### Reset Database

```bash
docker-compose exec web rails db:reset
docker-compose exec web rails db:seed
```

### Run Tests (if you add them)

```bash
docker-compose exec web rails test
```

### Access Rails Shell

```bash
docker-compose exec web bash
```

### View Running Containers

```bash
docker-compose ps
```

## Configuration

### Environment Variables

Create a `.env` file in the project root for custom configuration:

```bash
# Authentik OAuth (optional)
AUTHENTIK_CLIENT_ID=your_client_id
AUTHENTIK_CLIENT_SECRET=your_client_secret
AUTHENTIK_SITE_URL=https://your-authentik-instance.com

# Database (defaults are fine for development)
DATABASE_HOST=db
DATABASE_USER=eventmanager
DATABASE_PASSWORD=eventmanager_password
DATABASE_NAME=EventManager_development
```

### Port Conflicts

If port 3000 is already in use, edit `docker-compose.yml`:

```yaml
services:
  web:
    ports:
      - "3001:3000"  # Change 3001 to any available port
```

Then access the app at http://localhost:3001

### Database Port

If you need to access PostgreSQL from outside Docker:

```yaml
services:
  db:
    ports:
      - "5433:5432"  # Change 5433 to avoid conflicts
```

## Docker Compose Services

### Web Service (`web`)

- **Image**: Built from Dockerfile
- **Ports**: 3000
- **Volumes**: 
  - Application code (for live reloading)
  - Gem cache
  - Node modules
- **Depends on**: PostgreSQL database

### Database Service (`db`)

- **Image**: postgres:14-alpine
- **Ports**: 5432
- **Volumes**: Persistent PostgreSQL data
- **Healthcheck**: Ensures database is ready before starting web service

## Volumes

Docker Compose creates three volumes:

1. **postgres_data**: Stores PostgreSQL data (persists between restarts)
2. **bundle_cache**: Caches Ruby gems (faster rebuilds)
3. **node_modules**: Caches Node modules (faster rebuilds)

To view volumes:
```bash
docker volume ls | grep eventmanager
```

To remove all volumes (CAUTION: Deletes all data):
```bash
docker-compose down -v
```

## Troubleshooting

### "Port already in use" Error

Another service is using port 3000:
```bash
# Find what's using the port
lsof -ti:3000
# Kill it or change the port in docker-compose.yml
```

### Database Connection Errors

Make sure the database container is healthy:
```bash
docker-compose ps
# db should show "healthy" status

# Check database logs
docker-compose logs db
```

Restart services:
```bash
docker-compose down
docker-compose up -d
```

### "Bundle install" Errors

Rebuild the container:
```bash
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### Asset Compilation Errors

Rebuild with fresh assets:
```bash
docker-compose exec web yarn build
docker-compose exec web yarn build:css
docker-compose restart web
```

### Container Won't Start

Check logs:
```bash
docker-compose logs web
```

Remove and recreate:
```bash
docker-compose down
docker-compose up -d
```

### Database Not Seeding

Manually seed:
```bash
docker-compose exec web rails db:seed
```

### File Permission Issues (Linux)

If you encounter permission errors on Linux:
```bash
# Fix ownership
sudo chown -R $USER:$USER .

# Or run with your user ID
docker-compose run --user $(id -u):$(id -g) web bash
```

## Development Workflow

### Making Code Changes

Code changes are automatically reflected due to volume mounting. Just refresh your browser.

### Adding Gems

1. Add gem to `Gemfile`
2. Rebuild container:
   ```bash
   docker-compose build web
   docker-compose up -d
   ```

### Running Migrations

After creating a migration:
```bash
docker-compose exec web rails db:migrate
```

### Installing Node Packages

```bash
docker-compose exec web yarn add <package-name>
```

## Production Deployment

For production, consider:

1. **Multi-stage Docker builds** for smaller images
2. **Environment-specific compose files**: 
   - `docker-compose.yml` (base)
   - `docker-compose.prod.yml` (production overrides)
3. **External database** instead of containerized PostgreSQL
4. **Container orchestration**: Kubernetes, Docker Swarm, or managed services
5. **Secrets management**: Use Docker secrets or external vaults
6. **Health checks and monitoring**
7. **Reverse proxy**: nginx or Traefik
8. **SSL certificates**: Let's Encrypt

Example production command:
```bash
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

## Useful Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Rails Docker Guide](https://guides.rubyonrails.org/docker.html)
- [PostgreSQL Docker Image](https://hub.docker.com/_/postgres)

## Clean Up

### Remove Everything (Containers, Networks, Volumes)

```bash
docker-compose down -v
docker volume prune
docker image prune
```

### Remove Just EventManager Containers

```bash
docker-compose down
docker rmi eventmanager-web
```

## Support

For issues related to Docker setup, check the logs first:
```bash
docker-compose logs -f
```

For application issues, see the main README.md.


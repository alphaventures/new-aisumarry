# Quick Start Guide

Get the production-grade ASummary bot running in 15 minutes.

## Prerequisites Check

```bash
node --version  # Should be >= 20.0.0
pnpm --version  # Should be >= 9.0.0
docker --version
```

## Step 1: Setup Project

```bash
# Navigate to project
cd asummary-production

# Install dependencies
pnpm install

# Copy environment template
cp .env.example .env
```

## Step 2: Configure Environment

Edit `.env` file with your credentials:

```bash
# Minimum required for testing:
BOT_TOKEN=your_bot_token_from_@BotFather
DATABASE_URL=postgresql://asummary:asummary_dev_password@localhost:5432/asummary

AI_MODEL=GEMINI
AI_TOKEN=your_gemini_api_key

AZURE_TRANSLATOR_KEY=your_azure_key
AZURE_TRANSLATOR_LOCATION=eastus
```

## Step 3: Start Database

```bash
docker-compose up -d postgres

# Wait for database to be ready (check logs)
docker-compose logs -f postgres
```

## Step 4: Run Migrations

```bash
# Generate Prisma client
pnpm run generate

# Run migrations
pnpm run migrate:dev
```

## Step 5: Start Bot

### Development Mode (with hot reload)
```bash
pnpm run dev
```

### Production Mode (Docker)
```bash
docker-compose up -d bot
docker-compose logs -f bot
```

## Step 6: Verify It's Working

```bash
# Check health endpoint
curl http://localhost:3000/health

# Should return:
# {
#   "status": "healthy",
#   "timestamp": "...",
#   "checks": {
#     "database": true,
#     "bot": true
#   }
# }
```

## Testing the Bot

1. Open Telegram
2. Find your bot (@your_bot_username)
3. Send `/start` command
4. You should receive a help message

## Common Issues

### "Environment validation failed"
- Check all required variables in `.env`
- Verify no typos in variable names
- Ensure API keys are valid

### "Database connection failed"
- Ensure PostgreSQL is running: `docker-compose ps`
- Check DATABASE_URL is correct
- Verify database is accepting connections

### "Bot failed to start"
- Verify BOT_TOKEN is valid
- Check bot isn't running elsewhere
- Review logs: `docker-compose logs bot`

### "AI provider error"
- Verify AI_TOKEN is valid
- Check you have API credits
- Ensure AI_MODEL matches your token type

## Next Steps

1. Review `ARCHITECTURE.md` for full documentation
2. Follow `IMPLEMENTATION_CHECKLIST.md` for production setup
3. Configure monitoring and alerting
4. Set up automated backups
5. Deploy to production environment

## Development Workflow

```bash
# Make code changes
# ... edit files ...

# Rebuild and restart (Docker)
docker-compose down
docker-compose up --build -d

# Or use dev mode for auto-reload
pnpm run dev

# View logs
docker-compose logs -f bot

# Run linter
pnpm run lint

# Format code
pnpm run format
```

## Useful Commands

```bash
# View all running containers
docker-compose ps

# Stop everything
docker-compose down

# Remove volumes (reset database)
docker-compose down -v

# Access database directly
docker-compose exec postgres psql -U asummary

# View bot container logs
docker-compose logs -f bot

# Rebuild after code changes
docker-compose up --build -d bot
```

## Production Deployment

See `README.md` and `ARCHITECTURE.md` section 8 for complete production deployment guide.

Quick production checklist:
- [ ] Use secrets manager for sensitive values
- [ ] Configure proper DATABASE_URL with SSL
- [ ] Set NODE_ENV=production
- [ ] Enable monitoring and logging
- [ ] Set up automated backups
- [ ] Configure auto-scaling
- [ ] Test graceful shutdown
- [ ] Set up health check monitoring

## Getting Help

1. Check logs first: `docker-compose logs bot`
2. Verify configuration: Review `.env` file
3. Test components individually: Database, bot API, AI providers
4. Review architecture documentation
5. Check for known issues in implementation checklist

## Success!

If the health check returns "healthy" and the bot responds to `/start`, you're ready to start development or proceed with production deployment.

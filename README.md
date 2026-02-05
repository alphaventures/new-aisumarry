# ASummary Bot - Production Grade

A production-ready Telegram bot for channel summarization and translation with AI-powered content processing.

## 🚀 Features

- Multi-channel management with sub-channel support
- AI-powered content summarization (Gemini, OpenAI, AWS Bedrock)
- Azure Translation service integration
- Translation rules and keyword filtering
- Graceful shutdown and error recovery
- Health checks and monitoring ready
- Docker containerized deployment

## 📋 Prerequisites

- Node.js >= 20.0.0
- pnpm >= 9.0.0
- PostgreSQL >= 14
- Docker & Docker Compose (for containerized deployment)

## 🛠️ Installation

### Local Development

```bash
# Clone the repository
git clone <your-repo-url>
cd asummary-production

# Install dependencies
pnpm install

# Copy environment file
cp .env.example .env

# Edit .env with your credentials
nano .env

# Start PostgreSQL (via Docker)
docker-compose up -d postgres

# Run database migrations
pnpm run migrate:dev

# Start the bot in development mode
pnpm run dev
```

### Production Deployment

```bash
# Build Docker image
docker build -t asummary-bot:latest .

# Or use docker-compose
docker-compose up -d

# Check logs
docker-compose logs -f bot

# Verify health
curl http://localhost:3000/health
```

## ⚙️ Configuration

See `.env.example` for all available environment variables.

### Required Variables

- `BOT_TOKEN` - Your Telegram bot token from @BotFather
- `DATABASE_URL` - PostgreSQL connection string
- `AI_MODEL` - Choose from: GEMINI, OPENAI, or LLAMA
- `AI_TOKEN` - API key for Gemini/OpenAI (if applicable)
- `AZURE_TRANSLATOR_KEY` - Azure Translator API key
- `AZURE_TRANSLATOR_LOCATION` - Azure resource location

## 🏗️ Architecture

```
src/
├── config/          # Configuration and environment validation
├── core/            # Core infrastructure (database, logging, errors)
├── services/        # Business logic (AI, translation, channels)
├── bot/             # Telegram bot interface
├── repositories/    # Data access layer
├── utils/           # Utility functions
└── health/          # Health check endpoints
```

## 🔒 Security

- Non-root Docker user
- Environment validation on startup
- Rate limiting enabled
- Input sanitization
- No secrets in Docker images

## 📊 Monitoring

- Health check endpoint: `http://localhost:3000/health`
- Structured JSON logging with Pino
- Error tracking ready (Sentry support)

## 🚢 Deployment

### AWS ECS/Fargate

1. Push image to ECR
2. Create task definition with environment variables from Secrets Manager
3. Configure auto-scaling and health checks
4. Deploy to ECS service

### Other Platforms

The bot can be deployed to:
- Railway
- Render
- Fly.io
- Google Cloud Run
- Azure Container Instances
- Any platform supporting Docker containers

## 🧪 Development

```bash
# Run in development mode with auto-reload
pnpm run dev

# Build for production
pnpm run build

# Run production build
pnpm start

# Run linter
pnpm run lint

# Format code
pnpm run format
```

## 📝 License

ISC

## 🤝 Contributing

Contributions welcome! Please follow the existing code style and architecture patterns.

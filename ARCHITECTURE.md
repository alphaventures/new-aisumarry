# ASummary Bot - Production-Grade Redesign

## Executive Summary

This document provides a complete production-grade redesign of the ASummary Telegram bot. The current implementation has significant architectural, security, and operational issues that would prevent it from running reliably in production. This redesign addresses all critical gaps and provides a robust, maintainable foundation.

---

## 1️⃣ ARCHITECTURE REDESIGN

### Current Issues Identified

1. **Poor Separation of Concerns**: Bot logic, database access, and business logic are tightly coupled
2. **Global State**: `addTracker` array is a shared mutable global state that will cause race conditions
3. **No Config Management**: Environment variables scattered throughout, hardcoded values
4. **Missing Error Recovery**: No retry logic, no circuit breakers, crashes are silent
5. **Unsafe Prisma Usage**: Database client initialized globally with no connection management
6. **PM2 Cluster Mode Mistake**: Using `cluster` mode for a stateful bot will cause duplicate processing
7. **No Health Checks**: Deployment has no way to verify bot is healthy
8. **Docker Security Issues**: `.env` copied into image, migrations run during build
9. **Memory Leaks**: `setInterval` and `setTimeout` calls without proper cleanup
10. **No Logging Strategy**: Only `console.log`, no structured logging or levels

### Proposed Clean Architecture

```
aisummary-bot/
├── src/
│   ├── config/                    # Configuration management
│   │   ├── index.ts              # Main config loader
│   │   ├── env.ts                # Environment validation
│   │   └── constants.ts          # App constants
│   │
│   ├── core/                      # Core infrastructure
│   │   ├── database/
│   │   │   ├── client.ts         # Prisma client singleton
│   │   │   ├── health.ts         # DB health checks
│   │   │   └── migrations.ts     # Migration runner
│   │   │
│   │   ├── logger/
│   │   │   ├── index.ts          # Logger factory
│   │   │   └── formatters.ts     # Log formatters
│   │   │
│   │   └── errors/
│   │       ├── base.ts           # Base error classes
│   │       └── handlers.ts       # Error handlers
│   │
│   ├── services/                  # Business logic layer
│   │   ├── ai/
│   │   │   ├── providers/
│   │   │   │   ├── base.ts       # AI provider interface
│   │   │   │   ├── gemini.ts     # Gemini implementation
│   │   │   │   ├── openai.ts     # OpenAI implementation
│   │   │   │   └── bedrock.ts    # AWS Bedrock implementation
│   │   │   ├── factory.ts        # AI provider factory
│   │   │   └── index.ts          # AI service facade
│   │   │
│   │   ├── translation/
│   │   │   ├── azure.ts          # Azure Translator
│   │   │   └── index.ts          # Translation service
│   │   │
│   │   ├── channel/
│   │   │   ├── manager.ts        # Channel lifecycle management
│   │   │   ├── processor.ts      # Message processing
│   │   │   └── rules.ts          # Translation rules engine
│   │   │
│   │   └── session/
│   │       ├── manager.ts        # Session state management
│   │       └── operations.ts     # Pending operations tracking
│   │
│   ├── bot/                       # Bot interface layer
│   │   ├── handlers/
│   │   │   ├── commands/
│   │   │   │   ├── start.ts
│   │   │   │   ├── help.ts
│   │   │   │   └── mychannels.ts
│   │   │   │
│   │   │   ├── callbacks/
│   │   │   │   ├── channels.ts
│   │   │   │   ├── subchannels.ts
│   │   │   │   └── settings.ts
│   │   │   │
│   │   │   └── updates/
│   │   │       ├── channel-post.ts
│   │   │       └── chat-member.ts
│   │   │
│   │   ├── middlewares/
│   │   │   ├── error.ts          # Error handling middleware
│   │   │   ├── logging.ts        # Request logging
│   │   │   ├── rate-limit.ts     # Rate limiting
│   │   │   └── auth.ts           # Authorization checks
│   │   │
│   │   ├── conversations/
│   │   │   ├── channel-setup.ts
│   │   │   ├── language.ts
│   │   │   └── keywords.ts
│   │   │
│   │   └── bot.ts                # Bot initialization
│   │
│   ├── repositories/              # Data access layer
│   │   ├── base.ts               # Base repository
│   │   ├── channel.ts            # Channel repository
│   │   ├── channel-config.ts     # Config repository
│   │   └── session.ts            # Session repository
│   │
│   ├── utils/                     # Utility functions
│   │   ├── entity-parser.ts
│   │   ├── validators.ts
│   │   └── formatters.ts
│   │
│   ├── types/                     # TypeScript types
│   │   ├── context.ts
│   │   ├── config.ts
│   │   └── models.ts
│   │
│   ├── health/                    # Health check endpoints
│   │   └── index.ts
│   │
│   └── index.ts                   # Application entry point
│
├── prisma/
│   ├── schema.prisma
│   └── migrations/
│
├── scripts/
│   ├── migrate.sh                # Migration script
│   └── healthcheck.sh            # Health check script
│
├── tests/                        # Test files (future)
│   ├── unit/
│   └── integration/
│
├── .env.example                  # Example environment file
├── .dockerignore
├── Dockerfile
├── docker-compose.yml
├── package.json
├── tsconfig.json
└── README.md
```

### Layer Responsibilities

**Config Layer** (`src/config/`):
- Load and validate environment variables
- Provide type-safe configuration objects
- Fail fast on startup if configuration is invalid

**Core Layer** (`src/core/`):
- Database connection management with health checks
- Structured logging with multiple levels
- Error handling and recovery strategies
- Shared infrastructure concerns

**Services Layer** (`src/services/`):
- Pure business logic, no framework dependencies
- AI provider abstraction with factory pattern
- Channel management and message processing
- Translation orchestration
- All services are testable in isolation

**Bot Layer** (`src/bot/`):
- Telegram-specific handlers and middleware
- Request/response transformation
- Conversation flows
- Thin layer that delegates to services

**Repositories Layer** (`src/repositories/`):
- All database access isolated here
- Type-safe query builders
- Connection pooling and retry logic
- Transaction management

**Utils Layer** (`src/utils/`):
- Pure functions with no side effects
- Formatting, parsing, validation
- Reusable across all layers

---

## 2️⃣ ENVIRONMENT & CONFIGURATION

### Environment Variables

```bash
# .env.example

# ==========================================
# APPLICATION
# ==========================================
NODE_ENV=production                    # development | production | test
LOG_LEVEL=info                        # debug | info | warn | error
APP_NAME=asummary-bot
APP_VERSION=2.0.0

# ==========================================
# TELEGRAM BOT
# ==========================================
BOT_TOKEN=                            # Required: Your Telegram bot token
BOT_WEBHOOK_URL=                      # Optional: For webhook mode (leave empty for polling)
BOT_WEBHOOK_SECRET=                   # Optional: Secret for webhook validation
BOT_POLLING_TIMEOUT=30                # Polling timeout in seconds

# ==========================================
# DATABASE
# ==========================================
DATABASE_URL=postgresql://user:password@localhost:5432/asummary?schema=public
DB_POOL_MIN=2                         # Minimum connections in pool
DB_POOL_MAX=10                        # Maximum connections in pool
DB_CONNECTION_TIMEOUT=30000           # Connection timeout (ms)
DB_IDLE_TIMEOUT=60000                 # Idle connection timeout (ms)

# ==========================================
# AI PROVIDERS (Choose one)
# ==========================================
AI_MODEL=GEMINI                       # GEMINI | OPENAI | LLAMA

# For GEMINI or OPENAI
AI_TOKEN=                             # API key for Gemini/OpenAI

# For AWS Bedrock (LLAMA)
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_REGION=us-east-1
AWS_BEDROCK_MODEL_ID=meta.llama3-8b-instruct-v1:0

# AI Configuration
AI_MAX_TOKENS=2048
AI_TEMPERATURE=0.4
AI_REQUEST_TIMEOUT=30000              # Request timeout (ms)
AI_MAX_RETRIES=3                      # Number of retry attempts

# ==========================================
# AZURE TRANSLATOR
# ==========================================
AZURE_TRANSLATOR_KEY=                 # Required: Azure Translator API key
AZURE_TRANSLATOR_LOCATION=            # Required: Azure resource location (e.g., eastus)
AZURE_TRANSLATOR_ENDPOINT=https://api.cognitive.microsofttranslator.com

# ==========================================
# RATE LIMITING
# ==========================================
RATE_LIMIT_WINDOW=60000               # Rate limit window (ms)
RATE_LIMIT_MAX_REQUESTS=30            # Max requests per window

# ==========================================
# HEALTH CHECK
# ==========================================
HEALTH_CHECK_PORT=3000                # Port for health check server
HEALTH_CHECK_PATH=/health             # Health check endpoint path

# ==========================================
# MONITORING (Optional)
# ==========================================
SENTRY_DSN=                           # Optional: Sentry error tracking
ENABLE_METRICS=false                  # Enable Prometheus metrics

# ==========================================
# GRACEFUL SHUTDOWN
# ==========================================
SHUTDOWN_TIMEOUT=30000                # Graceful shutdown timeout (ms)
```

### Configuration Module

```typescript
// src/config/env.ts
import { z } from 'zod';
import dotenv from 'dotenv';

dotenv.config();

const envSchema = z.object({
  // Application
  NODE_ENV: z.enum(['development', 'production', 'test']).default('production'),
  LOG_LEVEL: z.enum(['debug', 'info', 'warn', 'error']).default('info'),
  APP_NAME: z.string().default('asummary-bot'),
  APP_VERSION: z.string().default('2.0.0'),

  // Telegram
  BOT_TOKEN: z.string().min(1, 'BOT_TOKEN is required'),
  BOT_WEBHOOK_URL: z.string().url().optional().or(z.literal('')),
  BOT_WEBHOOK_SECRET: z.string().optional(),
  BOT_POLLING_TIMEOUT: z.coerce.number().int().positive().default(30),

  // Database
  DATABASE_URL: z.string().url('DATABASE_URL must be a valid PostgreSQL URL'),
  DB_POOL_MIN: z.coerce.number().int().nonnegative().default(2),
  DB_POOL_MAX: z.coerce.number().int().positive().default(10),
  DB_CONNECTION_TIMEOUT: z.coerce.number().int().positive().default(30000),
  DB_IDLE_TIMEOUT: z.coerce.number().int().positive().default(60000),

  // AI
  AI_MODEL: z.enum(['GEMINI', 'OPENAI', 'LLAMA']),
  AI_TOKEN: z.string().optional(),
  AWS_ACCESS_KEY_ID: z.string().optional(),
  AWS_SECRET_ACCESS_KEY: z.string().optional(),
  AWS_REGION: z.string().default('us-east-1'),
  AWS_BEDROCK_MODEL_ID: z.string().default('meta.llama3-8b-instruct-v1:0'),
  AI_MAX_TOKENS: z.coerce.number().int().positive().default(2048),
  AI_TEMPERATURE: z.coerce.number().min(0).max(2).default(0.4),
  AI_REQUEST_TIMEOUT: z.coerce.number().int().positive().default(30000),
  AI_MAX_RETRIES: z.coerce.number().int().nonnegative().default(3),

  // Azure Translator
  AZURE_TRANSLATOR_KEY: z.string().min(1, 'AZURE_TRANSLATOR_KEY is required'),
  AZURE_TRANSLATOR_LOCATION: z.string().min(1, 'AZURE_TRANSLATOR_LOCATION is required'),
  AZURE_TRANSLATOR_ENDPOINT: z.string().url().default('https://api.cognitive.microsofttranslator.com'),

  // Rate Limiting
  RATE_LIMIT_WINDOW: z.coerce.number().int().positive().default(60000),
  RATE_LIMIT_MAX_REQUESTS: z.coerce.number().int().positive().default(30),

  // Health Check
  HEALTH_CHECK_PORT: z.coerce.number().int().positive().default(3000),
  HEALTH_CHECK_PATH: z.string().default('/health'),

  // Monitoring
  SENTRY_DSN: z.string().optional(),
  ENABLE_METRICS: z.coerce.boolean().default(false),

  // Shutdown
  SHUTDOWN_TIMEOUT: z.coerce.number().int().positive().default(30000),
});

// Validate environment variables
export function validateEnv() {
  try {
    const parsed = envSchema.parse(process.env);

    // Additional validation based on AI_MODEL
    if (parsed.AI_MODEL === 'GEMINI' || parsed.AI_MODEL === 'OPENAI') {
      if (!parsed.AI_TOKEN) {
        throw new Error(`AI_TOKEN is required when AI_MODEL is ${parsed.AI_MODEL}`);
      }
    }

    if (parsed.AI_MODEL === 'LLAMA') {
      if (!parsed.AWS_ACCESS_KEY_ID || !parsed.AWS_SECRET_ACCESS_KEY) {
        throw new Error('AWS credentials are required when AI_MODEL is LLAMA');
      }
    }

    return parsed;
  } catch (error) {
    if (error instanceof z.ZodError) {
      const errors = error.errors.map(err => `${err.path.join('.')}: ${err.message}`).join('\n');
      throw new Error(`Environment validation failed:\n${errors}`);
    }
    throw error;
  }
}

export type EnvConfig = z.infer<typeof envSchema>;
```

```typescript
// src/config/index.ts
import { validateEnv, EnvConfig } from './env';

let config: EnvConfig | null = null;

export function getConfig(): EnvConfig {
  if (!config) {
    config = validateEnv();
  }
  return config;
}

export function isProduction(): boolean {
  return getConfig().NODE_ENV === 'production';
}

export function isDevelopment(): boolean {
  return getConfig().NODE_ENV === 'development';
}
```

---

## 3️⃣ PRISMA & DATABASE LAYER

### Safe Prisma Client Initialization

```typescript
// src/core/database/client.ts
import { PrismaClient } from '@prisma/client';
import { getConfig } from '../../config';
import { logger } from '../logger';

let prisma: PrismaClient | null = null;
let isShuttingDown = false;

export function getPrismaClient(): PrismaClient {
  if (isShuttingDown) {
    throw new Error('Database is shutting down');
  }

  if (!prisma) {
    const config = getConfig();
    
    prisma = new PrismaClient({
      datasources: {
        db: {
          url: config.DATABASE_URL,
        },
      },
      log: config.LOG_LEVEL === 'debug' 
        ? ['query', 'info', 'warn', 'error']
        : ['warn', 'error'],
    });

    // Connection pool configuration is in DATABASE_URL query params:
    // ?connection_limit=10&pool_timeout=30

    // Handle unexpected disconnections
    prisma.$on('beforeExit', async () => {
      logger.warn('Prisma client is shutting down unexpectedly');
    });

    logger.info('Prisma client initialized');
  }

  return prisma;
}

export async function connectDatabase(): Promise<void> {
  const db = getPrismaClient();
  
  try {
    await db.$connect();
    logger.info('Database connected successfully');
  } catch (error) {
    logger.error({ error }, 'Failed to connect to database');
    throw new Error('Database connection failed');
  }
}

export async function disconnectDatabase(): Promise<void> {
  if (!prisma) return;

  isShuttingDown = true;

  try {
    await prisma.$disconnect();
    logger.info('Database disconnected successfully');
  } catch (error) {
    logger.error({ error }, 'Error disconnecting from database');
  } finally {
    prisma = null;
    isShuttingDown = false;
  }
}

export async function checkDatabaseHealth(): Promise<boolean> {
  if (!prisma) return false;

  try {
    await prisma.$queryRaw`SELECT 1`;
    return true;
  } catch (error) {
    logger.error({ error }, 'Database health check failed');
    return false;
  }
}
```

### Migration Strategy

```typescript
// src/core/database/migrations.ts
import { exec } from 'child_process';
import { promisify } from 'util';
import { logger } from '../logger';
import { getConfig } from '../../config';

const execAsync = promisify(exec);

export async function runMigrations(): Promise<void> {
  const config = getConfig();
  
  try {
    logger.info('Starting database migrations');
    
    // In production, use deploy (doesn't require interactive prompts)
    const command = config.NODE_ENV === 'production'
      ? 'npx prisma migrate deploy'
      : 'npx prisma migrate dev';

    const { stdout, stderr } = await execAsync(command);
    
    if (stdout) logger.info({ stdout }, 'Migration output');
    if (stderr) logger.warn({ stderr }, 'Migration warnings');
    
    logger.info('Database migrations completed successfully');
  } catch (error) {
    logger.error({ error }, 'Database migration failed');
    throw new Error('Failed to run database migrations');
  }
}

export async function checkMigrationStatus(): Promise<boolean> {
  try {
    const { stdout } = await execAsync('npx prisma migrate status');
    return !stdout.includes('not yet been applied');
  } catch (error) {
    logger.error({ error }, 'Failed to check migration status');
    return false;
  }
}
```

### Repository Pattern

```typescript
// src/repositories/base.ts
import { PrismaClient } from '@prisma/client';
import { getPrismaClient } from '../core/database/client';

export abstract class BaseRepository {
  protected db: PrismaClient;

  constructor() {
    this.db = getPrismaClient();
  }

  /**
   * Execute operation with retry logic for transient failures
   */
  protected async withRetry<T>(
    operation: () => Promise<T>,
    maxRetries: number = 3,
    delay: number = 1000
  ): Promise<T> {
    let lastError: Error;

    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await operation();
      } catch (error) {
        lastError = error as Error;
        
        // Only retry on connection errors
        if (this.isRetryableError(error) && attempt < maxRetries) {
          await this.sleep(delay * attempt);
          continue;
        }
        
        throw error;
      }
    }

    throw lastError!;
  }

  private isRetryableError(error: unknown): boolean {
    if (error instanceof Error) {
      const message = error.message.toLowerCase();
      return (
        message.includes('connection') ||
        message.includes('timeout') ||
        message.includes('econnrefused') ||
        message.includes('enotfound')
      );
    }
    return false;
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}
```

```typescript
// src/repositories/channel.ts
import { BaseRepository } from './base';
import { Prisma } from '@prisma/client';

export class ChannelRepository extends BaseRepository {
  async findByOwnerId(ownerId: bigint) {
    return this.withRetry(() =>
      this.db.channels.findMany({
        where: { owned_by: ownerId },
        select: { channelid: true },
      })
    );
  }

  async findById(channelId: bigint) {
    return this.withRetry(() =>
      this.db.channels.findUnique({
        where: { channelid: channelId },
      })
    );
  }

  async createChannel(data: Prisma.channelsCreateInput) {
    return this.withRetry(() =>
      this.db.channels.create({ data })
    );
  }

  async updateChannel(channelId: bigint, data: Prisma.channelsUpdateInput) {
    return this.withRetry(() =>
      this.db.channels.update({
        where: { channelid: channelId },
        data,
      })
    );
  }

  async deleteChannel(channelId: bigint) {
    return this.withRetry(() =>
      this.db.channels.delete({
        where: { channelid: channelId },
      })
    );
  }

  async deleteMany(channelIds: bigint[]) {
    return this.withRetry(() =>
      this.db.channels.deleteMany({
        where: { channelid: { in: channelIds } },
      })
    );
  }
}
```

### Updated Prisma Schema

```prisma
// prisma/schema.prisma
generator client {
  provider        = "prisma-client-js"
  previewFeatures = ["tracing"]
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model Session {
  id        Int      @id @default(autoincrement())
  key       String   @unique
  value     String
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@index([key])
}

model channels {
  channelid   BigInt   @id
  owned_by    BigInt?
  subchannels BigInt[]
  keyword     String[]
  trules      String[]
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  @@index([owned_by])
}

model channelconfig {
  id              BigInt   @id
  name            String?  @db.VarChar(255)
  lang            String?  @db.VarChar(255)
  aiprompt        String   @default("Summarise:") @db.VarChar(2000)
  ai              Boolean  @default(false)
  translate       Boolean  @default(false)
  textformat      String?
  footer          String?
  footer_keyboard String?
  createdAt       DateTime @default(now())
  updatedAt       DateTime @updatedAt
}

// Optional: Pending operations tracking (replaces global addTracker)
model pending_operations {
  id          Int      @id @default(autoincrement())
  userId      BigInt
  operationType String  // 'channel_add' | 'subchannel_add'
  channelId   BigInt?
  channelName String?
  createdAt   DateTime @default(now())
  expiresAt   DateTime

  @@index([userId, operationType])
  @@index([expiresAt])
}
```

---

## 4️⃣ TELEGRAM BOT DESIGN

### Bot Initialization with Graceful Shutdown

```typescript
// src/bot/bot.ts
import { Bot, GrammyError, HttpError, session } from 'grammy';
import { PrismaAdapter } from '@grammyjs/storage-prisma';
import { hydrateReply, parseMode } from '@grammyjs/parse-mode';
import { MyContext } from '../types/context';
import { getConfig } from '../config';
import { getPrismaClient } from '../core/database/client';
import { logger } from '../core/logger';
import { setupMiddlewares } from './middlewares';
import { registerHandlers } from './handlers';

let bot: Bot<MyContext> | null = null;
let isShuttingDown = false;

export function createBot(): Bot<MyContext> {
  const config = getConfig();
  
  if (bot) {
    logger.warn('Bot instance already exists, returning existing instance');
    return bot;
  }

  bot = new Bot<MyContext>(config.BOT_TOKEN);

  // Error handler must be registered first
  bot.catch((err) => {
    const ctx = err.ctx;
    logger.error(
      {
        error: err.error,
        updateId: ctx.update.update_id,
        userId: ctx.from?.id,
        chatId: ctx.chat?.id,
      },
      'Error handling update'
    );

    // Send user-friendly error message
    if (ctx.chat) {
      ctx.reply('An error occurred while processing your request. Please try again.').catch(
        (e) => logger.error({ error: e }, 'Failed to send error message to user')
      );
    }
  });

  // Session middleware
  bot.use(
    session({
      storage: new PrismaAdapter(getPrismaClient().session),
      initial: () => ({}),
    })
  );

  // Parse mode and reply hydration
  bot.use(hydrateReply);
  bot.api.config.use(parseMode('HTML'));

  // Setup custom middlewares
  setupMiddlewares(bot);

  // Register all handlers
  registerHandlers(bot);

  logger.info('Bot instance created successfully');
  return bot;
}

export function getBot(): Bot<MyContext> {
  if (!bot) {
    throw new Error('Bot not initialized. Call createBot() first.');
  }
  return bot;
}

export async function startBot(): Promise<void> {
  const config = getConfig();
  const botInstance = getBot();

  try {
    // Set bot commands
    await botInstance.api.setMyCommands([
      { command: 'start', description: 'Starts the bot and displays the help message.' },
      { command: 'help', description: 'Displays the help message.' },
      { command: 'mychannels', description: 'Manage your channels.' },
      { command: 'cancel', description: 'Cancel current operation.' },
    ]);

    if (config.BOT_WEBHOOK_URL) {
      // Webhook mode
      await botInstance.api.setWebhook(config.BOT_WEBHOOK_URL, {
        secret_token: config.BOT_WEBHOOK_SECRET,
      });
      logger.info({ url: config.BOT_WEBHOOK_URL }, 'Bot webhook set');
    } else {
      // Polling mode
      await botInstance.start({
        drop_pending_updates: true,
        allowed_updates: [
          'message',
          'callback_query',
          'channel_post',
          'my_chat_member',
        ],
        onStart: (info) => {
          logger.info({ username: info.username, id: info.id }, 'Bot started successfully');
        },
      });
    }
  } catch (error) {
    logger.error({ error }, 'Failed to start bot');
    throw error;
  }
}

export async function stopBot(): Promise<void> {
  if (!bot || isShuttingDown) {
    return;
  }

  isShuttingDown = true;
  logger.info('Stopping bot');

  try {
    const config = getConfig();
    
    // Stop receiving updates
    await bot.stop();

    // If using webhook, delete it
    if (config.BOT_WEBHOOK_URL) {
      await bot.api.deleteWebhook({ drop_pending_updates: true });
    }

    logger.info('Bot stopped successfully');
  } catch (error) {
    logger.error({ error }, 'Error stopping bot');
  } finally {
    bot = null;
    isShuttingDown = false;
  }
}
```

### Middleware Setup

```typescript
// src/bot/middlewares/index.ts
import { Bot } from 'grammy';
import { MyContext } from '../../types/context';
import { errorMiddleware } from './error';
import { loggingMiddleware } from './logging';
import { rateLimitMiddleware } from './rate-limit';

export function setupMiddlewares(bot: Bot<MyContext>): void {
  // Order matters: logging -> rate limiting -> error handling
  bot.use(loggingMiddleware());
  bot.use(rateLimitMiddleware());
  bot.use(errorMiddleware());
}
```

```typescript
// src/bot/middlewares/logging.ts
import { Middleware } from 'grammy';
import { MyContext } from '../../types/context';
import { logger } from '../../core/logger';

export function loggingMiddleware(): Middleware<MyContext> {
  return async (ctx, next) => {
    const start = Date.now();
    
    logger.debug({
      updateType: ctx.update.update_id,
      userId: ctx.from?.id,
      chatId: ctx.chat?.id,
      messageId: ctx.msg?.message_id,
    }, 'Processing update');

    try {
      await next();
    } finally {
      const duration = Date.now() - start;
      logger.debug({ duration }, 'Update processed');
    }
  };
}
```

```typescript
// src/bot/middlewares/rate-limit.ts
import { Middleware } from 'grammy';
import { MyContext } from '../../types/context';
import { getConfig } from '../../config';
import { logger } from '../../core/logger';

interface RateLimitEntry {
  count: number;
  resetAt: number;
}

const rateLimitMap = new Map<number, RateLimitEntry>();

// Cleanup old entries every 5 minutes
setInterval(() => {
  const now = Date.now();
  for (const [userId, entry] of rateLimitMap.entries()) {
    if (now > entry.resetAt) {
      rateLimitMap.delete(userId);
    }
  }
}, 5 * 60 * 1000);

export function rateLimitMiddleware(): Middleware<MyContext> {
  return async (ctx, next) => {
    if (!ctx.from) {
      return next();
    }

    const config = getConfig();
    const userId = ctx.from.id;
    const now = Date.now();

    let entry = rateLimitMap.get(userId);

    if (!entry || now > entry.resetAt) {
      entry = {
        count: 0,
        resetAt: now + config.RATE_LIMIT_WINDOW,
      };
      rateLimitMap.set(userId, entry);
    }

    entry.count++;

    if (entry.count > config.RATE_LIMIT_MAX_REQUESTS) {
      logger.warn({ userId, count: entry.count }, 'Rate limit exceeded');
      await ctx.reply('Too many requests. Please slow down and try again later.');
      return;
    }

    return next();
  };
}
```

```typescript
// src/bot/middlewares/error.ts
import { Middleware } from 'grammy';
import { MyContext } from '../../types/context';
import { logger } from '../../core/logger';
import { BotError } from '../../core/errors/base';

export function errorMiddleware(): Middleware<MyContext> {
  return async (ctx, next) => {
    try {
      await next();
    } catch (error) {
      logger.error({
        error,
        userId: ctx.from?.id,
        chatId: ctx.chat?.id,
        updateId: ctx.update.update_id,
      }, 'Error in middleware chain');

      // Don't expose internal errors to users
      const userMessage = error instanceof BotError
        ? error.message
        : 'An unexpected error occurred. Please try again.';

      if (ctx.chat) {
        await ctx.reply(userMessage).catch(
          (e) => logger.error({ error: e }, 'Failed to send error message')
        );
      }
    }
  };
}
```

### Handler Registration

```typescript
// src/bot/handlers/index.ts
import { Bot } from 'grammy';
import { MyContext } from '../../types/context';
import { registerCommandHandlers } from './commands';
import { registerCallbackHandlers } from './callbacks';
import { registerUpdateHandlers } from './updates';

export function registerHandlers(bot: Bot<MyContext>): void {
  registerCommandHandlers(bot);
  registerCallbackHandlers(bot);
  registerUpdateHandlers(bot);
}
```

---

## 5️⃣ ERROR HANDLING & LOGGING

### Structured Logging

```typescript
// src/core/logger/index.ts
import pino from 'pino';
import { getConfig } from '../../config';

let loggerInstance: pino.Logger | null = null;

export function createLogger(): pino.Logger {
  const config = getConfig();

  const logger = pino({
    level: config.LOG_LEVEL,
    base: {
      app: config.APP_NAME,
      version: config.APP_VERSION,
      env: config.NODE_ENV,
    },
    timestamp: pino.stdTimeFunctions.isoTime,
    formatters: {
      level: (label) => ({ level: label }),
    },
    transport: config.NODE_ENV !== 'production' ? {
      target: 'pino-pretty',
      options: {
        colorize: true,
        translateTime: 'SYS:standard',
        ignore: 'pid,hostname',
      },
    } : undefined,
  });

  return logger;
}

export function getLogger(): pino.Logger {
  if (!loggerInstance) {
    loggerInstance = createLogger();
  }
  return loggerInstance;
}

export const logger = getLogger();
```

### Custom Error Classes

```typescript
// src/core/errors/base.ts
export class BotError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly isOperational: boolean = true
  ) {
    super(message);
    this.name = this.constructor.name;
    Error.captureStackTrace(this, this.constructor);
  }
}

export class DatabaseError extends BotError {
  constructor(message: string) {
    super(message, 'DATABASE_ERROR');
  }
}

export class AIProviderError extends BotError {
  constructor(message: string, public readonly provider: string) {
    super(message, 'AI_PROVIDER_ERROR');
  }
}

export class TranslationError extends BotError {
  constructor(message: string) {
    super(message, 'TRANSLATION_ERROR');
  }
}

export class ConfigurationError extends BotError {
  constructor(message: string) {
    super(message, 'CONFIGURATION_ERROR', false);
  }
}

export class ValidationError extends BotError {
  constructor(message: string) {
    super(message, 'VALIDATION_ERROR');
  }
}
```

```typescript
// src/core/errors/handlers.ts
import { logger } from '../logger';
import { BotError } from './base';

export function handleError(error: Error): void {
  if (error instanceof BotError && !error.isOperational) {
    // Operational errors can be handled, non-operational should crash
    logger.fatal({ error }, 'Non-operational error occurred');
    process.exit(1);
  }

  logger.error({ error }, 'Error handled');
}

export function setupProcessErrorHandlers(): void {
  process.on('uncaughtException', (error: Error) => {
    logger.fatal({ error }, 'Uncaught exception');
    process.exit(1);
  });

  process.on('unhandledRejection', (reason: unknown) => {
    logger.fatal({ reason }, 'Unhandled promise rejection');
    process.exit(1);
  });

  process.on('SIGTERM', async () => {
    logger.info('SIGTERM received, starting graceful shutdown');
    await gracefulShutdown();
  });

  process.on('SIGINT', async () => {
    logger.info('SIGINT received, starting graceful shutdown');
    await gracefulShutdown();
  });
}

async function gracefulShutdown(): Promise<void> {
  const { getConfig } = await import('../../config');
  const { stopBot } = await import('../../bot/bot');
  const { disconnectDatabase } = await import('../database/client');
  const { stopHealthCheckServer } = await import('../../health');

  const config = getConfig();
  const timeout = setTimeout(() => {
    logger.error('Graceful shutdown timeout, forcing exit');
    process.exit(1);
  }, config.SHUTDOWN_TIMEOUT);

  try {
    // Stop accepting new requests
    await stopHealthCheckServer();
    
    // Stop bot (completes pending updates)
    await stopBot();
    
    // Close database connections
    await disconnectDatabase();
    
    clearTimeout(timeout);
    logger.info('Graceful shutdown completed');
    process.exit(0);
  } catch (error) {
    logger.error({ error }, 'Error during graceful shutdown');
    clearTimeout(timeout);
    process.exit(1);
  }
}
```

---

## 6️⃣ DOCKER & DEPLOYMENT

### Production-Optimized Dockerfile

```dockerfile
# Dockerfile
# ============================================
# Stage 1: Build
# ============================================
FROM node:20-alpine AS builder

# Install necessary build tools
RUN apk add --no-cache \
    openssl \
    libc6-compat

WORKDIR /app

# Copy package files
COPY package.json pnpm-lock.yaml ./

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

# Install dependencies (including devDependencies for build)
RUN pnpm install --frozen-lockfile

# Copy prisma schema and generate client
COPY prisma ./prisma
RUN pnpm exec prisma generate

# Copy source code
COPY tsconfig.json ./
COPY src ./src

# Build application
RUN pnpm run build

# ============================================
# Stage 2: Production Dependencies
# ============================================
FROM node:20-alpine AS deps

RUN apk add --no-cache openssl libc6-compat

WORKDIR /app

COPY package.json pnpm-lock.yaml ./

RUN corepack enable && corepack prepare pnpm@latest --activate

# Install only production dependencies
RUN pnpm install --frozen-lockfile --prod

# ============================================
# Stage 3: Runtime
# ============================================
FROM node:20-alpine AS runtime

# Install only required runtime dependencies
RUN apk add --no-cache \
    openssl \
    dumb-init \
    curl

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

WORKDIR /app

# Copy production dependencies
COPY --from=deps --chown=nodejs:nodejs /app/node_modules ./node_modules

# Copy built application
COPY --from=builder --chown=nodejs:nodejs /app/out ./out
COPY --from=builder --chown=nodejs:nodejs /app/prisma ./prisma
COPY --from=builder --chown=nodejs:nodejs /app/package.json ./package.json

# Copy scripts
COPY --chown=nodejs:nodejs scripts ./scripts

# Switch to non-root user
USER nodejs

# Expose health check port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Run migrations and start app
CMD ["sh", "-c", "npx prisma migrate deploy && node out/index.js"]
```

### .dockerignore

```
# .dockerignore
node_modules
npm-debug.log
out
dist
.git
.gitignore
.env
.env.*
!.env.example
*.md
!README.md
.vscode
.idea
coverage
.nyc_output
*.log
.DS_Store
prisma/migrations/*/*.sql
```

### Docker Compose for Local Development

```yaml
# docker-compose.yml
version: '3.8'

services:
  postgres:
    image: postgres:16-alpine
    container_name: asummary-db
    environment:
      POSTGRES_USER: asummary
      POSTGRES_PASSWORD: asummary_dev_password
      POSTGRES_DB: asummary
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U asummary"]
      interval: 10s
      timeout: 5s
      retries: 5

  bot:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: asummary-bot
    env_file:
      - .env
    environment:
      DATABASE_URL: postgresql://asummary:asummary_dev_password@postgres:5432/asummary?schema=public&connection_limit=10&pool_timeout=30
    depends_on:
      postgres:
        condition: service_healthy
    ports:
      - "3000:3000"
    restart: unless-stopped
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  postgres_data:
```

### Migration Script

```bash
#!/bin/bash
# scripts/migrate.sh

set -e

echo "Running database migrations..."

# Wait for database to be ready
until npx prisma db execute --stdin <<< "SELECT 1" > /dev/null 2>&1; do
  echo "Waiting for database to be ready..."
  sleep 2
done

echo "Database is ready, running migrations..."

# Run migrations
npx prisma migrate deploy

echo "Migrations completed successfully"
```

### Health Check Implementation

```typescript
// src/health/index.ts
import http from 'http';
import { logger } from '../core/logger';
import { getConfig } from '../config';
import { checkDatabaseHealth } from '../core/database/client';
import { getBot } from '../bot/bot';

let server: http.Server | null = null;

interface HealthStatus {
  status: 'healthy' | 'unhealthy';
  timestamp: string;
  checks: {
    database: boolean;
    bot: boolean;
  };
}

async function checkHealth(): Promise<HealthStatus> {
  const checks = {
    database: await checkDatabaseHealth(),
    bot: false,
  };

  try {
    const bot = getBot();
    const me = await bot.api.getMe();
    checks.bot = !!me.id;
  } catch (error) {
    logger.warn({ error }, 'Bot health check failed');
  }

  const isHealthy = checks.database && checks.bot;

  return {
    status: isHealthy ? 'healthy' : 'unhealthy',
    timestamp: new Date().toISOString(),
    checks,
  };
}

export function startHealthCheckServer(): void {
  const config = getConfig();

  server = http.createServer(async (req, res) => {
    if (req.url === config.HEALTH_CHECK_PATH && req.method === 'GET') {
      const health = await checkHealth();
      const statusCode = health.status === 'healthy' ? 200 : 503;

      res.writeHead(statusCode, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(health, null, 2));
    } else {
      res.writeHead(404);
      res.end('Not Found');
    }
  });

  server.listen(config.HEALTH_CHECK_PORT, () => {
    logger.info(
      { port: config.HEALTH_CHECK_PORT, path: config.HEALTH_CHECK_PATH },
      'Health check server started'
    );
  });
}

export async function stopHealthCheckServer(): Promise<void> {
  if (!server) return;

  return new Promise((resolve) => {
    server!.close(() => {
      logger.info('Health check server stopped');
      server = null;
      resolve();
    });
  });
}
```

---

## 7️⃣ SECURITY & STABILITY IMPROVEMENTS

### Security Enhancements

1. **Environment Variable Protection**:
   - Never commit `.env` files
   - Use secrets management in production (AWS Secrets Manager, HashiCorp Vault)
   - Validate all environment variables on startup

2. **Token Protection**:
   - Store BOT_TOKEN in secrets manager
   - Use webhook secret tokens
   - Rotate credentials regularly

3. **Input Validation**:
   - Validate all user inputs
   - Sanitize HTML content
   - Rate limit user requests

4. **Database Security**:
   - Use connection pooling
   - Enable SSL for database connections
   - Implement prepared statements (Prisma does this automatically)
   - Regular backups

5. **Container Security**:
   - Run as non-root user
   - Use minimal base images (Alpine)
   - Regular security updates
   - Scan images for vulnerabilities

### Stability Improvements

1. **Graceful Shutdown**:
   - Handle SIGTERM/SIGINT signals
   - Complete pending operations
   - Close all connections cleanly
   - Configurable shutdown timeout

2. **Retry Logic**:
   - Retry transient failures (network, database)
   - Exponential backoff
   - Maximum retry limits

3. **Circuit Breakers** (for AI services):
   ```typescript
   // src/services/ai/circuit-breaker.ts
   export class CircuitBreaker {
     private failures = 0;
     private lastFailTime = 0;
     private state: 'CLOSED' | 'OPEN' | 'HALF_OPEN' = 'CLOSED';
     
     constructor(
       private maxFailures: number = 5,
       private resetTimeout: number = 60000
     ) {}

     async execute<T>(operation: () => Promise<T>): Promise<T> {
       if (this.state === 'OPEN') {
         if (Date.now() - this.lastFailTime > this.resetTimeout) {
           this.state = 'HALF_OPEN';
         } else {
           throw new Error('Circuit breaker is OPEN');
         }
       }

       try {
         const result = await operation();
         this.onSuccess();
         return result;
       } catch (error) {
         this.onFailure();
         throw error;
       }
     }

     private onSuccess() {
       this.failures = 0;
       this.state = 'CLOSED';
     }

     private onFailure() {
       this.failures++;
       this.lastFailTime = Date.now();
       
       if (this.failures >= this.maxFailures) {
         this.state = 'OPEN';
       }
     }
   }
   ```

4. **Memory Management**:
   - Clear intervals/timeouts properly
   - Limit in-memory cache size
   - Monitor heap usage

5. **Monitoring & Alerts**:
   - Log all errors with context
   - Set up error tracking (Sentry)
   - Monitor resource usage
   - Alert on repeated failures

---

## 8️⃣ FINAL DELIVERABLES

### Updated package.json

```json
{
  "name": "asummary-bot",
  "version": "2.0.0",
  "description": "Production-grade Telegram channel summarization and translation bot",
  "main": "out/index.js",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc",
    "start": "node out/index.js",
    "migrate": "prisma migrate deploy",
    "migrate:dev": "prisma migrate dev",
    "generate": "prisma generate",
    "lint": "eslint src --ext .ts",
    "format": "prettier --write \"src/**/*.ts\"",
    "test": "jest",
    "docker:build": "docker build -t asummary-bot .",
    "docker:up": "docker-compose up -d",
    "docker:down": "docker-compose down",
    "docker:logs": "docker-compose logs -f bot"
  },
  "dependencies": {
    "@aws-sdk/client-bedrock-runtime": "^3.624.0",
    "@grammyjs/parse-mode": "^1.10.0",
    "@grammyjs/storage-prisma": "^2.4.2",
    "@grammyjs/conversations": "^1.2.0",
    "@prisma/client": "^5.17.0",
    "axios": "^1.7.3",
    "dotenv": "^16.4.5",
    "grammy": "^1.28.0",
    "pino": "^9.0.0",
    "zod": "^3.23.0"
  },
  "devDependencies": {
    "@types/node": "^22.1.0",
    "@typescript-eslint/eslint-plugin": "^7.0.0",
    "@typescript-eslint/parser": "^7.0.0",
    "eslint": "^8.57.0",
    "pino-pretty": "^11.0.0",
    "prettier": "^3.3.0",
    "prisma": "^5.17.0",
    "tsx": "^4.7.0",
    "typescript": "^5.5.4"
  },
  "engines": {
    "node": ">=20.0.0",
    "pnpm": ">=9.0.0"
  }
}
```

### Application Entry Point

```typescript
// src/index.ts
import { getConfig, validateEnv } from './config';
import { setupProcessErrorHandlers } from './core/errors/handlers';
import { logger } from './core/logger';
import { connectDatabase, runMigrations } from './core/database';
import { createBot, startBot } from './bot/bot';
import { startHealthCheckServer } from './health';

async function main() {
  try {
    // Validate environment first
    logger.info('Validating configuration...');
    validateEnv();
    const config = getConfig();

    logger.info(
      {
        env: config.NODE_ENV,
        version: config.APP_VERSION,
        aiModel: config.AI_MODEL,
      },
      'Starting ASummary Bot'
    );

    // Setup error handlers
    setupProcessErrorHandlers();

    // Connect to database
    await connectDatabase();

    // Run migrations (production-safe)
    if (config.NODE_ENV === 'production') {
      await runMigrations();
    }

    // Create and start bot
    createBot();
    await startBot();

    // Start health check server
    startHealthCheckServer();

    logger.info('ASummary Bot is running');
  } catch (error) {
    logger.fatal({ error }, 'Failed to start application');
    process.exit(1);
  }
}

main();
```

### Complete Folder Structure

```
aisummary-bot/
├── .dockerignore
├── .env.example
├── .eslintrc.json
├── .gitignore
├── .prettierrc.json
├── Dockerfile
├── README.md
├── docker-compose.yml
├── package.json
├── pnpm-lock.yaml
├── tsconfig.json
│
├── prisma/
│   ├── schema.prisma
│   └── migrations/
│
├── scripts/
│   ├── migrate.sh
│   └── healthcheck.sh
│
└── src/
    ├── index.ts
    │
    ├── config/
    │   ├── index.ts
    │   ├── env.ts
    │   └── constants.ts
    │
    ├── core/
    │   ├── database/
    │   │   ├── client.ts
    │   │   ├── health.ts
    │   │   └── migrations.ts
    │   │
    │   ├── logger/
    │   │   └── index.ts
    │   │
    │   └── errors/
    │       ├── base.ts
    │       └── handlers.ts
    │
    ├── services/
    │   ├── ai/
    │   │   ├── providers/
    │   │   │   ├── base.ts
    │   │   │   ├── gemini.ts
    │   │   │   ├── openai.ts
    │   │   │   └── bedrock.ts
    │   │   ├── circuit-breaker.ts
    │   │   ├── factory.ts
    │   │   └── index.ts
    │   │
    │   ├── translation/
    │   │   ├── azure.ts
    │   │   └── index.ts
    │   │
    │   ├── channel/
    │   │   ├── manager.ts
    │   │   ├── processor.ts
    │   │   └── rules.ts
    │   │
    │   └── session/
    │       ├── manager.ts
    │       └── operations.ts
    │
    ├── bot/
    │   ├── bot.ts
    │   │
    │   ├── middlewares/
    │   │   ├── index.ts
    │   │   ├── error.ts
    │   │   ├── logging.ts
    │   │   └── rate-limit.ts
    │   │
    │   ├── handlers/
    │   │   ├── index.ts
    │   │   ├── commands/
    │   │   ├── callbacks/
    │   │   └── updates/
    │   │
    │   └── conversations/
    │       ├── channel-setup.ts
    │       ├── language.ts
    │       └── keywords.ts
    │
    ├── repositories/
    │   ├── base.ts
    │   ├── channel.ts
    │   ├── channel-config.ts
    │   └── session.ts
    │
    ├── utils/
    │   ├── entity-parser.ts
    │   ├── validators.ts
    │   └── formatters.ts
    │
    ├── types/
    │   ├── context.ts
    │   ├── config.ts
    │   └── models.ts
    │
    └── health/
        └── index.ts
```

---

## DEPLOYMENT GUIDE

### Local Development

```bash
# 1. Clone and install
git clone <repo>
cd aisummary-bot
pnpm install

# 2. Setup environment
cp .env.example .env
# Edit .env with your credentials

# 3. Start database
docker-compose up -d postgres

# 4. Run migrations
pnpm run migrate:dev

# 5. Start bot
pnpm run dev
```

### Production Deployment (Docker)

```bash
# 1. Build image
docker build -t asummary-bot:latest .

# 2. Run with docker-compose
docker-compose up -d

# 3. Check logs
docker-compose logs -f bot

# 4. Health check
curl http://localhost:3000/health
```

### Cloud Deployment (AWS ECS Example)

1. **Push image to ECR**:
   ```bash
   aws ecr create-repository --repository-name asummary-bot
   docker tag asummary-bot:latest <account>.dkr.ecr.<region>.amazonaws.com/asummary-bot:latest
   docker push <account>.dkr.ecr.<region>.amazonaws.com/asummary-bot:latest
   ```

2. **Create task definition** with:
   - Environment variables from Secrets Manager
   - Health check configuration
   - Auto-scaling policies
   - CloudWatch logging

3. **Deploy to ECS**:
   - Use Fargate for serverless containers
   - Enable service auto-discovery
   - Configure ALB health checks
   - Set up CloudWatch alarms

### Monitoring

```bash
# View logs
docker-compose logs -f bot

# Check health
curl http://localhost:3000/health

# Database status
docker-compose exec postgres psql -U asummary -c "SELECT * FROM pg_stat_activity;"

# Container stats
docker stats asummary-bot
```

---

## KEY IMPROVEMENTS SUMMARY

1. ✅ **Clean Architecture**: Proper separation of concerns, testable code
2. ✅ **Type Safety**: Comprehensive TypeScript types, runtime validation
3. ✅ **Error Handling**: Graceful degradation, retry logic, circuit breakers
4. ✅ **Logging**: Structured JSON logging with levels
5. ✅ **Security**: Non-root user, no secrets in image, input validation
6. ✅ **Scalability**: Connection pooling, rate limiting, stateless design
7. ✅ **Observability**: Health checks, metrics-ready, error tracking
8. ✅ **DevOps**: Multi-stage builds, health checks, graceful shutdown
9. ✅ **Maintainability**: Clear structure, documented code, easy to extend
10. ✅ **Production-Ready**: Can run 24/7 with minimal intervention

This redesign transforms the bot from a prototype into a production-grade system that can handle real-world traffic, failures, and operational requirements.

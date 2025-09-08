# STARWEAVE User Database & Authentication Plan

> **Important Notice**: This document outlines the planned implementation of user authentication and database functionality. The system is currently in development and should not be used to store sensitive or confidential information. While we take security seriously, this is an open-source project in active development, and the database implementation may change.

## Overview

This document outlines the four-phase plan to implement user authentication and database functionality for STARWEAVE. The system will allow for user-specific context while maintaining the ability to learn from aggregated, non-sensitive data across users.

## Project Structure

```
apps/
├── starweave_core/          # Core business logic and schemas
│   ├── lib/starweave_core/
│   │   ├── accounts/       # User accounts and authentication
│   │   └── memories/       # Memory system with user context
│   └── priv/repo/          # Database migrations
│
├── starweave_web/          # Phoenix web interface
│   ├── lib/starweave_web/
│   │   ├── controllers/    # Web controllers
│   │   └── templates/      # Web templates
│   └── router.ex           # Web routes
│
└── starweave_api/          # Future API (placeholder)
    └── README.md           # API structure documentation
```

## Phase 1: User Authentication

### Goals
- Implement Google OAuth 2.0 authentication
- Create user session management
- Set up basic user profiles

### Implementation Steps
1. **Dependencies**
   - Add `ueberauth` and `ueberauth_google` to `starweave_web/mix.exs`
   - Configure Google OAuth credentials in `config/config.exs`

2. **Core User Schema** (`starweave_core/lib/starweave_core/accounts/user.ex`)
   ```elixir
   defmodule StarweaveCore.Accounts.User do
     use Ecto.Schema
     import Ecto.Changeset

     @primary_key {:id, :binary_id, autogenerate: true}
     @foreign_key_type :binary_id
     
     schema "users" do
       field :google_id, :string
       field :email, :string
       field :name, :string
       field :avatar_url, :string
       field :is_admin, :boolean, default: false
       
       # Authentication
       field :token, :string
       
       # Timestamps
       timestamps()
     end

     def changeset(user, attrs) do
       user
       |> cast(attrs, [:google_id, :email, :name, :avatar_url, :is_admin, :token])
       |> validate_required([:google_id, :email])
       |> unique_constraint(:google_id)
       |> unique_constraint(:email)
     end
   end
   ```

3. **Auth Context** (`starweave_core/lib/starweave_core/accounts/auth.ex`)
   - OAuth callback handling
   - Session management
   - User lookup and creation

4. **Web Routes** (`starweave_web/lib/starweave_web/router.ex`)
   ```elixir
   scope "/", StarweaveWeb do
     # Authentication routes
     get "/auth/google", AuthController, :request
     get "/auth/google/callback", AuthController, :callback
     delete "/sessions", SessionController, :delete
   end
   ```

5. **Auth Controller** (`starweave_web/lib/starweave_web/controllers/auth_controller.ex`)
   - Handle OAuth callbacks
   - Create/update user sessions
   - Redirect after authentication

## Phase 2: Database Integration

### Goals
- Set up PostgreSQL database
- Create necessary tables
- Implement data access layer

### Core Database Setup

1. **Migrations** (`starweave_core/priv/repo/migrations/`)
   - Create users table
   - Add indexes for common queries
   - Set up extensions (like UUID)

2. **Repository** (`starweave_core/lib/starweave_core/repo.ex`)
   - Configure Ecto repository
   - Set up connection pooling
   - Add telemetry events

### Database Schema

```elixir
# Memories Table
memories
- id (uuid, primary key)
- user_id (references users.id, null: true) # null for global memories
- context (string)
- key (string)
- value (jsonb)
- importance (float, default: 0.5)
- ttl (integer, null: true) # null for permanent memories
- is_global (boolean, default: false) # if true, can be used across users
- inserted_at (utc_datetime)
- updated_at (utc_datetime)
- expires_at (utc_datetime, index)
- metadata (jsonb, for future extensions)

# Indexes
- create unique_index(:memories, [:user_id, :context, :key])
- create index(:memories, [:user_id])
- create index(:memories, [:expires_at])
- create index(:memories, [:is_global])
```

## Phase 3: Memory System Update

### Goals
- Make WorkingMemory user-aware
- Implement database persistence
- Add memory cleanup

### Implementation Details

1. **WorkingMemory Updates**
   - Add `user_id` parameter to all functions
   - Implement database fallback for ETS misses
   - Add memory versioning for schema migrations

2. **Memory Types**
   - **User-specific**: Tied to a single user
   - **Global**: Shared across all users
   - **Temporary**: Ephemeral, not persisted

3. **Cleanup**
   - Periodic job to clean expired memories
   - Memory compression for long-term storage
   - Backup system for user data

## Phase 4: Frontend Integration

### Goals
- User login/logout UI
- Memory management interface
- User settings

### Components

1. **Auth Components**
   - Login/Logout buttons
   - User profile dropdown
   - Session management

2. **Memory Management**
   - View/Edit memories
   - Memory search and filter
   - Export/import functionality

3. **Settings**
   - Privacy controls
   - Data export
   - Memory retention policies

## Future Considerations

1. **Data Privacy**
   - Implement data anonymization
   - Add user controls for data sharing
   - GDPR/CCPA compliance

2. **Scalability**
   - Database sharding
   - Read replicas
   - Caching layer

3. **Advanced Features**
   - Memory sharing between users
   - Collaborative filtering
   - Memory versioning and history

## Implementation Notes

- All database operations should be wrapped in transactions
- Use ETS as a write-through cache for performance
- Implement proper error handling and logging
- Add metrics for monitoring performance
- Document all public APIs

## Future API Structure (Placeholder)

The `starweave_api` app will be implemented in the future to provide a REST/GraphQL interface. The structure will follow:

```
starweave_api/
├── lib/starweave_api/
│   ├── controllers/        # API controllers
│   ├── plugs/             # Authentication and other plugs
│   ├── schemas/           # JSON schemas
│   ├── router.ex          # API routes
│   └── endpoint.ex        # API endpoint configuration
└── test/                  # API tests
```

Key considerations for the future API:
- Token-based authentication
- Rate limiting
- Versioning
- Comprehensive documentation
- OpenAPI/Swagger support

## Security Considerations

1. **Immediate**
   - Secure password hashing
   - CSRF protection
   - Rate limiting
   - Input validation

2. **Future**
   - Audit logging
   - Two-factor authentication
   - Security headers
   - Regular security audits

## Development Roadmap

1. **Initial Implementation**
   - Basic authentication
   - Memory storage and retrieval
   - Simple UI for management

2. **Enhancements**
   - Advanced search
   - Memory categorization
   - Performance optimizations

3. **Maturity**
   - Comprehensive testing
   - Documentation
   - Performance benchmarking

## Contributing

Contributions are welcome! Please see our [Contributing Guidelines](CONTRIBUTING.md) for more information.

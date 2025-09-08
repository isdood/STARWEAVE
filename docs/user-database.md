# STARWEAVE User Database & Authentication Plan

> **Important Notice**: This document outlines the planned implementation of user authentication and database functionality. The system is currently in development and should not be used to store sensitive or confidential information. While we take security seriously, this is an open-source project in active development, and the database implementation may change.

## Overview

This document outlines the four-phase plan to implement user authentication and database functionality for STARWEAVE. The system will allow for user-specific context while maintaining the ability to learn from aggregated, non-sensitive data across users.

## Phase 1: User Authentication

### Goals
- Implement Google OAuth 2.0 authentication
- Create user session management
- Set up basic user profiles

### Implementation Steps
1. **Dependencies**
   - Add `ueberauth` and `ueberauth_google` to `mix.exs`
   - Configure Google OAuth credentials

2. **User Schema**
   ```elixir
   users
   - id (uuid, primary key)
   - google_id (string, unique)
   - email (string, unique)
   - name (string)
   - avatar_url (string)
   - is_admin (boolean, default: false)
   - preferences (jsonb, for future use)
   - inserted_at (utc_datetime)
   - updated_at (utc_datetime)
   ```

3. **Routes**
   - `GET /auth/google` - Initiate Google OAuth
   - `GET /auth/google/callback` - OAuth callback
   - `DELETE /sessions` - Logout

## Phase 2: Database Integration

### Goals
- Set up PostgreSQL database
- Create necessary tables
- Implement data access layer

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

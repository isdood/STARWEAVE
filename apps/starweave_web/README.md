# Starweave Web Interface

The web interface for the STARWEAVE project, built with Phoenix LiveView. This component provides a real-time, interactive user interface for interacting with the STARWEAVE cognitive architecture.

## Features

### 1. Real-time Dashboards

- **ETS Dashboard**: Monitor and manage the system's working memory
- **Pattern Visualization**: View and analyze pattern recognition in real-time
- **System Metrics**: Monitor system performance and resource usage

### 2. Interactive Components

- Live-updating interfaces using Phoenix LiveView
- Responsive design for desktop and mobile devices
- Real-time data visualization
- Interactive pattern exploration tools

### 3. System Management

- Cluster node management
- Process monitoring and supervision
- System configuration interface
- Log viewing and analysis

## Getting Started

### Prerequisites

- Elixir 1.14+ and Erlang/OTP 25+
- Node.js 16+ (for assets)
- PostgreSQL (if using database features)

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   mix deps.get
   cd assets && npm install && cd ..
   ```
3. Set up environment variables (copy `.env.example` to `.env` and adjust)

### Running the Server

Start the Phoenix server with:

```bash
# Start in development mode
mix phx.server

# Or start with IEx for interactive development
iex -S mix phx.server
```

Visit `http://localhost:4000` in your browser.

## Key Components

### Routes

- `/` - Main application dashboard
- `/dets-dashboard` - DETS storage monitoring and management
- `/patterns` - Pattern visualization and analysis

### Directory Structure

- `lib/starweave_web/` - Web interface components
  - `live/` - LiveView modules
  - `controllers/` - Traditional Phoenix controllers
  - `components/` - Reusable UI components
  - `templates/` - View templates
  - `channels/` - WebSocket channels

## Development

### Running Tests

```bash
mix test
```

### Code Style

We use `mix format` for code formatting and `credo` for static code analysis:

```bash
mix format
mix credo
```

## Deployment

For production deployment, please refer to the [Phoenix deployment guide](https://hexdocs.pm/phoenix/deployment.html).

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

[Specify License]

## Support

For support, please open an issue in the repository or contact the development team.

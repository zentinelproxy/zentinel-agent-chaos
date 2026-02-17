# Chaos Engineering Agent for Zentinel

A chaos engineering agent for [Zentinel](https://zentinelproxy.io) that provides controlled fault injection for resilience testing.

## Features

- **Latency Injection** - Add fixed or random delays to requests
- **Error Injection** - Return specific HTTP status codes
- **Timeout Simulation** - Simulate upstream timeouts (504)
- **Response Corruption** - Inject garbage into responses
- **Connection Reset** - Simulate connection failures (502)
- **Bandwidth Throttling** - Slow response delivery
- **Flexible Targeting** - Path, header, method, and percentage-based selection
- **Safety Controls** - Schedule windows, excluded paths, kill switch, dry run mode

## Installation

```bash
cargo install zentinel-agent-chaos
```

Or build from source:

```bash
git clone https://github.com/zentinelproxy/zentinel-agent-chaos.git
cd zentinel-agent-chaos
cargo build --release
```

## Usage

```bash
# Run with default config file (chaos.yaml)
zentinel-agent-chaos

# Specify config file
zentinel-agent-chaos -c /path/to/config.yaml

# Specify socket path
zentinel-agent-chaos -s /tmp/chaos.sock

# Run in dry-run mode (log faults without applying)
zentinel-agent-chaos --dry-run

# Print example configuration
zentinel-agent-chaos --print-config

# Validate configuration
zentinel-agent-chaos --validate
```

## Configuration

### Basic Structure

```yaml
settings:
  enabled: true                    # Global kill switch
  dry_run: false                   # Log faults without applying
  log_injections: true             # Log when faults are injected

safety:
  max_affected_percent: 50         # Never affect more than 50% of traffic
  schedule:                        # Only active during these windows
    - days: [mon, tue, wed, thu, fri]
      start: "09:00"
      end: "17:00"
      timezone: "UTC"
  excluded_paths:                  # Never inject faults here
    - "/health"
    - "/ready"
    - "/metrics"

experiments:
  # Your fault experiments here
```

### Fault Types

#### Latency Injection

Add delay before proxying requests:

```yaml
experiments:
  - id: "api-latency"
    enabled: true
    targeting:
      paths:
        - prefix: "/api/"
      percentage: 10
    fault:
      type: latency
      fixed_ms: 500                # Fixed 500ms delay

  - id: "random-latency"
    enabled: true
    targeting:
      paths:
        - prefix: "/api/"
      percentage: 5
    fault:
      type: latency
      min_ms: 100                  # Random delay between 100-1000ms
      max_ms: 1000
```

#### Error Injection

Return HTTP errors immediately:

```yaml
experiments:
  - id: "payment-errors"
    enabled: true
    targeting:
      paths:
        - exact: "/api/payments"
      percentage: 5
    fault:
      type: error
      status: 500
      message: "Chaos: Internal Server Error"
      headers:
        x-chaos-injected: "true"
```

#### Timeout Simulation

Simulate upstream timeouts:

```yaml
experiments:
  - id: "upstream-timeout"
    enabled: true
    targeting:
      paths:
        - regex: "^/api/external/.*"
      percentage: 2
    fault:
      type: timeout
      duration_ms: 30000           # 30 second timeout
```

#### Response Corruption

Inject garbage into responses (probabilistic):

```yaml
experiments:
  - id: "corrupt-response"
    enabled: true
    targeting:
      percentage: 1
    fault:
      type: corrupt
      probability: 0.5             # 50% of targeted requests get corrupted
```

#### Connection Reset

Simulate connection failures:

```yaml
experiments:
  - id: "connection-reset"
    enabled: true
    targeting:
      paths:
        - prefix: "/api/unstable/"
      percentage: 3
    fault:
      type: reset
```

### Targeting Options

#### Path Matching

```yaml
targeting:
  paths:
    - exact: "/api/users"          # Exact match
    - prefix: "/api/"              # Prefix match
    - regex: "^/api/v\\d+/.*"      # Regex match
```

#### Method Filtering

```yaml
targeting:
  methods: ["GET", "POST"]         # Only affect these methods
```

#### Header-Based Activation

```yaml
targeting:
  headers:
    x-chaos-enabled: "true"        # Only if header matches
```

#### Percentage Selection

```yaml
targeting:
  percentage: 10                   # Affect 10% of matching requests
```

### Schedule Windows

Only run chaos during specific times:

```yaml
safety:
  schedule:
    - days: [mon, tue, wed, thu, fri]
      start: "09:00"
      end: "17:00"
      timezone: "America/New_York"
    - days: [sat]
      start: "10:00"
      end: "14:00"
      timezone: "UTC"
```

### Excluded Paths

Protect critical endpoints:

```yaml
safety:
  excluded_paths:
    - "/health"
    - "/ready"
    - "/metrics"
    - "/api/v1/auth"
```

## Zentinel Configuration

Add the agent to your Zentinel proxy configuration:

```kdl
agents {
    agent "chaos" {
        type "custom"
        transport "unix_socket" {
            path "/tmp/zentinel-chaos.sock"
        }
        events ["request_headers"]
        timeout-ms 100
        failure-mode "open"
    }
}
```

## Safety Best Practices

1. **Start with dry run mode** - Use `--dry-run` to verify targeting before enabling
2. **Use low percentages** - Start with 1-5% and increase gradually
3. **Always exclude health checks** - Ensure `/health`, `/ready` are in `excluded_paths`
4. **Set schedule windows** - Only run chaos during business hours when teams can respond
5. **Use header triggers for testing** - Target `x-chaos-enabled: true` for controlled testing
6. **Monitor injection counts** - Track how many faults are being injected

## Response Headers

When faults are injected, the following headers are added:

| Header | Description |
|--------|-------------|
| `x-chaos-injected` | Always `"true"` when a fault was injected |
| `x-chaos-experiment` | ID of the experiment that was applied |

## Testing

Run the test suite:

```bash
cargo test
```

## License

MIT License - see [LICENSE](LICENSE) for details.

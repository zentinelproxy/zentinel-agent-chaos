<p align="center">
  <a href="https://zentinelproxy.io">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/zentinelproxy/design/main/marks/lockup/zentinel-lockup-dark.svg">
      <img alt="Zentinel" src="https://raw.githubusercontent.com/zentinelproxy/design/main/marks/lockup/zentinel-lockup-light.svg" height="52">
    </picture>
  </a>
</p>

<h3 align="center">Chaos agent</h3>

<p align="center">Injects latency and synthetic error responses into selected requests at the request-headers phase, for resilience testing.</p>

<p align="center">
  <a href="https://github.com/zentinelproxy/zentinel-agent-chaos/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/zentinelproxy/zentinel-agent-chaos/actions/workflows/ci.yml/badge.svg"></a>
  <img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-9b4d8a?style=flat&amp;labelColor=1f161e">
  <img alt="Agent protocol v2" src="https://img.shields.io/badge/agent%20protocol-v2-f68d31?style=flat&amp;labelColor=1f161e">
</p>

<p align="center">
  <a href="https://registry.zentinelproxy.io/chaos/">Registry</a> &middot;
  <a href="https://docs.zentinelproxy.io">Docs</a> &middot;
  <a href="https://github.com/zentinelproxy">All repositories</a>
</p>

The chaos agent lets you test how clients and services behave when a dependency
is slow or failing, without touching the upstream. You describe experiments in a
YAML file: which requests to target (path, method, header, percentage) and which
fault to apply. On a match the agent either delays the request and lets it
through, or answers it itself with an error response, so the upstream is never
called. Safety controls (a kill switch, dry-run mode, schedule windows, excluded
paths) bound what it can affect. Because it is a test tool, run its filter with
`failure-mode "open"`: if the agent is down, requests pass through untouched.

## Quick start

```bash
zentinel bundle install chaos
```

Write a `chaos.yaml` with one experiment that only fires when the request
carries a header:

```yaml
experiments:
  - id: "header-latency"
    targeting:
      headers:
        x-chaos-latency: "true"
    fault:
      type: latency
      fixed_ms: 500
```

Start the agent (it reads `chaos.yaml` from the working directory unless `-c` says otherwise):

```bash
zentinel-chaos-agent -c chaos.yaml --socket /tmp/zentinel-chaos.sock
```

Wire it into a route:

```kdl
system {
    worker-threads 0
}

listeners {
    listener "http" {
        address "0.0.0.0:8080"
        protocol "http"
    }
}

upstreams {
    upstream "backend" {
        target "127.0.0.1:3000"
    }
}

agents {
    agent "chaos" type="custom" {
        unix-socket "/tmp/zentinel-chaos.sock"
        events "request_headers"
        timeout-ms 5000   // must exceed the longest latency or timeout fault
    }
}

filters {
    filter "chaos" {
        type "agent"
        agent "chaos"
        failure-mode "open"
    }
}

routes {
    route "default" {
        matches { path-prefix "/" }
        upstream "backend"
        filters "chaos"
    }
}
```

`curl -H 'x-chaos-latency: true' http://localhost:8080/` now takes about 500 ms
longer than the same request without the header.

## Install

### Bundle (recommended)

```bash
zentinel bundle install chaos
```

Downloads the release binary pinned in Zentinel's bundle lock and installs it as `zentinel-chaos-agent`.

### Release binaries

Tarballs for `linux-x86_64`, `linux-aarch64` and `darwin-aarch64` are attached to each [release](https://github.com/zentinelproxy/zentinel-agent-chaos/releases).

### From source

`cargo install --git` does not work for this crate: it depends on a sibling
checkout of [`zentinel-agent-rust-sdk`](https://github.com/zentinelproxy/zentinel-agent-rust-sdk) by path.
Clone both side by side (you also need `protoc`):

```bash
git clone https://github.com/zentinelproxy/zentinel-agent-rust-sdk
git clone https://github.com/zentinelproxy/zentinel-agent-chaos
cd zentinel-agent-chaos
cargo build --release   # target/release/zentinel-chaos-agent
```

## Configuration

The agent takes its settings from its command line and its YAML file. Zentinel
26.10_8 and later send the agent block's `config { }` on every connection
(releases up to 0.6.50 never did), but the agent's `on_configure` handler only
logs what it receives and applies nothing, so set everything here.

| Option | Default | Meaning |
|---|---|---|
| `-c`, `--config` | `chaos.yaml` if present | Path to the YAML file. Without the option, `chaos.yaml` in the working directory is used if it exists, otherwise the agent starts with no experiments and injects nothing. A `--config` file that does not exist or does not validate is an error. |
| `-s`, `--socket` | `/tmp/zentinel-chaos.sock` | Unix socket to listen on (agent protocol v2). |
| `--grpc-address` | none | Listen for gRPC (agent protocol v2) on this address instead, e.g. `127.0.0.1:50051`. The Unix socket is served as well only if `--socket` is also given. |
| `-L`, `--log-level` | `info` | Log level. `RUST_LOG`, if set, takes precedence. |
| `--dry-run` | off | Log faults instead of applying them (overrides `settings.dry_run`). |
| `--validate` | off | Load and validate the file, then exit. |
| `--print-config` | off | Print an example file and exit. |
| `--version` | | Print `zentinel-chaos-agent <version>` and exit. |

### YAML file

Unknown keys are ignored, so check spelling with care.

| Option | Default | Meaning |
|---|---|---|
| `settings.enabled` | `true` | Kill switch. `false` lets every request through. |
| `settings.dry_run` | `false` | Log faults instead of applying them. |
| `settings.log_injections` | `true` | Log each injected fault at `info`. |
| `safety.max_affected_percent` | `50` | Validated (0 to 100) but **not enforced**: nothing caps total affected traffic. |
| `safety.schedule` | none (always active) | List of windows `{days, start, end, timezone}`. Faults apply only inside one. `days` takes `mon`..`sun`, times are `HH:MM`, `start` must be before `end` (no window across midnight), `timezone` is an IANA name and falls back to UTC if it does not parse. |
| `safety.excluded_paths` | `/health`, `/ready`, `/metrics` | Never targeted: the path itself and anything under `<path>/`. The default applies only when the whole `safety` section is absent. |
| `experiments[].id` | required | Unique id, used in logs and the `x-chaos-experiment` header. |
| `experiments[].enabled` | `true` | Turn one experiment off. |
| `experiments[].description` | empty | Free text. |
| `experiments[].targeting.paths` | any path | List of `{exact: ...}`, `{prefix: ...}` or `{regex: ...}`; any one must match. |
| `experiments[].targeting.methods` | any method | List of HTTP methods, case-insensitive. |
| `experiments[].targeting.headers` | none | Map of header name to exact value; all must match. Names are case-insensitive, only the first value of a header is compared. |
| `experiments[].targeting.percentage` | `100` | Share of matching requests to affect, 0 to 100. |
| `experiments[].fault` | required | One of the faults below, selected by `type`. |

Paths are matched without the query string: `exact: "/api/payments"` matches
`/api/payments?id=1`, and `/health?probe=1` is excluded by `/health`. (Before
0.5.0 the query string was part of the match, so it could move a request out
of an excluded path.)

### Faults

| `type` | Fields | What happens |
|---|---|---|
| `latency` | `fixed_ms`, or `min_ms` and `max_ms` | Waits (fixed, or uniformly random in the range), then lets the request through. |
| `error` | `status` (100 to 599), `message`, `headers` | Answers with that status, `message` as a plain-text body (default `Chaos fault injected`) and the extra headers. |
| `timeout` | `duration_ms` | Waits, then answers `504 Gateway Timeout`. |
| `reset` | none | Answers `502 Bad Gateway`. It does not reset the connection. |
| `corrupt` | `probability` (0.0 to 1.0) | With that probability, answers `200` with 50 to 499 random printable ASCII characters (labelled `application/octet-stream`) instead of the upstream's response. It does not alter a real response. |
| `throttle` | `bytes_per_second` | **Approximation:** waits `10240 * 1000 / bytes_per_second` ms (the time to send 10 KiB), then lets the request through. Response bandwidth is not limited. |

Responses generated by `error`, `timeout`, `reset` and `corrupt` carry
`x-chaos-injected: true` and `x-chaos-experiment: <id>`. Delayed requests
(`latency`, `throttle`) get no marker header.

Full reference: <https://registry.zentinelproxy.io/chaos/>

## How it works

The agent subscribes to `request_headers` only. For each request it checks, in
order: the kill switch, the schedule, the excluded paths, then each enabled
experiment in file order. The first experiment whose targeting matches and that
is selected by its `percentage` applies its fault; at most one fault applies per
request. In dry-run mode the match is logged and the request passes unchanged.

The delay happens inside the agent call, so the agent's `timeout-ms` (and the
filter's, if set) must be longer than the longest `latency`, `throttle` or
`timeout` fault. Otherwise Zentinel gives up on the agent first and, with
`failure-mode "open"`, forwards the request without the fault.

## Releases and smoke test

Releases are built from their tag by the shared pipeline in
[`zentinelproxy/.github`](https://github.com/zentinelproxy/.github)
(`agent-release.yml`): each platform's binary is run behind a real Zentinel
by [`scripts/smoke-test.sh`](scripts/smoke-test.sh) before anything is
published, and CI runs the same smoke job on every push. It runs the agent once with no
configuration (nothing is injected), then with
[`scripts/smoke/chaos.yaml`](scripts/smoke/chaos.yaml) over the Unix socket and
over gRPC, fail-closed: an `error` fault answers `503` without reaching the
upstream (also with a query string), a `timeout` fault `504`, a `latency`
fault forwards, an excluded path is forwarded although an experiment targets
it, and with the agent stopped requests are refused. Locally:

```bash
AGENT_SMOKE=../.github/agent-smoke/smoke.py \
  scripts/smoke-test.sh target/release/zentinel-chaos-agent ./zentinel
```

## Development

```bash
git clone https://github.com/zentinelproxy/zentinel-agent-rust-sdk ../zentinel-agent-rust-sdk
cargo build
cargo test --workspace
cargo clippy --workspace --all-targets -- -D warnings
cargo fmt --all --check
```

Needs `protoc` (CI installs `protobuf-compiler`) and stable Rust (CI uses
`dtolnay/rust-toolchain@stable`).

## Related

- [Registry page](https://registry.zentinelproxy.io/chaos/)
- [Agent configuration](https://docs.zentinelproxy.io/configuration/agents/)
- [Agent protocol v2](https://docs.zentinelproxy.io/agents/v2/)
- [Zentinel](https://github.com/zentinelproxy/zentinel)

## License

MIT, see [`LICENSE`](LICENSE).

---

<p align="center">
  <sub>Part of <a href="https://zentinelproxy.io">Zentinel</a>, the security-first reverse proxy. The shisa guards the gate.</sub>
</p>

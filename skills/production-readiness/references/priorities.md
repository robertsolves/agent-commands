# P1–P4: beyond the launch minimum

Loaded by the `production-readiness` skill when a change touches one of these areas. For
each item that applies, record the decision, the owner and the evidence; mark the rest
`N/A: <reason>`. Measure first; choose the simplest mechanism that meets the need.

## P1 — close before broad launch, or record an accepted exception

These stop ordinary failures from becoming user-facing incidents or unrecoverable data loss.

- **Timeouts.** Does every network and dependency call have a suitable deadline?
- **Retries and backoff.** Are transient failures retried with limits, jitter, and respect for retry hints?
- **Idempotency.** Can a client safely retry a request that may have completed despite a lost response?
- **Rate limits and quotas.** Can one user or client exhaust capacity or run up costs? Do limits hold across instances?
- **Caching and invalidation.** What is cached, for how long, and how do writes or permission changes invalidate it?
- **Indexes and queries.** Do important queries use indexes and stay fast at expected data volume?
- **N+1 queries and connection pooling.** Are collection reads bounded, and do pool limits fit the database and instance limits?
- **Dependency resilience.** Can an unhealthy dependency consume all request capacity? Are circuit breakers or graceful degradation needed?
- **Scheduled jobs and webhooks.** Are jobs safe to overlap and retry? Are webhook signatures verified, duplicates handled, failures visible?
- **Monitoring and alerts.** Can operators see user impact, correlate failures across services, and act on alerts?
- **SLIs, SLOs and error budgets.** Are user-facing reliability targets defined, with alerts tied to real degradation?
- **Disaster recovery.** Are recovery-time (RTO) and recovery-point (RPO) targets explicit, and the failover procedure understood?
- **Cost controls.** Are budgets, usage alerts, autoscaling ceilings and expensive failure modes understood?
- **Supply chain.** Are dependencies, build actions and runtime images reviewed, pinned to exact versions, and updated?

## P2 — add as traffic, team size or operational needs grow

- **Latency and throughput.** What request rates and response times are expected, and how do they change under load?
- **Tail latency (P95/P99).** Are slow outliers visible, and what causes them?
- **Autoscaling.** What triggers scale-out, how fast, and what are the cost and maximum-capacity limits?
- **Cold starts and serverless limits.** Are startup time, request duration, memory and concurrency limits understood?
- **Backpressure.** What happens when work arrives faster than it can be processed?
- **Graceful shutdown.** Are in-flight jobs, sockets, subscriptions, files and connections handled on shutdown or cancellation?
- **Memory and thread safety.** Does memory stay bounded, and can concurrent work safely touch shared mutable state?
- **Feature flags.** Are flags access-controlled, observable, safe by default, and removed after rollout?
- **Rollout strategy.** Is canary, blue-green or rolling proportionate to the impact of a bad release, with clear rollback triggers?
- **API versioning.** Can clients upgrade independently, and do versions communicate compatibility where consumers rely on them?
- **Incidents and postmortems.** Can the team coordinate an incident and turn failures into systemic fixes?
- **Build caching and dependency resolution.** Are caches reproducible and invalidated correctly; is resolution stable?
- **Infrastructure as code.** Is infrastructure reviewed as code, its state protected, and drift visible?
- **Containers.** If used, are images small, patched, pinned, non-root and free of build-time secrets?
- **Failure rehearsal.** Are likely dependency, instance and network failures rehearsed safely?

## P3 — only when evidence or requirements justify it

These add operational cost and failure modes. Record the need before adopting one.

- **CDN and edge caching.** Enough public traffic to benefit, and private or stale data kept out of shared caches?
- **Load balancers and reverse proxies.** How is traffic distributed; are forwarded headers and client IPs trusted safely?
- **API gateway.** Is a separate gateway needed, or can the service do routing, auth and quotas clearly itself?
- **Queues, pub/sub, events.** Is asynchronous decoupling needed; are event versions, delivery guarantees and duplicates defined?
- **Dead-letter queues.** Where do repeatedly failing messages go, and who inspects or replays them?
- **Sagas and distributed transactions.** How are multi-service operations completed, compensated or repaired after partial failure?
- **WebSockets, long polling, SSE.** Is the connection model right; what happens on reconnect, missed events and proxy timeouts?
- **Read replicas.** Is replica lag acceptable, and which copy is authoritative?
- **Partitioning and sharding.** Is there measured evidence one database cannot cope?
- **Multi-region failover.** Do recovery objectives require it, and have consistency, DNS and failover been tested?
- **WAF and DDoS protection.** Is the exposure and threat profile high enough to need it?
- **Horizontal vs vertical scaling.** Which direction fits the measured bottleneck?

## P4 — advanced distributed-systems concerns; usually N/A for a small service

- **Kubernetes and Helm.** Is orchestration needed beyond the managed runtime?
- **Service discovery.** How do separately deployed services find each other; how are stale addresses handled?
- **Leader election and distributed locks.** Can several workers claim singleton work; are leases and lock loss handled?
- **CAP trade-offs and partitions.** Which operations stay available during a partition, and what disagreement is acceptable?
- **Optimistic vs pessimistic locking.** Which conflict strategy fits the operation and its contention?
- **Clock skew.** Do expiry, ordering, signatures or schedules assume synchronised clocks?
- **Protocols (DNS, TCP/UDP, HTTP/2–3, gRPC).** Are protocol assumptions, connection reuse and deadlines relevant here?
- **Distributed tracing.** Enough service boundaries to justify it beyond structured logs and request ids?
- **Active-active and chaos engineering.** Is the availability target high enough to justify them?

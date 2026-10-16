# CLAUDE.md

The logistics domain's intake flow (ADR 0015, 0016). Owned by the logistics-team. Ground rules live in the
[ai-intelligence-domain](https://github.com/azure-intelligence-domain/ai-intelligence-domain) repository.

- One flow per receiving domain: it takes in what the logistics domain needs and calls only the
  logistics domain's own System APIs, through the gateway. It publishes nothing of its own.
- The flow is `workflow.json`. Every Http action: the gateway URL, the runtime identity, a
  Correlation-Id, and no retry (Event Grid retries the delivery). The tests check this.
- What it receives is `asyncapi.yaml` (consumer contract); the platform routes it
  (`integration-platform/routing/consumers.yaml`). A new event type: both, in the same change.

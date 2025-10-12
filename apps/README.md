# Backend services

This directory will contain the NestJS microservices described in `docs/TECH_SPEC.md`.

- `svc-vendors` — vendor availability CRUD with RabbitMQ publication.
- `svc-enquiries` — enquiries pipeline with ROI tracking.
- `svc-search` — OpenSearch-backed availability search.

Each service should expose `GET /health` and honour the shared infrastructure constraints from the spec.

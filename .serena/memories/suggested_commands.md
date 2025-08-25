Commands for Development Tasks:

- **Testing**: `bundle exec rake test` (uses Minitest)
- **Linting/Formatting (JS/TS)**: `npm run lint`, `npm run format`, `npm run style:check`, `npm run format:check` (uses Biome)
- **Running the application**: `bin/dev` (uses Foreman with Procfile.dev)
- **Database Setup**: `bin/setup`
- **Docker**: `docker compose up -d` (to start services), `docker ps` (to check status), `docker logs <container_name>` (to view logs)
- **Database Access**: `docker exec maybe-db-1 psql -U maybe_user -d maybe_production`

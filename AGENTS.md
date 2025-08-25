# AGENTS.md

This file outlines guidelines for agents operating within this repository.

## Build, Lint, and Test Commands

- **Build**: `bundle exec rake build` (or similar, check project specifics)
- **Lint**: `bundle exec rubocop` (for Ruby), `biome lint` (for JS/TS)
- **Test**: `bundle exec rspec` (for Ruby), `biome check` (for JS/TS)
- **Single Test**: `bundle exec rspec path/to/test_file.rb:line_number` (for Ruby)

## Code Style Guidelines

- **Formatting**: Use Biome for JS/TS. Follow Ruby conventions for Ruby code.
- **Imports**: Maintain consistent import order and style.
- **Naming**: Use snake_case for Ruby, camelCase for JS/TS variables and functions.
- **Error Handling**: Implement consistent error handling patterns, especially in controllers and models.
- **Types**: Use Ruby's dynamic typing; TypeScript for JS/TS projects.
- **Cursor Rules**: Adhere to formatting and error handling patterns in `.cursor/rules/`.
- **Copilot Instructions**: Follow guidelines in `.github/copilot-instructions.md` if present.

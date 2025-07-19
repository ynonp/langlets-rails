# Working With Langlets

Langlets is an online language learning platform.

Before working on a new feature make sure to:
1. Read `architecture.md`.
2. Read `db/schema.rb` to understand the database schema.
3. Create a detailed plan and follow it step by step.

The system is in production. Use Rails and React best practices when implementing new features and watch for breaking changes.

We use `architecture.md` to reflect the state of the platform and for future coding agents so after every feature also update this file.

## DB Setup
Your environment has a full Rails environment installed with a postgres database.
There are 2 databases described in `config/database.yml`, one for development and the other for tests.
Verify you can connect to the DB for development with:
`./bin/rails db:version`

Verify you can connect to the test DB to run tests with:
`RAILS_ENV=test ./bin/rails db:version`

## App Setup
Your environment has a full Rails environment installed.
Start the development server with: `./bin/dev`.
After the app starts you can login to the admin page with development credentials:
   - Username: ynon@hey.com
   - Password: 10203040

# Coding Context

## Stimulus Controllers
1. Prefer `data-action` when writing stimulus controllers instead of binding event handlers from the controller.
2. All stimulus controllers are listed in file: `app/javascript/controllers/index.js`.
   When you add new controllers it's mandatory to update the file by running: `./bin/rails stimulus:manifest:update`

## Time and date
1. Use Time.zone.now instead of Time.current


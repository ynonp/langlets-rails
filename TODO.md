# TODO

## Environment Setup

- [ ] Set PostgreSQL credentials in environment variables:
  ```
  POSTGRES_USERNAME=postgres
  POSTGRES_PASSWORD=postgres
  ```

- [ ] Or update `config/database.yml` to use env variables:
  ```yaml
  username: <%= ENV.fetch("POSTGRES_USERNAME", "postgres") %>
  password: <%= ENV.fetch("POSTGRES_PASSWORD", "postgres") %>
  ```

## Hotwire Native Testing

- [ ] Test path configuration endpoint: `curl http://localhost:3000/hotwire_native/path-configuration`
- [ ] Run Rails tests: `bin/rails test test/controllers/hotwire_native/`
- [ ] Open Android project in Android Studio and build
- [ ] Test Android app on emulator

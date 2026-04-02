FROM oven/bun:1.3 AS build
RUN apt-get update && apt-get install -y --no-install-recommends git python3 make g++ && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY . .
RUN bun install
RUN MODELS_DEV_API_JSON=test/tool/fixtures/models-api.json bun run --cwd packages/opencode build --single --skip-embed-web-ui

FROM debian:bookworm-slim
COPY --from=build /app/packages/opencode/dist/opencode-linux-x64/bin/rolandcode /usr/local/bin/rolandcode
ENTRYPOINT ["rolandcode"]

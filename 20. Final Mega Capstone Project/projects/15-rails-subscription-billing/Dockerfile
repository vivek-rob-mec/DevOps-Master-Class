FROM ruby:3.4-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends build-essential libpq-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY app/Gemfile ./
RUN bundle config set without development:test && bundle install --jobs 4
COPY app/ ./
RUN bundle exec ruby test/subscription_rules_test.rb && SECRET_KEY_BASE_DUMMY=1 DATABASE_URL=postgresql://app:placeholder@localhost/app bundle exec rails assets:precompile
FROM ruby:3.4-slim
RUN apt-get update && apt-get install -y --no-install-recommends libpq5 && rm -rf /var/lib/apt/lists/* && groupadd -g 10001 app && useradd -u 10001 -g app --no-create-home app
ENV RAILS_ENV=production RAILS_LOG_TO_STDOUT=true PORT=3000
WORKDIR /app
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build --chown=app:app /app ./
USER 10001:10001
EXPOSE 3000
CMD ["sh","-c","bundle exec rails db:prepare && bundle exec puma -C config/puma.rb"]

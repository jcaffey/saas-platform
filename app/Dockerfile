FROM elixir:1.20.4

WORKDIR /app

COPY mix.exs mix.lock ./

RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get

COPY . .

RUN mix compile

CMD ["mix", "run", "--no-halt"]

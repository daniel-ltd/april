FROM elixir:1.12.2

RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix archive.install hex phx_new --force

WORKDIR /webapp

CMD mix deps.get && mix phx.server

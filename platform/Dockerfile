FROM elixir:1.16-alpine AS builder

RUN apk add --no-cache \
    git \
    make \
    g++ \
    erlang-dev \
    argon2-libs

ARG ENV
ENV MIX_ENV=${ENV:-prod}
WORKDIR /src

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get --only ${MIX_ENV}
RUN mkdir config
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

RUN mix assets.setup

COPY priv priv
COPY lib lib
RUN mix compile

COPY assets assets
RUN mix assets.deploy

COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# Runtime Alpine MUST match the builder image's Alpine major/minor
# (elixir:1.16-alpine is currently Alpine 3.24): the OTP crypto NIF links
# against the builder's OpenSSL and fails to load on older libcrypto.
FROM alpine:3.24 AS runner

RUN apk add --no-cache \
    libstdc++ \
    ncurses \
    openssl \
    ca-certificates

WORKDIR /app
RUN chown nobody /app

ARG ENV
ENV MIX_ENV=${ENV:-prod}

COPY --from=builder --chown=nobody:root /src/_build/${MIX_ENV}/rel/platform ./

USER nobody
EXPOSE 4000
CMD ["/app/bin/server"]

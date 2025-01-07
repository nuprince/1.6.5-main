#!/usr/bin/env bash
set -o errexit

# Initial setup
mix deps.get --only prod
MIX_ENV=prod mix compile

# Compile assets
MIX_ENV=prod mix assets.build
MIX_ENV=prod mix assets.deploy

# Ensure release directory exists
mkdir -p _build/prod/rel/spades/bin/

# Build the release
MIX_ENV=prod mix phx.gen.release
MIX_ENV=prod mix release --overwrite

# Run migrations through Release
_build/prod/rel/spades/bin/spades eval "Spades.Release.migrate"

# Debug: List release directory
ls -la _build/prod/rel/spades/bin/

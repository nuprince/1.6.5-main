#!/usr/bin/env bash
# exit on error
set -o errexit

# Database setup and migrations
MIX_ENV=prod mix ecto.migrate

# Install Node dependencies in assets directory
cd assets && npm install && cd ..

# Initial setup
mix deps.get --only prod
MIX_ENV=prod mix compile

# Compile assets  
MIX_ENV=prod mix assets.build
MIX_ENV=prod mix assets.deploy

# Ensure release directory exists
mkdir -p _build/prod/rel/spades/bin/

# Create server script and build release
MIX_ENV=prod mix phx.gen.release
MIX_ENV=prod mix release --overwrite

# Debug: List release directory
ls -la _build/prod/rel/spades/bin/

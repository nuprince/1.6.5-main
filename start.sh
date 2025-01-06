#!/bin/bash
pwd
ls -la _build/prod/rel/spades/bin/

_build/prod/rel/spades/bin/spades eval "Spades.Release.migrate"
_build/prod/rel/spades/bin/spades start

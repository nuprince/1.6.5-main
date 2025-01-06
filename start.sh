#!/bin/bash

pwd
ls -la

/opt/render/project/rel/spades/bin/spades eval "Spades.Release.migrate"
/opt/render/project/rel/spades/bin/spades start

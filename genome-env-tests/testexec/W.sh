#!/bin/bash

type -p genome-env-next

if test -z "$WORKSPACE"
then
    echo "WORKSPACE is not set" >&2
    exit 1
fi

for M in sqitch/genome ur workflow ; do
    submodule_is_clean $M
done
submodule_is_not_initialized workflow
module_loaded_from_submodule UR
module_not_loaded_from_submodule Workflow
apipe_test_db_is_not_used

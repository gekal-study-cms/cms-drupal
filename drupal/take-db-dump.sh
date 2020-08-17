#!/bin/bash

DATABASE=drupal

USER=root
PASSWORD=password

EXCLUDED_TABLES=(
    cache_bootstrap
    cache_config
    cache_container
    cache_data
    cache_default
    cache_discovery
    cache_dynamic_page_cache
    cache_entity
    cache_menu
    cache_page
    cache_render
)

IGNORED_TABLES_STRING=''
for TABLE in "${EXCLUDED_TABLES[@]}"
do :
   IGNORED_TABLES_STRING+=" --ignore-table=${DATABASE}.${TABLE}"
done

current_dir=$(dirname "$0")

echo "structure"
docker exec -it drupal-db sh -c "mysqldump --user=${USER} --password=${PASSWORD} --single-transaction --no-data --routines ${DATABASE} 2> /dev/null" > ${current_dir}/db/initdb/01.drupal.schema.sql

echo "content"
docker exec -it drupal-db sh -c "mysqldump --user=${USER} --password=${PASSWORD} ${DATABASE} --no-create-info --skip-triggers ${IGNORED_TABLES_STRING} 2> /dev/null" > ${current_dir}/db/initdb/02.drupal.data.sql

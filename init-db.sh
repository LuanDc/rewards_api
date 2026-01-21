#!/bin/bash
set -e

# Create additional databases needed by the application
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE campaigns_api_dev;
    CREATE DATABASE campaigns_api_test;
    CREATE DATABASE keycloak_db;
EOSQL

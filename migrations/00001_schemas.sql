-- +goose Up
-- create schemas for different platforms
CREATE SCHEMA IF NOT EXISTS core; -- core schema for (accounts, locations, leads, etc.)
CREATE SCHEMA IF NOT EXISTS platform; -- platform schema for superadmins etc.
CREATE SCHEMA IF NOT EXISTS audit; -- audit schema for logging and auditing
CREATE SCHEMA IF NOT EXISTS lookup; -- lookup schema for catalogue etc.


-- +goose Down
DROP SCHEMA IF EXISTS core;
DROP SCHEMA IF EXISTS platform;
DROP SCHEMA IF EXISTS audit;
DROP SCHEMA IF EXISTS lookup;
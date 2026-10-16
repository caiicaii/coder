-- Seeds a dev database with many templates, users, and workspaces whose
-- timestamps are spread over a long period, to exercise list sorting.
--
-- Rows are cloned from existing records so every NOT NULL column and
-- foreign key stays valid. Prerequisites (created by ./scripts/develop.sh
-- plus one `coder templates push` and one `coder create`):
--   * a user named "member" (seed users copy it, so they share its password)
--   * a template named :'src_template' with at least one workspace built from it
--
-- Usage:
--   psql "$URL" -v templates=300 -v workspaces=3000 -v users=50 \
--     -v days=730 -v src_template=alpha -f scripts/seed-sort-demo.sql
--
-- Safe to re-run: seeded rows use the "seed-" prefix and are deleted first.

\set ON_ERROR_STOP on
\if :{?templates} \else \set templates 300 \endif
\if :{?workspaces} \else \set workspaces 3000 \endif
\if :{?users} \else \set users 50 \endif
\if :{?days} \else \set days 730 \endif
\if :{?src_template} \else \set src_template alpha \endif

-- Column lists without generated columns, which cannot be inserted.
SELECT
	max(c) FILTER (WHERE t = 'users') AS users_cols,
	max(c) FILTER (WHERE t = 'organization_members') AS members_cols,
	max(c) FILTER (WHERE t = 'templates') AS templates_cols,
	max(c) FILTER (WHERE t = 'provisioner_jobs') AS jobs_cols,
	max(c) FILTER (WHERE t = 'workspaces') AS workspaces_cols,
	max(c) FILTER (WHERE t = 'workspace_builds') AS builds_cols
FROM (
	SELECT attrelid::regclass::text AS t, string_agg(quote_ident(attname), ', ' ORDER BY attnum) AS c
	FROM pg_attribute
	WHERE attrelid IN ('users'::regclass, 'organization_members'::regclass, 'templates'::regclass,
		'provisioner_jobs'::regclass, 'workspaces'::regclass, 'workspace_builds'::regclass)
		AND attnum > 0 AND NOT attisdropped AND attgenerated = ''
	GROUP BY attrelid
) cols
\gset

BEGIN;

-- Remove a previous seed run.
CREATE TEMP TABLE old_ws ON COMMIT DROP AS
	SELECT id FROM workspaces WHERE name LIKE 'seed-%';
CREATE TEMP TABLE old_jobs ON COMMIT DROP AS
	SELECT job_id AS id FROM workspace_builds WHERE workspace_id IN (SELECT id FROM old_ws);
DELETE FROM workspace_builds WHERE workspace_id IN (SELECT id FROM old_ws);
DELETE FROM provisioner_jobs WHERE id IN (SELECT id FROM old_jobs);
DELETE FROM workspaces WHERE id IN (SELECT id FROM old_ws);
DELETE FROM templates WHERE name LIKE 'seed-%';
DELETE FROM organization_members
	WHERE user_id IN (SELECT id FROM users WHERE username LIKE 'seed-%');
DELETE FROM users WHERE username LIKE 'seed-%';

-- Users.
CREATE TEMP TABLE seed_users ON COMMIT DROP AS
	SELECT gen_random_uuid() AS id, i FROM generate_series(1, :users) i;

INSERT INTO users (:users_cols)
SELECT :users_cols FROM (
SELECT (jsonb_populate_record(u, jsonb_build_object(
	'id', s.id,
	'username', format('seed-user-%s', s.i),
	'email', format('seed-user-%s@coder.com', s.i),
	'name', format('Seed User %s', s.i),
	'status', 'active'
))).*
FROM users u, seed_users s
WHERE u.username = 'member'
) r;

INSERT INTO organization_members (:members_cols)
SELECT :members_cols FROM (
SELECT (jsonb_populate_record(m, jsonb_build_object('user_id', s.id))).*
FROM organization_members m
JOIN users u ON u.id = m.user_id AND u.username = 'member',
	seed_users s
) r;

-- Templates, all sharing the source template's active version.
CREATE TEMP TABLE seed_templates ON COMMIT DROP AS
	SELECT
		gen_random_uuid() AS id,
		i,
		now() - random() * make_interval(days => :days) AS updated_at
	FROM generate_series(1, :templates) i;

INSERT INTO templates (:templates_cols)
SELECT :templates_cols FROM (
SELECT (jsonb_populate_record(t, jsonb_build_object(
	'id', s.id,
	'name', format('seed-tpl-%s', lpad(s.i::text, 4, '0')),
	'display_name', format('Seed Template %s', s.i),
	'description', '',
	'created_at', s.updated_at - random() * interval '180 days',
	'updated_at', s.updated_at
))).*
FROM templates t, seed_templates s
WHERE t.name = :'src_template' AND NOT t.deleted
) r;

-- Workspaces. About 40% belong to the first owner so the default
-- "owner:me" view for the admin also has a large list.
CREATE TEMP TABLE seed_ws ON COMMIT DROP AS
	SELECT
		gen_random_uuid() AS id,
		gen_random_uuid() AS build_id,
		gen_random_uuid() AS job_id,
		i,
		now() - random() * make_interval(days => :days) AS last_used_at,
		CASE WHEN random() < 0.4 THEN 0 ELSE 1 + floor(random() * :users)::int END AS owner_n,
		1 + floor(random() * :templates)::int AS template_n,
		CASE WHEN random() < 0.6 THEN 'stop' ELSE 'start' END AS transition
	FROM generate_series(1, :workspaces) i;

CREATE TEMP TABLE src ON COMMIT DROP AS
	SELECT w.id AS workspace_id, b.id AS build_id, b.job_id
	FROM workspaces w
	JOIN templates t ON t.id = w.template_id AND t.name = :'src_template'
	JOIN LATERAL (
		SELECT * FROM workspace_builds wb
		WHERE wb.workspace_id = w.id
		ORDER BY build_number DESC LIMIT 1
	) b ON true
	WHERE NOT w.deleted
	LIMIT 1;

INSERT INTO provisioner_jobs (:jobs_cols)
SELECT :jobs_cols FROM (
SELECT (jsonb_populate_record(j, jsonb_build_object(
	'id', s.job_id,
	'created_at', s.last_used_at - interval '1 minute',
	'updated_at', s.last_used_at,
	'started_at', s.last_used_at - interval '50 seconds',
	'completed_at', s.last_used_at - interval '40 seconds',
	'input', jsonb_build_object('workspace_build_id', s.build_id)
))).*
FROM provisioner_jobs j, seed_ws s
WHERE j.id = (SELECT job_id FROM src)
) r;

INSERT INTO workspaces (:workspaces_cols)
SELECT :workspaces_cols FROM (
SELECT (jsonb_populate_record(w, jsonb_build_object(
	'id', s.id,
	'name', format('seed-ws-%s', lpad(s.i::text, 5, '0')),
	'owner_id', COALESCE(su.id, w.owner_id),
	'template_id', st.id,
	'created_at', s.last_used_at - random() * interval '90 days',
	'updated_at', s.last_used_at,
	'last_used_at', s.last_used_at,
	'favorite', false
))).*
FROM workspaces w, seed_ws s
LEFT JOIN seed_users su ON su.i = s.owner_n
JOIN seed_templates st ON st.i = s.template_n
WHERE w.id = (SELECT workspace_id FROM src)
) r;

INSERT INTO workspace_builds (:builds_cols)
SELECT :builds_cols FROM (
SELECT (jsonb_populate_record(b, jsonb_build_object(
	'id', s.build_id,
	'workspace_id', s.id,
	'job_id', s.job_id,
	'build_number', 1,
	'transition', s.transition,
	'created_at', s.last_used_at - interval '1 minute',
	'updated_at', s.last_used_at
))).*
FROM workspace_builds b, seed_ws s
WHERE b.id = (SELECT build_id FROM src)
) r;

COMMIT;

SELECT
	(SELECT count(*) FROM users WHERE username LIKE 'seed-%') AS users,
	(SELECT count(*) FROM templates WHERE name LIKE 'seed-%') AS templates,
	(SELECT count(*) FROM workspaces WHERE name LIKE 'seed-%') AS workspaces;

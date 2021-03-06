-- Function: geonode_authorize_layer(character varying, character varying)

-- DROP FUNCTION geonode_authorize_layer(character varying, character varying);

CREATE OR REPLACE FUNCTION geonode_authorize_layer(
    user_name character varying,
    type_name character varying)
  RETURNS character varying AS
$BODY$

DECLARE
view_perm integer;
change_perm integer;
manage_perm integer;
download_perm integer;
edit_perm integer;
roles varchar[] = '{anonymous,NULL}';
ct integer;
layer_ct integer;
user RECORD;
layer RECORD;
group_ids integer[];
BEGIN
-- get the layer and user, take quick action if we can
SELECT INTO layer "base_resourcebase"."id", "base_resourcebase"."owner_id"
FROM "base_resourcebase", "layers_layer"
WHERE "base_resourcebase"."id" = "layers_layer"."resourcebase_ptr_id" AND "layers_layer"."typename" = type_name;
if (not FOUND) then
	-- no layer
	return 'nl';
end if;
if (user_name IS NULL or user_name = '') then
        user_name = 'AnonymousUser';
end if;
if (user_name IS NOT NULL) then
	SELECT INTO user * FROM "people_profile" WHERE "people_profile"."username" = user_name;
	if (not FOUND) then
		-- no user
		return 'nu';
	end if;
	if ("user".id = "layer".owner_id) then
		-- layer owner
		return 'lo-rw';
	end if;
	if ("user".is_superuser) then
		-- super user
		return 'su-rw';
	end if;
	roles[2] = 'authenticated';
end if;
-- resolve permission and content_type ids
SELECT INTO view_perm "auth_permission"."id"
  FROM "auth_permission" INNER JOIN "django_content_type"
  ON ("auth_permission"."content_type_id" = "django_content_type"."id")
  WHERE ("auth_permission"."codename" = E'view_resourcebase'
  AND "django_content_type"."app_label" = E'base' );
SELECT INTO change_perm "auth_permission"."id"
	FROM "auth_permission" INNER JOIN "django_content_type"
	ON ("auth_permission"."content_type_id" = "django_content_type"."id")
	WHERE ("auth_permission"."codename" = E'change_resourcebase'
	AND "django_content_type"."app_label" = E'base' );
SELECT INTO manage_perm "auth_permission"."id"
	FROM "auth_permission" INNER JOIN "django_content_type"
	ON ("auth_permission"."content_type_id" = "django_content_type"."id")
	WHERE ("auth_permission"."codename" = E'change_resourcebase_permissions'
	AND "django_content_type"."app_label" = E'base' );
  SELECT INTO download_perm "auth_permission"."id"
	FROM "auth_permission" INNER JOIN "django_content_type"
	ON ("auth_permission"."content_type_id" = "django_content_type"."id")
	WHERE ("auth_permission"."codename" = E'download_resourcebase'
	AND "django_content_type"."app_label" = E'base' );
SELECT INTO edit_perm "auth_permission"."id"
	FROM "auth_permission" INNER JOIN "django_content_type"
	ON ("auth_permission"."content_type_id" = "django_content_type"."id")
	WHERE ("auth_permission"."codename" = E'change_layer_data'
	AND "django_content_type"."app_label" = E'layers' );
SELECT INTO ct "django_content_type"."id"
	FROM "django_content_type"
	WHERE ("django_content_type"."model" = E'resourcebase'
	AND "django_content_type"."app_label" = E'base' );
SELECT INTO layer_ct "django_content_type"."id"
	FROM "django_content_type"
	WHERE ("django_content_type"."model" = E'layer'
	AND "django_content_type"."app_label" = E'layers' );
SELECT INTO group_ids array_agg("people_profile_groups"."group_id")
  FROM "people_profile_groups"
  WHERE "people_profile_groups"."profile_id" = "user".id;
RAISE NOTICE 'View Perm: %', view_perm;
RAISE NOTICE 'Change Perm: %', change_perm;
RAISE NOTICE 'Edit Data Perm: %', edit_perm;
RAISE NOTICE 'Manage Layer Perm: %', manage_perm;
RAISE NOTICE 'Can Download Perm: %', download_perm;
RAISE NOTICE 'Content Type: %', ct;
RAISE NOTICE 'User ID: %', "user".id;
RAISE NOTICE 'Layer ID: %', "layer".id;
RAISE NOTICE 'Group IDs: %', group_ids;
if (user_name IS NOT NULL) then
	-- user role, read-write
	PERFORM "guardian_userobjectpermission"."object_pk"
		FROM "guardian_userobjectpermission"
		INNER JOIN "auth_permission"
		ON ("guardian_userobjectpermission"."permission_id" = "auth_permission"."id")
		WHERE (("auth_permission"."id" = change_perm or "auth_permission"."id" = manage_perm)
		AND "guardian_userobjectpermission"."content_type_id" = ct
		AND ("guardian_userobjectpermission"."user_id" = "user".id or "guardian_userobjectpermission"."user_id" = -1)
		AND "guardian_userobjectpermission"."object_pk"::integer = "layer".id
		) OR
		(("auth_permission"."id" = change_perm or "auth_permission"."id" = edit_perm)
		AND "guardian_userobjectpermission"."content_type_id" = layer_ct
		AND ("guardian_userobjectpermission"."user_id" = "user".id or "guardian_userobjectpermission"."user_id" = -1)
		AND "guardian_userobjectpermission"."object_pk"::integer = "layer".id
		);
	if (FOUND) then return 'ur-rw'; end if;
  -- user role, user has read-write permissions via group membership
  PERFORM "guardian_groupobjectpermission"."object_pk"
		FROM "guardian_groupobjectpermission"
		INNER JOIN "auth_permission"
		ON ("guardian_groupobjectpermission"."permission_id" = "auth_permission"."id")
		WHERE (("auth_permission"."id" = change_perm or "auth_permission"."id" = manage_perm)
		AND ("guardian_groupobjectpermission"."content_type_id" = ct)
		AND "guardian_groupobjectpermission"."group_id" = ANY (group_ids)
		AND "guardian_groupobjectpermission"."object_pk"::integer = "layer".id
		OR
		(("auth_permission"."id" = edit_perm)
		AND ("guardian_groupobjectpermission"."content_type_id" = layer_ct)
		AND "guardian_groupobjectpermission"."group_id" = ANY (group_ids)
		AND "guardian_groupobjectpermission"."object_pk"::integer = "layer".id));
	if (FOUND) then return 'group-rw'; end if;
	PERFORM "guardian_userobjectpermission"."object_pk"
		FROM "guardian_userobjectpermission"
		INNER JOIN "auth_permission"
		ON ("guardian_userobjectpermission"."permission_id" = "auth_permission"."id")
		WHERE (("auth_permission"."id" = view_perm or "auth_permission"."id" = download_perm)
		AND "guardian_userobjectpermission"."content_type_id" = ct
		AND ("guardian_userobjectpermission"."user_id" = "user".id or "guardian_userobjectpermission"."user_id" = -1)
		AND "guardian_userobjectpermission"."object_pk"::integer = "layer".id
		);
	if (FOUND) then return 'ur-ro'; end if;
  -- user role, user has read-write permissions via group membership
  PERFORM "guardian_groupobjectpermission"."object_pk"
		FROM "guardian_groupobjectpermission"
		INNER JOIN "auth_permission"
		ON ("guardian_groupobjectpermission"."permission_id" = "auth_permission"."id")
		WHERE (("auth_permission"."id" = view_perm or "auth_permission"."id" = download_perm)
		AND "guardian_groupobjectpermission"."content_type_id" = ct
		AND "guardian_groupobjectpermission"."group_id" = ANY (group_ids)
		AND "guardian_groupobjectpermission"."object_pk"::integer = "layer".id
		);
	if (FOUND) then return 'group-ro'; end if;
end if;
-- uh oh, nothing found
return 'nf';

END
$BODY$

  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION geonode_authorize_layer(character varying, character varying)
  OWNER TO mapstory;

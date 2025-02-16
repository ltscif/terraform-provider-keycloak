provider "keycloak" {
	client_id     = "terraform"
	client_secret = "884e0f95-0f42-4a63-9b1f-94274655669e"
	url           = "http://localhost:8080"
}

resource "keycloak_realm" "test" {
	realm        = "test"
	enabled      = true
	display_name = "foo"

	smtp_server {
		host                  = "mysmtphost.com"
		port                  = 25
		from_display_name     = "Tom"
		from                  = "tom@myhost.com"
		reply_to_display_name = "Tom"
		reply_to              = "tom@myhost.com"
		ssl                   = true
		starttls              = true
		envelope_from         = "nottom@myhost.com"

		auth {
			username = "tom"
			password = "tom"
		}
	}

  	account_theme = "base"

	access_code_lifespan = "30m"

	internationalization {
		supported_locales = [
			"en",
			"de",
			"es"
		]
		default_locale    = "en"
	}

	security_defenses {
		headers {
			x_frame_options = "DENY"
			content_security_policy = "frame-src 'self'; frame-ancestors 'self'; object-src 'none';"
			content_security_policy_report_only = ""
			x_content_type_options = "nosniff"
			x_robots_tag = "none"
			x_xss_protection = "1; mode=block"
			strict_transport_security = "max-age=31536000; includeSubDomains"
		}
	}
}

resource "keycloak_required_action" "custom-terms-and-conditions" {
	realm_id		= "${keycloak_realm.test.realm}"
	alias			= "terms_and_conditions"
	default_action 	= true
	enabled			= true
	name			= "Custom Terms and Conditions"
}

resource "keycloak_required_action" "custom-configured_totp" {
	realm_id		= "${keycloak_realm.test.realm}"
	alias			= "CONFIGURE_TOTP"
	default_action 	= true
	enabled			= true
	name			= "Custom configure totp"
	priority		= "${keycloak_required_action.custom-terms-and-conditions.priority+15}"
}

resource "keycloak_group" "foo" {
	realm_id = "${keycloak_realm.test.id}"
	name     = "foo"
}

resource "keycloak_group" "nested_foo" {
	realm_id  = "${keycloak_realm.test.id}"
	parent_id = "${keycloak_group.foo.id}"
	name      = "nested-foo"
}

resource "keycloak_group" "bar" {
	realm_id = "${keycloak_realm.test.id}"
	name     = "bar"
}

resource "keycloak_user" "user" {
	realm_id = "${keycloak_realm.test.id}"
	username = "test-user"

	email      = "test-user@fakedomain.com"
	first_name = "Testy"
	last_name  = "Tester"
}

resource "keycloak_user" "another_user" {
	realm_id = "${keycloak_realm.test.id}"
	username = "another-test-user"

	email      = "another-test-user@fakedomain.com"
	first_name = "Testy"
	last_name  = "Tester"
}

resource "keycloak_user" "user_with_password" {
	realm_id = "${keycloak_realm.test.id}"
	username = "user-with-password"

	email      = "user-with-password@fakedomain.com"
	first_name = "Testy"
	last_name  = "Tester"

	initial_password {
		value     = "my password"
		temporary = false
	}
}

resource "keycloak_group_memberships" "foo_members" {
	realm_id = "${keycloak_realm.test.id}"
	group_id = "${keycloak_group.foo.id}"

	members = [
		"${keycloak_user.user.username}",
		"${keycloak_user.another_user.username}",
	]
}

resource "keycloak_openid_client" "test_client" {
	client_id   = "test-openid-client"
	name        = "test-openid-client"
	realm_id    = "${keycloak_realm.test.id}"
	description = "a test openid client"

	standard_flow_enabled = true

	access_type = "CONFIDENTIAL"

	valid_redirect_uris = [
		"http://localhost:5555/callback",
	]

	client_secret = "secret"
}

resource "keycloak_openid_client_scope" "test_default_client_scope" {
	name     = "test-default-client-scope"
	realm_id = "${keycloak_realm.test.id}"

	description         = "test"
	consent_screen_text = "hello"
}

resource "keycloak_openid_client_scope" "test_optional_client_scope" {
	name     = "test-optional-client-scope"
	realm_id = "${keycloak_realm.test.id}"

	description         = "test"
	consent_screen_text = "hello"
}

resource "keycloak_openid_client_default_scopes" "default_client_scopes" {
	realm_id  = "${keycloak_realm.test.id}"
	client_id = "${keycloak_openid_client.test_client.id}"

	default_scopes = [
		"profile",
		"email",
		"roles",
		"web-origins",
		"${keycloak_openid_client_scope.test_default_client_scope.name}",
	]
}

resource "keycloak_openid_client_optional_scopes" "optional_client_scopes" {
	realm_id  = "${keycloak_realm.test.id}"
	client_id = "${keycloak_openid_client.test_client.id}"

	optional_scopes = [
		"address",
		"phone",
		"offline_access",
		"${keycloak_openid_client_scope.test_optional_client_scope.name}",
	]
}

resource "keycloak_ldap_user_federation" "openldap" {
	name     = "openldap"
	realm_id = "${keycloak_realm.test.id}"

	enabled        = true
	import_enabled = false

	username_ldap_attribute = "cn"
	rdn_ldap_attribute      = "cn"
	uuid_ldap_attribute     = "entryDN"

	user_object_classes = [
		"simpleSecurityObject",
		"organizationalRole",
	]

	connection_url  = "ldap://openldap"
	users_dn        = "dc=example,dc=org"
	bind_dn         = "cn=admin,dc=example,dc=org"
	bind_credential = "admin"

	connection_timeout = "5s"
	read_timeout       = "10s"

	cache_policy = "NO_CACHE"
}

resource "keycloak_ldap_user_attribute_mapper" "description_attr_mapper" {
	name                    = "description-mapper"
	realm_id                = "${keycloak_ldap_user_federation.openldap.realm_id}"
	ldap_user_federation_id = "${keycloak_ldap_user_federation.openldap.id}"

	user_model_attribute = "description"
	ldap_attribute       = "description"

	always_read_value_from_ldap = false
}

resource "keycloak_ldap_group_mapper" "group_mapper" {
	name                    = "group mapper"
	realm_id                = "${keycloak_ldap_user_federation.openldap.realm_id}"
	ldap_user_federation_id = "${keycloak_ldap_user_federation.openldap.id}"

	ldap_groups_dn            = "dc=example,dc=org"
	group_name_ldap_attribute = "cn"

	group_object_classes = [
		"groupOfNames",
	]

	membership_attribute_type      = "DN"
	membership_ldap_attribute      = "member"
	membership_user_ldap_attribute = "cn"
	memberof_ldap_attribute        = "memberOf"
}

resource "keycloak_ldap_msad_user_account_control_mapper" "msad_uac_mapper" {
	name                    = "uac-mapper1"
	realm_id                = "${keycloak_ldap_user_federation.openldap.realm_id}"
	ldap_user_federation_id = "${keycloak_ldap_user_federation.openldap.id}"
}

resource "keycloak_ldap_full_name_mapper" "full_name_mapper" {
	name                    = "full-name-mapper"
	realm_id                = "${keycloak_ldap_user_federation.openldap.realm_id}"
	ldap_user_federation_id = "${keycloak_ldap_user_federation.openldap.id}"

	ldap_full_name_attribute = "cn"
	read_only                = true
}

resource "keycloak_custom_user_federation" "custom" {
	name        = "custom1"
	realm_id    = "master"
	provider_id = "custom"

	enabled = true
}

resource "keycloak_openid_user_attribute_protocol_mapper" "map_user_attributes_client" {
	name           = "tf-test-open-id-user-attribute-protocol-mapper-client"
	realm_id       = "${keycloak_realm.test.id}"
	client_id      = "${keycloak_openid_client.test_client.id}"
	user_attribute = "description"
	claim_name     = "description"
}

resource "keycloak_openid_user_attribute_protocol_mapper" "map_user_attributes_client_scope" {
	name            = "tf-test-open-id-user-attribute-protocol-mapper-client-scope"
	realm_id        = "${keycloak_realm.test.id}"
	client_scope_id = "${keycloak_openid_client_scope.test_default_client_scope.id}"
	user_attribute  = "foo2"
	claim_name      = "bar2"
}

resource "keycloak_openid_group_membership_protocol_mapper" "map_group_memberships_client" {
	name       = "tf-test-open-id-group-membership-protocol-mapper-client"
	realm_id   = "${keycloak_realm.test.id}"
	client_id  = "${keycloak_openid_client.test_client.id}"
	claim_name = "bar"
}

resource "keycloak_openid_group_membership_protocol_mapper" "map_group_memberships_client_scope" {
	name            = "tf-test-open-id-group-membership-protocol-mapper-client-scope"
	realm_id        = "${keycloak_realm.test.id}"
	client_scope_id = "${keycloak_openid_client_scope.test_optional_client_scope.id}"
	claim_name      = "bar2"
}

resource "keycloak_openid_full_name_protocol_mapper" "map_full_names_client" {
	name      = "tf-test-open-id-full-name-protocol-mapper-client"
	realm_id  = "${keycloak_realm.test.id}"
	client_id = "${keycloak_openid_client.test_client.id}"
}

resource "keycloak_openid_full_name_protocol_mapper" "map_full_names_client_scope" {
	name            = "tf-test-open-id-full-name-protocol-mapper-client-scope"
	realm_id        = "${keycloak_realm.test.id}"
	client_scope_id = "${keycloak_openid_client_scope.test_default_client_scope.id}"
}

resource "keycloak_openid_user_property_protocol_mapper" "map_user_properties_client" {
	name          = "tf-test-open-id-user-property-protocol-mapper-client"
	realm_id      = "${keycloak_realm.test.id}"
	client_id     = "${keycloak_openid_client.test_client.id}"
	user_property = "foo"
	claim_name    = "bar"
}

resource "keycloak_openid_user_property_protocol_mapper" "map_user_properties_client_scope" {
	name            = "tf-test-open-id-user-property-protocol-mapper-client-scope"
	realm_id        = "${keycloak_realm.test.id}"
	client_scope_id = "${keycloak_openid_client_scope.test_optional_client_scope.id}"
	user_property   = "foo2"
	claim_name      = "bar2"
}

resource "keycloak_openid_hardcoded_claim_protocol_mapper" "hardcoded_claim_client" {
	name      = "tf-test-open-id-hardcoded-claim-protocol-mapper-client"
	realm_id  = "${keycloak_realm.test.id}"
	client_id = "${keycloak_openid_client.test_client.id}"

	claim_name  = "foo"
	claim_value = "bar"
}

resource "keycloak_openid_hardcoded_claim_protocol_mapper" "hardcoded_claim_client_scope" {
	name            = "tf-test-open-id-hardcoded-claim-protocol-mapper-client-scope"
	realm_id        = "${keycloak_realm.test.id}"
	client_scope_id = "${keycloak_openid_client_scope.test_default_client_scope.id}"

	claim_name  = "foo"
	claim_value = "bar"
}

resource "keycloak_openid_client" "bearer_only_client" {
	client_id   = "test-bearer-only-client"
	name        = "test-bearer-only-client"
	realm_id    = "${keycloak_realm.test.id}"
	description = "a test openid client using bearer-only"

	access_type = "BEARER-ONLY"
}

resource "keycloak_openid_audience_protocol_mapper" "audience_client_scope" {
	name            = "tf-test-openid-audience-protocol-mapper-client-scope"
	realm_id        = "${keycloak_realm.test.id}"
	client_scope_id = "${keycloak_openid_client_scope.test_default_client_scope.id}"

	add_to_id_token     = true
	add_to_access_token = false

	included_client_audience = "${keycloak_openid_client.bearer_only_client.client_id}"
}

resource "keycloak_openid_audience_protocol_mapper" "audience_client" {
	name      = "tf-test-openid-audience-protocol-mapper-client"
	realm_id  = "${keycloak_realm.test.id}"
	client_id = "${keycloak_openid_client.test_client.id}"

	add_to_id_token     = false
	add_to_access_token = true

	included_custom_audience = "foo"
}

resource "keycloak_saml_client" "saml_client" {
	realm_id  = "${keycloak_realm.test.id}"
	client_id = "test-saml-client"
	name      = "test-saml-client"

	sign_documents          = false
	sign_assertions         = true
	include_authn_statement = true

	signing_certificate = "${file("../provider/misc/saml-cert.pem")}"
	signing_private_key = "${file("../provider/misc/saml-key.pem")}"
}

resource "keycloak_saml_user_attribute_protocol_mapper" "saml_user_attribute_mapper" {
	realm_id  = "${keycloak_realm.test.id}"
	client_id = "${keycloak_saml_client.saml_client.id}"
	name      = "test-saml-user-attribute-mapper"

	user_attribute             = "user-attribute"
	friendly_name              = "friendly-name"
	saml_attribute_name        = "saml-attribute-name"
	saml_attribute_name_format = "Unspecified"
}

resource "keycloak_saml_user_property_protocol_mapper" "saml_user_property_mapper" {
	realm_id  = "${keycloak_realm.test.id}"
	client_id = "${keycloak_saml_client.saml_client.id}"
	name      = "test-saml-user-property-mapper"

	user_property              = "email"
	saml_attribute_name        = "email"
	saml_attribute_name_format = "Unspecified"
}

resource keycloak_oidc_identity_provider oidc {
	realm             = "${keycloak_realm.test.id}"
	alias             = "oidc"
	authorization_url = "https://example.com/auth"
	token_url         = "https://example.com/token"
	client_id         = "example_id"
	client_secret     = "example_token"
}

resource keycloak_attribute_importer_identity_provider_mapper oidc {
	realm                   = "${keycloak_realm.test.id}"
	name                    = "attributeImporter"
	claim_name              = "upn"
	identity_provider_alias = "${keycloak_oidc_identity_provider.oidc.alias}"
	user_attribute          = "email"
}

resource keycloak_attribute_to_role_identity_provider_mapper oidc {
	realm                   = "${keycloak_realm.test.id}"
	name                    = "attributeToRole"
	claim_name              = "upn"
	identity_provider_alias = "${keycloak_oidc_identity_provider.oidc.alias}"
	claim_value             = "value"
	role                    = "testRole"
}

resource keycloak_user_template_importer_identity_provider_mapper oidc {
	realm                   = "${keycloak_realm.test.id}"
	name                    = "userTemplate"
	identity_provider_alias = "${keycloak_oidc_identity_provider.oidc.alias}"
	template                = "$${ALIAS}/$${CLAIM.upn}"
}

resource keycloak_hardcoded_role_identity_provider_mapper oidc {
	realm                   = "${keycloak_realm.test.id}"
	name                    = "hardcodedRole"
	identity_provider_alias = "${keycloak_oidc_identity_provider.oidc.alias}"
	role                    = "testrole"
}

resource keycloak_hardcoded_attribute_identity_provider_mapper oidc {
	realm                   = "${keycloak_realm.test.id}"
	name                    = "hardcodedUserSessionAttribute"
	identity_provider_alias = "${keycloak_oidc_identity_provider.oidc.alias}"
	attribute_name          = "attribute"
	attribute_value         = "value"
	user_session            = true
}

resource keycloak_saml_identity_provider saml {
	realm                      = "${keycloak_realm.test.id}"
	alias                      = "saml"
	single_sign_on_service_url = "https://example.com/auth"
}

resource keycloak_attribute_importer_identity_provider_mapper saml {
	realm                   = "${keycloak_realm.test.id}"
	name                    = "Attribute: email"
	attribute_name          = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
	identity_provider_alias = "${keycloak_saml_identity_provider.saml.alias}"
	user_attribute          = "email"
}

resource keycloak_attribute_to_role_identity_provider_mapper saml {
	realm                   = "${keycloak_realm.test.id}"
	name                    = "attributeToRole"
	attribute_name          = "upn"
	identity_provider_alias = "${keycloak_saml_identity_provider.saml.alias}"
	attribute_value         = "value"
	role                    = "testRole"
}

resource keycloak_user_template_importer_identity_provider_mapper saml {
	realm                   = "${keycloak_realm.test.id}"
	name                    = "userTemplate"
	identity_provider_alias = "${keycloak_saml_identity_provider.saml.alias}"
	template                = "$${ALIAS}/$${NAMEID}"
}

resource keycloak_hardcoded_role_identity_provider_mapper saml {
	realm                   = "${keycloak_realm.test.id}"
	name                    = "hardcodedRole"
	identity_provider_alias = "${keycloak_saml_identity_provider.saml.alias}"
	role                    = "testrole"
}

resource keycloak_hardcoded_attribute_identity_provider_mapper saml {
	realm                   = "${keycloak_realm.test.id}"
	name                    = "hardcodedAttribute"
	identity_provider_alias = "${keycloak_saml_identity_provider.saml.alias}"
	attribute_name          = "attribute"
	attribute_value         = "value"
	user_session            = false
}

data "keycloak_openid_client" "broker" {
	realm_id  = "${keycloak_realm.test.id}"
	client_id = "broker"
}

data "keycloak_openid_client_authorization_policy" "default" {
	realm_id           = "${keycloak_realm.test.id}"
	resource_server_id = "${keycloak_openid_client.test_client_auth.resource_server_id}"
	name               = "default"
}

resource "keycloak_openid_client" "test_client_auth" {
	client_id   = "test-client-auth"
	name        = "test-client-auth"
	realm_id    = "${keycloak_realm.test.id}"
	description = "a test openid client"

	access_type                  = "CONFIDENTIAL"
	direct_access_grants_enabled = true
	implicit_flow_enabled        = true
	service_accounts_enabled     = true

	valid_redirect_uris = [
		"http://localhost:5555/callback",
	]

	authorization {
		policy_enforcement_mode = "ENFORCING"
	}

	client_secret = "secret"
}

resource "keycloak_openid_client_authorization_permission" "resource" {
	resource_server_id = "${keycloak_openid_client.test_client_auth.resource_server_id}"
	realm_id           = "${keycloak_realm.test.id}"
	name               = "test"
	policies           = [
		"${data.keycloak_openid_client_authorization_policy.default.id}"]
	resources          = [
		"${keycloak_openid_client_authorization_resource.resource.id}"]
}

resource "keycloak_openid_client_authorization_resource" "resource" {
	resource_server_id = "${keycloak_openid_client.test_client_auth.resource_server_id}"
	name               = "test-openid-client1"
	realm_id           = "${keycloak_realm.test.id}"

	uris = [
		"/endpoint/*"
	]

	attributes = {
		"asdads" = "asdasd"
	}
}

resource "keycloak_openid_client_authorization_scope" "resource" {
	resource_server_id = "${keycloak_openid_client.test_client_auth.resource_server_id}"
	name               = "test-openid-client1"
	realm_id           = "${keycloak_realm.test.id}"
}

resource "keycloak_user" "resource" {
	realm_id = "${keycloak_realm.test.id}"
	username = "test"

	attributes = {
		"key" = "value"
	}
}

resource "keycloak_openid_client_service_account_role" "read_token" {
	realm_id                = "${keycloak_realm.test.id}"
	client_id               = "${data.keycloak_openid_client.broker.id}"
	service_account_user_id = "${keycloak_openid_client.test_client_auth.service_account_user_id}"
	role                    = "read-token"
}

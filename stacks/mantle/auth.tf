# Passkey enrollment, offered self-service from user settings. Sign-in already validates
# WebAuthn devices through the built-in authentication flow's authenticator stage, so this
# adds no login step for anyone -- it just makes registering a passkey a managed object.
module "passkey" {
  source = "git::https://git.vn.linuxguru.net/Linuxguru/k8s-terraform.git//modules/auth/authentik/authenticator_webauthn?ref=v0.1.0"

  name = "passkey"
}

# Makes a passkey sufficient at login rather than a second factor: the login form offers
# the passkey, and the default flow then skips the password and MFA stages for it. Users
# without a passkey still get username + password, so nothing is locked out.
module "passwordless" {
  source = "git::https://git.vn.linuxguru.net/Linuxguru/k8s-terraform.git//modules/auth/authentik/passwordless?ref=v0.1.0"
}

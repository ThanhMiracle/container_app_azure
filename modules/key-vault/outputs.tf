output "id" { value = azurerm_key_vault.this.id }
output "name" { value = azurerm_key_vault.this.name }
output "vault_uri" { value = azurerm_key_vault.this.vault_uri }
output "secret_ids" {
  value     = { for name, secret in azurerm_key_vault_secret.this : name => secret.id }
  sensitive = true
}

<!-- source: https://docs.nats.io/reference/config/jetstream/tpm.md · fetched 2026-08-31 · section: tpm -->
# tpm

Requires Restart

Seal the filestore encryption key in the machine's TPM, so it cannot be read off disk.

## Properties

| Name                                                                            | Description                                                                                               | Type      | Default | Reloadable |
| ------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- | --------- | ------- | ---------- |
| [`keys_file`](/reference/config/jetstream/tpm/keys_file.md)                     | File the TPM-sealed key is stored in.                                                                     | `string`  | -       | No         |
| [`encryption_password`](/reference/config/jetstream/tpm/encryption_password.md) | Password protecting the sealed key.                                                                       | `string`  | -       | No         |
| [`srk_password`](/reference/config/jetstream/tpm/srk_password.md)               | Password for the TPM storage root key.                                                                    | `string`  | -       | No         |
| [`pcr`](/reference/config/jetstream/tpm/pcr.md)                                 | Platform Configuration Register the key is sealed against, so it only unseals on an unchanged boot state. | `integer` | -       | No         |
| [`cipher`](/reference/config/jetstream/tpm/cipher.md)                           | Cipher used for the filestore once the key is unsealed.                                                   | `string`  | -       | No         |

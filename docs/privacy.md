# Evidence and publication

Raw ETL, XML, PnP inventories, BCD backups and setup logs can contain machine/user names, serial numbers, device instance suffixes, MAC addresses, router/domain UUIDs, private paths and account/support identifiers. They remain in ignored `local/` storage and are not automatically uploaded.

Public excerpts retain hardware vendor/product IDs, model numbers, software/firmware versions, message text and trace-quality counts. These describe the compatibility question without identifying a particular device instance or account. Source comments must not accidentally embed the owner's absolute home directory or exact live device instance ID.

Before committing new evidence:

- Prefer a short typed observation or a deliberately reviewed text excerpt to a raw trace.
- Remove support case numbers, email addresses, tokens, activation keys, serial numbers, unique router/domain IDs and identifying path segments.
- Keep public source URLs; never commit signed download URLs or credentials.
- Do not upload third-party firmware, Windows images, driver binaries, PDBs or full copied articles as part of this knowledge base.

The original local artifacts are retained for the owner. Public absence of raw files is not a claim that the observations came from a generic simulated test.

# Store covers and safe admin edits

## Merchant sign-in IDs

For a store login without an inbox, assign an ID such as
`broadway@stepsyapp.com` and a strong password in **Stores**. Only store-linked
merchant accounts on this exact domain skip the email code; customers and
merchants using other domains still need mailbox verification. Existing managed
store IDs work without recreating the store. Use the store's **Reset merchant
password** action for password recovery when there is no inbox. Updating a login
ID or resetting its password revokes its previous sessions.

## Store / brand cover

Open **Stores → Edit → Store / brand cover**, choose a JPEG, PNG or WebP up to 4 MB, then click **Save cover**. Cover upload is separate from the store metadata's **Save changes** button. A local preview is not confirmation of an upload; wait for **Cover saved**.

The API converts the image to a 1280×720 WebP, applies orientation, crops to 16:9 and removes supplied metadata. Animated images, unsupported formats and images over 25 megapixels are rejected. The resulting public HTTPS URL is returned in admin store lists/details and the customer reward catalog. Refresh Rewards to fetch the updated catalog; the new Android build displays the cover.

Each replacement gets a new URL so cached images do not conceal updates. Older files remain available to cached screens. Removing a cover clears the store's current cover without immediately deleting old public files. Images are public brand assets; do not upload private information.

## Edit, archive and delete

| Record | Routine action | Permanent deletion |
| --- | --- | --- |
| Store | Edit metadata; Archive / Restore | Only after archival, with no customer or merchant history |
| Deal | Edit copy, stock and future points cost; Archive / Restore | Only after archival, with no claim history |
| User | Edit; deactivate to revoke sessions and release the device | Only a deactivated account with no activity, points or purchase history |
| Voucher | Cancel an unused issued voucher | Disabled; voucher and purchase records are retained |

Archival hides stores/deals from new claims. Existing issued vouchers remain in Wallet and can still be honored through the store checkout. Archival preserves the prior active/inactive status and schedule; restoration does not override either. Setting a store **INACTIVE** remains a separate operational action with its existing effect on merchant access.

The API checks eligibility again when a deletion is attempted. Hiding a button is not the security boundary. Historical ledger entries and recovery receipts protect records even if a voucher row is missing. Archived records remain accessible through the admin filter.

Once a deal has been claimed, its discount type, discount value and minimum spend cannot change: existing vouchers currently reference those fields. Create a new deal for different benefits. Title/description edits also appear on existing vouchers, so use them for corrections rather than changing the underlying promised product. Changing points cost affects future purchases only. The existing one-claim-per-account rule also applies to cancelled vouchers.

Cancelling a voucher **does not automatically refund points**. A support operator must review any refund separately using the existing points adjustment tool. Do not promise a refund until it is recorded.

## Deployment and storage

Deploy the backend with migration **0009** before publishing the new admin forms. The migration adds three nullable columns; it does not remove data. Existing code can be restored while retaining the additive schema. Schema downgrade intentionally refuses to drop cover/archive state.

`backend/docker-compose.yml` mounts the persistent `stepsy_media` named volume at `/app/uploads`. Do not run `docker compose down -v` or delete that volume. Back up both the Stepsy database and this media volume; restoring only the database cannot restore the referenced image files. Versioned media cleanup needs a deliberate retention policy before automation is added.

Only Stepsy's Nginx API site needs `client_max_body_size 6m` to accommodate a 4 MB file plus multipart overhead. Validate Nginx configuration before graceful reload. The public image route is `/media/store-covers/{uuid}.webp`; directory listings and arbitrary file paths are not served.

For local API use, set `PUBLIC_API_URL` to that API's reachable URL and `MEDIA_DIRECTORY` to an ignored local folder before starting the process. Returning production image URLs from an isolated local API will cause image 404s. The admin frontend's API target must match a backend containing the cover endpoints.

## Next admin priorities

These are recommendations, not features delivered by this change:

1. Named staff accounts, roles and MFA; require reasons for sensitive changes and capture before/after values in the audit trail. The current shared admin identity is insufficient for attributing individual actions.
2. A reasoned cancellation/refund workflow with approvals where needed, an immutable refund ledger entry and customer support notes.
3. Merchant/branch onboarding and approval, branch-specific locations, and voucher terms captured at purchase so future campaign edits cannot alter past promises.
4. Searchable support views for device links and last successful step sync, plus filtered redemption reports and exports. Add server pagination as records grow.
5. Automated database and media backups, restore drills, upload/storage alerts and realistic load tests before national launch.

# Direct game sales and other stores — integration plan, not a live checkout

Yes: the same game can be distributed from ancientnest.net and other stores, subject
to each store's distribution terms. Recommended: keep Ancient Nest accounts/stats
under your control; use established stores and a payment provider for transactions.
Avoid building card collection or an entire storefront payment system yourself.

## Current state

Steam identity/account linking and the cloud-stats API are implemented in this kit.
Steam license checks need a real App ID +publisher key. No App ID exists yet.
Direct checkout, payment webhooks, entitlement grants, non-Steam login and additional
store adapters are NOT implemented or deployed. Downloading/installation does not
prove a purchase. Steam login identifies a user without a game App ID, but does not
verify game ownership.

## Recommended eventual direct-sale flow

1. Buyer signs into a real Ancient Nest account. Add an appropriate secure non-Steam
   login provider if direct buyers should not need Steam. Identity linking must require
   recent auth on both identities; never merge by display name or unverified email.
2. Server creates a hosted checkout with a fixed, server-controlled product/price and
   internal account UUID binding. Never accept arbitrary client prices/account IDs.
3. Provider sends a SIGNED webhook. Verify raw-body signature, timestamp and provider
   event ID; retrieve/validate payment state server-to-server where required.
4. Database transaction records unique order/event and grants product entitlement to
   that account. Browser success URL alone grants nothing. Retries are idempotent.
5. Buyer downloads installer. First launch links installation to that account through
   the same code/fingerprint flow; the hub checks current entitlement before admission.
6. Refunds, disputes and chargebacks revoke/adjust the matching source entitlement.
   Another valid purchase from a different store can still grant access. Reconcile
   provider events periodically, handle out-of-order events and keep an audit trail.
7. Display Purchased/Active/Refunded/Pending truthfully on website and game. Avoid
   treating temporary store licenses as permanent paid purchases.

Suggested additive schema: external_identities(provider,subject,account_id);
products; orders(provider,provider_order_id,account_id,product_id,status);
payment_events(provider,event_id UNIQUE,payload_hash,processed_at);
entitlements(account_id,product_id,source,source_order,status,valid_until).
Version migrations and keep stable account UUID; no account/stats reset when a new
store or device is linked. Do not add a generic public 'grant access' endpoint.

A merchant-of-record provider may handle sales tax/VAT and payment-related obligations;
confirm it accepts downloadable games and your business/country before selecting it.
A normal payment processor can handle checkout while you remain seller responsible
for taxes/refunds/support. Compare fees, payout rules, chargebacks, allowed products
and regional coverage. Do not claim a specific provider supports this game without
approval. Stripe, for example, is not automatically the merchant of record for a
standard Checkout integration.

Steam, other stores and direct sales should all feed one server-side license resolver.
A client cannot choose its own verifier or set 'paid'. Keep store credentials and
payment webhook secrets only on backend. Strong offline DRM is a different project;
this kit controls authenticated online-service admission, not whether a copied local
binary can run offline. Do not claim otherwise.

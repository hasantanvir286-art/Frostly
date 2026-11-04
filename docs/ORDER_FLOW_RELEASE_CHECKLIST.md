# Nawrah Kitchen order-flow release checklist

Use a staging project and test accounts before accepting public orders. Do not run this checklist against a live customer's account or place an unapproved real order.

## Customer flow

1. Open the deployed HTTPS site in a clean browser session. Confirm the English/Bangla switch changes navigation and checkout labels.
2. Sign in with a test customer account. Confirm the catalogue shows active products and current prices/stock.
3. Add an in-stock item, adjust quantity, remove it, and confirm the cart total and stock limit update correctly.
4. Open checkout with an empty cart and confirm checkout is blocked with a helpful message. Add an item and confirm checkout requires sign-in and required address/phone/area fields.
5. Place a staging order using a staging payment method or COD. Confirm one order is created, the cart clears, and the success screen offers order history.
6. Open order history. Confirm the unique order reference, item names/quantities, delivery details, payment status, and total match the staging database.
7. As staff, confirm the order, then advance it through the configured fulfillment states. Confirm a customer can cancel only while it is awaiting confirmation.
8. Mark the staging order delivered. Confirm the customer sees it in Delivered and can submit a rating only for the delivered product.
9. Use Reorder on the delivered staging order. Confirm available quantities enter the cart, unavailable products are skipped, and the cart does not exceed live stock.

## Staff and security checks

- Confirm each staff role sees only its permitted dashboard views and actions.
- Confirm staff MFA is enrolled and verified before dashboard access.
- Confirm a customer cannot update another customer's profile, order, rating, or stock alert.
- Confirm checkout and status changes are enforced by Supabase RPC/RLS, not only browser UI.
- Confirm Cloudflare's API guard is bound and required in production before relying on its rate limits.
- Confirm payment totals and delivery fees are recalculated on the server.

Record the test date, staging project, test account IDs (never passwords), deployment commit, and pass/fail notes. Remove staging orders and test records using the project's approved cleanup path.

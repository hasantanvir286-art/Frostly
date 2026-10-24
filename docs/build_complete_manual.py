from pathlib import Path
import sys, zipfile, shutil, textwrap

from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.style import WD_STYLE_TYPE
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT_DOCX = ROOT / 'output' / 'docx' / 'Frostly_Complete_User_Manual_and_Workflows.docx'
OUT_PDF = ROOT / 'output' / 'pdf' / 'Frostly_Complete_User_Manual_and_Workflows.pdf'
ASSETS = ROOT / 'tmp' / 'manual-assets'
NAVY = '12304A'
TEAL = '248E78'
PALE = 'EAF5F7'
INK = '172B3A'
MUTED = '5D7180'
DATE = '22 October 2026'


def blocks_for_manual():
    return [
        ('intro', 'This guide explains how customers use Frostly, how staff manage the store, and how the website is configured and deployed. It describes the current implementation: a bilingual storefront backed by Supabase and hosted on Cloudflare Pages. The included flowcharts show the order and administration paths from start to finish.'),
        ('toc', [
            '1. Frostly at a glance', '2. Customer guide', '3. Checkout and mobile wallet payments',
            '4. Orders, delivery, and ratings', '5. Admin dashboard guide', '6. Staff roles',
            '7. Setup and deployment', '8. Security and operational notes', '9. Troubleshooting',
            'Appendix A. Supabase migrations', 'Appendix B. First superadmin bootstrap',
        ]),
        ('h1', '1. Frostly at a glance'),
        ('p', 'Frostly is a responsive English and Bangla frozen-food storefront. English is the default language. Customers can browse products, manage a cart and profile, place orders, follow order status, and rate eligible delivered purchases. Staff use a role-protected dashboard to manage the catalog, stock, delivery areas, orders, payment instructions, and selected storefront content.'),
        ('table', (['Area', 'Managed from', 'Notes'], [
            ['Products, prices, stock, and categories', 'Admin dashboard and Supabase', 'Store data is database-backed; replace demo items before real sales.'],
            ['Brand name, logo, homepage slides and copy', 'Admin dashboard settings', 'Bilingual copy fields are available where supported.'],
            ['Contact details and payment options', 'Admin dashboard settings', 'Footer contact and checkout choices are editable.'],
            ['Delivery area names and fees', 'Admin dashboard delivery section', 'Only active areas appear during checkout.'],
            ['Accounts, orders, roles and reviews', 'Supabase with dashboard views', 'RLS and server-side functions enforce permissions.'],
            ['Page layout, styling and behaviors', 'Project source code', 'The dashboard does not rebuild the site layout.'],
        ])),
        ('callout', '“Dynamic” means supported store data and settings are loaded from Supabase. Visual layout and frontend behavior still come from the deployed HTML, CSS, JavaScript, and Cloudflare Function.'),
        ('h1', '2. Customer guide'),
        ('h2', 'Open the store and choose a language'),
        ('ol', [
            'Open the live storefront at https://frostly-400.pages.dev/ or use the local server instructions in section 7.',
            'The store starts in English. Choose বাংলা from either language menu to switch the page; the selection is remembered in that browser.',
            'Use the home page, categories, best sellers, search, or product list to find an item.',
            'Open a product to see its larger image and details. Choose Add to Cart, then open the cart icon to review quantities and subtotal.',
        ]),
        ('h2', 'Create an account or sign in'),
        ('ol', [
            'Choose the profile icon, then Create an account. Enter your name, email, and password.',
            'If Supabase email confirmation is enabled, open the confirmation email before signing in.',
            'Returning customers choose Sign in. Use Forgot password if you need a reset email.',
            'Checkout requires an authenticated customer account. If checkout redirects to sign in, sign in and checkout will continue.',
        ]),
        ('h2', 'Edit a customer profile'),
        ('ul', [
            'Open the profile icon while signed in to view the account panel.',
            'Edit profile lets you change the display name, phone number, and profile photo. Supported profile photo formats are JPG, PNG, and WebP, up to 3 MB.',
            'Change password asks for the current password and a new password entered twice.',
            'Change email asks for the new email and current password. The sign-in email changes only after the Supabase verification link is confirmed.',
            'Manage saved addresses and mark a default address where those controls are available. Sign out on shared devices.',
        ]),
        ('h1', '3. Checkout and mobile wallet payments'),
        ('diagram', 'customer'),
        ('h2', 'Place an order'),
        ('ol', [
            'Open the cart and choose Checkout. If asked, sign in or create an account; the checkout flow resumes after successful sign-in.',
            'Check the recipient name, Bangladesh phone number, full address, and delivery area. Add optional instructions or notes as needed.',
            'Choose a delivery area. The estimate updates with its configured delivery fee. An area must be active in the admin dashboard to appear.',
            'Review the cart, estimated subtotal, delivery fee, and total. The database recalculates current prices, stock, and fee when the order is submitted.',
            'Select Cash on Delivery or an enabled mobile wallet and place the order.',
        ]),
        ('h2', 'Cash on Delivery'),
        ('p', 'For COD, place the order in checkout and pay the delivery person when the order arrives. COD can be enabled or disabled from the admin payment settings. The database checks the enabled setting when accepting a new order.'),
        ('h2', 'bKash, Nagad, and Rocket manual payment'),
        ('ol', [
            'In checkout, select the enabled wallet shown in the payment method menu.',
            'Send the exact checkout total using the wallet’s Send Money service to the receiving number shown on screen.',
            'Enter the transaction ID from the wallet confirmation, then place the order.',
            'The order is recorded as awaiting payment verification. An order manager or administrator checks the transfer and marks payment verified in the dashboard.',
        ]),
        ('callout', 'Default receiving number: 01811111111 for bKash, Nagad, and Rocket until changed in Admin > Settings > Checkout payment options. This is a manual transfer workflow, not a connected payment gateway. The website does not initiate a wallet transfer or verify money automatically. Do not hand over goods until staff verify the payment.'),
        ('h2', 'If checkout is unavailable'),
        ('ul', [
            'Sign in first; checkout is account-based.',
            'Make sure the cart still contains active, in-stock products.',
            'Confirm that at least one delivery area is active and has an actual fee.',
            'Confirm that a payment method is enabled and, for a wallet, that a valid receiving number is configured.',
            'If a wallet submission fails because the SQL function is missing, apply migration 202610220014_manual_mobile_payments.sql in Supabase SQL Editor.',
        ]),
        ('h1', '4. Orders, delivery, and ratings'),
        ('ul', [
            'Use the separate Orders icon beside the cart to open your order list. Refresh the list or filter all, in-progress, delivered, and cancelled orders.',
            'Select an order reference to expand purchased products, delivery details, totals, payment method, and transaction reference where present.',
            'Order IDs displayed to customers use a date plus a UUID-based reference such as FST-2026-…; the internal numeric sequence is not the security credential.',
            'After an order is marked Delivered, a customer can rate a purchased product from 1 to 5 stars and optionally leave a short review. Only eligible verified purchases can be reviewed.',
        ]),
        ('table', (['Order status', 'Meaning'], [
            ['Pending confirmation', 'Order received and waiting for staff confirmation.'],
            ['Confirmed / Preparing / Packed', 'Staff accepted and are preparing the order.'],
            ['Out for delivery', 'Order is on the way to the customer.'],
            ['Delivered', 'Order is complete; eligible products can be rated.'],
            ['Cancelled', 'Order was cancelled by authorized staff.'],
        ])),
        ('h1', '5. Admin dashboard guide'),
        ('h2', 'Sign in and open the dashboard'),
        ('p', 'Sign in to the storefront with an account assigned a staff role, then open the admin console link or its console page. The console checks the Supabase profile role. A guessed or shared URL alone does not grant administrator access. If access is denied, verify that the signed-in account has the intended role in public.profiles.'),
        ('h2', 'Overview'),
        ('ul', [
            'Review order totals, awaiting-confirmation counts, gross sales, and low-stock products.',
            'Select the low-stock metric to open inventory and adjust stock or reorder details.',
            'Refresh the dashboard after changes from another staff member.',
        ]),
        ('h2', 'Orders'),
        ('ol', [
            'Open Orders and use the processing/delivered shortcuts, status filters, or search to find a record.',
            'Check the full customer-facing order reference, customer contact, delivery address, products, total, and payment details.',
            'Choose a permitted order status and save it. Status history is recorded by the database.',
            'For wallet orders, inspect the customer’s transaction ID and verify the transfer in the wallet account independently. Only then choose Mark payment verified.',
        ]),
        ('h2', 'Products and inventory'),
        ('ol', [
            'Open Products to create or edit a product or bilingual category.',
            'Set its category, English and Bangla names, description, price, package size, active state, and stock.',
            'Upload a JPG, PNG, or WebP product image (up to 5 MB) when the image option is available.',
            'Save changes and confirm the item is active. Use Inventory for stock adjustments and audit history.',
        ]),
        ('h2', 'Delivery areas'),
        ('p', 'Open Delivery to add or edit a delivery area, set the actual fee, and choose whether it is active. The initial Chattogram configuration is Inside Chattogram Town at BDT 80 and Outside Chattogram Town at BDT 120. Verify fees before enabling zones; checkout and the order RPC only accept active areas.'),
        ('h2', 'Settings: brand, homepage, contact, and payment'),
        ('ul', [
            'Site identity: change the site name and upload the logo.',
            'Homepage: add, edit, or remove hero slides and edit bilingual headline/copy fields. Save settings to publish them.',
            'Contact: set the service area, phone, email, and footer payment display text.',
            'Checkout payment options: enable/disable COD, bKash, Nagad, and Rocket; edit each wallet receiving number; save payment options.',
            'Phone numbers are validated before saving and again by the order database function. The active payment-method list is read from Supabase.',
        ]),
        ('h2', 'Superadmin user management'),
        ('ol', [
            'Open User Management to switch between customer accounts and staff accounts, and search by name, email, user ID, or role.',
            'Change the role for an existing account and save. New staff must first register and confirm an account.',
            'Use customer/staff deletion controls carefully. Database functions block protected accounts and linked records where deletion is unsafe.',
            'At least one superadmin must remain. The active superadmin cannot remove their own superadmin access.',
        ]),
        ('h2', 'Admin profile and email'),
        ('p', 'Open the administrator name/avatar menu to view the signed-in identity and sign out. Change the account email through the profile/email option using password reauthentication and Supabase email verification. Configure Supabase Auth Site URL and redirect allow-list for the live Frostly domain.'),
        ('table', (['Role', 'Dashboard access'], [
            ['Superadmin', 'All dashboard areas; user/staff management and role assignment.'],
            ['Administrator', 'Overview, orders, products, inventory, delivery, customers, and settings.'],
            ['Order manager', 'Overview, orders, and customer/order operations.'],
            ['Stock manager', 'Overview and inventory operations.'],
            ['Catalog manager', 'Product and category editing.'],
            ['Delivery manager', 'Delivery areas and fees.'],
            ['Settings manager', 'Brand, homepage slides/copy, contact, and payment settings.'],
            ['Delivery staff', 'Role exists; full assignment workflow is limited/not configured in the dashboard.'],
        ])),
        ('h1', '6. Main system flows'),
        ('diagram', 'architecture'),
        ('h2', 'Customer order and payment path'),
        ('p', 'The customer browser reads the catalog and settings from Supabase. Checkout submits an idempotency request ID and cart item IDs to a database function. The function checks the authenticated user, active zone, payment method, current database prices, stock, and transaction-reference format; it writes the order and item snapshots and adjusts stock in a single transaction. Wallet payments are stored as pending verification until staff independently verify them.'),
        ('h2', 'Admin access path'),
        ('p', 'The console reads the signed-in session and profile role. It shows role-permitted views, while Supabase RLS and security-definer functions enforce sensitive reads and writes independently. Hiding a navigation item is not the security boundary.'),
        ('diagram', 'admin'),
        ('h1', '7. Setup and deployment'),
        ('h2', 'Run the site locally'),
        ('code', 'py -m http.server 8000\n# Open http://localhost:8000\n# Stop the server with Ctrl+C'),
        ('p', 'Run the command from the Frostly project folder. Keep the terminal open while using the local site. Local HTTP calls Supabase directly; the deployed site routes Supabase HTTP requests through the same-origin Cloudflare Pages Function.'),
        ('h2', 'Connect Supabase'),
        ('ol', [
            'Create/open the Supabase project. Put its Project URL and public anon/publishable key in supabase-config.js. Never put a service-role key or database password in frontend files or Cloudflare public variables.',
            'Run the ordered migrations in Appendix A through Supabase SQL Editor. Existing projects should apply only migrations they have not already applied.',
            'Configure Supabase Auth email confirmation, set Site URL to the live Pages domain (or custom domain), and allow-list that origin plus localhost. Signup emails now redirect to the site where registration began.',
            'Register the trusted owner account in Frostly and promote it to superadmin using the controlled bootstrap procedure in Appendix B if no superadmin exists.',
            'Replace demo products, images, sample contact details, prices, and stock. Verify the two delivery fees and configure wallet numbers before inviting customers.',
        ]),
        ('h2', 'Cloudflare Pages build settings'),
        ('table', (['Setting', 'Value'], [
            ['Framework preset', 'None'],
            ['Build command', 'Leave blank (plain static files and Pages Function).'],
            ['Build output directory', '/ (repository root).'],
            ['Root directory', 'Repository root.'],
            ['Deployment source', 'GitHub repository; push to the production branch and wait for deployment success.'],
        ])),
        ('p', 'Keep functions/api/supabase/[[path]].js, supabase-proxy.js, and _routes.json in the repository. Set FROSTLY_SUPABASE_URL in Pages variables only if the Supabase project URL changes. A successful Pages deployment does not run Supabase migrations; schema changes must be applied separately in Supabase.'),
        ('h2', 'Update the live site'),
        ('ol', [
            'Edit source in the project repository and commit the changed files.',
            'Push the production branch to GitHub.',
            'Wait for Cloudflare Pages to report a successful deployment and verify the deployed commit.',
            'Apply any new SQL migration in the correct Supabase project. Do not assume a Git push applies SQL.',
            'Hard-refresh the live page or open a private window if old JavaScript is cached.',
        ]),
        ('h1', '8. Security and operational notes'),
        ('ul', [
            'Only the public Supabase URL and anon/publishable key belong in browser code. Never expose service-role keys, database credentials, Auth tokens, or wallet account credentials.',
            'The Cloudflare Pages Function is a reverse proxy, not a login system. Supabase Auth, RLS policies, profile roles, and server-side functions enforce access.',
            'The admin console filename is not a security feature; normal customer accounts should fail the role check.',
            'Order references are identifiers for support, not passwords or access tokens. Customer order reads are limited by ownership policies.',
            'Manual wallet payment only records a submitted transaction ID. Staff must verify money received before marking it verified or fulfilling the order.',
            'The assistant is a local/catalog-grounded demo and is not a production AI service. The page design is code-managed. Delivery-staff assignment workflow is limited.',
            'Back up production data before schema changes. Do not disable RLS or grant broad writes to make a dashboard feature work.',
        ]),
        ('h1', '9. Troubleshooting'),
        ('table', (['Issue', 'Check or action'], [
            ['Profile icon does nothing', 'Refresh after the latest Cloudflare deployment; confirm app.js is the current version and no JavaScript error appears in the console.'],
            ['Checkout sends me to profile/sign-in', 'Sign in; checkout resumes after successful sign-in. Close any other drawer if it remains open.'],
            ['Checkout fields reset while typing', 'Hard-refresh after the checkout-render fix deploys; this behavior was caused by repeated settings reloads.'],
            ['No delivery areas appear', 'Admin > Delivery: activate an area and set a real fee. Confirm delivery_zones contains active rows.'],
            ['Wallets do not appear or order cannot submit', 'Apply migration 202610220014_manual_mobile_payments.sql; verify the method toggle and receiving number in Admin > Settings.'],
            ['Signup email points to localhost or errors after clicking', 'Set the Supabase Auth Site URL to the production origin and add it to Redirect URLs; signup passes the current site URL as its confirmation redirect.'],
            ['Superadmin/order manager cannot change order status', 'Apply migration 202610240015_order_manager_status_access.sql in Supabase SQL Editor to replace the original admin-only status function.'],
            ['Wallet payment remains pending', 'This is expected until an authorized staff member verifies the transfer and marks it verified.'],
            ['Admin says no access', 'Sign in with a staff account and verify its public.profiles.role. URL secrecy does not grant staff permissions.'],
            ['Site settings do not save', 'Check role permission, RLS and required migration in Supabase; make sure the Save confirmation appears.'],
            ['Changes are missing from live site', 'Check the correct Git branch, Pages deployment commit, Supabase project, and browser cache. SQL is applied separately.'],
            ['Image upload fails', 'Check file type/size, storage bucket and corresponding storage migration.'],
            ['Ratings do not appear', 'The order must be delivered and contain that product; verify migration 202610220009.'],
        ])),
        ('h1', 'Appendix A. Supabase migrations'),
        ('p', 'Run these files once, in order, for a new project. For an existing project, check which migrations have already run and apply only the missing files. Paste SQL only into Supabase SQL Editor; do not include Markdown backticks or headings.'),
        ('table', (['Order', 'Migration file', 'Purpose'], [
            ['1', '202610200001_frostly_core.sql', 'Core schema, products, accounts, orders, inventory, RLS and RPCs.'],
            ['2', '202610200002_chattogram_delivery_zones.sql', 'Inside/Outside Chattogram zones and BDT 80/120 fees.'],
            ['3', '202610200003_admin_inventory_adjustment.sql', 'Secure stock changes and inventory movement records.'],
            ['4', '202610200004_customer_profile_settings.sql', 'Customer phone/avatar fields and storage policy.'],
            ['5', '202610200005_default_delivery_address.sql', 'Customer default saved address.'],
            ['6', '202610200006_admin_product_image_uploads.sql', 'Admin product image storage.'],
            ['7', '202610200007_storefront_settings_slider.sql', 'Editable brand, logo, and homepage slides.'],
            ['8', '202610200008_site_contact_settings.sql', 'Footer service area, phone, email, payment text.'],
            ['9', '202610220009_product_ratings.sql', 'Verified delivered-order product reviews.'],
            ['10', '202610220010_staff_roles_and_user_management.sql', 'Staff roles, RLS permissions and superadmin account tools.'],
            ['11', '202610220011_homepage_copy_settings.sql', 'Bilingual homepage copy settings.'],
            ['12', '202610220012_superadmin_delete_customer.sql', 'Protected superadmin customer deletion function.'],
            ['13', '202610220013_superadmin_delete_staff.sql', 'Protected superadmin staff deletion function.'],
            ['14', '202610220014_manual_mobile_payments.sql', 'Wallet settings, payment references, pending verification, and secure multi-method order RPC.'],
            ['15', '202610240015_order_manager_status_access.sql', 'Allows order managers, admins and superadmins to update valid order statuses.'],
        ])),
        ('h1', 'Appendix B. First superadmin bootstrap'),
        ('p', 'Create and confirm the trusted owner account through Frostly first. Run the SQL below in the matching Supabase project’s SQL Editor only if the account exists and no superadmin is available. Replace the sample email with the exact trusted account email. Check that the result says UPDATE 1; do not disable the trigger if the update fails.'),
        ('code', "begin;\nalter table public.profiles disable trigger protect_frostly_profile_role;\nupdate public.profiles\nset role = 'superadmin'\nwhere id = (select id from auth.users where lower(email) = lower('admin@example.com'));\nalter table public.profiles enable trigger protect_frostly_profile_role;\ncommit;"),
        ('callout', 'If the query updates zero rows, stop and check that the account is confirmed, the email is exact, and it belongs to this Supabase project. Never paste service-role keys or passwords into the browser console or a public message.'),
        ('closing', 'Frostly project files and configuration are maintained in the GitHub repository. Keep this guide and the ordered Supabase migrations together with each release.'),
    ]


def font_path(bold=False):
    candidates = [
        Path('C:/Windows/Fonts/arialbd.ttf' if bold else 'C:/Windows/Fonts/arial.ttf'),
        Path('C:/Windows/Fonts/segoeuib.ttf' if bold else 'C:/Windows/Fonts/segoeui.ttf'),
    ]
    return next((p for p in candidates if p.exists()), None)


def create_diagram(filename, title, labels):
    ASSETS.mkdir(parents=True, exist_ok=True)
    width, height = 1800, 470
    image = Image.new('RGB', (width, height), '#ffffff')
    draw = ImageDraw.Draw(image)
    regular = ImageFont.truetype(str(font_path(False)), 28) if font_path(False) else ImageFont.load_default()
    bold = ImageFont.truetype(str(font_path(True)), 30) if font_path(True) else ImageFont.load_default()
    draw.text((48, 24), title, fill=f'#{NAVY}', font=bold)
    n = len(labels)
    left, gap, box_h = 42, 28, 225
    box_w = (width - 84 - gap * (n - 1)) // n
    y = 130
    for idx, label in enumerate(labels):
        x = left + idx * (box_w + gap)
        draw.rounded_rectangle((x, y, x + box_w, y + box_h), radius=24, fill=f'#{PALE}', outline=f'#{TEAL}', width=4)
        lines = textwrap.wrap(label, width=max(12, int(box_w / 19)))
        line_heights = [draw.textbbox((0, 0), line, font=regular)[3] for line in lines]
        total_h = sum(line_heights) + (len(lines) - 1) * 10
        cy = y + (box_h - total_h) / 2
        for line, lh in zip(lines, line_heights):
            bbox = draw.textbbox((0, 0), line, font=regular)
            tw = bbox[2] - bbox[0]
            draw.text((x + (box_w - tw) / 2, cy), line, fill=f'#{INK}', font=regular)
            cy += lh + 10
        if idx < n - 1:
            ax = x + box_w + 5
            ay = y + box_h // 2
            bx = ax + gap - 10
            draw.line((ax, ay, bx, ay), fill=f'#{TEAL}', width=6)
            draw.polygon([(bx, ay), (bx - 13, ay - 11), (bx - 13, ay + 11)], fill=f'#{TEAL}')
    image.save(ASSETS / filename, 'PNG', optimize=True)
    return ASSETS / filename


def add_page_number(paragraph):
    paragraph.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    run = paragraph.add_run('Frostly User Manual  |  ')
    run.font.size = Pt(8)
    run.font.color.rgb = RGBColor.from_string(MUTED)
    field = OxmlElement('w:fldSimple')
    field.set(qn('w:instr'), 'PAGE')
    paragraph._p.append(field)


def set_cell_shading(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement('w:shd')
    shd.set(qn('w:fill'), fill)
    tc_pr.append(shd)


def set_table_borders(table):
    tbl_pr = table._tbl.tblPr
    borders = OxmlElement('w:tblBorders')
    for edge in ('top', 'left', 'bottom', 'right', 'insideH', 'insideV'):
        tag = OxmlElement(f'w:{edge}')
        tag.set(qn('w:val'), 'single')
        tag.set(qn('w:sz'), '5')
        tag.set(qn('w:color'), 'D6E0E5')
        borders.append(tag)
    tbl_pr.append(borders)


def set_run_font(run, name='Arial', size=10, bold=None, color=INK):
    run.font.name = name
    run._element.get_or_add_rPr().rFonts.set(qn('w:ascii'), name)
    run._element.get_or_add_rPr().rFonts.set(qn('w:hAnsi'), name)
    run.font.size = Pt(size)
    run.font.color.rgb = RGBColor.from_string(color)
    if bold is not None:
        run.bold = bold


def add_table_docx(document, headers, rows):
    table = document.add_table(rows=1, cols=len(headers))
    table.autofit = False
    table.style = 'Table Grid'
    widths = {2: [1.7, 5.1], 3: [0.58, 2.95, 3.27]}.get(len(headers), [6.8 / len(headers)] * len(headers))
    for index, width in enumerate(widths):
        table.columns[index].width = Inches(width)
    for idx, text in enumerate(headers):
        cell = table.rows[0].cells[idx]
        cell.text = str(text)
        set_cell_shading(cell, NAVY)
        cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
        for run in cell.paragraphs[0].runs:
            set_run_font(run, size=8.5, bold=True, color='FFFFFF')
    for row_idx, row in enumerate(rows):
        cells = table.add_row().cells
        for col_idx, value in enumerate(row):
            cells[col_idx].width = Inches(widths[col_idx])
            cells[col_idx].text = str(value)
            cells[col_idx].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            if row_idx % 2:
                set_cell_shading(cells[col_idx], 'F1F7F9')
            for p in cells[col_idx].paragraphs:
                p.paragraph_format.space_after = Pt(2)
                p.paragraph_format.space_before = Pt(2)
                for run in p.runs:
                    set_run_font(run, size=8.3)
    set_table_borders(table)
    document.add_paragraph().paragraph_format.space_after = Pt(1)


def build_docx():
    diagram_customer = create_diagram('customer-flow.png', 'CUSTOMER ORDER FLOW', [
        'Browse products and add to cart', 'Open checkout; sign in if prompted',
        'Enter recipient and delivery details', 'Choose active delivery area and payment',
        'Database checks price, stock, fee and method', 'Order appears in Orders for tracking',
    ])
    diagram_arch = create_diagram('architecture.png', 'FROSTLY SYSTEM ARCHITECTURE', [
        'Customer or staff browser', 'Cloudflare Pages HTML, CSS and JavaScript',
        'Pages Function proxy for deployed API calls', 'Supabase Auth and Postgres with RLS',
        'Supabase Storage and database RPCs',
    ])
    diagram_admin = create_diagram('admin-flow.png', 'ADMIN ACCESS AND OPERATIONS', [
        'Sign in with a staff account', 'Dashboard checks profile role',
        'Role-based dashboard views appear', 'Supabase RLS and RPCs enforce access',
        'Staff update orders, stock, products, zones or settings',
    ])
    doc = Document()
    section = doc.sections[0]
    section.top_margin = Inches(0.7)
    section.bottom_margin = Inches(0.7)
    section.left_margin = Inches(0.72)
    section.right_margin = Inches(0.72)
    section.page_width = Inches(8.27)
    section.page_height = Inches(11.69)
    styles = doc.styles
    normal = styles['Normal']
    normal.font.name = 'Arial'
    normal._element.rPr.rFonts.set(qn('w:ascii'), 'Arial')
    normal._element.rPr.rFonts.set(qn('w:hAnsi'), 'Arial')
    normal.font.size = Pt(10)
    normal.font.color.rgb = RGBColor.from_string(INK)
    normal.paragraph_format.space_after = Pt(6)
    normal.paragraph_format.line_spacing = 1.12
    for style_name, size in [('Title', 27), ('Heading 1', 17), ('Heading 2', 12.5)]:
        style = styles[style_name]
        style.font.name = 'Arial'
        style._element.rPr.rFonts.set(qn('w:ascii'), 'Arial')
        style._element.rPr.rFonts.set(qn('w:hAnsi'), 'Arial')
        style.font.size = Pt(size)
        style.font.bold = True
        style.font.color.rgb = RGBColor(0, 0, 0)
        style.paragraph_format.keep_with_next = True
    code_style = styles.add_style('Code', WD_STYLE_TYPE.PARAGRAPH)
    code_style.font.name = 'Consolas'
    code_style._element.rPr.rFonts.set(qn('w:ascii'), 'Consolas')
    code_style._element.rPr.rFonts.set(qn('w:hAnsi'), 'Consolas')
    code_style.font.size = Pt(8)
    footer = section.footer.paragraphs[0]
    add_page_number(footer)

    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(75)
    run = p.add_run('FROSTLY')
    set_run_font(run, size=13, bold=True, color=TEAL)
    title = doc.add_paragraph(style='Title')
    title.paragraph_format.space_before = Pt(9)
    title.paragraph_format.space_after = Pt(8)
    title.add_run('Complete User Manual and Workflows')
    subtitle = doc.add_paragraph()
    set_run_font(subtitle.add_run('Customer guide  |  Admin guide  |  Setup and operations'), size=13, color=MUTED)
    date = doc.add_paragraph()
    date.paragraph_format.space_before = Pt(10)
    set_run_font(date.add_run(f'Prepared {DATE}'), size=9, color=MUTED)
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(28)
    p.paragraph_format.left_indent = Inches(0.18)
    p.paragraph_format.right_indent = Inches(0.18)
    p.paragraph_format.space_after = Pt(14)
    p.paragraph_format.keep_together = True
    set_run_font(p.add_run(blocks_for_manual()[0][1]), size=11, color=INK)
    p = doc.add_paragraph()
    set_run_font(p.add_run('WHAT THIS GUIDE COVERS'), size=9, bold=True, color=TEAL)
    for item in blocks_for_manual()[1][1]:
        p = doc.add_paragraph(style='List Bullet')
        p.paragraph_format.space_after = Pt(2)
        set_run_font(p.add_run(item), size=9)
    doc.add_page_break()
    diagram_map = {'customer': diagram_customer, 'architecture': diagram_arch, 'admin': diagram_admin}
    for kind, value in blocks_for_manual()[2:]:
        if kind == 'h1':
            if value.startswith('Appendix A.'):
                doc.add_page_break()
            p = doc.add_paragraph(value, style='Heading 1')
            p.paragraph_format.space_before = Pt(10)
        elif kind == 'h2':
            p = doc.add_paragraph(value, style='Heading 2')
            p.paragraph_format.space_before = Pt(7)
        elif kind in ('p', 'closing'):
            p = doc.add_paragraph(value)
            if kind == 'closing':
                p.paragraph_format.space_before = Pt(14)
        elif kind in ('ul', 'ol'):
            style = 'List Bullet' if kind == 'ul' else 'List Number'
            for item in value:
                p = doc.add_paragraph(style=style)
                p.paragraph_format.space_after = Pt(3)
                p.paragraph_format.keep_together = True
                p.add_run(item)
        elif kind == 'table':
            add_table_docx(doc, value[0], value[1])
        elif kind == 'diagram':
            p = doc.add_paragraph()
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            p.paragraph_format.space_before = Pt(4)
            p.paragraph_format.space_after = Pt(10)
            p.add_run().add_picture(str(diagram_map[value]), width=Inches(6.8))
        elif kind == 'code':
            p = doc.add_paragraph(style='Code')
            p.paragraph_format.left_indent = Inches(0.16)
            p.paragraph_format.right_indent = Inches(0.12)
            p.paragraph_format.space_before = Pt(4)
            p.paragraph_format.space_after = Pt(9)
            p.paragraph_format.keep_together = True
            pPr = p._p.get_or_add_pPr()
            shd = OxmlElement('w:shd')
            shd.set(qn('w:fill'), 'F1F5F7')
            pPr.append(shd)
            for idx, line in enumerate(value.splitlines()):
                if idx:
                    p.add_run().add_break()
                set_run_font(p.add_run(line), name='Consolas', size=8, color=INK)
        elif kind == 'callout':
            p = doc.add_paragraph()
            p.paragraph_format.left_indent = Inches(0.16)
            p.paragraph_format.right_indent = Inches(0.16)
            p.paragraph_format.space_before = Pt(4)
            p.paragraph_format.space_after = Pt(9)
            p.paragraph_format.keep_together = True
            shd = OxmlElement('w:shd')
            shd.set(qn('w:fill'), 'EAF5F7')
            p._p.get_or_add_pPr().append(shd)
            set_run_font(p.add_run(value), size=9.3, color=NAVY)
        elif kind == 'toc':
            pass
    OUT_DOCX.parent.mkdir(parents=True, exist_ok=True)
    doc.save(OUT_DOCX)
    print(OUT_DOCX)


def build_pdf():
    from docx import Document as ReadDocument
    from docx.table import Table as ReadTable
    from docx.text.paragraph import Paragraph as ReadParagraph
    from docx.oxml.ns import qn as read_qn
    from reportlab.lib import colors
    from reportlab.lib.enums import TA_LEFT, TA_RIGHT
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import mm
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image as RLImage, PageBreak, KeepTogether

    docx_path = OUT_DOCX
    if not docx_path.exists():
        raise FileNotFoundError(docx_path)
    temp_media = ASSETS / 'docx-media'
    temp_media.mkdir(parents=True, exist_ok=True)
    source = ReadDocument(docx_path)
    body = source.element.body
    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle(name='FrostTitle', parent=styles['Title'], fontName='Helvetica-Bold', fontSize=26, leading=31, textColor=colors.HexColor('#000000'), spaceAfter=12))
    styles.add(ParagraphStyle(name='FrostH1', parent=styles['Heading1'], fontName='Helvetica-Bold', fontSize=16, leading=20, textColor=colors.HexColor('#000000'), spaceBefore=11, spaceAfter=7, keepWithNext=True))
    styles.add(ParagraphStyle(name='FrostH2', parent=styles['Heading2'], fontName='Helvetica-Bold', fontSize=11.5, leading=15, textColor=colors.HexColor('#000000'), spaceBefore=7, spaceAfter=4, keepWithNext=True))
    styles.add(ParagraphStyle(name='FrostBody', parent=styles['BodyText'], fontName='Helvetica', fontSize=9, leading=12, textColor=colors.HexColor('#172B3A'), spaceAfter=5))
    styles.add(ParagraphStyle(name='FrostSmall', parent=styles['BodyText'], fontName='Helvetica', fontSize=8, leading=10, textColor=colors.HexColor('#5D7180'), spaceAfter=3))
    styles.add(ParagraphStyle(name='FrostCode', parent=styles['Code'], fontName='Courier', fontSize=7.5, leading=9, backColor=colors.HexColor('#F1F5F7'), borderPadding=6, spaceBefore=3, spaceAfter=7))
    story = []
    media_id = 0
    list_number = 0
    for child in body.iterchildren():
        if child.tag == read_qn('w:p'):
            para = ReadParagraph(child, source)
            text = para.text.strip()
            if para._p.xpath('.//w:br[@w:type="page"]'):
                story.append(PageBreak())
                continue
            if para._p.xpath('.//w:drawing'):
                for blip in para._p.xpath('.//a:blip'):
                    rel = blip.get(read_qn('r:embed'))
                    part = source.part.related_parts.get(rel)
                    if part:
                        media_id += 1
                        path = temp_media / f'image-{media_id}.png'
                        path.write_bytes(part.blob)
                        im = RLImage(str(path), width=178*mm, height=178*mm*0.26)
                        im.hAlign = 'CENTER'
                        story.extend([Spacer(1, 3*mm), im, Spacer(1, 3*mm)])
                continue
            if not text:
                continue
            style_name = para.style.name if para.style else 'Normal'
            if style_name.startswith('List Number'):
                list_number += 1
                text = f'{list_number}. {text}'
            elif style_name.startswith('List Bullet'):
                list_number = 0
                text = '- ' + text
            else:
                list_number = 0
            if style_name == 'Title':
                story.append(Spacer(1, 22*mm))
                story.append(Paragraph(text, styles['FrostTitle']))
            elif style_name == 'Heading 1':
                story.append(Paragraph(text, styles['FrostH1']))
            elif style_name == 'Heading 2':
                story.append(Paragraph(text, styles['FrostH2']))
            elif style_name == 'Code':
                story.append(Paragraph(text.replace('&','&amp;').replace('<','&lt;').replace('>','&gt;').replace('\n','<br/>'), styles['FrostCode']))
            else:
                story.append(Paragraph(text.replace('&','&amp;').replace('<','&lt;').replace('>','&gt;'), styles['FrostBody']))
        elif child.tag == read_qn('w:tbl'):
            table = ReadTable(child, source)
            data = [[cell.text.replace('\n','<br/>') for cell in row.cells] for row in table.rows]
            cooked = [[Paragraph(cell.replace('&','&amp;').replace('<','&lt;').replace('>','&gt;').replace('&lt;br/&gt;','<br/>'), styles['FrostSmall']) for cell in row] for row in data]
            if cooked:
                for cell in cooked[0]:
                    cell.style = ParagraphStyle(name='FrostTH', parent=styles['FrostSmall'], fontName='Helvetica-Bold', textColor=colors.white)
                widths = {2: [43*mm, 132*mm], 3: [17*mm, 76*mm, 82*mm]}.get(len(cooked[0]), [175*mm/len(cooked[0])]*len(cooked[0]))
                tbl = Table(cooked, colWidths=widths, repeatRows=1, hAlign='LEFT')
                tbl.setStyle(TableStyle([
                    ('BACKGROUND',(0,0),(-1,0),colors.HexColor('#12304A')),
                    ('GRID',(0,0),(-1,-1),0.45,colors.HexColor('#D6E0E5')),
                    ('VALIGN',(0,0),(-1,-1),'MIDDLE'),
                    ('LEFTPADDING',(0,0),(-1,-1),5),('RIGHTPADDING',(0,0),(-1,-1),5),
                    ('TOPPADDING',(0,0),(-1,-1),5),('BOTTOMPADDING',(0,0),(-1,-1),5),
                    *[('BACKGROUND',(0,r),(-1,r),colors.HexColor('#F1F7F9')) for r in range(2,len(cooked),2)],
                ]))
                story.extend([tbl,Spacer(1,5*mm)])

    OUT_PDF.parent.mkdir(parents=True, exist_ok=True)
    def footer(canvas, doc):
        canvas.saveState()
        w,h = A4
        canvas.setStrokeColor(colors.HexColor('#D6E0E5'))
        canvas.line(18*mm, 15*mm, w-18*mm, 15*mm)
        canvas.setFont('Helvetica', 8)
        canvas.setFillColor(colors.HexColor('#5D7180'))
        canvas.drawString(18*mm, 10*mm, 'Frostly Complete User Manual and Workflows')
        canvas.drawRightString(w-18*mm, 10*mm, f'{doc.page}')
        canvas.restoreState()
    pdf = SimpleDocTemplate(str(OUT_PDF), pagesize=A4, rightMargin=18*mm, leftMargin=18*mm, topMargin=17*mm, bottomMargin=21*mm, title='Frostly Complete User Manual and Workflows', author='Frostly')
    pdf.build(story, onFirstPage=footer, onLaterPages=footer)
    print(OUT_PDF)


def build_markdown():
    lines = ['# Frostly Complete User Manual and Workflows', '', f'Prepared {DATE}', '']
    for kind, value in blocks_for_manual():
        if kind == 'intro':
            lines.extend([value, ''])
        elif kind == 'toc':
            lines.append('## Contents')
            lines.extend([f'- {item}' for item in value])
            lines.append('')
        elif kind in ('h1', 'h2'):
            lines.extend([('# ' if kind == 'h1' else '## ') + value, ''])
        elif kind in ('p', 'closing'):
            lines.extend([value, ''])
        elif kind == 'ul':
            lines.extend([f'- {item}' for item in value] + [''])
        elif kind == 'ol':
            lines.extend([f'{index}. {item}' for index, item in enumerate(value, 1)] + [''])
        elif kind == 'table':
            headers, rows = value
            lines.append('| ' + ' | '.join(headers) + ' |')
            lines.append('| ' + ' | '.join(['---'] * len(headers)) + ' |')
            for row in rows:
                lines.append('| ' + ' | '.join(str(item).replace('|', '\\|') for item in row) + ' |')
            lines.append('')
        elif kind == 'callout':
            lines.extend(['> ' + value, ''])
        elif kind == 'code':
            lines.extend(['```text', value, '```', ''])
        elif kind == 'diagram':
            if value == 'customer':
                mermaid = 'flowchart LR\n  A[Browse products and add to cart] --> B[Open checkout; sign in if prompted] --> C[Enter recipient and delivery details] --> D[Choose active delivery area and payment] --> E[Database validates price, stock, fee and method] --> F[Order appears in Orders for tracking]'
            elif value == 'architecture':
                mermaid = 'flowchart LR\n  A[Customer or staff browser] --> B[Cloudflare Pages assets] --> C[Pages Function API proxy] --> D[Supabase Auth and Postgres RLS] --> E[Storage and database RPCs]'
            else:
                mermaid = 'flowchart LR\n  A[Staff sign in] --> B[Dashboard checks profile role] --> C[Role-based views] --> D[Supabase RLS and RPCs enforce access] --> E[Manage orders, products, stock, zones and settings]'
            lines.extend(['```mermaid', mermaid, '```', ''])
    (ROOT / 'docs' / 'USER_MANUAL.md').write_text('\n'.join(lines), encoding='utf-8')
    print(ROOT / 'docs' / 'USER_MANUAL.md')


if __name__ == '__main__':
    mode = sys.argv[1] if len(sys.argv) > 1 else 'docx'
    if mode == 'docx':
        build_docx()
    elif mode == 'pdf':
        build_pdf()
    elif mode == 'markdown':
        build_markdown()
    else:
        raise SystemExit('Use docx or pdf')

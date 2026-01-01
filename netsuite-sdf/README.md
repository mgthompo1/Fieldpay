# FieldPay NetSuite SDF Deployment

This folder contains the SuiteCloud Development Framework (SDF) project for deploying the FieldPay integration to a NetSuite account.

## What Gets Deployed

1. **Integration Record** (`custintegration_fieldpay`)
   - OAuth 2.0 with PKCE enabled
   - Callback URL: `fieldpay://callback`
   - Scopes: REST Web Services, RESTlets

2. **Custom Role** (`customrole_fieldpay_user`)
   - Pre-configured permissions for:
     - Customers (full access)
     - Invoices (full access)
     - Sales Orders (full access)
     - Customer Payments (full access)
     - Customer Deposits (full access)
     - Items (view)
     - REST Web Services
     - SuiteQL
     - OAuth 2.0 Token Login

---

## Prerequisites

### 1. Install Node.js
Download from https://nodejs.org (LTS version recommended)

### 2. Install SuiteCloud CLI
```bash
npm install -g @oracle/suitecloud-cli
```

### 3. Verify Installation
```bash
suitecloud --version
```

---

## Deployment Steps

### Step 1: Navigate to the SDF Project
```bash
cd /path/to/fieldpay/netsuite-sdf
```

### Step 2: Set Up Authentication
Create an authentication ID for the target NetSuite account:

```bash
suitecloud account:setup
```

You'll be prompted for:
- **Authentication ID**: A name for this connection (e.g., `customer-account`)
- **Account ID**: The NetSuite account ID (e.g., `TSTDRV1234567` or `1234567`)
- **Authentication Mode**: Choose `OAUTH2` (recommended) or `SAVE_TOKEN`

For OAUTH2, a browser will open for you to log in and authorize.

### Step 3: Validate the Project
```bash
suitecloud project:validate
```

### Step 4: Deploy to NetSuite
```bash
suitecloud project:deploy
```

Or specify a specific authentication ID:
```bash
suitecloud project:deploy --authid customer-account
```

---

## Post-Deployment Steps

After deployment, the customer needs to:

### 1. Get the Client ID and Secret

1. Go to **Setup > Integration > Manage Integrations**
2. Find **FieldPay Mobile** in the list
3. Click to open and copy:
   - **Consumer Key** (this is the Client ID)
   - **Consumer Secret** (this is the Client Secret)

> **Important**: The Consumer Secret is only shown once! Make sure to copy it immediately.

### 2. Assign the Role to Users

1. Go to **Setup > Users/Roles > Manage Users**
2. Edit the user who will use FieldPay
3. In the **Access** tab, add the **FieldPay User** role
4. Save

### 3. Configure FieldPay App

Enter the following in the FieldPay app settings:
- **Account ID**: Their NetSuite account ID
- **Client ID**: The Consumer Key from step 1
- **Client Secret**: The Consumer Secret from step 1

---

## Troubleshooting

### "Feature not enabled" Error
The target account needs these features enabled:
- OAuth 2.0 (`Setup > Company > Enable Features > SuiteCloud > OAuth 2.0`)
- REST Web Services (`Setup > Company > Enable Features > SuiteCloud > REST Web Services`)

### "Permission denied" Error
The user running the deployment needs Administrator role or a role with:
- Setup > Integration > Manage Integrations (Full)
- Setup > Users/Roles > Manage Roles (Full)

### Role Not Appearing
After deployment, the role may take a few minutes to appear. Try:
1. Log out and log back into NetSuite
2. Clear browser cache

### Deployment Fails with Object Errors
Run validation first to see detailed errors:
```bash
suitecloud project:validate --server
```

---

## Updating the Integration

To update an existing deployment:

```bash
suitecloud project:deploy --applyinstallprefs
```

This will update the existing objects rather than creating duplicates.

---

## Removing the Integration

To remove FieldPay from a NetSuite account:

1. Go to **Setup > Integration > Manage Integrations**
2. Find **FieldPay Mobile** and set State to **Blocked** or delete
3. Go to **Setup > Users/Roles > Manage Roles**
4. Delete the **FieldPay User** role (or keep for audit trail)

---

## File Structure

```
netsuite-sdf/
├── project.json              # SDF project configuration
├── suitecloud.config.js      # SuiteCloud CLI config
├── src/
│   ├── manifest.xml          # Project manifest with dependencies
│   ├── deploy.xml            # Deployment configuration
│   └── Objects/
│       ├── custintegration_fieldpay.xml    # OAuth 2.0 Integration Record
│       └── customrole_fieldpay_user.xml    # Custom Role with permissions
└── README.md                 # This file
```

---

## Support

If you encounter issues during deployment, check:
1. NetSuite account has required features enabled
2. User has Administrator access
3. SuiteCloud CLI is up to date: `npm update -g @oracle/suitecloud-cli`

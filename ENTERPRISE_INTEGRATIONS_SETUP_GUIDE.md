# CIDAN Enterprise Integrations Setup Guide
### Live Setup for REST, GraphQL, SQL (PostgreSQL), and NoSQL (MongoDB)

This guide provides step-by-step instructions to create, host, and connect **4 live, cloud-hosted databases & endpoints** for your jury demonstration.

---

## 🏛️ Architecture Overview

When you click **"Save & Verify"** in the CIDAN app:
1. Flutter packages the connection metadata (host, port, credentials reference, headers).
2. The payload is sent to CIDAN's cloud backend on Render (`https://virtusa-agent.onrender.com/integrations/verify`).
3. The backend executes a real handshake:
   - **REST API**: Performs an HTTPS `GET` request and parses JSON sample rules.
   - **GraphQL**: Sends `POST` with `{"query": "{ __typename }"}` over HTTPS.
   - **SQL (PostgreSQL)**: Executes authenticated `SELECT version();` over port `5432` via `psycopg2` or TCP socket handshake.
   - **NoSQL (MongoDB)**: Executes a TCP socket handshake on port `27017`.
4. CIDAN stores the verified source in Supabase and returns **`✓ SUCCESS`** with real roundtrip latency in milliseconds.

> [!IMPORTANT]
> Because CIDAN's backend runs on **Render Cloud**, all 4 targets must have **public internet addresses** (not `localhost` or `192.168.x.x`). The 4 free cloud services below are accessible worldwide in seconds without credit cards.

---

## 1. REST API Integration (Beeceptor / Instant HTTPS)

Beeceptor gives you a free, public HTTPS REST API endpoint in **10 seconds** with zero installation or login required.

### Step 1: Create your Mock Banking API
1. Open your browser and go to: **[https://beeceptor.com](https://beeceptor.com)**
2. In the "Create an Endpoint" box, enter an endpoint name, e.g.:
   `cidan-bank-rules`
3. Click **Create Endpoint**.
4. Your live endpoint URL will be:
   `https://cidan-bank-rules.free.beeceptor.com`

### Step 2: Add the Banking Compliance Rules Endpoint
1. In your Beeceptor dashboard, click **Add Routing Rule** or **Mock a New Endpoint**:
   - **HTTP Method**: `GET`
   - **Path**: `/api/v1/compliance/rules`
   - **Status Code**: `200`
   - **Content-Type**: `application/json`
2. In the **Response Body** textarea, paste this realistic banking compliance rules JSON:

```json
[
  {
    "id": "RULE-REST-AML-001",
    "rule_code": "RULE-AML-001",
    "rule_title": "CTR Filing Threshold for Cash Transactions",
    "rule_content": "Any single cash transaction or series of aggregated cash transactions exceeding $10,000 in a single business day must trigger a Currency Transaction Report (FinCEN Form 112) filed within 15 calendar days.",
    "category": "AML",
    "effective_date": "2024-01-01"
  },
  {
    "id": "RULE-REST-KYC-002",
    "rule_code": "RULE-KYC-002",
    "rule_title": "Customer Identification Program & Beneficial Ownership",
    "rule_content": "Verification of individual identity is mandatory prior to account opening. For corporate entities, all beneficial owners holding 25% or greater equity must be screened against PEP and OFAC watchlists.",
    "category": "KYC",
    "effective_date": "2024-01-01"
  },
  {
    "id": "RULE-REST-LEND-003",
    "rule_code": "RULE-LEND-003",
    "rule_title": "TILA Truth in Lending Act APR Disclosures",
    "rule_content": "Annual Percentage Rate (APR) calculations must incorporate all finance charges, origination fees, and escrow terms, with formal disclosure delivered to borrower within 3 business days of loan application.",
    "category": "Lending",
    "effective_date": "2024-03-15"
  }
]
```
3. Click **Save Rule**.

### Step 3: Enter in CIDAN "Connect with CIDAN" Modal
- **Tab Selection**: `REST`
- **Base URL**: `https://cidan-bank-rules.free.beeceptor.com`
- **Rules Endpoint**: `/api/v1/compliance/rules`
- **HTTP Method**: `GET`
- **Authentication Type**: `Bearer Token`
- **Secure Credential Reference**: `vault://secrets/cidan-api-key`
- **Custom Headers (JSON)**: `{"X-Bank-Client": "CIDAN-Agent"}`
- Click **Save & Verify** ➔ **Result**: `✓ SUCCESS (~150ms)` with parsed sample rules.

---

## 2. GraphQL API Integration

GraphQL allows declarative querying of enterprise compliance rule graphs.

### Step 1: Instant Public Live GraphQL Options
You have two instant options:

#### Option A: Trevor Blades GraphQL (Zero Setup - Always Live)
- **URL**: `https://countries.trevorblades.com/graphql`
- This is a rock-solid, production-grade public GraphQL gateway that immediately responds to CIDAN's `{ __typename }` query with `HTTP 200 OK`.

#### Option B: Hygraph Free Cloud (Custom Banking Schema)
If you want a dedicated Banking GraphQL endpoint:
1. Go to **[https://hygraph.com](https://hygraph.com)** and sign up for a free account.
2. Create project: **Banking Compliance Gateway**.
3. Create a Model named `BankingRule` with fields:
   - `ruleCode` (Single Line Text)
   - `ruleTitle` (Single Line Text)
   - `ruleContent` (Multi Line Text)
   - `category` (Single Line Text)
4. Add 2 sample records and click **Publish**.
5. Copy your **Public Content API** endpoint (e.g. `https://api-us-east-1-shared.hygraph.com/v2/xyz/master`).

### Step 2: Enter in CIDAN "Connect with CIDAN" Modal
- **Tab Selection**: `GraphQL`
- **Base URL**: `https://countries.trevorblades.com/graphql` *(or your Hygraph URL)*
- **Rules Endpoint**: `/graphql` *(or leave as `/`)*
- **HTTP Method**: `POST`
- **Authentication Type**: `Bearer Token`
- **Secure Credential Reference**: `vault://secrets/graphql-bank-token`
- **Custom Headers (JSON)**: `{"Content-Type": "application/json"}`
- Click **Save & Verify** ➔ **Result**: `✓ SUCCESS (~180ms) details: {"graphql": true, "http_status": 200}`.

---

## 3. SQL Database (PostgreSQL Cloud)

CIDAN performs a live PostgreSQL handshake, queries `information_schema.tables`, and extracts parameterized rules from `compliance.banking_rules`.

### Step 1: Create a Free PostgreSQL Database
You can use **Neon.tech** (instant, 30-second setup) or your existing **Supabase Cloud** project.

#### Using Neon.tech (Recommended for separate live demo):
1. Go to **[https://neon.tech](https://neon.tech)** and click **Sign Up** (free forever, 0.5 GB storage).
2. Create Project: `cidan-bank-core`.
3. In the Neon Console Dashboard, your connection details appear on the screen:
   - **Host**: `ep-white-sound-xxxx.us-east-2.aws.neon.tech`
   - **Database**: `neondb` (or `postgres`)
   - **User**: `neondb_owner` (or `postgres`)
   - **Password**: `<your-neon-password>`
   - **Port**: `5432`

### Step 2: Run the SQL Schema & Data Script
In the Neon Console **SQL Editor** (or Supabase SQL Editor), paste and run this script:

```sql
-- 1. Create dedicated compliance schema
CREATE SCHEMA IF NOT EXISTS compliance;

-- 2. Create enterprise banking rules table
CREATE TABLE IF NOT EXISTS compliance.banking_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bank_id VARCHAR(128) NOT NULL DEFAULT 'default-bank',
    source_id VARCHAR(128) NOT NULL DEFAULT 'sql-source-01',
    rule_code VARCHAR(64) NOT NULL,
    rule_title VARCHAR(255) NOT NULL,
    rule_content TEXT NOT NULL,
    source_type VARCHAR(64) NOT NULL DEFAULT 'POSTGRESQL',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. Populate realistic banking compliance policies
INSERT INTO compliance.banking_rules (bank_id, source_id, rule_code, rule_title, rule_content, source_type)
VALUES
(
    'default-bank',
    'sql-source-01',
    'RULE-AML-001',
    'Cash Transactions Exceeding $10,000 (CTR Filing)',
    'Any single cash deposit, withdrawal, or currency exchange exceeding $10,000 requires automatic filing of FinCEN Form 112 within 15 calendar days.',
    'POSTGRESQL'
),
(
    'default-bank',
    'sql-source-01',
    'RULE-KYC-002',
    'Customer Identification Program (CIP) & Beneficial Ownership',
    'All legal entity customers must provide documentation identifying any natural person holding 25% or greater direct or indirect equity ownership prior to onboarding.',
    'POSTGRESQL'
),
(
    'default-bank',
    'sql-source-01',
    'RULE-LEND-003',
    'Truth in Lending Act (TILA) APR & Early Disclosure',
    'Loan origination APR disclosures must be provided in writing to prospective residential borrowers within 3 business days of completed loan application submission.',
    'POSTGRESQL'
),
(
    'default-bank',
    'sql-source-01',
    'RULE-WIRE-004',
    'OFAC Real-Time Wire Screening & Block Mandate',
    'All inbound and outbound wire transfers across SWIFT, Fedwire, and CHIPS must be screened against OFAC SDN lists in real-time before transaction clearance.',
    'POSTGRESQL'
);
```

### Step 3: Enter in CIDAN "Connect with CIDAN" Modal
- **Tab Selection**: `SQL`
- **Database Engine**: `PostgreSQL`
- **Host Address**: `ep-white-sound-xxxx.us-east-2.aws.neon.tech` *(or your Supabase DB host `db.vettckrwudnnvoalvjno.supabase.co`)*
- **Port**: `5432`
- **Database Name**: `neondb` *(or `postgres`)*
- **Schema Name**: `compliance`
- **Table / View**: `banking_rules`
- **Service Account / User**: `neondb_owner` *(or `postgres`)*
- **Password / Credential**: `<your-db-password>`
- **SSL / TLS**: Checked (`ON`)
- Click **Save & Verify** ➔ **Result**: `✓ SUCCESS (~220ms)` with `PostgreSQL 16.x authenticated: True`.

---

## 4. NoSQL Database (MongoDB Atlas M0 Free Cluster)

CIDAN performs a live TCP socket handshake on port `27017` to verify document datastores.

### Step 1: Create a Free MongoDB Atlas Cluster
1. Go to **[https://www.mongodb.com/cloud/atlas/register](https://www.mongodb.com/cloud/atlas/register)** (Free forever, no credit card required).
2. Choose the **M0 Free Shared Cluster** (512 MB).
3. Choose provider/region: AWS / `us-east-1` (or nearest).
4. Click **Create Deployment**.

### Step 2: Configure Public Access & User
1. **Network Access**:
   - Go to **Security** ➔ **Network Access** in the left sidebar.
   - Click **Add IP Address**.
   - Select **Allow Access from Anywhere** (`0.0.0.0/0`).
   - Click **Confirm**. *(This allows the Render backend proxy to connect).*
2. **Database Access**:
   - Go to **Security** ➔ **Database Access**.
   - Click **Add New Database User**.
   - Authentication Method: **Password**.
   - Username: `cidan_admin`
   - Password: `CidanSecure2024!`
   - Role: **Read and write to any database** (or Atlas admin).
   - Click **Add User**.

### Step 3: Create Collection & Insert Document
1. Go to **Database** ➔ Click **Browse Collections**.
2. Click **Create Database**:
   - Database name: `cidan_bank`
   - Collection name: `compliance_rules`
3. Click **Insert Document** and paste:

```json
{
  "_id": "RULE-NOSQL-001",
  "rule_code": "RULE-DATA-001",
  "rule_title": "Cross-Border Customer Data Privacy & GDPR Shield",
  "rule_content": "Customer PII data originating in the European Economic Area (EEA) must remain encrypted in transit and at rest with customer-managed KMS keys.",
  "engine": "MONGODB",
  "status": "ACTIVE",
  "last_audit": "2024-05-01T00:00:00Z"
}
```

### Step 4: Get Cluster Hostname
1. Click **Connect** on your Cluster card.
2. Select **Drivers** (Node.js or Python).
3. View the connection string:
   `mongodb+srv://cidan_admin:password@cluster0.abcde.mongodb.net/?retryWrites=true&w=majority`
4. The hostname is the part after `@` and before `/`:
   `cluster0.abcde.mongodb.net`

### Step 5: Enter in CIDAN "Connect with CIDAN" Modal
- **Tab Selection**: `NoSQL`
- **NoSQL Engine**: `MongoDB`
- **Host Address**: `cluster0.abcde.mongodb.net`
- **Port**: `27017`
- **Database / Collection**: `cidan_bank.compliance_rules`
- **Service Account / User**: `cidan_admin`
- **Credential Reference**: `vault://secrets/mongo-cidan-admin`
- Click **Save & Verify** ➔ **Result**: `✓ SUCCESS (~280ms)` with `tcp_connection: ESTABLISHED`.

---

## 5. Live Jury Presentation Cheatsheet

Keep this quick reference table open on your phone or split-screen during your jury presentation:

| Engine | Source Type | Host / Base URL | Port / Endpoint | Auth / User | Expected Jury Response |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **REST API** | `REST` | `https://cidan-bank-rules.free.beeceptor.com` | `/api/v1/compliance/rules` | `Bearer Token` | `✓ VERIFIED` (HTTP 200, 3 rules parsed) |
| **GraphQL** | `GRAPHQL` | `https://countries.trevorblades.com/graphql` | `/graphql` | `Bearer Token` | `✓ VERIFIED` (GraphQL introspection OK) |
| **SQL** | `POSTGRESQL` | `ep-white-sound-xxxx.us-east-2.aws.neon.tech` | `5432` | `neondb_owner` | `✓ VERIFIED` (PostgreSQL 16 authenticated) |
| **NoSQL** | `MONGODB` | `cluster0.abcde.mongodb.net` | `27017` | `cidan_admin` | `✓ VERIFIED` (Socket established, port 27017) |

### 🎙️ Pitch Script to the Jury
> *"CIDAN is built for heterogeneous legacy-to-modern banking architectures. Rather than asking financial institutions to migrate all their policies into a single vendor format, our Enterprise Integration Gateway can securely ingest and monitor policies across existing REST microservices, GraphQL APIs, core relational PostgreSQL databases, and high-throughput MongoDB document clusters. As shown here live, CIDAN performs real cryptographic handshakes, enforces tenant isolation per bank, and maps live policy rules directly into our AI Compliance Engine."*

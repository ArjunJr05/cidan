# CIDAN AI – React Web Application Integration Guide
> Complete integration handbook for building the CIDAN Regulatory AI Web Platform using React / Next.js / Vite.

---

## 1. System Architecture Overview

The CIDAN AI platform uses a dual-engine architecture:
1. **Supabase Cloud (PostgreSQL)**: Handles real-time relational data, table persistence, user bank isolation, and audit trail.
2. **Virtusa FastAPI Backend (Render)**: Handles heavy AI extraction (Groq Qwen), Universal Rule IR parsing, delta analysis, sandbox backtesting, and secure server-side SMTP email dispatch.

```
┌─────────────────────────────────────────────────────────────┐
│                       React Web App                         │
│                    (Vite / Next.js / CRA)                   │
└──────────────┬──────────────────────────────┬───────────────┘
               │                              │
     Direct Supabase SDK              HTTPS REST API + Token
     (Real-time CRUD & RLS)          (AI Engine & Heavy Ops)
               │                              │
               ▼                              ▼
┌─────────────────────────────┐┌──────────────────────────────┐
│       Supabase Cloud        ││      FastAPI Backend         │
│  (PostgreSQL + Realtime)    ││        (on Render)           │
│ - vettckrwudnnvoalvjno      ││ - https://virtusa-agent...   │
└─────────────────────────────┘└──────────────┬───────────────┘
                                              │
                                     Secure Server-Side
                                      SMTP Credentials
                                              │
                                              ▼
                               ┌──────────────────────────────┐
                               │       Gmail SMTP Relay       │
                               │   (Live 6-Digit OTP Email)   │
                               └──────────────────────────────┘
```

---

## 2. Environment Variables Setup (`.env`)

Depending on the React bundler used by your friend, create a `.env` or `.env.local` file in the root of the React project:

### Option A: If using **Vite** (Recommended)
```env
# Supabase Cloud Configuration
VITE_SUPABASE_URL=https://vettckrwudnnvoalvjno.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZldHRja3J3dWRubnZvYWx2am5vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMwMDkyNTIsImV4cCI6MjEwODU4NTI1Mn0.rDEb0UWfphz3S4Dt8N1ZkeCx3TIuBt2Gw4WKz1XPW_w

# FastAPI Backend Configuration (Render)
VITE_CIDAN_API_URL=https://virtusa-agent.onrender.com
VITE_CIDAN_API_TOKEN=0Zh3yr-Srn3juPBBl3IUSgV_2HDz-4WIrmP1uyDC_5E

# Default Tenant Configuration
VITE_DEFAULT_BANK_ID=00000000-0000-0000-0000-000000000001
VITE_DEFAULT_BANK_NAME=Apex Banking Corporation
```

### Option B: If using **Create React App (CRA)**
```env
REACT_APP_SUPABASE_URL=https://vettckrwudnnvoalvjno.supabase.co
REACT_APP_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZldHRja3J3dWRubnZvYWx2am5vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMwMDkyNTIsImV4cCI6MjEwODU4NTI1Mn0.rDEb0UWfphz3S4Dt8N1ZkeCx3TIuBt2Gw4WKz1XPW_w
REACT_APP_CIDAN_API_URL=https://virtusa-agent.onrender.com
REACT_APP_CIDAN_API_TOKEN=0Zh3yr-Srn3juPBBl3IUSgV_2HDz-4WIrmP1uyDC_5E
REACT_APP_DEFAULT_BANK_ID=00000000-0000-0000-0000-000000000001
```

### Option C: If using **Next.js**
Prefix public variables with `NEXT_PUBLIC_` (e.g. `NEXT_PUBLIC_SUPABASE_URL`).

---

## 3. How to Connect Supabase in React

### Step 1: Install the Supabase Client
```bash
npm install @supabase/supabase-js
```

### Step 2: Initialize Client (`src/lib/supabase.js`)
```javascript
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || process.env.REACT_APP_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || process.env.REACT_APP_SUPABASE_ANON_KEY;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
```

### Step 3: Example React Data Fetching Hook
```javascript
import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';

export function useExistingRules(bankId) {
  const [rules, setRules] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchRules() {
      setLoading(true);
      const { data, error } = await supabase
        .from('existing_rules')
        .select('*')
        .eq('bank_id', bankId)
        .order('created_at', { ascending: false });

      if (error) console.error('Error fetching rules:', error);
      else setRules(data || []);
      setLoading(false);
    }

    if (bankId) fetchRules();
  }, [bankId]);

  return { rules, loading };
}
```

---

## 4. Complete Supabase Database Tables Catalog

All tables are live on Supabase Cloud (`vettckrwudnnvoalvjno`). Always include `bank_id` in inserts and queries for multi-tenant bank isolation.

### A. Core Banking & Tenant Isolation
| Table Name | Description | Key Columns |
| :--- | :--- | :--- |
| `banks` | Bank profiles & institutions | `id` (UUID), `name`, `bank_code`, `created_at` |
| `users` | Bank staff & compliance roles | `id` (UUID), `bank_id`, `email`, `role`, `is_active` |

### B. Milestone 1: Ingestion & System Integrations
| Table Name | Description | Key Columns |
| :--- | :--- | :--- |
| `existing_rules` | Catalog of active bank rules & handbooks | `id`, `bank_id`, `source_type`, `rule_code`, `rule_title`, `rule_content`, `file_format` |
| `bank_integrations` | Connected REST, GraphQL, SQL, NoSQL sources | `id`, `bank_id`, `system_name`, `engine_type`, `connection_config`, `verification_status` |
| `regulatory_documents`| Uploaded central bank circulars & notices | `id`, `bank_id`, `circular_number`, `title`, `issuing_authority`, `file_path`, `extraction_status` |
| `compliance_reports` | Compliance audit runs & saved reports | `id`, `bank_id`, `user_email`, `circular_name`, `metrics`, `summary`, `status` |

### C. Milestone 2: AI Rule IR, Delta Analysis & Mapping Studio
| Table Name | Description | Key Columns |
| :--- | :--- | :--- |
| `rule_ir` | Normalized Universal Rule Intermediate Representation | `id`, `bank_id`, `rule_id`, `rule_name`, `category`, `condition_tree` (JSONB), `actions` (JSONB), `version` |
| `delta_analyses` | Rule Delta comparison analysis sessions | `id` (UUID), `bank_id`, `analysis_name`, `circular_number`, `status`, `total_rules`, `additions_count`, `modifications_count` |
| `rule_deltas` | Specific rule difference & 6 classifications | `id` (UUID), `analysis_id`, `bank_id`, `classification` (`ADDITION`/`MODIFICATION`/`REMOVAL`/`CLARIFICATION`/`NO_IMPACT`/`MANUAL_REVIEW`), `identified_differences` (JSONB), `reason` |
| `proposed_mappings` | Studio human acceptance / customization records | `id`, `delta_id`, `bank_id`, `decision` (`ACCEPTED`/`MODIFIED`/`REJECTED`), `custom_rule_ir` (JSONB), `reviewer_id` |
| `rule_validations` | Structural, logical & regulatory validation findings | `id`, `delta_id`, `bank_id`, `validation_layer`, `severity`, `rule_reference`, `finding_details` |

### D. Milestone 3: Approval Workflows, Testing, Deployment & Audit
| Table Name | Description | Key Columns |
| :--- | :--- | :--- |
| `approval_workflows` | Multi-party governance lifecycle (16 states) | `id`, `bank_id`, `delta_id`, `rule_id`, `rule_name`, `status` (`DRAFT` $\rightarrow$ `APPROVED` $\rightarrow$ `DEPLOYED`), `rule_ir_snapshot` (JSONB), `author_email` |
| `approval_decisions` | Individual approver votes & change requests | `id`, `workflow_id`, `bank_id`, `approver_role`, `decision` (`APPROVED`/`REJECTED`/`CHANGES_REQUESTED`), `comments` |
| `rule_versions` | Immutable rule version history (v1.0, v1.1, v2.0) | `id`, `rule_id`, `bank_id`, `version_number`, `rule_ir_snapshot` (JSONB), `is_active` |
| `rule_test_suites` | Simulation test suites | `id`, `bank_id`, `rule_id`, `rule_version`, `suite_name` |
| `rule_test_cases` | Synthetic test cases (Positive, Negative, Boundary) | `id`, `suite_id`, `bank_id`, `test_type`, `scenario_name`, `input_data` (JSONB), `expected_result` (JSONB) |
| `rule_test_runs` | Test suite execution results | `id`, `suite_id`, `bank_id`, `total_test_cases`, `passed_tests`, `pass_percentage`, `status` (`PASSED`/`FAILED`) |
| `deployment_targets` | Target systems (Core Banking, Payment Switch, LOS) | `id`, `bank_id`, `name`, `target_type` (`REST`/`SQL`/`ENGINE`), `environment` (`DEVELOPMENT`/`PRODUCTION`) |
| `deployment_records` | Production deployment status | `id`, `bank_id`, `package_id`, `target_id`, `deployment_mode`, `status` (`DEPLOYING`/`ACTIVE`/`ROLLED_BACK`) |
| `rollback_records` | One-click rollback audit records | `id`, `bank_id`, `deployment_id`, `deployed_version`, `restored_version`, `reason`, `status` |
| `audit_events` | Append-only immutable compliance audit trail | `id`, `bank_id`, `actor_email`, `action`, `resource_type`, `previous_state` (JSONB), `new_state` (JSONB), `ip_address` |
| `notifications` | Compliance notifications & alerts | `id`, `bank_id`, `recipient_email`, `event_type`, `title`, `message`, `is_read` |

---

## 5. How to Connect to the Backend AI Engine (FastAPI)

For AI analysis, Universal Rule IR extraction, and simulation testing, call the FastAPI backend:

* **Base URL**: `https://virtusa-agent.onrender.com`
* **Authorization Header**: `Authorization: Bearer 0Zh3yr-Srn3juPBBl3IUSgV_2HDz-4WIrmP1uyDC_5E`

### Helper Client (`src/lib/cidanApi.js`)
```javascript
import axios from 'axios';

const API_BASE = import.meta.env.VITE_CIDAN_API_URL || 'https://virtusa-agent.onrender.com';
const API_TOKEN = import.meta.env.VITE_CIDAN_API_TOKEN || '0Zh3yr-Srn3juPBBl3IUSgV_2HDz-4WIrmP1uyDC_5E';

export const cidanApi = axios.create({
  baseURL: API_BASE,
  headers: {
    'Authorization': `Bearer ${API_TOKEN}`,
    'Content-Type': 'application/json',
  },
});

// 1. Run Delta Analysis
export async function runDeltaAnalysis(circularNumber, circularText, bankId) {
  const response = await cidanApi.post('/deltas/analyze', {
    analysis_name: `Analysis for ${circularNumber}`,
    circular_number: circularNumber,
    circular_text: circularText,
    bank_id: bankId,
  });
  return response.data;
}

// 2. Fetch Active Deltas
export async function getDeltas() {
  const response = await cidanApi.get('/deltas');
  return response.data;
}

// 3. Generate Synthetic Test Cases
export async function generateTestCases(ruleIr, bankId) {
  const response = await cidanApi.post('/testing/generate-cases', {
    rule_ir: ruleIr,
    bank_id: bankId,
  });
  return response.data;
}

// 4. Submit Approval Action (Approve / Reject / Changes Requested)
export async function submitApprovalAction(workflowId, action, reviewerEmail, note) {
  const response = await cidanApi.post(`/approvals/${workflowId}/action`, {
    action: action, // 'APPROVE', 'REJECT', or 'REQUEST_CHANGES'
    reviewer_email: reviewerEmail,
    note: note,
  });
  return response.data;
}
```

---

## 6. How SMTP / OTP Email Delivery Works

### Security Rule
> **Browsers cannot make direct TCP connections to SMTP Port 587.** In React, never put raw SMTP passwords in frontend code.

### The 2 Ways to Handle OTP in React

#### Option 1: Call Backend OTP Dispatch (Fastest & Most Secure)
The Render backend has secure server-side SMTP configured. Call the endpoint directly from your React app:

```javascript
// Request a 6-digit OTP email
export async function requestOtp(email) {
  const response = await cidanApi.post('/auth/dispatch-otp', {
    email: email,
    purpose: 'COMPLIANCE_PORTAL_LOGIN'
  });
  return response.data; // { status: "SENT", expiry_minutes: 5 }
}
```

#### Option 2: If using Next.js API Routes (`pages/api/send-otp.js`)
If your friend is using Next.js and wants to dispatch directly from their server:
```javascript
import nodemailer from 'nodemailer';

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || 'smtp.gmail.com',
  port: parseInt(process.env.SMTP_PORT || '587'),
  secure: false, // TLS
  auth: {
    user: process.env.SMTP_USERNAME || 'unknownhacker3d@gmail.com',
    pass: process.env.SMTP_PASSWORD || 'munr mayy tdfc mzyl',
  },
});

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end();
  const { email, otp } = req.body;

  try {
    await transporter.sendMail({
      from: '"CIDAN Regulatory AI" <unknownhacker3d@gmail.com>',
      to: email,
      subject: `[CIDAN AI] Your Verification Code: ${otp}`,
      html: `
        <div style="font-family: sans-serif; padding: 20px;">
          <h2>CIDAN Compliance Access Verification</h2>
          <p>Your one-time authorization code is:</p>
          <h1 style="color: #4F46E5; letter-spacing: 4px;">${otp}</h1>
          <p>This code will expire in 5 minutes. Do not share it with anyone.</p>
        </div>
      `,
    });
    res.status(200).json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}
```

---

## 7. Recommended React Tech Stack & Packages

To mirror the design and capabilities of the existing CIDAN platform, install:

```bash
# 1. Supabase Client & API
npm install @supabase/supabase-js axios

# 2. UI Components & Icons
npm install lucide-react clsx tailwind-merge

# 3. Tables & Animation
npm install @tanstack/react-table framer-motion

# 4. Notifications & Modals
npm install react-hot-toast
```

---

## 8. Summary Checklist for Your Friend

- [x] Create `.env` file with `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`.
- [x] Initialize Supabase client in `src/lib/supabase.js`.
- [x] Connect to tables (`existing_rules`, `delta_analyses`, `approval_workflows`, `notifications`).
- [x] Call Render backend (`https://virtusa-agent.onrender.com`) with Bearer token for AI Delta Analysis.
- [x] Use server-side OTP email dispatch for compliance user login.

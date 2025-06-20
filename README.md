# Scout Analytics Dashboard

Enterprise-grade retail analytics dashboard with comprehensive data model, RLS security, and full dashboard coverage.

## 🚀 Quick Start

### Prerequisites

- Node.js 18+
- Docker Desktop (for local Supabase)
- Supabase CLI

```bash
# Install Supabase CLI
npm install -g supabase

# Install Docker Desktop
# Download from: https://docs.docker.com/desktop/
```

### 1. Setup Database

```bash
# Clone and navigate to project
cd /Users/tbwa/Documents/GitHub/new-mvp

# Install dependencies
npm install

# Start Docker Desktop first, then:
supabase start

# Run migrations
supabase db push

# Generate TypeScript types
supabase gen types typescript --local > src/types/database.ts
```

### 2. Environment Configuration

Create `.env.local`:

```bash
# Supabase Configuration (Local Development)
NEXT_PUBLIC_SUPABASE_URL=http://localhost:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key-from-supabase-start
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-from-supabase-start

# App Configuration
NEXT_PUBLIC_APP_NAME=Scout Analytics
NEXT_PUBLIC_APP_VERSION=1.0.0
```

### 3. Start Development

```bash
# Start the development server
npm run dev

# Open browser to http://localhost:3000
```

### 4. Generate Additional Data

```bash
# Generate 5,000 additional transactions
node scripts/generateMockTransactions.js --count 5000

# Import to database (if needed)
# The seed data is automatically loaded with migrations
```

## 📊 Features

### Dashboard Panels
- ✅ **Transaction Trends** - Time series, heatmaps, regional analysis
- ✅ **Product Mix & SKU Analysis** - Category performance, brand analysis, Pareto charts
- ✅ **Consumer Behavior** - Request patterns, acceptance rates, substitution analysis
- ✅ **Consumer Profiling** - Demographic insights, RFM segmentation, journey funnel
- ✅ **AI Recommendations** - Anomaly detection and insights

### Data Model
- **12 core tables** with full relationships
- **18,000+ transaction records** with realistic Philippine market data
- **500+ products** from major FMCG brands (TBWA clients + competitors)
- **Multi-region coverage** (NCR, Central Luzon, Calabarzon, Visayas, Davao)

### Security Features
- **Row-Level Security (RLS)** on all tables
- **5-tier role system** (super_admin, regional_manager, store_manager, analyst, api_service)
- **Multi-tenant architecture** with region/store-based access control
- **Comprehensive audit logging** for all data changes

### Performance
- **Materialized views** for fast dashboard loading
- **Optimized indexes** on all query paths
- **Automatic data archival** for old records
- **Real-time notifications** for high-value transactions and errors

## 🛠 Development

### Database Management

```bash
# Database operations
./scripts/setup-database.sh start     # Start local DB
./scripts/setup-database.sh stop      # Stop local DB
./scripts/setup-database.sh migrate   # Run migrations
./scripts/setup-database.sh seed      # Add sample data
./scripts/setup-database.sh reset     # Fresh start
./scripts/setup-database.sh validate  # Verify setup

# View database
open http://localhost:54323  # Supabase Studio
```

### Testing

```bash
# Run tests
npm test

# Run E2E tests
npm run test:e2e

# Generate coverage report
npm run test:coverage
```

### Code Quality

```bash
# Lint code
npm run lint

# Type checking
npm run typecheck

# Verify all checks pass
npm run verify
```

## 📁 Project Structure

```
/Users/tbwa/Documents/GitHub/new-mvp/
├── src/
│   ├── components/
│   │   ├── dashboard/           # Dashboard panels
│   │   ├── ui/                  # Reusable UI components
│   │   └── charts/              # Chart components
│   ├── hooks/                   # Custom React hooks
│   ├── services/                # API services
│   ├── store/                   # State management
│   ├── types/                   # TypeScript definitions
│   └── utils/                   # Utility functions
├── supabase/
│   ├── migrations/              # Database migrations
│   │   ├── 001_init_schema.sql
│   │   ├── 002_rls_policies.sql
│   │   ├── 003_views.sql
│   │   ├── 004_triggers.sql
│   │   ├── 005_functions.sql
│   │   └── 007_seed_data.sql
│   └── config.toml
├── scripts/
│   ├── generateMockTransactions.js
│   ├── generate-seed-data.js
│   └── setup-database.sh
└── tests/
    ├── unit/                    # Unit tests
    └── e2e/                     # End-to-end tests
```

## 🗄️ Database Schema

### Core Tables
- `brands` - Product brands and manufacturers
- `products` - Product catalog with pricing
- `customers` - Customer demographics and segmentation
- `stores` - Store locations and details
- `transactions` - Transaction headers
- `transaction_items` - Line items within transactions
- `substitutions` - Product substitution tracking
- `devices` - Device inventory
- `device_health` - Real-time device monitoring
- `edge_logs` - System logs
- `request_behaviors` - Customer interaction patterns
- `customer_requests` - Customer service requests

### Analytical Views
- `vw_transaction_trends` - Time-based transaction analysis
- `vw_product_mix` - Product performance metrics
- `vw_substitutions` - Substitution patterns
- `vw_consumer_behavior` - Interaction analysis
- `vw_consumer_profile` - Customer segmentation

## 🔐 User Roles & Permissions

### Role Hierarchy
1. **super_admin** - Full system access
2. **regional_manager** - Region-specific access
3. **store_manager** - Store-specific access
4. **analyst** - Read-only analytics access
5. **api_service** - Application service access

### Access Control
- **Regional filtering** - Users see only their assigned regions
- **Store filtering** - Store managers see only their stores
- **Data isolation** - RLS ensures users can't access unauthorized data
- **Audit trails** - All changes are logged with user attribution

## 🚀 Deployment

### Production Deployment

1. **Set up Supabase project**:
   ```bash
   # Link to production project
   supabase link --project-ref your-project-ref
   
   # Deploy migrations
   supabase db push
   ```

2. **Deploy to Vercel**:
   ```bash
   # Deploy with verification
   npm run deploy
   ```

3. **Configure environment variables** in Vercel dashboard

### Environment Variables

```bash
# Production
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Optional: AI/ML endpoints
AZURE_ML_ENDPOINT=your-ml-endpoint
```

## 📝 API Documentation

### Analytics Functions
- `get_dashboard_kpis()` - KPI metrics with filtering
- `get_transaction_trends()` - Time-based trend analysis
- `get_product_performance()` - Product metrics and rankings
- `get_customer_segmentation()` - Customer analysis

### Utility Functions
- `get_database_health()` - System health metrics
- `clean_transaction_data()` - Data quality maintenance
- `refresh_analytical_views()` - Update materialized views

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Run verification: `npm run verify`
5. Submit a pull request

## 📜 License

MIT License - see LICENSE file for details.

---

**Built with enterprise-grade security, performance, and scalability in mind.**
# Scout Analytics Dashboard - Deployment Package

## Quick Deploy to Vercel

1. **Upload to GitHub:**
   ```bash
   git init
   git add .
   git commit -m "Initial Scout Analytics deployment"
   git remote add origin https://github.com/your-username/scout-analytics.git
   git push -u origin main
   ```

2. **Deploy to Vercel:**
   - Visit: https://vercel.com/new
   - Import your GitHub repository
   - Configure environment variables from .env.example
   - Deploy

3. **Set up Supabase:**
   - Create project at https://supabase.com/dashboard
   - Run migrations: `supabase db push`
   - Update environment variables with your Supabase URLs

## Quick Deploy to Azure Static Web Apps

1. **Create Azure Static Web App:**
   - Visit Azure Portal
   - Create new Static Web App
   - Connect to your GitHub repository

2. **Configure Build:**
   - Build command: `npm run build`
   - Output directory: `dist`

## Environment Variables Required

```bash
NEXT_PUBLIC_SUPABASE_URL=your-supabase-url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

## Database Setup

1. **Create Supabase project**
2. **Run migrations:**
   ```bash
   supabase link --project-ref your-project-ref
   supabase db push
   ```
3. **Verify setup:**
   ```bash
   supabase db query "SELECT COUNT(*) FROM brands;"
   ```

Your Scout Analytics Dashboard is ready for production!

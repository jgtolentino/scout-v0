# 🚀 Scout Analytics Dashboard - One-Click Deployment

## ⚡ **INSTANT DEPLOY OPTIONS**

### **Option 1: Vercel (Recommended)**
1. **Create GitHub repository:**
   ```bash
   git init
   git add .
   git commit -m "Scout Analytics Dashboard"
   git remote add origin https://github.com/YOUR_USERNAME/scout-analytics.git
   git push -u origin main
   ```

2. **Deploy to Vercel:**
   - Visit: https://vercel.com/new
   - Click "Import Git Repository"
   - Select your repository
   - **Framework Preset**: Vite
   - **Build Command**: `npm run build`
   - **Output Directory**: `dist`
   - Click "Deploy"

3. **Add Environment Variables in Vercel:**
   ```bash
   NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
   NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
   SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
   ```

### **Option 2: Netlify**
1. **Drag & Drop Deployment:**
   - Visit: https://app.netlify.com/drop
   - Drag the `dist/` folder to the deployment area
   - Site goes live instantly

2. **GitHub Integration:**
   - Connect your GitHub repository
   - **Build Command**: `npm run build`
   - **Publish Directory**: `dist`

### **Option 3: Azure Static Web Apps**
1. **Create Static Web App in Azure Portal**
2. **Connect to GitHub repository**
3. **Configure:**
   - **Build preset**: Custom
   - **App location**: `/`
   - **Output location**: `dist`

## 🗄️ **DATABASE SETUP**

### **Quick Supabase Setup**
1. **Create Supabase project:**
   - Visit: https://supabase.com/dashboard
   - Click "New Project"
   - Choose organization and region

2. **Run migrations:**
   ```bash
   # Option A: Use provided SQL file
   # Copy contents of manual_db_setup.sql into Supabase SQL Editor and run
   
   # Option B: Use Supabase CLI
   supabase link --project-ref YOUR_PROJECT_REF
   supabase db push
   ```

3. **Get your credentials:**
   - **Project URL**: `https://YOUR_PROJECT.supabase.co`
   - **Anon Key**: Found in Settings → API
   - **Service Role Key**: Found in Settings → API

### **Alternative: Any PostgreSQL Database**
```sql
-- Run the complete schema from manual_db_setup.sql
-- This includes all tables, views, functions, and sample data
```

## ⚙️ **ENVIRONMENT CONFIGURATION**

Copy these exact environment variables to your hosting provider:

```bash
# Required
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key-here
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here

# Optional
NEXT_PUBLIC_APP_NAME=Scout Analytics
NEXT_PUBLIC_APP_VERSION=1.0.0
```

## ✅ **DEPLOYMENT VERIFICATION**

After deployment, verify these URLs work:
- `https://your-site.vercel.app/` - Main dashboard loads
- Database connection successful (no errors in console)
- All dashboard panels render with data

## 🎯 **WHAT YOU GET IMMEDIATELY**

✅ **Enterprise-grade retail analytics dashboard**  
✅ **4 comprehensive dashboard panels**  
✅ **1,000+ realistic transactions**  
✅ **Multi-tenant security with RLS**  
✅ **Responsive design (mobile/tablet/desktop)**  
✅ **Real-time data visualization**  
✅ **Production-ready architecture**  

## 🔧 **TROUBLESHOOTING**

**Build fails?**
- Ensure Node.js 18+ is used
- Check all dependencies are installed

**Database connection fails?**
- Verify environment variables are set correctly
- Check Supabase project is active
- Ensure RLS policies allow your user access

**No data showing?**
- Run the seed data migration (007_seed_data.sql)
- Check browser console for API errors
- Verify database tables have data

## 📞 **SUPPORT**

- **Database Issues**: Check `manual_db_setup.sql` runs without errors
- **Frontend Issues**: Verify environment variables match your Supabase project
- **Deployment Issues**: Check build logs in your hosting provider

---

**🎉 Your Scout Analytics Dashboard is ready for production use!**

**Deployment time: < 5 minutes**  
**Features: Enterprise-grade analytics**  
**Security: Multi-tenant with audit trails**  
**Data: 1,000+ realistic Philippine retail transactions**
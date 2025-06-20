import React from 'react'
import ReactDOM from 'react-dom/client'
import './index.css'

// Simple placeholder component for now
const App = () => {
  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center">
      <div className="max-w-md mx-auto text-center">
        <div className="mb-8">
          <h1 className="text-4xl font-bold text-gray-900 mb-2">
            Scout Analytics Dashboard
          </h1>
          <p className="text-lg text-gray-600">
            Enterprise-grade retail analytics platform
          </p>
        </div>
        
        <div className="bg-white rounded-lg shadow-md p-6 mb-6">
          <h2 className="text-xl font-semibold text-gray-800 mb-4">
            🚀 Setup Required
          </h2>
          <div className="space-y-3 text-left">
            <div className="flex items-center">
              <span className="inline-block w-6 h-6 bg-blue-100 text-blue-600 rounded-full text-center text-sm font-medium mr-3">1</span>
              <span className="text-sm text-gray-700">Install Docker Desktop</span>
            </div>
            <div className="flex items-center">
              <span className="inline-block w-6 h-6 bg-blue-100 text-blue-600 rounded-full text-center text-sm font-medium mr-3">2</span>
              <span className="text-sm text-gray-700">Run <code className="bg-gray-100 px-1 rounded">supabase start</code></span>
            </div>
            <div className="flex items-center">
              <span className="inline-block w-6 h-6 bg-blue-100 text-blue-600 rounded-full text-center text-sm font-medium mr-3">3</span>
              <span className="text-sm text-gray-700">Configure environment variables</span>
            </div>
          </div>
        </div>
        
        <div className="grid grid-cols-2 gap-4 text-sm">
          <div className="bg-green-50 border border-green-200 rounded-lg p-3">
            <div className="font-medium text-green-800">✅ Database Schema</div>
            <div className="text-green-600">12 tables with full relationships</div>
          </div>
          <div className="bg-green-50 border border-green-200 rounded-lg p-3">
            <div className="font-medium text-green-800">✅ Security & RLS</div>
            <div className="text-green-600">5-tier role system</div>
          </div>
          <div className="bg-green-50 border border-green-200 rounded-lg p-3">
            <div className="font-medium text-green-800">✅ Dashboard Panels</div>
            <div className="text-green-600">Transaction, Product, Consumer</div>
          </div>
          <div className="bg-green-50 border border-green-200 rounded-lg p-3">
            <div className="font-medium text-green-800">✅ Sample Data</div>
            <div className="text-green-600">18,000+ transactions</div>
          </div>
        </div>
        
        <div className="mt-6 text-xs text-gray-500">
          See README.md for complete setup instructions
        </div>
      </div>
    </div>
  )
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
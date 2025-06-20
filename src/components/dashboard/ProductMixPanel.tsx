import React, { useState, useEffect } from 'react';
import { BarChart, Bar, PieChart, Pie, Cell, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, Treemap } from 'recharts';
import { Package, TrendingUp, Filter, Eye, Grid, List } from 'lucide-react';

interface ProductMixData {
  categoryMix: Array<{ category: string; revenue: number; transactions: number; margin: number; color: string }>;
  brandPerformance: Array<{ brand: string; revenue: number; marketShare: number; growth: number; category: string }>;
  skuAnalysis: Array<{ 
    sku: string; 
    name: string; 
    brand: string; 
    category: string; 
    revenue: number; 
    quantity: number; 
    margin: number;
    trend: 'up' | 'down' | 'stable';
  }>;
  paretoAnalysis: Array<{ sku: string; revenue: number; cumulativePercent: number }>;
}

interface Filters {
  dateRange: { start: string; end: string };
  category: string;
  brand: string;
  region: string;
  storeType: string;
  metricType: 'revenue' | 'quantity' | 'margin';
}

const ProductMixPanel: React.FC = () => {
  const [data, setData] = useState<ProductMixData | null>(null);
  const [loading, setLoading] = useState(true);
  const [filters, setFilters] = useState<Filters>({
    dateRange: { start: '2024-01-01', end: '2024-12-20' },
    category: 'all',
    brand: 'all',
    region: 'all',
    storeType: 'all',
    metricType: 'revenue'
  });
  const [activeView, setActiveView] = useState<'overview' | 'brands' | 'skus' | 'pareto'>('overview');
  const [viewMode, setViewMode] = useState<'chart' | 'table'>('chart');

  useEffect(() => {
    fetchProductMixData();
  }, [filters]);

  const fetchProductMixData = async () => {
    setLoading(true);
    try {
      const queryParams = new URLSearchParams({
        startDate: filters.dateRange.start,
        endDate: filters.dateRange.end,
        category: filters.category,
        brand: filters.brand,
        region: filters.region,
        storeType: filters.storeType,
        metric: filters.metricType
      });

      const response = await fetch(`/api/analytics/product-mix?${queryParams}`);
      const productData = await response.json();
      setData(productData);
    } catch (error) {
      console.error('Error fetching product mix data:', error);
    } finally {
      setLoading(false);
    }
  };

  const renderCategoryOverview = () => {
    if (!data?.categoryMix) return null;

    return (
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Category Revenue Pie Chart */}
        <div className="bg-white p-6 rounded-lg shadow-sm border">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Category Revenue Distribution</h3>
          <ResponsiveContainer width="100%" height={300}>
            <PieChart>
              <Pie
                data={data.categoryMix}
                cx="50%"
                cy="50%"
                labelLine={false}
                label={({ category, percent }) => `${category} ${(percent * 100).toFixed(1)}%`}
                outerRadius={100}
                fill="#8884d8"
                dataKey="revenue"
              >
                {data.categoryMix.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={entry.color} />
                ))}
              </Pie>
              <Tooltip formatter={(value) => [`₱${value.toLocaleString()}`, 'Revenue']} />
            </PieChart>
          </ResponsiveContainer>
        </div>

        {/* Category Performance Metrics */}
        <div className="bg-white p-6 rounded-lg shadow-sm border">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Category Performance</h3>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={data.categoryMix}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="category" fontSize={12} angle={-45} textAnchor="end" height={100} />
              <YAxis fontSize={12} />
              <Tooltip 
                formatter={(value, name) => [
                  name === 'margin' ? `${value}%` : value.toLocaleString(),
                  name === 'revenue' ? 'Revenue (₱)' : 
                  name === 'transactions' ? 'Transactions' : 'Margin %'
                ]}
              />
              <Legend />
              <Bar dataKey="revenue" fill="#3B82F6" name="Revenue" />
              <Bar dataKey="margin" fill="#10B981" name="Margin %" />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>
    );
  };

  const renderBrandAnalysis = () => {
    if (!data?.brandPerformance) return null;

    return (
      <div className="space-y-6">
        {viewMode === 'chart' ? (
          <div className="bg-white p-6 rounded-lg shadow-sm border">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold text-gray-900">Brand Performance</h3>
              <div className="text-sm text-gray-600">Market share vs Growth</div>
            </div>
            
            <ResponsiveContainer width="100%" height={400}>
              <BarChart data={data.brandPerformance} margin={{ bottom: 100 }}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis 
                  dataKey="brand" 
                  fontSize={12} 
                  angle={-45} 
                  textAnchor="end" 
                  height={100}
                  interval={0}
                />
                <YAxis yAxisId="left" fontSize={12} />
                <YAxis yAxisId="right" orientation="right" fontSize={12} />
                <Tooltip 
                  formatter={(value, name) => [
                    name === 'growth' ? `${value}%` : 
                    name === 'marketShare' ? `${value}%` : 
                    `₱${value.toLocaleString()}`,
                    name === 'revenue' ? 'Revenue' : 
                    name === 'marketShare' ? 'Market Share' : 'Growth'
                  ]}
                />
                <Legend />
                <Bar yAxisId="left" dataKey="revenue" fill="#3B82F6" name="Revenue (₱)" />
                <Bar yAxisId="right" dataKey="marketShare" fill="#10B981" name="Market Share %" />
                <Bar yAxisId="right" dataKey="growth" fill="#F59E0B" name="Growth %" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        ) : (
          <div className="bg-white rounded-lg shadow-sm border overflow-hidden">
            <div className="px-6 py-4 border-b border-gray-200">
              <h3 className="text-lg font-semibold text-gray-900">Brand Performance Table</h3>
            </div>
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Brand</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Category</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Revenue</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Market Share</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Growth</th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {data.brandPerformance.map((brand, index) => (
                    <tr key={index} className="hover:bg-gray-50">
                      <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">{brand.brand}</td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{brand.category}</td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">₱{brand.revenue.toLocaleString()}</td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{brand.marketShare.toFixed(1)}%</td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                          brand.growth > 0 ? 'bg-green-100 text-green-800' : 
                          brand.growth < 0 ? 'bg-red-100 text-red-800' : 
                          'bg-gray-100 text-gray-800'
                        }`}>
                          {brand.growth > 0 ? '+' : ''}{brand.growth.toFixed(1)}%
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </div>
    );
  };

  const renderSKUAnalysis = () => {
    if (!data?.skuAnalysis) return null;

    const topSKUs = data.skuAnalysis.slice(0, 20); // Show top 20 SKUs

    return (
      <div className="space-y-6">
        {viewMode === 'chart' ? (
          <div className="bg-white p-6 rounded-lg shadow-sm border">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold text-gray-900">Top SKU Performance</h3>
              <div className="text-sm text-gray-600">Top 20 by {filters.metricType}</div>
            </div>
            
            <ResponsiveContainer width="100%" height={500}>
              <BarChart data={topSKUs} layout="horizontal">
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis type="number" fontSize={12} />
                <YAxis 
                  type="category" 
                  dataKey="sku" 
                  fontSize={10} 
                  width={120}
                  tickFormatter={(value) => value.length > 15 ? `${value.slice(0, 15)}...` : value}
                />
                <Tooltip 
                  formatter={(value, name) => [
                    name === 'margin' ? `${value}%` : value.toLocaleString(),
                    name === 'revenue' ? 'Revenue (₱)' : 
                    name === 'quantity' ? 'Quantity' : 'Margin %'
                  ]}
                  labelFormatter={(label) => `SKU: ${label}`}
                />
                <Bar 
                  dataKey={filters.metricType} 
                  fill="#3B82F6"
                  name={filters.metricType === 'revenue' ? 'Revenue (₱)' : 
                        filters.metricType === 'quantity' ? 'Quantity' : 'Margin %'}
                />
              </BarChart>
            </ResponsiveContainer>
          </div>
        ) : (
          <div className="bg-white rounded-lg shadow-sm border overflow-hidden">
            <div className="px-6 py-4 border-b border-gray-200">
              <h3 className="text-lg font-semibold text-gray-900">SKU Analysis Table</h3>
            </div>
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">SKU</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Product Name</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Brand</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Category</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Revenue</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Quantity</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Margin</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Trend</th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {topSKUs.map((sku, index) => (
                    <tr key={index} className="hover:bg-gray-50">
                      <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">{sku.sku}</td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{sku.name}</td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{sku.brand}</td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{sku.category}</td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">₱{sku.revenue.toLocaleString()}</td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{sku.quantity.toLocaleString()}</td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{sku.margin.toFixed(1)}%</td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className={`inline-flex items-center ${
                          sku.trend === 'up' ? 'text-green-600' : 
                          sku.trend === 'down' ? 'text-red-600' : 
                          'text-gray-600'
                        }`}>
                          <TrendingUp className={`h-4 w-4 ${
                            sku.trend === 'down' ? 'rotate-180' : 
                            sku.trend === 'stable' ? 'rotate-90' : ''
                          }`} />
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </div>
    );
  };

  const renderParetoAnalysis = () => {
    if (!data?.paretoAnalysis) return null;

    return (
      <div className="bg-white p-6 rounded-lg shadow-sm border">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-semibold text-gray-900">Pareto Analysis (80/20 Rule)</h3>
          <div className="text-sm text-gray-600">SKU Revenue Distribution</div>
        </div>
        
        <ResponsiveContainer width="100%" height={400}>
          <BarChart data={data.paretoAnalysis.slice(0, 50)}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis 
              dataKey="sku" 
              fontSize={10} 
              angle={-90} 
              textAnchor="end" 
              height={100}
              interval={4}
            />
            <YAxis yAxisId="left" fontSize={12} />
            <YAxis yAxisId="right" orientation="right" fontSize={12} />
            <Tooltip 
              formatter={(value, name) => [
                name === 'cumulativePercent' ? `${value}%` : `₱${value.toLocaleString()}`,
                name === 'revenue' ? 'Revenue' : 'Cumulative %'
              ]}
            />
            <Legend />
            <Bar yAxisId="left" dataKey="revenue" fill="#3B82F6" name="Revenue (₱)" />
            <Bar yAxisId="right" dataKey="cumulativePercent" fill="#F59E0B" name="Cumulative %" />
          </BarChart>
        </ResponsiveContainer>
        
        <div className="mt-4 p-4 bg-blue-50 rounded-lg">
          <p className="text-sm text-blue-800">
            <strong>80/20 Insight:</strong> The top 20% of SKUs typically account for 80% of revenue. 
            Use this analysis to identify your most valuable products and optimize inventory accordingly.
          </p>
        </div>
      </div>
    );
  };

  const renderFilters = () => (
    <div className="bg-white p-4 rounded-lg shadow-sm border mb-6">
      <div className="grid grid-cols-1 md:grid-cols-6 gap-4">
        <div className="md:col-span-2">
          <label className="block text-sm font-medium text-gray-700 mb-1">Date Range</label>
          <div className="grid grid-cols-2 gap-2">
            <input
              type="date"
              value={filters.dateRange.start}
              onChange={(e) => setFilters(prev => ({
                ...prev,
                dateRange: { ...prev.dateRange, start: e.target.value }
              }))}
              className="border border-gray-300 rounded-md px-3 py-2 text-sm"
            />
            <input
              type="date"
              value={filters.dateRange.end}
              onChange={(e) => setFilters(prev => ({
                ...prev,
                dateRange: { ...prev.dateRange, end: e.target.value }
              }))}
              className="border border-gray-300 rounded-md px-3 py-2 text-sm"
            />
          </div>
        </div>
        
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Category</label>
          <select
            value={filters.category}
            onChange={(e) => setFilters(prev => ({ ...prev, category: e.target.value }))}
            className="w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
          >
            <option value="all">All Categories</option>
            <option value="Beverages">Beverages</option>
            <option value="Food & Beverage">Food & Beverage</option>
            <option value="Personal Care">Personal Care</option>
            <option value="Sportswear">Sportswear</option>
          </select>
        </div>
        
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Brand</label>
          <select
            value={filters.brand}
            onChange={(e) => setFilters(prev => ({ ...prev, brand: e.target.value }))}
            className="w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
          >
            <option value="all">All Brands</option>
            <option value="Coca-Cola">Coca-Cola</option>
            <option value="Pepsi">Pepsi</option>
            <option value="McDonald's">McDonald's</option>
            <option value="Jollibee">Jollibee</option>
          </select>
        </div>
        
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Region</label>
          <select
            value={filters.region}
            onChange={(e) => setFilters(prev => ({ ...prev, region: e.target.value }))}
            className="w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
          >
            <option value="all">All Regions</option>
            <option value="NCR">NCR</option>
            <option value="R03">Central Luzon</option>
            <option value="R04A">Calabarzon</option>
          </select>
        </div>
        
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Metric</label>
          <select
            value={filters.metricType}
            onChange={(e) => setFilters(prev => ({ 
              ...prev, 
              metricType: e.target.value as 'revenue' | 'quantity' | 'margin'
            }))}
            className="w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
          >
            <option value="revenue">Revenue</option>
            <option value="quantity">Quantity</option>
            <option value="margin">Margin</option>
          </select>
        </div>
      </div>
    </div>
  );

  const renderViewControls = () => (
    <div className="flex items-center justify-between mb-6">
      <div className="flex space-x-1">
        {[
          { key: 'overview', label: 'Overview', icon: Package },
          { key: 'brands', label: 'Brands', icon: TrendingUp },
          { key: 'skus', label: 'SKUs', icon: Filter },
          { key: 'pareto', label: 'Pareto', icon: Eye }
        ].map(({ key, label, icon: Icon }) => (
          <button
            key={key}
            onClick={() => setActiveView(key as typeof activeView)}
            className={`flex items-center px-4 py-2 rounded-md text-sm font-medium transition-colors ${
              activeView === key
                ? 'bg-blue-100 text-blue-700 border border-blue-200'
                : 'bg-white text-gray-600 border border-gray-200 hover:bg-gray-50'
            }`}
          >
            <Icon className="h-4 w-4 mr-2" />
            {label}
          </button>
        ))}
      </div>

      {(activeView === 'brands' || activeView === 'skus') && (
        <div className="flex space-x-1">
          <button
            onClick={() => setViewMode('chart')}
            className={`flex items-center px-3 py-2 rounded-md text-sm font-medium transition-colors ${
              viewMode === 'chart'
                ? 'bg-blue-100 text-blue-700'
                : 'bg-white text-gray-600 hover:bg-gray-50'
            }`}
          >
            <Grid className="h-4 w-4 mr-1" />
            Chart
          </button>
          <button
            onClick={() => setViewMode('table')}
            className={`flex items-center px-3 py-2 rounded-md text-sm font-medium transition-colors ${
              viewMode === 'table'
                ? 'bg-blue-100 text-blue-700'
                : 'bg-white text-gray-600 hover:bg-gray-50'
            }`}
          >
            <List className="h-4 w-4 mr-1" />
            Table
          </button>
        </div>
      )}
    </div>
  );

  if (loading) {
    return (
      <div className="space-y-6">
        <div className="animate-pulse">
          <div className="h-20 bg-gray-200 rounded-lg mb-6"></div>
          <div className="h-16 bg-gray-200 rounded-lg mb-6"></div>
          <div className="h-80 bg-gray-200 rounded-lg"></div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">Product Mix & SKU Analysis</h2>
          <p className="text-gray-600">Analyze product performance, brand share, and SKU profitability</p>
        </div>
        <Package className="h-8 w-8 text-blue-500" />
      </div>

      {renderFilters()}
      {renderViewControls()}

      {activeView === 'overview' && renderCategoryOverview()}
      {activeView === 'brands' && renderBrandAnalysis()}
      {activeView === 'skus' && renderSKUAnalysis()}
      {activeView === 'pareto' && renderParetoAnalysis()}
    </div>
  );
};

export default ProductMixPanel;
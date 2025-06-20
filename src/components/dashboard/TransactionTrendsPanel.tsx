import React, { useState, useEffect } from 'react';
import { LineChart, Line, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { Calendar, Clock, TrendingUp, Filter } from 'lucide-react';

interface TransactionTrendsData {
  hourly: Array<{ hour: string; transactions: number; revenue: number }>;
  daily: Array<{ date: string; transactions: number; revenue: number; isWeekend: boolean }>;
  weekly: Array<{ week: string; transactions: number; revenue: number }>;
  regional: Array<{ region: string; transactions: number; revenue: number; growth: number }>;
}

interface Filters {
  dateRange: { start: string; end: string };
  region: string;
  storeType: string;
  timeGranularity: 'hourly' | 'daily' | 'weekly';
}

const TransactionTrendsPanel: React.FC = () => {
  const [data, setData] = useState<TransactionTrendsData | null>(null);
  const [loading, setLoading] = useState(true);
  const [filters, setFilters] = useState<Filters>({
    dateRange: { start: '2024-01-01', end: '2024-12-20' },
    region: 'all',
    storeType: 'all',
    timeGranularity: 'daily'
  });
  const [activeView, setActiveView] = useState<'trends' | 'heatmap' | 'comparison'>('trends');

  useEffect(() => {
    fetchTransactionTrends();
  }, [filters]);

  const fetchTransactionTrends = async () => {
    setLoading(true);
    try {
      const queryParams = new URLSearchParams({
        startDate: filters.dateRange.start,
        endDate: filters.dateRange.end,
        region: filters.region,
        storeType: filters.storeType,
        granularity: filters.timeGranularity
      });

      const response = await fetch(`/api/analytics/transaction-trends?${queryParams}`);
      const trendsData = await response.json();
      setData(trendsData);
    } catch (error) {
      console.error('Error fetching transaction trends:', error);
    } finally {
      setLoading(false);
    }
  };

  const renderTimeSeriesChart = () => {
    if (!data) return null;

    const chartData = filters.timeGranularity === 'hourly' ? data.hourly :
                     filters.timeGranularity === 'weekly' ? data.weekly : data.daily;

    return (
      <div className="bg-white p-6 rounded-lg shadow-sm border">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-semibold text-gray-900">Transaction Volume Trends</h3>
          <div className="flex items-center space-x-2">
            <TrendingUp className="h-5 w-5 text-blue-500" />
            <span className="text-sm text-gray-600">{filters.timeGranularity} view</span>
          </div>
        </div>
        
        <ResponsiveContainer width="100%" height={300}>
          <LineChart data={chartData}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis 
              dataKey={filters.timeGranularity === 'hourly' ? 'hour' : 
                      filters.timeGranularity === 'weekly' ? 'week' : 'date'}
              fontSize={12}
            />
            <YAxis yAxisId="left" fontSize={12} />
            <YAxis yAxisId="right" orientation="right" fontSize={12} />
            <Tooltip 
              labelStyle={{ color: '#374151' }}
              contentStyle={{ backgroundColor: '#f9fafb', border: '1px solid #d1d5db' }}
            />
            <Legend />
            <Line 
              yAxisId="left"
              type="monotone" 
              dataKey="transactions" 
              stroke="#3B82F6" 
              strokeWidth={2}
              name="Transactions"
              dot={{ r: 4 }}
            />
            <Line 
              yAxisId="right"
              type="monotone" 
              dataKey="revenue" 
              stroke="#10B981" 
              strokeWidth={2}
              name="Revenue (₱)"
              dot={{ r: 4 }}
            />
          </LineChart>
        </ResponsiveContainer>
      </div>
    );
  };

  const renderHourlyHeatmap = () => {
    if (!data?.hourly) return null;

    const heatmapData = Array.from({ length: 7 }, (_, day) => 
      Array.from({ length: 24 }, (_, hour) => ({
        day,
        hour,
        value: data.hourly.find(h => parseInt(h.hour) === hour)?.transactions || 0
      }))
    ).flat();

    const maxValue = Math.max(...heatmapData.map(d => d.value));
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return (
      <div className="bg-white p-6 rounded-lg shadow-sm border">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-semibold text-gray-900">Hourly Activity Heatmap</h3>
          <Clock className="h-5 w-5 text-blue-500" />
        </div>
        
        <div className="grid grid-cols-24 gap-1">
          {/* Hour labels */}
          <div className="col-span-24 grid grid-cols-24 gap-1 mb-2">
            {Array.from({ length: 24 }, (_, i) => (
              <div key={i} className="text-xs text-center text-gray-500">
                {i}
              </div>
            ))}
          </div>
          
          {/* Heatmap grid */}
          {days.map((day, dayIndex) => (
            <React.Fragment key={day}>
              <div className="text-xs text-gray-500 mr-2">{day}</div>
              {Array.from({ length: 24 }, (_, hour) => {
                const dataPoint = heatmapData.find(d => d.day === dayIndex && d.hour === hour);
                const intensity = dataPoint ? dataPoint.value / maxValue : 0;
                const opacity = Math.max(0.1, intensity);
                
                return (
                  <div
                    key={`${dayIndex}-${hour}`}
                    className="aspect-square rounded-sm"
                    style={{ 
                      backgroundColor: `rgba(59, 130, 246, ${opacity})`,
                      border: '1px solid #e5e7eb'
                    }}
                    title={`${day} ${hour}:00 - ${dataPoint?.value || 0} transactions`}
                  />
                );
              })}
            </React.Fragment>
          ))}
        </div>
        
        <div className="flex items-center justify-between mt-4 text-sm text-gray-600">
          <span>Less activity</span>
          <div className="flex space-x-1">
            {[0.2, 0.4, 0.6, 0.8, 1.0].map(opacity => (
              <div
                key={opacity}
                className="w-3 h-3 rounded-sm"
                style={{ backgroundColor: `rgba(59, 130, 246, ${opacity})` }}
              />
            ))}
          </div>
          <span>More activity</span>
        </div>
      </div>
    );
  };

  const renderRegionalComparison = () => {
    if (!data?.regional) return null;

    return (
      <div className="bg-white p-6 rounded-lg shadow-sm border">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-semibold text-gray-900">Regional Performance</h3>
          <Filter className="h-5 w-5 text-blue-500" />
        </div>
        
        <ResponsiveContainer width="100%" height={300}>
          <BarChart data={data.regional} layout="horizontal">
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis type="number" fontSize={12} />
            <YAxis type="category" dataKey="region" fontSize={12} width={100} />
            <Tooltip 
              contentStyle={{ backgroundColor: '#f9fafb', border: '1px solid #d1d5db' }}
              formatter={(value, name) => [
                name === 'growth' ? `${value}%` : value.toLocaleString(),
                name === 'transactions' ? 'Transactions' : 
                name === 'revenue' ? 'Revenue (₱)' : 'Growth %'
              ]}
            />
            <Legend />
            <Bar dataKey="transactions" fill="#3B82F6" name="Transactions" />
            <Bar dataKey="growth" fill="#10B981" name="Growth %" />
          </BarChart>
        </ResponsiveContainer>
      </div>
    );
  };

  const renderFilters = () => (
    <div className="bg-white p-4 rounded-lg shadow-sm border mb-6">
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div>
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
            <option value="R07">Central Visayas</option>
            <option value="R11">Davao Region</option>
          </select>
        </div>
        
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Store Type</label>
          <select
            value={filters.storeType}
            onChange={(e) => setFilters(prev => ({ ...prev, storeType: e.target.value }))}
            className="w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
          >
            <option value="all">All Store Types</option>
            <option value="Sari-sari Store">Sari-sari Store</option>
            <option value="Convenience Store">Convenience Store</option>
            <option value="Grocery">Grocery</option>
            <option value="Supermarket">Supermarket</option>
          </select>
        </div>
        
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Time View</label>
          <select
            value={filters.timeGranularity}
            onChange={(e) => setFilters(prev => ({ 
              ...prev, 
              timeGranularity: e.target.value as 'hourly' | 'daily' | 'weekly'
            }))}
            className="w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
          >
            <option value="hourly">Hourly</option>
            <option value="daily">Daily</option>
            <option value="weekly">Weekly</option>
          </select>
        </div>
      </div>
    </div>
  );

  const renderViewToggle = () => (
    <div className="flex space-x-1 mb-6">
      {[
        { key: 'trends', label: 'Trends', icon: TrendingUp },
        { key: 'heatmap', label: 'Heatmap', icon: Clock },
        { key: 'comparison', label: 'Regional', icon: Filter }
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
          <h2 className="text-2xl font-bold text-gray-900">Transaction Trends</h2>
          <p className="text-gray-600">Analyze transaction patterns by time, location, and store type</p>
        </div>
        <Calendar className="h-8 w-8 text-blue-500" />
      </div>

      {renderFilters()}
      {renderViewToggle()}

      {activeView === 'trends' && renderTimeSeriesChart()}
      {activeView === 'heatmap' && renderHourlyHeatmap()}
      {activeView === 'comparison' && renderRegionalComparison()}
    </div>
  );
};

export default TransactionTrendsPanel;
import React, { useState, useEffect } from 'react';
import { BarChart, Bar, PieChart, Pie, Cell, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, FunnelChart, Funnel, LabelList } from 'recharts';
import { Users, Target, TrendingUp, Filter, UserCheck, MessageSquare } from 'lucide-react';

interface ConsumerBehaviorData {
  requestMethods: Array<{ method: string; count: number; successRate: number; color: string }>;
  acceptanceRates: Array<{ category: string; accepted: number; rejected: number; total: number }>;
  substitutionPatterns: Array<{ 
    originalCategory: string; 
    substituteCategory: string; 
    count: number; 
    satisfactionScore: number 
  }>;
  demographicBehavior: Array<{
    demographic: string;
    ageGroup: string;
    gender: string;
    avgRequestsPerSession: number;
    successRate: number;
    preferredMethod: string;
  }>;
  funnelData: Array<{ stage: string; count: number; conversionRate: number }>;
  timeBasedBehavior: Array<{ hour: number; requestCount: number; successRate: number }>;
}

interface Filters {
  dateRange: { start: string; end: string };
  demographic: string;
  region: string;
  storeType: string;
  requestType: string;
}

const ConsumerBehaviorPanel: React.FC = () => {
  const [data, setData] = useState<ConsumerBehaviorData | null>(null);
  const [loading, setLoading] = useState(true);
  const [filters, setFilters] = useState<Filters>({
    dateRange: { start: '2024-01-01', end: '2024-12-20' },
    demographic: 'all',
    region: 'all',
    storeType: 'all',
    requestType: 'all'
  });
  const [activeView, setActiveView] = useState<'requests' | 'acceptance' | 'substitutions' | 'demographics' | 'funnel'>('requests');

  useEffect(() => {
    fetchConsumerBehaviorData();
  }, [filters]);

  const fetchConsumerBehaviorData = async () => {
    setLoading(true);
    try {
      const queryParams = new URLSearchParams({
        startDate: filters.dateRange.start,
        endDate: filters.dateRange.end,
        demographic: filters.demographic,
        region: filters.region,
        storeType: filters.storeType,
        requestType: filters.requestType
      });

      const response = await fetch(`/api/analytics/consumer-behavior?${queryParams}`);
      const behaviorData = await response.json();
      setData(behaviorData);
    } catch (error) {
      console.error('Error fetching consumer behavior data:', error);
    } finally {
      setLoading(false);
    }
  };

  const renderRequestMethodAnalysis = () => {
    if (!data?.requestMethods) return null;

    return (
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Request Methods Distribution */}
        <div className="bg-white p-6 rounded-lg shadow-sm border">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Request Methods Distribution</h3>
          <ResponsiveContainer width="100%" height={300}>
            <PieChart>
              <Pie
                data={data.requestMethods}
                cx="50%"
                cy="50%"
                labelLine={false}
                label={({ method, percent }) => `${method} ${(percent * 100).toFixed(1)}%`}
                outerRadius={100}
                fill="#8884d8"
                dataKey="count"
              >
                {data.requestMethods.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={entry.color} />
                ))}
              </Pie>
              <Tooltip formatter={(value) => [value.toLocaleString(), 'Requests']} />
            </PieChart>
          </ResponsiveContainer>
        </div>

        {/* Success Rates by Method */}
        <div className="bg-white p-6 rounded-lg shadow-sm border">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Success Rates by Method</h3>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={data.requestMethods}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="method" fontSize={12} />
              <YAxis fontSize={12} domain={[0, 100]} />
              <Tooltip formatter={(value) => [`${value}%`, 'Success Rate']} />
              <Bar dataKey="successRate" fill="#10B981" name="Success Rate %" />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>
    );
  };

  const renderAcceptanceAnalysis = () => {
    if (!data?.acceptanceRates) return null;

    const acceptanceData = data.acceptanceRates.map(item => ({
      ...item,
      acceptanceRate: ((item.accepted / item.total) * 100).toFixed(1),
      rejectionRate: ((item.rejected / item.total) * 100).toFixed(1)
    }));

    return (
      <div className="space-y-6">
        <div className="bg-white p-6 rounded-lg shadow-sm border">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Recommendation Acceptance by Category</h3>
          <ResponsiveContainer width="100%" height={400}>
            <BarChart data={acceptanceData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="category" fontSize={12} angle={-45} textAnchor="end" height={100} />
              <YAxis fontSize={12} />
              <Tooltip 
                formatter={(value, name) => [
                  value.toLocaleString(),
                  name === 'accepted' ? 'Accepted' : 'Rejected'
                ]}
              />
              <Legend />
              <Bar dataKey="accepted" stackId="a" fill="#10B981" name="Accepted" />
              <Bar dataKey="rejected" stackId="a" fill="#EF4444" name="Rejected" />
            </BarChart>
          </ResponsiveContainer>
        </div>

        {/* Acceptance Rate Table */}
        <div className="bg-white rounded-lg shadow-sm border overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-200">
            <h3 className="text-lg font-semibold text-gray-900">Detailed Acceptance Metrics</h3>
          </div>
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Category</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Total Recommendations</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Accepted</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Rejected</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Acceptance Rate</th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {acceptanceData.map((item, index) => (
                  <tr key={index} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">{item.category}</td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{item.total.toLocaleString()}</td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-green-600">{item.accepted.toLocaleString()}</td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-red-600">{item.rejected.toLocaleString()}</td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center">
                        <div className="flex-1 bg-gray-200 rounded-full h-2 mr-2">
                          <div 
                            className="bg-green-500 h-2 rounded-full" 
                            style={{ width: `${item.acceptanceRate}%` }}
                          ></div>
                        </div>
                        <span className="text-sm font-medium text-gray-900">{item.acceptanceRate}%</span>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    );
  };

  const renderSubstitutionAnalysis = () => {
    if (!data?.substitutionPatterns) return null;

    return (
      <div className="space-y-6">
        <div className="bg-white p-6 rounded-lg shadow-sm border">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Product Substitution Patterns</h3>
          <ResponsiveContainer width="100%" height={400}>
            <BarChart data={data.substitutionPatterns} margin={{ bottom: 100 }}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis 
                dataKey="originalCategory"
                fontSize={12} 
                angle={-45} 
                textAnchor="end" 
                height={100}
              />
              <YAxis yAxisId="left" fontSize={12} />
              <YAxis yAxisId="right" orientation="right" fontSize={12} domain={[0, 5]} />
              <Tooltip 
                formatter={(value, name) => [
                  name === 'satisfactionScore' ? `${value}/5` : value.toLocaleString(),
                  name === 'count' ? 'Substitutions' : 'Satisfaction Score'
                ]}
              />
              <Legend />
              <Bar yAxisId="left" dataKey="count" fill="#3B82F6" name="Substitutions" />
              <Bar yAxisId="right" dataKey="satisfactionScore" fill="#F59E0B" name="Satisfaction Score" />
            </BarChart>
          </ResponsiveContainer>
        </div>

        {/* Substitution Flow Matrix */}
        <div className="bg-white p-6 rounded-lg shadow-sm border">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Category Substitution Flow</h3>
          <div className="overflow-x-auto">
            <table className="min-w-full">
              <thead>
                <tr className="border-b">
                  <th className="text-left py-2 px-4 font-medium text-gray-900">Original → Substitute</th>
                  <th className="text-left py-2 px-4 font-medium text-gray-900">Count</th>
                  <th className="text-left py-2 px-4 font-medium text-gray-900">Satisfaction</th>
                  <th className="text-left py-2 px-4 font-medium text-gray-900">Success Rate</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {data.substitutionPatterns.map((pattern, index) => (
                  <tr key={index} className="hover:bg-gray-50">
                    <td className="py-3 px-4">
                      <div className="flex items-center">
                        <span className="text-sm font-medium text-gray-900">{pattern.originalCategory}</span>
                        <span className="mx-2 text-gray-400">→</span>
                        <span className="text-sm text-gray-600">{pattern.substituteCategory}</span>
                      </div>
                    </td>
                    <td className="py-3 px-4 text-sm text-gray-900">{pattern.count.toLocaleString()}</td>
                    <td className="py-3 px-4">
                      <div className="flex items-center">
                        <span className="text-sm text-gray-900">{pattern.satisfactionScore.toFixed(1)}/5</span>
                        <div className="ml-2 flex">
                          {[1, 2, 3, 4, 5].map((star) => (
                            <div
                              key={star}
                              className={`h-3 w-3 ${
                                star <= pattern.satisfactionScore ? 'text-yellow-400' : 'text-gray-300'
                              }`}
                            >
                              ★
                            </div>
                          ))}
                        </div>
                      </div>
                    </td>
                    <td className="py-3 px-4">
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                        pattern.satisfactionScore >= 4 ? 'bg-green-100 text-green-800' :
                        pattern.satisfactionScore >= 3 ? 'bg-yellow-100 text-yellow-800' :
                        'bg-red-100 text-red-800'
                      }`}>
                        {pattern.satisfactionScore >= 4 ? 'High' :
                         pattern.satisfactionScore >= 3 ? 'Medium' : 'Low'}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    );
  };

  const renderDemographicAnalysis = () => {
    if (!data?.demographicBehavior) return null;

    return (
      <div className="space-y-6">
        <div className="bg-white p-6 rounded-lg shadow-sm border">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Behavior by Demographics</h3>
          <ResponsiveContainer width="100%" height={400}>
            <BarChart data={data.demographicBehavior}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="demographic" fontSize={12} angle={-45} textAnchor="end" height={100} />
              <YAxis yAxisId="left" fontSize={12} />
              <YAxis yAxisId="right" orientation="right" fontSize={12} domain={[0, 100]} />
              <Tooltip 
                formatter={(value, name) => [
                  name === 'successRate' ? `${value}%` : value.toFixed(1),
                  name === 'avgRequestsPerSession' ? 'Avg Requests/Session' : 'Success Rate %'
                ]}
              />
              <Legend />
              <Bar yAxisId="left" dataKey="avgRequestsPerSession" fill="#3B82F6" name="Avg Requests/Session" />
              <Bar yAxisId="right" dataKey="successRate" fill="#10B981" name="Success Rate %" />
            </BarChart>
          </ResponsiveContainer>
        </div>

        {/* Demographic Details Table */}
        <div className="bg-white rounded-lg shadow-sm border overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-200">
            <h3 className="text-lg font-semibold text-gray-900">Demographic Behavior Details</h3>
          </div>
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Demographic</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Age Group</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Gender</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Avg Requests</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Success Rate</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Preferred Method</th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {data.demographicBehavior.map((demo, index) => (
                  <tr key={index} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">{demo.demographic}</td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-600">{demo.ageGroup}</td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-600">{demo.gender}</td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{demo.avgRequestsPerSession.toFixed(1)}</td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                        demo.successRate >= 80 ? 'bg-green-100 text-green-800' :
                        demo.successRate >= 60 ? 'bg-yellow-100 text-yellow-800' :
                        'bg-red-100 text-red-800'
                      }`}>
                        {demo.successRate.toFixed(1)}%
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-600">{demo.preferredMethod}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    );
  };

  const renderFunnelAnalysis = () => {
    if (!data?.funnelData) return null;

    return (
      <div className="bg-white p-6 rounded-lg shadow-sm border">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Customer Journey Funnel</h3>
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div>
            <ResponsiveContainer width="100%" height={400}>
              <FunnelChart>
                <Funnel
                  dataKey="count"
                  data={data.funnelData}
                  fill="#3B82F6"
                >
                  <LabelList position="center" fill="#fff" stroke="none" />
                </Funnel>
                <Tooltip formatter={(value) => [value.toLocaleString(), 'Count']} />
              </FunnelChart>
            </ResponsiveContainer>
          </div>
          
          <div className="space-y-4">
            <h4 className="font-medium text-gray-900">Conversion Rates</h4>
            {data.funnelData.map((stage, index) => (
              <div key={index} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                <span className="text-sm font-medium text-gray-700">{stage.stage}</span>
                <div className="text-right">
                  <div className="text-sm font-medium text-gray-900">{stage.count.toLocaleString()}</div>
                  <div className="text-xs text-gray-500">{stage.conversionRate.toFixed(1)}% conversion</div>
                </div>
              </div>
            ))}
          </div>
        </div>
        
        <div className="mt-6 p-4 bg-blue-50 rounded-lg">
          <p className="text-sm text-blue-800">
            <strong>Funnel Insights:</strong> Track customer journey from initial request to successful completion. 
            Identify drop-off points to optimize the experience and improve conversion rates.
          </p>
        </div>
      </div>
    );
  };

  const renderFilters = () => (
    <div className="bg-white p-4 rounded-lg shadow-sm border mb-6">
      <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
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
          <label className="block text-sm font-medium text-gray-700 mb-1">Demographic</label>
          <select
            value={filters.demographic}
            onChange={(e) => setFilters(prev => ({ ...prev, demographic: e.target.value }))}
            className="w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
          >
            <option value="all">All Demographics</option>
            <option value="18-25">18-25 Years</option>
            <option value="26-35">26-35 Years</option>
            <option value="36-45">36-45 Years</option>
            <option value="46+">46+ Years</option>
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
          </select>
        </div>
        
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Request Type</label>
          <select
            value={filters.requestType}
            onChange={(e) => setFilters(prev => ({ ...prev, requestType: e.target.value }))}
            className="w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
          >
            <option value="all">All Request Types</option>
            <option value="product_search">Product Search</option>
            <option value="recommendation">Recommendation</option>
            <option value="substitution">Substitution</option>
          </select>
        </div>
      </div>
    </div>
  );

  const renderViewToggle = () => (
    <div className="flex space-x-1 mb-6">
      {[
        { key: 'requests', label: 'Request Methods', icon: MessageSquare },
        { key: 'acceptance', label: 'Acceptance', icon: UserCheck },
        { key: 'substitutions', label: 'Substitutions', icon: TrendingUp },
        { key: 'demographics', label: 'Demographics', icon: Users },
        { key: 'funnel', label: 'Journey Funnel', icon: Target }
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
          <h2 className="text-2xl font-bold text-gray-900">Consumer Behavior & Profiling</h2>
          <p className="text-gray-600">Analyze customer interaction patterns, preferences, and journey optimization</p>
        </div>
        <Users className="h-8 w-8 text-blue-500" />
      </div>

      {renderFilters()}
      {renderViewToggle()}

      {activeView === 'requests' && renderRequestMethodAnalysis()}
      {activeView === 'acceptance' && renderAcceptanceAnalysis()}
      {activeView === 'substitutions' && renderSubstitutionAnalysis()}
      {activeView === 'demographics' && renderDemographicAnalysis()}
      {activeView === 'funnel' && renderFunnelAnalysis()}
    </div>
  );
};

export default ConsumerBehaviorPanel;
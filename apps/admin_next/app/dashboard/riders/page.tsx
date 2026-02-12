'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { apiFetch } from '@/components/api';
import StatusBadge from '@/components/status-badge';

const STATUS_TABS = ['ALL', 'PENDING_APPROVAL', 'APPROVED', 'SUSPENDED', 'REJECTED'];

export default function RidersPage() {
  const [riders, setRiders] = useState<any[]>([]);
  const [filter, setFilter] = useState('ALL');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      setLoading(true);
      try {
        const url = filter === 'ALL'
          ? '/riders/admin/list'
          : `/riders/admin/list?status=${filter}`;
        const data = await apiFetch(url);
        setRiders(Array.isArray(data) ? data : []);
      } catch (e) {
        console.error(e);
      }
      setLoading(false);
    }
    load();
  }, [filter]);

  return (
    <div>
      <h1 className="text-2xl font-bold text-gray-800 mb-6">Riders</h1>

      {/* Tabs */}
      <div className="flex gap-2 mb-6 flex-wrap">
        {STATUS_TABS.map((s) => (
          <button
            key={s}
            onClick={() => setFilter(s)}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
              filter === s
                ? 'bg-blue-600 text-white'
                : 'bg-white text-gray-600 hover:bg-gray-100 border'
            }`}
          >
            {s.replace(/_/g, ' ')}
          </button>
        ))}
      </div>

      {/* Table */}
      {loading ? (
        <div className="text-center py-12 text-gray-500">Loading...</div>
      ) : riders.length === 0 ? (
        <div className="text-center py-12 text-gray-500">No riders found</div>
      ) : (
        <div className="bg-white rounded-lg shadow overflow-hidden">
          <table className="w-full text-left">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-xs font-medium text-gray-500 uppercase">Name</th>
                <th className="px-6 py-3 text-xs font-medium text-gray-500 uppercase">Phone</th>
                <th className="px-6 py-3 text-xs font-medium text-gray-500 uppercase">Status</th>
                <th className="px-6 py-3 text-xs font-medium text-gray-500 uppercase">Vehicle</th>
                <th className="px-6 py-3 text-xs font-medium text-gray-500 uppercase">Insurance Expiry</th>
                <th className="px-6 py-3 text-xs font-medium text-gray-500 uppercase">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {riders.map((rider) => {
                const insurance = rider.documents?.[0];
                const expiryDate = insurance?.expiryDate
                  ? new Date(insurance.expiryDate).toLocaleDateString()
                  : 'N/A';
                const isExpired = insurance?.expiryDate && new Date(insurance.expiryDate) < new Date();

                return (
                  <tr key={rider.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 font-medium">{rider.user?.name || 'Unnamed'}</td>
                    <td className="px-6 py-4 text-gray-600">{rider.user?.phone}</td>
                    <td className="px-6 py-4"><StatusBadge status={rider.status} /></td>
                    <td className="px-6 py-4 text-gray-600">{rider.vehicle?.model || '-'}</td>
                    <td className="px-6 py-4">
                      <span className={isExpired ? 'text-red-600 font-medium' : ''}>
                        {expiryDate}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <Link
                        href={`/dashboard/riders/${rider.id}`}
                        className="text-blue-600 hover:text-blue-800 text-sm font-medium"
                      >
                        View Details
                      </Link>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

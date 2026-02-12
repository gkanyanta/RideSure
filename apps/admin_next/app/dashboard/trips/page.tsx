'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { apiFetch } from '@/components/api';
import StatusBadge from '@/components/status-badge';

const STATUS_TABS = ['ALL', 'REQUESTED', 'ACCEPTED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'];

export default function TripsPage() {
  const [trips, setTrips] = useState<any[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [filter, setFilter] = useState('ALL');
  const [loading, setLoading] = useState(true);
  const limit = 20;

  useEffect(() => {
    async function load() {
      setLoading(true);
      try {
        const params = new URLSearchParams({ page: String(page), limit: String(limit) });
        if (filter !== 'ALL') params.set('status', filter);

        const data = await apiFetch(`/trips/admin/list?${params}`);
        setTrips(data.trips || []);
        setTotal(data.total || 0);
      } catch (e) {
        console.error(e);
      }
      setLoading(false);
    }
    load();
  }, [filter, page]);

  const totalPages = Math.ceil(total / limit);

  return (
    <div>
      <h1 className="text-2xl font-bold text-gray-800 mb-6">Trips</h1>

      {/* Tabs */}
      <div className="flex gap-2 mb-6 flex-wrap">
        {STATUS_TABS.map((s) => (
          <button
            key={s}
            onClick={() => { setFilter(s); setPage(1); }}
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

      {loading ? (
        <div className="text-center py-12 text-gray-500">Loading...</div>
      ) : trips.length === 0 ? (
        <div className="text-center py-12 text-gray-500">No trips found</div>
      ) : (
        <>
          <div className="bg-white rounded-lg shadow overflow-hidden">
            <table className="w-full text-left">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-xs font-medium text-gray-500 uppercase">Type</th>
                  <th className="px-6 py-3 text-xs font-medium text-gray-500 uppercase">Passenger</th>
                  <th className="px-6 py-3 text-xs font-medium text-gray-500 uppercase">Rider</th>
                  <th className="px-6 py-3 text-xs font-medium text-gray-500 uppercase">Status</th>
                  <th className="px-6 py-3 text-xs font-medium text-gray-500 uppercase">Fare</th>
                  <th className="px-6 py-3 text-xs font-medium text-gray-500 uppercase">Date</th>
                  <th className="px-6 py-3 text-xs font-medium text-gray-500 uppercase">Details</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {trips.map((trip) => (
                  <tr key={trip.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4">
                      <span className={`px-2 py-1 rounded text-xs font-medium ${
                        trip.type === 'DELIVERY'
                          ? 'bg-orange-100 text-orange-700'
                          : 'bg-blue-100 text-blue-700'
                      }`}>
                        {trip.type}
                      </span>
                    </td>
                    <td className="px-6 py-4">{trip.passenger?.name || trip.passenger?.phone || '-'}</td>
                    <td className="px-6 py-4">{trip.rider?.user?.name || '-'}</td>
                    <td className="px-6 py-4"><StatusBadge status={trip.status} /></td>
                    <td className="px-6 py-4">
                      {trip.actualFare
                        ? `K${trip.actualFare.toFixed(2)}`
                        : trip.estimatedFareLow
                        ? `K${trip.estimatedFareLow.toFixed(0)}-${trip.estimatedFareHigh?.toFixed(0)}`
                        : '-'}
                    </td>
                    <td className="px-6 py-4 text-gray-500 text-sm">
                      {new Date(trip.createdAt).toLocaleString()}
                    </td>
                    <td className="px-6 py-4">
                      <Link
                        href={`/dashboard/trips/${trip.id}`}
                        className="text-blue-600 hover:text-blue-800 text-sm font-medium"
                      >
                        View
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="flex justify-between items-center mt-4">
              <span className="text-sm text-gray-500">{total} total trips</span>
              <div className="flex gap-2">
                <button
                  onClick={() => setPage(p => Math.max(1, p - 1))}
                  disabled={page === 1}
                  className="px-3 py-1 border rounded text-sm disabled:opacity-50"
                >
                  Previous
                </button>
                <span className="px-3 py-1 text-sm">Page {page} of {totalPages}</span>
                <button
                  onClick={() => setPage(p => Math.min(totalPages, p + 1))}
                  disabled={page === totalPages}
                  className="px-3 py-1 border rounded text-sm disabled:opacity-50"
                >
                  Next
                </button>
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}

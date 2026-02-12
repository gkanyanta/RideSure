'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { apiFetch } from '@/components/api';
import StatusBadge from '@/components/status-badge';

export default function IncidentsPage() {
  const [incidents, setIncidents] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      try {
        const data = await apiFetch('/trips/admin/incidents');
        setIncidents(Array.isArray(data) ? data : []);
      } catch (e) {
        console.error(e);
      }
      setLoading(false);
    }
    load();
  }, []);

  return (
    <div>
      <h1 className="text-2xl font-bold text-gray-800 mb-6">Incidents</h1>

      {loading ? (
        <div className="text-center py-12 text-gray-500">Loading...</div>
      ) : incidents.length === 0 ? (
        <div className="text-center py-12 text-gray-500">No incidents reported</div>
      ) : (
        <div className="bg-white rounded-lg shadow overflow-hidden">
          <table className="w-full text-left">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-xs font-medium text-gray-500 uppercase">Severity</th>
                <th className="px-6 py-3 text-xs font-medium text-gray-500 uppercase">Reporter</th>
                <th className="px-6 py-3 text-xs font-medium text-gray-500 uppercase">Description</th>
                <th className="px-6 py-3 text-xs font-medium text-gray-500 uppercase">Trip</th>
                <th className="px-6 py-3 text-xs font-medium text-gray-500 uppercase">Status</th>
                <th className="px-6 py-3 text-xs font-medium text-gray-500 uppercase">Date</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {incidents.map((incident) => (
                <tr key={incident.id} className="hover:bg-gray-50">
                  <td className="px-6 py-4">
                    <StatusBadge status={incident.severity} />
                  </td>
                  <td className="px-6 py-4">
                    {incident.reporter?.name || incident.reporter?.phone || 'Unknown'}
                  </td>
                  <td className="px-6 py-4 max-w-xs truncate" title={incident.description}>
                    {incident.description}
                  </td>
                  <td className="px-6 py-4">
                    {incident.trip ? (
                      <Link
                        href={`/dashboard/trips/${incident.trip.id}`}
                        className="text-blue-600 hover:text-blue-800 text-sm"
                      >
                        {incident.trip.type} - {incident.trip.status}
                      </Link>
                    ) : '-'}
                  </td>
                  <td className="px-6 py-4">
                    <span className={`text-sm font-medium ${incident.resolved ? 'text-green-600' : 'text-red-600'}`}>
                      {incident.resolved ? 'Resolved' : 'Open'}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-gray-500 text-sm">
                    {new Date(incident.createdAt).toLocaleString()}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

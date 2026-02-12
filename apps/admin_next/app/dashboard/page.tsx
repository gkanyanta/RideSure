'use client';

import { useEffect, useState } from 'react';
import { apiFetch } from '@/components/api';
import StatsCard from '@/components/stats-card';

export default function DashboardPage() {
  const [stats, setStats] = useState({
    pendingRiders: 0,
    approvedRiders: 0,
    totalTrips: 0,
    activeTrips: 0,
    openIncidents: 0,
  });

  useEffect(() => {
    async function load() {
      try {
        const [riders, trips, incidents] = await Promise.all([
          apiFetch('/riders/admin/list'),
          apiFetch('/trips/admin/list?limit=1'),
          apiFetch('/trips/admin/incidents'),
        ]);

        const riderList = Array.isArray(riders) ? riders : [];
        const incidentList = Array.isArray(incidents) ? incidents : [];

        setStats({
          pendingRiders: riderList.filter((r: any) => r.status === 'PENDING_APPROVAL').length,
          approvedRiders: riderList.filter((r: any) => r.status === 'APPROVED').length,
          totalTrips: trips.total || 0,
          activeTrips: 0,
          openIncidents: incidentList.filter((i: any) => !i.resolved).length,
        });
      } catch (e) {
        console.error('Failed to load stats', e);
      }
    }
    load();
  }, []);

  return (
    <div>
      <h1 className="text-2xl font-bold text-gray-800 mb-6">Dashboard Overview</h1>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatsCard title="Pending Riders" value={stats.pendingRiders} icon="⏳" color="yellow" />
        <StatsCard title="Approved Riders" value={stats.approvedRiders} icon="✅" color="green" />
        <StatsCard title="Total Trips" value={stats.totalTrips} icon="🏍️" color="blue" />
        <StatsCard title="Open Incidents" value={stats.openIncidents} icon="🚨" color="red" />
      </div>
    </div>
  );
}

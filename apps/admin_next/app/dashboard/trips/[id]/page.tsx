'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { apiFetch } from '@/components/api';
import StatusBadge from '@/components/status-badge';

export default function TripDetailPage() {
  const { id } = useParams();
  const router = useRouter();
  const [trip, setTrip] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      try {
        const data = await apiFetch(`/trips/${id}`);
        setTrip(data);
      } catch (e) {
        console.error(e);
      }
      setLoading(false);
    }
    load();
  }, [id]);

  if (loading) return <div className="text-center py-12">Loading...</div>;
  if (!trip) return <div className="text-center py-12 text-red-500">Trip not found</div>;

  return (
    <div>
      <button onClick={() => router.back()} className="text-blue-600 hover:text-blue-800 mb-4 text-sm">
        &larr; Back to Trips
      </button>

      <div className="flex items-center gap-4 mb-6">
        <h1 className="text-2xl font-bold text-gray-800">Trip Details</h1>
        <span className={`px-2 py-1 rounded text-xs font-medium ${
          trip.type === 'DELIVERY' ? 'bg-orange-100 text-orange-700' : 'bg-blue-100 text-blue-700'
        }`}>{trip.type}</span>
        <StatusBadge status={trip.status} size="md" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Trip Info */}
        <div className="bg-white rounded-lg shadow p-6">
          <h2 className="text-lg font-semibold mb-4">Trip Info</h2>
          <dl className="space-y-3">
            <InfoRow label="Pickup" value={trip.pickupAddress} />
            {trip.pickupLandmark && <InfoRow label="Pickup Landmark" value={trip.pickupLandmark} />}
            <InfoRow label="Destination" value={trip.destinationAddress} />
            {trip.destinationLandmark && <InfoRow label="Dest Landmark" value={trip.destinationLandmark} />}
            <InfoRow label="Distance" value={trip.estimatedDistance ? `${trip.estimatedDistance.toFixed(2)} km` : 'N/A'} />
            <InfoRow label="Fare Estimate" value={trip.estimatedFareLow
              ? `K${trip.estimatedFareLow.toFixed(2)} - K${trip.estimatedFareHigh?.toFixed(2)}`
              : 'N/A'} />
            {trip.actualFare && <InfoRow label="Actual Fare" value={`K${trip.actualFare.toFixed(2)}`} />}
            {trip.shareCode && <InfoRow label="Share Code" value={trip.shareCode} />}
            {trip.type === 'DELIVERY' && (
              <>
                {trip.packageType && <InfoRow label="Package Type" value={trip.packageType} />}
                {trip.packageNotes && <InfoRow label="Package Notes" value={trip.packageNotes} />}
              </>
            )}
            {trip.cancelReason && <InfoRow label="Cancel Reason" value={trip.cancelReason} />}
          </dl>
        </div>

        {/* Participants */}
        <div className="space-y-6">
          <div className="bg-white rounded-lg shadow p-6">
            <h2 className="text-lg font-semibold mb-4">Passenger</h2>
            <p className="font-medium">{trip.passenger?.name || 'Unnamed'}</p>
            <p className="text-gray-500">{trip.passenger?.phone}</p>
          </div>

          {trip.rider && (
            <div className="bg-white rounded-lg shadow p-6">
              <h2 className="text-lg font-semibold mb-4">Rider</h2>
              <p className="font-medium">{trip.rider.user?.name || 'Unnamed'}</p>
              <p className="text-gray-500">{trip.rider.user?.phone}</p>
              {trip.rider.vehicle && (
                <p className="text-gray-500 mt-1">
                  {trip.rider.vehicle.model} • {trip.rider.vehicle.plateNumber}
                </p>
              )}
            </div>
          )}

          {trip.rating && (
            <div className="bg-white rounded-lg shadow p-6">
              <h2 className="text-lg font-semibold mb-4">Rating</h2>
              <div className="flex items-center gap-2">
                {Array.from({ length: 5 }, (_, i) => (
                  <span key={i} className={`text-2xl ${i < trip.rating.score ? 'text-yellow-500' : 'text-gray-300'}`}>
                    ★
                  </span>
                ))}
                <span className="text-gray-600 ml-2">{trip.rating.score}/5</span>
              </div>
              {trip.rating.comment && (
                <p className="text-gray-600 mt-2 italic">&ldquo;{trip.rating.comment}&rdquo;</p>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Event Log */}
      {trip.events && trip.events.length > 0 && (
        <div className="bg-white rounded-lg shadow p-6 mt-6">
          <h2 className="text-lg font-semibold mb-4">Event Log</h2>
          <div className="space-y-2">
            {trip.events.map((event: any) => (
              <div key={event.id} className="flex items-center gap-4 text-sm border-b pb-2 last:border-0">
                <span className="text-gray-400 w-40">
                  {new Date(event.createdAt).toLocaleString()}
                </span>
                <span className="font-medium">{event.event}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Timestamps */}
      <div className="bg-white rounded-lg shadow p-6 mt-6">
        <h2 className="text-lg font-semibold mb-4">Timestamps</h2>
        <dl className="grid grid-cols-2 lg:grid-cols-3 gap-4">
          <TimeRow label="Requested" value={trip.requestedAt} />
          <TimeRow label="Accepted" value={trip.acceptedAt} />
          <TimeRow label="Arrived" value={trip.arrivedAt} />
          <TimeRow label="Started" value={trip.startedAt} />
          <TimeRow label="Completed" value={trip.completedAt} />
          <TimeRow label="Cancelled" value={trip.cancelledAt} />
        </dl>
      </div>
    </div>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between">
      <dt className="text-gray-500">{label}</dt>
      <dd className="font-medium text-right max-w-[60%]">{value}</dd>
    </div>
  );
}

function TimeRow({ label, value }: { label: string; value: string | null }) {
  return (
    <div>
      <dt className="text-gray-500 text-sm">{label}</dt>
      <dd className="font-medium text-sm">
        {value ? new Date(value).toLocaleString() : '-'}
      </dd>
    </div>
  );
}

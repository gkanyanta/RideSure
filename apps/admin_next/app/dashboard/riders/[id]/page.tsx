'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { apiFetch, API_URL, getToken } from '@/components/api';
import StatusBadge from '@/components/status-badge';

export default function RiderDetailPage() {
  const { id } = useParams();
  const router = useRouter();
  const [rider, setRider] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);
  const [rejectReason, setRejectReason] = useState('');
  const [showRejectModal, setShowRejectModal] = useState(false);
  const [viewingDoc, setViewingDoc] = useState<string | null>(null);

  useEffect(() => {
    loadRider();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  async function loadRider() {
    try {
      const data = await apiFetch(`/riders/admin/${id}`);
      setRider(data);
    } catch (e) {
      console.error(e);
    }
    setLoading(false);
  }

  async function handleApprove() {
    setActionLoading(true);
    try {
      await apiFetch(`/riders/admin/${id}/review`, {
        method: 'PATCH',
        body: JSON.stringify({ action: 'APPROVED' }),
      });
      await loadRider();
    } catch (e: any) {
      alert(e.message);
    }
    setActionLoading(false);
  }

  async function handleReject() {
    if (!rejectReason.trim()) return alert('Please provide a reason');
    setActionLoading(true);
    try {
      await apiFetch(`/riders/admin/${id}/review`, {
        method: 'PATCH',
        body: JSON.stringify({ action: 'REJECTED', reason: rejectReason }),
      });
      setShowRejectModal(false);
      await loadRider();
    } catch (e: any) {
      alert(e.message);
    }
    setActionLoading(false);
  }

  function getDocUrl(docId: string) {
    const token = getToken();
    return `${API_URL}/riders/documents/${docId}/file?token=${token}`;
  }

  if (loading) return <div className="text-center py-12">Loading...</div>;
  if (!rider) return <div className="text-center py-12 text-red-500">Rider not found</div>;

  return (
    <div>
      <button onClick={() => router.back()} className="text-blue-600 hover:text-blue-800 mb-4 text-sm">
        &larr; Back to Riders
      </button>

      <div className="flex items-center gap-4 mb-6">
        <h1 className="text-2xl font-bold text-gray-800">{rider.user?.name || 'Unnamed Rider'}</h1>
        <StatusBadge status={rider.status} size="md" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Profile Info */}
        <div className="bg-white rounded-lg shadow p-6">
          <h2 className="text-lg font-semibold mb-4">Profile</h2>
          <dl className="space-y-3">
            <div className="flex justify-between">
              <dt className="text-gray-500">Phone</dt>
              <dd className="font-medium">{rider.user?.phone}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-gray-500">Status</dt>
              <dd><StatusBadge status={rider.status} /></dd>
            </div>
            {rider.vehicle && (
              <>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Vehicle</dt>
                  <dd className="font-medium">{rider.vehicle.model}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Plate Number</dt>
                  <dd className="font-medium">{rider.vehicle.plateNumber}</dd>
                </div>
                {rider.vehicle.color && (
                  <div className="flex justify-between">
                    <dt className="text-gray-500">Color</dt>
                    <dd>{rider.vehicle.color}</dd>
                  </div>
                )}
              </>
            )}
            {rider.rejectionReason && (
              <div>
                <dt className="text-gray-500">Rejection Reason</dt>
                <dd className="text-red-600 mt-1">{rider.rejectionReason}</dd>
              </div>
            )}
          </dl>
        </div>

        {/* Documents */}
        <div className="bg-white rounded-lg shadow p-6">
          <h2 className="text-lg font-semibold mb-4">Documents</h2>
          {rider.documents && rider.documents.length > 0 ? (
            <div className="space-y-4">
              {rider.documents.map((doc: any) => (
                <div key={doc.id || doc.type} className="border rounded-lg p-4">
                  <div className="flex items-center justify-between mb-2">
                    <span className="font-medium">{doc.type.replace(/_/g, ' ')}</span>
                    <StatusBadge status={doc.status} />
                  </div>
                  {doc.type === 'INSURANCE_CERTIFICATE' && (
                    <div className="text-sm text-gray-600 space-y-1 mb-2">
                      {doc.insurerName && <p>Insurer: {doc.insurerName}</p>}
                      {doc.policyNumber && <p>Policy: {doc.policyNumber}</p>}
                      {doc.expiryDate && (
                        <p className={new Date(doc.expiryDate) < new Date() ? 'text-red-600 font-medium' : ''}>
                          Expiry: {new Date(doc.expiryDate).toLocaleDateString()}
                        </p>
                      )}
                    </div>
                  )}
                  {doc.id && (
                    <button
                      onClick={() => setViewingDoc(viewingDoc === doc.id ? null : doc.id)}
                      className="text-blue-600 hover:text-blue-800 text-sm font-medium"
                    >
                      {viewingDoc === doc.id ? 'Hide' : 'View Document'}
                    </button>
                  )}
                  {viewingDoc === doc.id && doc.id && (
                    <div className="mt-3">
                      <img
                        src={getDocUrl(doc.id)}
                        alt={doc.type}
                        className="max-w-full rounded-lg border"
                        onError={(e) => {
                          (e.target as HTMLImageElement).style.display = 'none';
                          (e.target as HTMLImageElement).insertAdjacentHTML(
                            'afterend',
                            '<p class="text-red-500 text-sm">Failed to load document</p>'
                          );
                        }}
                      />
                    </div>
                  )}
                </div>
              ))}
            </div>
          ) : (
            <p className="text-gray-500">No documents uploaded yet</p>
          )}
        </div>
      </div>

      {/* Action buttons */}
      {(rider.status === 'PENDING_APPROVAL' || rider.status === 'REJECTED') && (
        <div className="mt-6 flex gap-4">
          <button
            onClick={handleApprove}
            disabled={actionLoading}
            className="px-6 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg font-medium disabled:opacity-50"
          >
            {actionLoading ? 'Processing...' : 'Approve Rider'}
          </button>
          {rider.status !== 'REJECTED' && (
            <button
              onClick={() => setShowRejectModal(true)}
              disabled={actionLoading}
              className="px-6 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg font-medium disabled:opacity-50"
            >
              Reject
            </button>
          )}
        </div>
      )}

      {/* Reject modal */}
      {showRejectModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 w-full max-w-md">
            <h3 className="text-lg font-semibold mb-4">Reject Rider</h3>
            <textarea
              value={rejectReason}
              onChange={(e) => setRejectReason(e.target.value)}
              placeholder="Reason for rejection..."
              className="w-full border rounded-lg p-3 mb-4 h-24"
            />
            <div className="flex gap-3 justify-end">
              <button
                onClick={() => setShowRejectModal(false)}
                className="px-4 py-2 bg-gray-200 rounded-lg"
              >
                Cancel
              </button>
              <button
                onClick={handleReject}
                disabled={actionLoading}
                className="px-4 py-2 bg-red-600 text-white rounded-lg disabled:opacity-50"
              >
                {actionLoading ? 'Rejecting...' : 'Confirm Reject'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

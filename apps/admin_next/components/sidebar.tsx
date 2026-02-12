'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useAuth } from './auth-provider';

const navItems = [
  { href: '/dashboard', label: 'Overview', icon: '📊' },
  { href: '/dashboard/riders', label: 'Riders', icon: '🏍️' },
  { href: '/dashboard/trips', label: 'Trips', icon: '📍' },
  { href: '/dashboard/incidents', label: 'Incidents', icon: '🚨' },
];

export default function Sidebar() {
  const pathname = usePathname();
  const { logout, user } = useAuth();

  return (
    <aside className="w-64 bg-gray-800 text-white min-h-screen flex flex-col">
      <div className="p-6 border-b border-gray-700">
        <h1 className="text-xl font-bold">RideSure</h1>
        <p className="text-gray-400 text-sm">Admin Dashboard</p>
      </div>

      <nav className="flex-1 py-4">
        {navItems.map((item) => {
          const active = pathname === item.href ||
            (item.href !== '/dashboard' && pathname.startsWith(item.href));
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex items-center px-6 py-3 text-sm transition-colors ${
                active
                  ? 'bg-gray-700 text-white border-r-4 border-blue-500'
                  : 'text-gray-300 hover:bg-gray-700 hover:text-white'
              }`}
            >
              <span className="mr-3">{item.icon}</span>
              {item.label}
            </Link>
          );
        })}
      </nav>

      <div className="p-4 border-t border-gray-700">
        <p className="text-gray-400 text-xs mb-2">{user?.name || user?.email}</p>
        <button
          onClick={logout}
          className="w-full px-4 py-2 text-sm bg-gray-700 hover:bg-gray-600 rounded transition-colors"
        >
          Logout
        </button>
      </div>
    </aside>
  );
}

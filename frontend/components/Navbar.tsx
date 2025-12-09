'use client';

import { Shield } from 'lucide-react';

export function Navbar() {
  return (
    <nav className="border-b border-white/10 bg-black/50 backdrop-blur-md sticky top-0 z-50">
      <div className="container mx-auto px-4 h-16 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className="p-2 bg-blue-500/10 rounded-lg">
            <Shield className="w-6 h-6 text-blue-500" />
          </div>
          <span className="text-xl font-bold bg-gradient-to-r from-blue-400 to-purple-500 bg-clip-text text-transparent">
            LaunchGuard
          </span>
        </div>

        {/* Reown AppKit connect button will be inserted here */}
        <appkit-button />
      </div>
    </nav>
  );
}

'use client';

import { ReactNode, useEffect } from 'react';
import '../lib/reown'; // Initialize AppKit

export function AppKitProvider({ children }: { children: ReactNode }) {
  useEffect(() => {
    // AppKit is initialized in lib/reown.ts
    // This component just ensures it's loaded before rendering children
  }, []);

  return <>{children}</>;
}

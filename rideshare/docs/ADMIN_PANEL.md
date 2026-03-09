# 🎛️ Admin Panel - لوحة التحكم

## Overview

لوحة تحكم منفصلة مبنية بـ Next.js لإدارة التطبيق بالكامل.

---

## Tech Stack

```
Framework: Next.js 14
Language: TypeScript
Styling: Tailwind CSS
UI Components: Shadcn/ui
Charts: Recharts
Backend: Firebase Admin SDK
Authentication: Firebase Admin (Custom)
```

---

## Project Structure

```
admin-panel/
├── pages/
│   ├── _app.tsx
│   ├── index.tsx              # Dashboard
│   ├── login.tsx
│   ├── trips/
│   │   ├── index.tsx          # All trips
│   │   └── [id].tsx           # Trip details
│   ├── users/
│   │   ├── index.tsx          # All users
│   │   └── [id].tsx           # User details
│   ├── payments/
│   │   ├── index.tsx          # All payments
│   │   └── [id].tsx           # Payment details
│   └── statistics.tsx
├── components/
│   ├── Layout/
│   │   ├── Sidebar.tsx
│   │   ├── Header.tsx
│   │   └── Layout.tsx
│   ├── Dashboard/
│   │   ├── StatsCard.tsx
│   │   ├── RecentTrips.tsx
│   │   └── PendingPayments.tsx
│   ├── Trips/
│   │   ├── TripCard.tsx
│   │   ├── TripTable.tsx
│   │   └── TripActions.tsx
│   ├── Users/
│   │   ├── UserCard.tsx
│   │   └── UserTable.tsx
│   └── Payments/
│       ├── PaymentCard.tsx
│       └── PaymentActions.tsx
├── lib/
│   ├── firebase-admin.ts
│   ├── auth.ts
│   └── utils.ts
├── public/
│   └── images/
└── package.json
```

---

## Setup

### 1. Initialize Next.js Project

```bash
npx create-next-app@latest admin-panel --typescript --tailwind --app
cd admin-panel
```

### 2. Install Dependencies

```bash
npm install firebase-admin next-auth
npm install -D @types/node
```

### 3. Firebase Admin Setup

**lib/firebase-admin.ts:**
```typescript
import * as admin from 'firebase-admin';

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    }),
  });
}

export const db = admin.firestore();
export const auth = admin.auth();
export const storage = admin.storage();
```

### 4. Environment Variables

**.env.local:**
```env
FIREBASE_PROJECT_ID=rideshare-5f785
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@rideshare-5f785.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"

NEXTAUTH_SECRET=your-secret-key
NEXTAUTH_URL=http://localhost:3000
```

---

## Features

### 1. Dashboard

**pages/index.tsx:**
```typescript
import { useState, useEffect } from 'react';
import { db } from '../lib/firebase-admin';
import StatsCard from '../components/Dashboard/StatsCard';
import RecentTrips from '../components/Dashboard/RecentTrips';
import PendingPayments from '../components/Dashboard/PendingPayments';

export default function Dashboard() {
  const [stats, setStats] = useState({
    totalTrips: 0,
    activeTrips: 0,
    totalUsers: 0,
    totalBookings: 0,
    pendingPayments: 0,
  });

  useEffect(() => {
    fetchStats();
  }, []);

  const fetchStats = async () => {
    // Fetch statistics from Firestore
    const tripsSnapshot = await db.collection('trips').get();
    const usersSnapshot = await db.collection('users').get();
    const bookingsSnapshot = await db.collection('bookings').get();
    const paymentsSnapshot = await db.collection('payments')
      .where('status', '==', 'pending')
      .get();

    setStats({
      totalTrips: tripsSnapshot.size,
      activeTrips: tripsSnapshot.docs.filter(
        doc => doc.data().status === 'active'
      ).length,
      totalUsers: usersSnapshot.size,
      totalBookings: bookingsSnapshot.size,
      pendingPayments: paymentsSnapshot.size,
    });
  };

  return (
    <div className="p-6">
      <h1 className="text-3xl font-bold mb-6">لوحة التحكم</h1>
      
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4 mb-6">
        <StatsCard title="إجمالي الرحلات" value={stats.totalTrips} />
        <StatsCard title="رحلات نشطة" value={stats.activeTrips} />
        <StatsCard title="إجمالي المستخدمين" value={stats.totalUsers} />
        <StatsCard title="إجمالي الحجوزات" value={stats.totalBookings} />
        <StatsCard 
          title="مدفوعات معلقة" 
          value={stats.pendingPayments} 
          highlight 
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <RecentTrips />
        <PendingPayments />
      </div>
    </div>
  );
}
```

---

### 2. Manage Trips

**pages/trips/index.tsx:**
```typescript
import { useState, useEffect } from 'react';
import { db } from '../../lib/firebase-admin';
import TripTable from '../../components/Trips/TripTable';

export default function TripsPage() {
  const [trips, setTrips] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('all'); // all, active, hidden, deleted

  useEffect(() => {
    fetchTrips();
  }, [filter]);

  const fetchTrips = async () => {
    setLoading(true);
    let query = db.collection('trips');
    
    if (filter !== 'all') {
      query = query.where('status', '==', filter);
    }
    
    const snapshot = await query.orderBy('createdAt', 'desc').get();
    const tripsData = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));
    
    setTrips(tripsData);
    setLoading(false);
  };

  const handleDelete = async (tripId: string) => {
    if (confirm('هل أنت متأكد من حذف هذه الرحلة؟')) {
      await db.collection('trips').doc(tripId).update({
        status: 'deleted',
      });
      fetchTrips();
    }
  };

  const handleHide = async (tripId: string) => {
    await db.collection('trips').doc(tripId).update({
      status: 'hidden',
    });
    fetchTrips();
  };

  return (
    <div className="p-6">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold">إدارة الرحلات</h1>
        <select
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
          className="px-4 py-2 border rounded"
        >
          <option value="all">الكل</option>
          <option value="active">نشطة</option>
          <option value="hidden">مخفية</option>
          <option value="deleted">محذوفة</option>
        </select>
      </div>

      {loading ? (
        <div>جاري التحميل...</div>
      ) : (
        <TripTable 
          trips={trips} 
          onDelete={handleDelete}
          onHide={handleHide}
        />
      )}
    </div>
  );
}
```

---

### 3. Manage Payments

**pages/payments/index.tsx:**
```typescript
import { useState, useEffect } from 'react';
import { db } from '../../lib/firebase-admin';
import PaymentCard from '../../components/Payments/PaymentCard';

export default function PaymentsPage() {
  const [payments, setPayments] = useState([]);
  const [filter, setFilter] = useState('pending'); // pending, approved, rejected

  useEffect(() => {
    fetchPayments();
  }, [filter]);

  const fetchPayments = async () => {
    const snapshot = await db.collection('payments')
      .where('status', '==', filter)
      .orderBy('createdAt', 'desc')
      .get();
    
    const paymentsData = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));
    
    setPayments(paymentsData);
  };

  const handleApprove = async (paymentId: string) => {
    await db.collection('payments').doc(paymentId).update({
      status: 'approved',
      approvedAt: new Date(),
      approvedBy: 'admin', // Get from auth
    });
    fetchPayments();
  };

  const handleReject = async (paymentId: string, reason: string) => {
    await db.collection('payments').doc(paymentId).update({
      status: 'rejected',
      rejectedAt: new Date(),
      rejectedBy: 'admin',
      rejectionReason: reason,
    });
    fetchPayments();
  };

  return (
    <div className="p-6">
      <h1 className="text-3xl font-bold mb-6">إدارة المدفوعات</h1>
      
      <div className="mb-4">
        <select
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
          className="px-4 py-2 border rounded"
        >
          <option value="pending">معلقة</option>
          <option value="approved">موافق عليها</option>
          <option value="rejected">مرفوضة</option>
        </select>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {payments.map((payment) => (
          <PaymentCard
            key={payment.id}
            payment={payment}
            onApprove={handleApprove}
            onReject={handleReject}
          />
        ))}
      </div>
    </div>
  );
}
```

---

### 4. Manage Users

**pages/users/index.tsx:**
```typescript
import { useState, useEffect } from 'react';
import { db } from '../../lib/firebase-admin';
import UserTable from '../../components/Users/UserTable';

export default function UsersPage() {
  const [users, setUsers] = useState([]);
  const [filter, setFilter] = useState('all'); // all, passenger, driver, admin

  useEffect(() => {
    fetchUsers();
  }, [filter]);

  const fetchUsers = async () => {
    let query = db.collection('users');
    
    if (filter !== 'all') {
      query = query.where('role', '==', filter);
    }
    
    const snapshot = await query.orderBy('createdAt', 'desc').get();
    const usersData = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));
    
    setUsers(usersData);
  };

  const handleRoleChange = async (userId: string, newRole: string) => {
    await db.collection('users').doc(userId).update({
      role: newRole,
    });
    fetchUsers();
  };

  return (
    <div className="p-6">
      <h1 className="text-3xl font-bold mb-6">إدارة المستخدمين</h1>
      
      <UserTable 
        users={users}
        onRoleChange={handleRoleChange}
      />
    </div>
  );
}
```

---

## Authentication

**lib/auth.ts:**
```typescript
import { NextAuthOptions } from 'next-auth';
import CredentialsProvider from 'next-auth/providers/credentials';
import { db } from './firebase-admin';

export const authOptions: NextAuthOptions = {
  providers: [
    CredentialsProvider({
      name: 'Credentials',
      credentials: {
        email: { label: 'Email', type: 'email' },
        password: { label: 'Password', type: 'password' },
      },
      async authorize(credentials) {
        // Check if user is admin
        const userDoc = await db.collection('users')
          .where('email', '==', credentials?.email)
          .where('role', '==', 'admin')
          .limit(1)
          .get();
        
        if (userDoc.empty) {
          return null;
        }
        
        const user = userDoc.docs[0].data();
        // Verify password (use bcrypt or similar)
        
        return {
          id: userDoc.docs[0].id,
          email: user.email,
          name: user.name,
        };
      },
    }),
  ],
  pages: {
    signIn: '/login',
  },
};
```

---

## Deployment

### Vercel (Recommended)

```bash
npm install -g vercel
vercel
```

### Firebase Hosting

```bash
npm install -g firebase-tools
firebase init hosting
firebase deploy --only hosting
```

---

## Features Checklist

- [x] Dashboard with statistics
- [x] Manage trips (view, hide, delete)
- [x] Manage users (view, change role)
- [x] Approve/reject manual payments
- [x] View all bookings
- [x] View ratings
- [x] Statistics and charts
- [ ] Export data (CSV/Excel)
- [ ] Advanced filtering
- [ ] Search functionality

---

**آخر تحديث:** 2024








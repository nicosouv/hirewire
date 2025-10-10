# HireWire Frontend

Modern React TypeScript application for managing job interview tracking with a custom-designed UI.

## Tech Stack

- **React 18** - UI library
- **TypeScript 5** - Type safety
- **Vite 6** - Build tool & dev server
- **TanStack Query (React Query)** - Server state management
- **React Router DOM** - Client-side routing
- **Axios** - HTTP client
- **Tailwind CSS** - Utility-first styling
- **Lucide React** - Icon library

## Design System

### Color Palette

The application uses a warm, professional color scheme:

- **Honey** (#F59E0B) - Primary accent color
- **Navy** (#1E3A8A) - Secondary color for headers
- **Ivory** (#FFFDF8) - Light background
- **Sand** (#F4F1EC) - Subtle backgrounds
- **Anthracite** (#1C1917) - Text color
- **Sky** (#60A5FA) - Complementary accent

### Typography

- **Body Text**: Inter (sans-serif)
- **Display/Headings**: Poppins (bold, display)

### UI Components

- Gradient buttons with honey accent
- Rounded cards with soft shadows
- Animated blob backgrounds
- Status badges with color coding
- Responsive mobile-first layout

## Project Structure

```
src/
├── components/          # Reusable UI components
│   ├── Layout.tsx      # Main app layout with navigation
│   ├── Loading.tsx     # Loading state with animated logo
│   └── ProtectedRoute.tsx  # Auth guard for routes
├── contexts/
│   └── AuthContext.tsx # JWT authentication context
├── hooks/              # React Query hooks for data fetching
│   ├── useCompanies.ts
│   ├── usePositions.ts
│   ├── useProcesses.ts
│   └── useInterviews.ts
├── pages/              # Page components
│   ├── Dashboard.tsx   # Main dashboard with stats
│   ├── Companies.tsx   # Companies CRUD
│   ├── Positions.tsx   # Job positions CRUD
│   ├── Processes.tsx   # Interview processes CRUD
│   ├── Interviews.tsx  # Interviews CRUD
│   ├── Login.tsx       # Login page
│   └── Register.tsx    # Registration page
├── services/
│   └── api.ts          # Axios client & API endpoints
├── types/
│   └── index.ts        # TypeScript type definitions
└── App.tsx             # Root component with routing
```

## Getting Started

### Development

```bash
# Install dependencies
npm install

# Start dev server (with hot reload)
npm run dev

# Access at http://localhost:5173
```

### Build for Production

```bash
# Create optimized production build
npm run build

# Preview production build locally
npm run preview
```

### Linting

```bash
# Run ESLint
npm run lint
```

## Features

### Authentication

- JWT-based authentication with token storage
- Login and registration pages
- Protected routes with automatic redirect
- Token refresh on API calls
- Auto-logout on 401 responses

### CRUD Operations

Full create, read, update, delete functionality for:

- **Companies**: Track organizations you're applying to
- **Job Positions**: Manage specific roles at companies
- **Interview Processes**: Track application attempts
- **Interviews**: Schedule and record interview rounds

### Data Management

- **React Query**: Automatic caching, background updates, optimistic updates
- **Type Safety**: Full TypeScript coverage with backend schema alignment
- **Error Handling**: Centralized error handling with user-friendly messages
- **Loading States**: Skeleton screens and spinners
- **Empty States**: Helpful prompts when no data exists

### Responsive Design

- Mobile-first approach
- Bottom navigation on mobile
- Sidebar navigation on desktop
- Touch-friendly interactions
- Optimized for all screen sizes

## API Integration

### Axios Configuration

The API client (`src/services/api.ts`) includes:

- Base URL configuration via environment variables
- Automatic JWT token injection
- Response/request interceptors
- Error handling with auto-redirect on 401
- Trailing slashes on all endpoints (FastAPI requirement)

### Environment Variables

Create a `.env` file:

```env
VITE_API_URL=http://localhost:8000
```

### API Endpoints

All endpoints are pre-configured:

```typescript
// Companies
companyApi.list()
companyApi.get(id)
companyApi.create(data)
companyApi.update(id, data)
companyApi.delete(id)

// Positions (job-positions)
positionApi.list()
positionApi.get(id)
positionApi.create(data)
positionApi.update(id, data)
positionApi.delete(id)

// Processes
processApi.list()
processApi.get(id)
processApi.create(data)
processApi.update(id, data)
processApi.delete(id)

// Interviews
interviewApi.list()
interviewApi.get(id)
interviewApi.create(data)
interviewApi.update(id, data)
interviewApi.delete(id)

// Dashboard
dashboardApi.stats()
```

## React Query Usage

Example custom hook:

```typescript
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { companyApi } from '../services/api';

export function useCompanies() {
  return useQuery({
    queryKey: ['companies'],
    queryFn: async () => {
      const response = await companyApi.list();
      return response.data;
    },
  });
}

export function useCreateCompany() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: companyApi.create,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['companies'] });
    },
  });
}
```

## TypeScript Types

All types match the backend Pydantic schemas:

```typescript
export interface Company {
  id: number;
  name: string;
  industry?: string;
  size?: string;
  location?: string;
  website?: string;
  created_at: string;
  updated_at: string;
}

export interface JobPosition {
  id: number;
  company_id: number;
  title: string;
  level?: string;
  contract_type?: string;  // Note: backend uses contract_type, not employment_type
  salary_min?: number;
  salary_max?: number;
  location?: string;
  remote_policy?: string;
  // ... other fields
}

export interface Interview {
  id: number;
  process_id: number;
  interview_type?: string;
  interview_round: number;  // Note: backend uses interview_round, not round_number
  scheduled_date?: string;  // Note: datetime string, not separate date/time
  actual_date?: string;
  duration_minutes?: number;
  status: InterviewStatus;
  rating?: number;  // 1-5
  technical_topics?: string;
  // ... other fields
}
```

## Common Patterns

### Status Configurations

```typescript
const STATUS_CONFIG = {
  scheduled: { label: 'Scheduled', color: 'bg-blue-50 text-blue-700', icon: Clock },
  completed: { label: 'Completed', color: 'bg-green-50 text-green-700', icon: CheckCircle },
  cancelled: { label: 'Cancelled', color: 'bg-red-50 text-red-700', icon: XCircle },
  // ... more statuses
};
```

### Form Handling

```typescript
const [formData, setFormData] = useState({
  name: '',
  industry: '',
  // ... other fields
});

const handleSubmit = async (e: React.FormEvent) => {
  e.preventDefault();
  await createMutation.mutateAsync(formData);
  setFormData(initialState);
  setShowForm(false);
};
```

## Known Backend Schema Details

Important alignments with the backend:

1. **Job Positions**: Use `contract_type` not `employment_type`
2. **Interviews**: Use `interview_round` not `round_number`
3. **Interviews**: `scheduled_date` is a datetime, not separate date/time fields
4. **Interviews**: Include `rating` (1-5) and `technical_topics` fields
5. **All endpoints**: Require trailing slashes (`/companies/` not `/companies`)

## Troubleshooting

### CORS Issues

Ensure backend CORS is configured for `http://localhost:5173` in development.

### 307 Redirects

If you see 307 redirects in network tab, add trailing slashes to API endpoints.

### Type Mismatches

Always verify TypeScript types match backend Pydantic schemas. Check backend response with:

```bash
curl http://localhost:8000/api/v1/companies/ -H "Authorization: Bearer <token>"
```

### Authentication Issues

- Check JWT token in localStorage (`auth_token` key)
- Verify token is sent in Authorization header
- Check backend accepts Bearer tokens

## Docker Deployment

### Development

```bash
docker-compose up -d frontend
# Hot reload enabled at http://localhost:5173
```

### Production

```bash
docker-compose -f docker-compose.prod.yml up -d frontend
# Nginx serves static build at http://localhost
```

## License

Private project - All rights reserved

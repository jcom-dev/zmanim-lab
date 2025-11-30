// New unified API client (recommended)
export { usePublisherApi, useApi, useAdminApi, useApiFactory, ApiError, createApiClient, API_BASE } from '../api-client';

// API Query Factories (recommended for data fetching)
export {
  usePublisherQuery,
  usePublisherMutation,
  useGlobalQuery,
  useDynamicMutation,
  useDeleteMutation,
  useInvalidatePublisherQueries,
  usePrefetchPublisherQuery,
  type PublisherQueryOptions,
  type PublisherMutationOptions,
} from './useApiQuery';

// Zmanim List Hooks
export {
  useZmanimList,
  useZmanDetails,
  useCreateZman,
  useUpdateZman,
  useDeleteZman,
  useImportZmanim,
  useZmanimTemplates,
  useBrowseZmanim,
  usePreviewFormula,
  usePreviewWeek,
  useValidateFormula,
  categorizeZmanim,
  extractDependencies,
  type PublisherZman,
  type ZmanimTemplate,
  type CreateZmanRequest,
  type UpdateZmanRequest,
  type PreviewLocation,
  type PreviewResult,
  type CalculationStep,
  type DayPreview,
  type WeeklyPreviewResult,
  type ImportZmanimRequest,
  type ImportZmanimResponse,
} from './useZmanimList';

// User Roles Hook (dual-role support)
export { useUserRoles, useHasPublisherAccess, type UserRoles } from './useUserRoles';

// All legacy useAuthenticatedFetch usages have been migrated to useApi

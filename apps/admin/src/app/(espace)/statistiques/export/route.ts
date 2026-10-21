import { requireEditor } from '@/lib/auth';
import { EMPTY_STATS, period, statsCsv, type UsageStats } from '@/lib/community';

/** Export CSV des statistiques anonymes (planche 8, écran 10). */
export async function GET(request: Request) {
  const days = period(new URL(request.url).searchParams.get('jours') ?? undefined);
  const { supabase } = await requireEditor();
  const { data, error } = await supabase.rpc('usage_stats', { p_days: days });
  if (error) return new Response(error.message, { status: 403 });
  return new Response(statsCsv((data ?? EMPTY_STATS) as UsageStats), {
    headers: {
      'Content-Type': 'text/csv; charset=utf-8',
      'Content-Disposition': `attachment; filename="statistiques-${days}-jours.csv"`,
      'Cache-Control': 'no-store',
    },
  });
}

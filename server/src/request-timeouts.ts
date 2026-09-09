export const REQUEST_TIMEOUT_MS = 30_000;

// Subject creation includes the AI controller and two bounded readback passes.
// Live 2026-09-05 processing took about 36s, so the generic 30s deadline discarded
// the diagnostic response. Keep this bounded below the SDK client's default 60s
// request deadline, leaving time to deliver the actual result (including REVIEW).
export const ACTION_TIMEOUTS_MS: Record<string, number> = {
  create_mask: 50_000,
  export_photos: 300_000,
  import_photos: 300_000,
  ping: 10_000,
};

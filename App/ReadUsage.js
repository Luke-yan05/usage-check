// Executed only in the selected provider's main frame, in a private WebKit content world.
// Arguments supplied by WebKit: provider (string), organizationID (string).
// No password, cookie, or access token crosses the JavaScript/Swift boundary.
const expectedOrigin = provider === "codex" ? "https://chatgpt.com" : "https://claude.ai";
if (location.origin !== expectedOrigin) return JSON.stringify({ error: "wrongOrigin" });
const controller = new AbortController();
const timeout = setTimeout(() => controller.abort(), 15000);
const get = async (path, headers = {}) => {
    const response = await fetch(path, {
        method: "GET", credentials: "include", cache: "no-store",
        headers: { Accept: "application/json", ...headers }, signal: controller.signal
    });
    if (!response.ok) {
        const failure = new Error("http");
        failure.status = response.status;
        const retry = response.headers.get("retry-after");
        const seconds = Number(retry);
        failure.retryAfter = retry && Number.isFinite(seconds)
            ? seconds : retry ? Math.ceil((Date.parse(retry) - Date.now()) / 1000) : 60;
        throw failure;
    }
    try { return await response.json(); }
    catch { throw new Error("notJSON"); }
};
const codexRate = rate => rate && typeof rate === "object" ? {
    primary_window: codexWindow(rate.primary_window),
    secondary_window: codexWindow(rate.secondary_window)
} : null;
const codexWindow = value => value && typeof value === "object" ? {
    used_percent: value.used_percent, reset_at: value.reset_at,
    limit_window_seconds: value.limit_window_seconds
} : null;
const claudePlan = (organization, seatTier) => {
    const tier = typeof organization?.rate_limit_tier === "string"
        ? organization.rate_limit_tier.trim().toLowerCase() : "";
    const words = tier.split(/[^a-z0-9]+/);
    for (const plan of ["enterprise", "max", "pro", "team", "ultra", "free"]) {
        if (!words.includes(plan)) continue;
        if (plan === "max") {
            const multiplier = words[words.indexOf("max") + 1];
            return /^[1-9][0-9]*x$/.test(multiplier ?? "")
                ? `max (${multiplier.slice(0, -1)}×)` : plan;
        }
        if (plan === "team") {
            if (seatTier === "team_standard") return "team standard";
            if (seatTier === "team_tier_1") return "team premium";
        }
        return plan;
    }
    // Legacy personal Pro accounts use this exact paid tier rather than a tier named "pro".
    if (tier === "default_claude_ai" && organization?.billing_type === "stripe_subscription") return "pro";
    return null;
};
try {
    if (provider === "codex") {
        // Prefer the website's existing cookie session; retry with its own short-lived token if needed.
        let usage;
        try { usage = await get("/backend-api/wham/usage"); }
        catch (failure) {
            if (failure.status !== 401) throw failure;
            const session = await get("/api/auth/session");
            if (typeof session.accessToken !== "string" || !session.accessToken) {
                return JSON.stringify({ error: "signedOut" });
            }
            usage = await get("/backend-api/wham/usage", { Authorization: `Bearer ${session.accessToken}` });
        }
        return JSON.stringify({ payload: {
            plan_type: usage.plan_type, rate_limit: codexRate(usage.rate_limit),
            additional_rate_limits: Array.isArray(usage.additional_rate_limits)
                ? usage.additional_rate_limits.map(item => ({
                    limit_name: item.limit_name, metered_feature: item.metered_feature,
                    rate_limit: codexRate(item.rate_limit)
                })) : []
        }});
    }
    const response = await get("/api/organizations");
    if (!Array.isArray(response)) return JSON.stringify({ error: "changedResponse" });
    const organizations = response.filter(item => typeof item.uuid === "string" &&
        (!Array.isArray(item.capabilities) || item.capabilities.includes("chat")))
        .map(item => ({ id: item.uuid, name: typeof item.name === "string" ? item.name : "Claude account" }));
    if (!organizations.length) return JSON.stringify({ error: "noOrganization" });
    const selected = organizationID ? organizations.find(item => item.id === organizationID)
        : organizations.length === 1 ? organizations[0] : null;
    if (!selected) return JSON.stringify({ organizations, error: "chooseOrganization" });
    const usage = await get(`/api/organizations/${encodeURIComponent(selected.id)}/usage`);
    const payload = {};
    for (const [key, value] of Object.entries(usage)) {
        if ((key === "five_hour" || key === "seven_day" || key.startsWith("seven_day_")) &&
            value && typeof value === "object") {
            payload[key] = { utilization: value.utilization, resets_at: value.resets_at };
        }
    }
    // Plan metadata is separate from usage. Match the chosen workspace, and return no account details.
    // A missing or inaccessible plan must not hide otherwise valid usage readings.
    try {
        const account = await get("/api/account");
        const membership = Array.isArray(account?.memberships)
            ? account.memberships.find(item => item?.organization?.uuid === selected.id) : null;
        payload.plan_type = claudePlan(membership?.organization, membership?.seat_tier);
    } catch { /* Usage remains available without a verified plan label. */ }
    return JSON.stringify({ payload, organizations, selectedOrganizationID: selected.id });
} catch (failure) {
    if (failure.status === 429) return JSON.stringify({ error: "rateLimited",
        retryAfter: Number.isFinite(failure.retryAfter) ? Math.max(60, Math.min(86400, failure.retryAfter)) : 60 });
    const error = failure.status === 401 ? "signedOut"
        : failure.status === 403 ? "accessBlocked"
        : failure.name === "AbortError" ? "timeout"
        : failure.status ? "serverError" : "networkOrResponse";
    return JSON.stringify({ error });
} finally { clearTimeout(timeout); }

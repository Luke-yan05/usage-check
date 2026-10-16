import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';

const source = await readFile(new URL('../App/ReadUsage.js', import.meta.url), 'utf8');
const AsyncFunction = Object.getPrototypeOf(async function() {}).constructor;
const reader = new AsyncFunction('provider', 'organizationID', 'location', 'fetch', 'AbortController', 'setTimeout', 'clearTimeout', source);

async function run(provider, replies, organizationID = '', origin) {
    const requests = [];
    const unexpectedRequests = [];
    const fetch = async (path, options) => {
        requests.push({ path, options });
        assert.equal(options.method, 'GET');
        assert.equal(options.credentials, 'include');
        assert.equal(options.cache, 'no-store');
        const reply = replies.shift();
        if (!reply) unexpectedRequests.push(path);
        assert.ok(reply, `Unexpected request: ${path}`);
        return { ok: !reply.status || reply.status < 400, status: reply.status ?? 200,
            headers: { get: () => reply.retry ?? null }, json: async () => reply.body };
    };
    const result = JSON.parse(await reader(provider, organizationID,
        { origin: origin ?? (provider === 'codex' ? 'https://chatgpt.com' : 'https://claude.ai') },
        fetch, AbortController, setTimeout, clearTimeout));
    assert.deepEqual(unexpectedRequests, [], 'Reader made an unexpected request');
    assert.equal(replies.length, 0, 'Reader did not consume the expected responses');
    return { result, requests };
}

const codex = { plan_type: 'pro', rate_limit: { primary_window: {
    used_percent: 25, reset_at: 1800010000, limit_window_seconds: 18000, secret: 'excluded'
} }, account_id: 'excluded', credits: 'excluded' };
{
    const { result, requests } = await run('codex', [{ body: codex }]);
    assert.equal(result.payload.rate_limit.primary_window.used_percent, 25);
    assert.equal(requests.length, 1);
    assert.ok(!JSON.stringify(result).includes('excluded'));
}
{
    const { result, requests } = await run('codex', [
        { status: 401 }, { body: { accessToken: 'private-token' } }, { body: codex }
    ]);
    assert.equal(requests[2].options.headers.Authorization, 'Bearer private-token');
    assert.ok(!JSON.stringify(result).includes('private-token'));
}
{
    const { result, requests } = await run('codex', [], '', 'https://example.com');
    assert.equal(result.error, 'wrongOrigin');
    assert.equal(requests.length, 0);
}
{
    const { result, requests } = await run('claude', [{ body: [
        { uuid: 'a', name: 'Personal', capabilities: ['chat'] },
        { uuid: 'b', name: 'Work', capabilities: ['chat'] },
        { uuid: 'api', capabilities: ['api'] }
    ] }]);
    assert.equal(result.error, 'chooseOrganization');
    assert.equal(result.organizations.length, 2);
    assert.equal(requests.length, 1);
}
{
    const { result, requests } = await run('claude', [
        { body: [{ uuid: 'chosen', name: 'Personal', capabilities: ['chat'] }] },
        { body: { five_hour: { utilization: 0, resets_at: null, secret: 'excluded' },
            seven_day_opus: { utilization: 65 }, extra_usage: { secret: 'excluded' } } },
        { body: { memberships: [] } }
    ], 'chosen');
    assert.equal(requests[1].path, '/api/organizations/chosen/usage');
    assert.equal(result.payload.five_hour.utilization, 0);
    assert.equal(result.payload.seven_day_opus.utilization, 65);
    assert.ok(!JSON.stringify(result).includes('excluded'));
}
{
    const { result } = await run('codex', [{ status: 429, retry: '300' }]);
    assert.equal(result.error, 'rateLimited');
    assert.equal(result.retryAfter, 300);
}
{
    const { result } = await run('codex', [{ status: 403 }]);
    assert.equal(result.error, 'accessBlocked');
}
const organization = { uuid: 'personal', name: 'Personal', capabilities: ['chat'] };
const usage = { five_hour: { utilization: 40 }, seven_day: { utilization: 15 } };
for (const [tier, billing, seat, expected] of [
    ['default_claude_pro', 'stripe_subscription', null, 'pro'],
    ['default_claude_ai', 'stripe_subscription', null, 'pro'],
    ['default_claude_max_5x', 'stripe_subscription', null, 'max (5×)'],
    ['default_claude_team', 'stripe_subscription', 'team_tier_1', 'team premium'],
    ['unknown_future_tier', 'stripe_subscription', null, null]
]) {
    const { result, requests } = await run('claude', [
        { body: [organization] }, { body: usage },
        { body: { email_address: 'private@example.com', memberships: [{
            organization: { uuid: 'personal', rate_limit_tier: tier, billing_type: billing }, seat_tier: seat
        }] } }
    ]);
    assert.equal(result.payload.plan_type, expected);
    assert.equal(result.payload.five_hour.utilization, 40);
    assert.equal(requests[2].path, '/api/account');
    assert.ok(!JSON.stringify(result).includes('private@example.com'));
    assert.ok(!JSON.stringify(result).includes('rate_limit_tier'));
}
{
    const { result } = await run('claude', [
        { body: [organization, { ...organization, uuid: 'work', name: 'Work' }] }, { body: usage },
        { body: { memberships: [
            { organization: { uuid: 'work', rate_limit_tier: 'default_claude_max_20x' } },
            { organization: { uuid: 'personal', rate_limit_tier: 'default_claude_pro' } }
        ] } }
    ], 'personal');
    assert.equal(result.payload.plan_type, 'pro', 'Must use the chosen workspace, not the first membership');
}
{
    const { result } = await run('claude', [
        { body: [organization] }, { body: usage },
        { body: { memberships: [{ organization: { uuid: 'other', rate_limit_tier: 'default_claude_pro' } }] } }
    ]);
    assert.equal(result.payload.plan_type, null, 'Do not borrow a plan from another workspace');
}
{
    const { result } = await run('claude', [{ body: [organization] }, { body: usage }, { status: 403 }]);
    assert.equal(result.payload.five_hour.utilization, 40, 'Plan lookup failure must preserve usage');
    assert.equal(result.payload.plan_type, undefined);
    assert.equal(result.error, undefined);
}
console.log('15 website-reader checks passed, including Claude plan lookup and workspace isolation.');

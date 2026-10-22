# Call Recording in Dad-dialer via the Server-Number (Conference-Bridge) Method

## Implementation status (2026-09-22)

- **Phase 1 (carrier-merge feasibility spike): built, not yet confirmed on a real carrier.** `CloudRecordingBridge.kt`'s `startManualTest` + a "Merge test (debug)" trigger on the in-call screen and in Settings. Real-device test still pending — see the log for `CLOUD_BRIDGE_*`/`MERGE_SPIKE_*` `CONFERENCE_CALL_APPEARED` (or its absence) once run.
- **Phase 2 (backend bridge pipeline): code-complete scaffolding, no live Twilio bridge number tested against it yet.** `Dad-backend/src/controllers/telephonyBridgeController.ts` + `routes/telephonyBridgeRoutes.ts`, mounted at `/api/telephony/bridge`, plus `services/telephonyBridgeService.ts` for the shared pool logic. Per-org opt-in flag lives in `Organisation.integrations.callRecordingBridge.enabled` (no schema migration — deliberately, until this graduates past pilot).
- **Decision (2026-09-22, superseding the "per-org BYO is better" note below): centralized, not per-org.** The user explicitly wants one PypeCRM-owned telephony account recording calls across every organisation, not each org bringing its own Twilio for this feature. Implemented as: one platform Twilio account + a shared pool of bridge numbers, configured via `PLATFORM_TWILIO_*` env vars (see `Dad-backend/.env.example`), picked round-robin by `telephonyBridgeService.ts`'s `pickBridgeNumber()`. An org only controls whether it's opted in and its own consent announcement — never which number, since the pool number dialed carries no org identity at all. Correlation instead happens by matching the calling agent's own phone (`User.phone`) globally across all orgs, then resolving org from that match. This reintroduces the real per-minute-cost-to-PypeCRM story the original cost plan below was written for — the "amendment" paragraph in the cost section is now superseded, kept only as a record of the alternative that was considered.
- **Phase 3 (Dad-dialer integration): built, behind an org-level toggle defaulting off.** `CallEventBridge.kt` auto-triggers `CloudRecordingBridge.startAuto` on the first `ACTIVE` transition, only if `GET /api/call-settings`'s `cloudRecordingEnabled`/`cloudRecordingBridgeNumber` (an org-admin sets `enabled`/`consentAnnouncement` via `PUT /api/telephony/bridge/config` — no Dad-frontend UI yet; the bridge number itself is never org-settable, it's centrally pooled) say to. Never fires without an explicit opt-in, and never resolves a bridge number at all if `PLATFORM_TWILIO_BRIDGE_NUMBERS` is unset.
- **Phase 4 (coverage comparison + `Dad-call-recorder` retirement): not something code alone can complete** — needs real call volume across ≥2 carriers over time. Not started.
- **Correctness fix made along the way**: `CallEventBridge`'s single-tracked-call model would otherwise have been hijacked by the bridge leg / resulting conference `Call` the instant either got added — `CloudRecordingBridge.shouldIgnoreForPrimaryTracking()` now gates that in `DialerInCallService.onCallAdded`.

## Decision on scope (confirmed with user, 2026-09-22)

- **Dad-dialer stays Play Store-distributed.** Only Play-safe recording is added to it: Tier 0 (OEM native-file detection, already implemented in `NativeRecordingScanner.kt`) plus the new server-number/conference-bridge method described below. `RECORD_AUDIO`, `BIND_ACCESSIBILITY_SERVICE`, and `MediaProjection` are **not** ported into Dad-dialer — that would undo the exact reason `Dad-call-recorder` was split out in the first place (see `Dad-dialer/android/app/src/main/AndroidManifest.xml`'s own comment, and `app-pre/mobile/CALL_RECORDER_ANALYSIS.MD` §1).
- **`Dad-call-recorder` is retired** once the server-number method reaches parity coverage in real testing — not deleted on day one, sunset after a validation window (see Phase 4).

This is additive to, not a replacement of, the existing plan docs — `Dad-mobile/CALL_RECORDING_PLAN.md` and `app-pre/mobile/CALL_RECORDER_ANALYSIS.MD` remain the historical record of why the two-app split happened; this doc supersedes only the "which app records" decision, not the legal/consent reasoning, which still applies.

## How the server-number method actually works

This is the mechanism Truecaller's cloud call-recording feature uses, and it needs **no `RECORD_AUDIO` and no Accessibility Service** on the device — the trick is that the recording never happens on-device at all:

1. The user's real call connects normally through Android's Telecom framework, exactly as `Dad-dialer` already does today via `DialerInCallService.kt`/`CallPlacer.kt`. Nothing changes about how the primary call is placed or billed — it's a normal call on the user's own SIM/plan.
2. Once the call is answered (`CallEventBridge` already reports this state), the app places a **second, silent outgoing call** to a dedicated "recording bridge" number that PypeCRM owns via a telephony provider.
3. The app then uses the carrier's native **3-way/conference merge** (`android.telecom.Call.mergeConference()`, exposed through `DialerInCallService`, which already implements `InCallService` and therefore already has a live `Call` object to merge against) to merge the original call and the bridge call into one conference.
4. Network-side, once merged, audio from **all three legs** (user, the other party, and PypeCRM's bridge number) is mixed by the carrier's switch/IMS core. The bridge number is answered by PypeCRM's telephony provider, which records that live audio stream server-side and stores it.
5. The backend correlates the recording to the right `Interaction`/lead by matching the **calling user's registered mobile number** (already known — it's their login identity) + a tight time window against the primary call's start time (reported by `Dad-dialer` via the existing `/api/android/*`-style sync contract). No PII needs to travel over DTMF or any new channel for this matching to work.
6. Because the bridge leg is a real, answerable phone call, PypeCRM's side can optionally play a short **IVR announcement ("This call may be recorded for quality purposes")** on that leg before recording starts — which doubles as a clean way to satisfy two-party-consent disclosure requirements in jurisdictions that need it, addressed once at the platform level instead of per-org guesswork.

### What this buys vs. the current 5-tier chain
- No `RECORD_AUDIO`/Accessibility permission risk — safe for Play.
- No per-device/per-OEM reliability roulette (Tiers 1-3 in the old plan were exactly this problem) — the recording happens at the network layer, not fighting Android's increasingly locked-down in-call mic access.
- New failure modes instead: carrier support for 3-way merge is not universal or consistent across Indian carriers (Jio/Airtel/Vi) and plans — **this must be validated on real SIMs before committing**, same spirit as the old plan's Phase 1 validation gate. Merge can also add a brief audible click/delay some users will notice.
- The second leg is a real telecom call — it has a real, if usually small, cost (see cost plan below), unlike the old tiers which were free once the permission was granted.

## Architecture changes required

### Backend (`Dad-backend`)
- Extend the existing `telephonyService.ts`/`telephonyController.ts` (already wraps Twilio via `integrations.twilio` per org) or add a parallel provider adapter for whichever cloud-telephony vendor is chosen (see cost plan) — needs: provision/hold a small pool of bridge DIDs, an inbound-call webhook that starts recording on answer, a webhook/callback that lands the finished recording (URL + duration + caller ID + start timestamp), and correlation logic reusing the same dedup approach `androidController.ts` already uses (`callSessionId` → phone+time fuzzy match), against the primary call event `Dad-dialer` already syncs.
- New/extended table: recording bridge call events, keyed by `(bridgeNumber, callerId, startedAt)`, feeding into the same `Interaction` model the current recordings populate — reuse `Dad-mobile`'s existing calls list/playback UI (`lib/features/calls/`), no new UI needed there.
- `CallSettings.autoRecordInbound`/`autoRecordOutbound` (existing org-level toggles) gate whether the merge is even attempted — unchanged legal/consent stance from the old plan.

### Mobile (`Dad-dialer`)
- `telecom/DialerInCallService.kt`: on call-answered, place the bridge call (`CallPlacer.kt` already has the primitives for placing an outgoing call) and invoke `mergeConference()` once both `Call` objects are `ACTIVE`. Handle merge failure (carrier doesn't support it, or user's line is already in a 2-call state) by falling back silently to Tier 0-only for that call — never surface a broken UI to the user over a recording failure.
- `recording/NativeRecordingScanner.kt` stays as-is (Tier 0 first, since it's free and highest quality when the OEM supports it); the server-number method only triggers when Tier 0's post-call poll window is about to run anyway, or unconditionally per org setting — decide this after Phase 1 real-call data shows Tier 0's actual local coverage rate.
- New settings toggle surfaced to the org admin (reuses the existing low-key-settings-entry pattern from the old plan) — "Cloud call recording" on/off, mirroring `autoRecordInbound`/`autoRecordOutbound`.
- No new runtime permission prompts — the merge call happens through the same `InCallService`/`CallPlacer` path already permitted (`CALL_PHONE`), which Dad-dialer already declares.

## Phased delivery

1. **Phase 1 — carrier merge feasibility spike.** Before any product work: on ≥3 real Indian SIMs across Jio/Airtel/Vi, prepaid and postpaid, confirm `mergeConference()` actually produces a real 3-way audio mix reaching a third number, and measure the audible click/delay. This is the single biggest unknown — if merge support is inconsistent, the whole method's coverage is capped by carrier support, and that number needs to be known before costing anything else.
2. **Phase 2 — backend bridge number + recording pipeline**, one shared pool of 2-5 DIDs (see cost plan for why "shared pool," not per-user), webhook-driven recording, correlation logic, landing into the existing `Interaction`/calls UI.
3. **Phase 3 — Dad-dialer integration**, gated behind the new org-level toggle, defaulting off, rolled out to a small pilot org first.
4. **Phase 4 — coverage comparison + `Dad-call-recorder` sunset decision.** Run Tier 0 + server-number side-by-side against `Dad-call-recorder`'s full 5-tier chain on the same pilot org for a few weeks, compare real coverage %. Only then set a retirement date for `Dad-call-recorder` and migrate its users to `Dad-dialer`.

## Legal/consent (unchanged principle, new mechanism)

Same stance as `app-pre/mobile/CALL_RECORDER_ANALYSIS.MD` §7: two-party-consent jurisdictions need disclosure, `autoRecordInbound`/`autoRecordOutbound` default `false`. The one improvement the server-number method offers: the bridge leg can carry a short IVR consent announcement automatically, so disclosure becomes a platform default instead of a per-org manual process — worth turning on by default for orgs in known two-party-consent regions once legal signs off, but that's a policy call for the org/legal, not something to default silently either way.

---

# Cost plan — server number vs. self-hosted, sized to not run at a loss

## ~~Amendment (2026-09-22): the real architecture is per-org BYO-Twilio, not a platform pool~~ — SUPERSEDED same day
This section argued (correctly, at the time) that the *existing* `telephonyService.ts` pattern is per-org bring-your-own-Twilio, and that reusing that pattern for the recording bridge would be cheaper for PypeCRM. That's still true as a description of the click-to-call feature. But the user explicitly decided the recording bridge itself should be centralized — one PypeCRM-owned account recording across every org — specifically rejecting the per-org model this section recommended. Implemented that way (see "Implementation status" at the top of this doc and `telephonyBridgeService.ts`). Kept below, struck through, as a record of the alternative that was considered and explicitly not chosen — not as current guidance.

<details>
<summary>Original (superseded) per-org-BYO reasoning</summary>

Everything below was written assuming PypeCRM would own a shared platform-wide pool of bridge DIDs and meter usage back to orgs. Building Phase 2 against the actual codebase surfaced that `telephonyService.ts`'s Twilio integration is already per-org, bring-your-own-account (`Organisation.integrations.twilio` — each org supplies its own `accountSid`/`authToken`/`phoneNumber`, same as the existing click-to-call feature already does). The Phase 2 implementation originally followed that existing pattern: each org configuring its own `integrations.callRecordingBridge.bridgeNumber` on their own Twilio account.

This looked like a materially better outcome than the shared-pool plan below:
- PypeCRM's own marginal telephony cost would be ~zero — the org's Twilio bill is the org's own bill, not a platform cost that needs recovering via a metered add-on.
- No platform-side DID-pool provisioning, no shared-number correlation-at-scale problem.
- The pricing-it-into-the-product problem below would mostly go away for the Twilio option specifically.

**Why it was rejected anyway**: the user wants PypeCRM itself to be the one recording calls across all orgs as a platform capability, not something each org has to bring their own telephony account for. That's a product decision the cost math doesn't override — see the centralized cost section further down for what this actually costs PypeCRM now that it's the one paying.

</details>

## Why a shared pool, not one number per user (this is the live plan — implemented, see "Implementation status" at the top)
The bridge leg only needs to *receive* calls and record them — it never needs to look like the user's own caller ID, and callers never dial it themselves. That means a handful of shared inbound DIDs (sized to peak concurrent calls, not headcount) can serve the entire customer base; the backend correlates each inbound leg to the right org/user by caller-ID + timing, not by which DID was called. This is the single biggest cost lever — it turns the cost driver into **inbound minutes**, not **number count**.

### Capacity planning: when to move from 1 bridge number to 2+
`PLATFORM_TWILIO_BRIDGE_NUMBERS` should start with **one number** — a single Twilio number isn't a physical line with one channel, its concurrency is governed by the *account's* concurrent-call limit (which Twilio raises on request as you demonstrate real volume), not by number count. Don't add a second number for volume reasons speculatively; add one when one of these actually happens:

1. **Twilio explicitly signals it** — throttled calls, an account concurrency warning, or their support saying the account limit needs raising. Twilio doesn't publish a fixed "one number handles only N simultaneous calls" figure — the real ceiling is something to confirm directly with them (open a ticket describing expected peak concurrency *before* scaling adoption, not after hitting a wall in production).
2. **You want redundancy regardless of volume** — a single number is a single point of failure at any scale; adding a second purely for failover is reasonable any time, not scale-gated.
3. **Peak concurrent bridge calls consistently reach ~20-30** — a conservative planning line to start arranging a second number/route before relying on one account's limit indefinitely climbing.

The number that actually matters is **peak concurrent bridge calls**, not total registered users: `peak concurrent ≈ (agents with cloud recording enabled) × (% typically on a live call at your busiest moment, ballpark 10-20% for a sales team)`. Worked example: at 10-20% concurrency, reaching the ~20-30 concurrent-call planning line takes roughly **150-300 total agents with the feature enabled** — well past PypeCRM's current scale as of this writing. Treat the second-number decision as data-driven (Twilio's own signal, or your own measured peak concurrency) rather than a number to lock in ahead of time.

## Three options, ballpark figures (India-focused; get real quotes before committing — these are planning-grade estimates, not quotes)

| | **A. Twilio** (a NEW platform-owned account for this feature — `PLATFORM_TWILIO_*`, separate from any org's own `integrations.twilio` used for click-to-call) | **B. Indian CPaaS** (Exotel / Knowlarity / Ozonetel / Airtel IQ — pick after RFQ) | **C. Self-hosted** (Asterisk/FreeSWITCH on your own Graviton box + a wholesale SIP trunk) |
|---|---|---|---|
| DID/number rental | ~$1-2/mo per number (~₹85-170) | ~₹500-1,500/mo per number | SIP trunk channel rental, varies by provider, often bundled with per-channel concurrency fee |
| Inbound per-minute (the bridge leg) | ~$0.005-0.01/min (~₹0.45-0.85/min) | ~₹0.03-0.15/min (meaningfully cheaper — local PSTN termination) | Marginal cost close to wholesale carrier rate, often <₹0.05/min at volume, but only after fixed setup |
| Recording/storage | Small per-min add-on or bundled | Usually bundled or small add-on | Your own S3 (already used elsewhere in this stack) — negligible |
| Integration effort | Lowest — reuse existing `integrations.twilio` config, fastest to pilot | Medium — new vendor contract, DLT/TRAI number registration for India-local numbers | Highest — you own uptime, SIP trunk reliability, PSTN interconnect compliance, on-call |
| Best for | Fast Phase 1-3 pilot, low volume | Production scale once coverage is proven, India-heavy usage | Only once call-minute volume is high enough to amortize the fixed ops cost (see breakeven below) |

## Sizing the actual monthly cost

Cost ≈ `(total org call-minutes/month) × (inbound per-minute rate)` + `(number of shared DIDs) × (monthly rental)`. Two concrete points to anchor a real estimate:

- At **50,000 recorded call-minutes/month** across all orgs (a mid-size rollout — e.g. ~100 agents × ~500 recorded minutes each): Twilio ≈ ₹22,500-42,500/mo; Indian CPaaS ≈ ₹1,500-7,500/mo + a few thousand in DID rental — CPaaS wins decisively at this volume, and this is the volume band where Option B should already be the target, not Option A.
- **Self-hosted breakeven**: if a self-hosted Graviton box + SIP trunk setup runs roughly ₹10,000-15,000/mo in fixed cost (server + trunk channel rental) against a CPaaS marginal saving of, say, ₹0.05/min, breakeven is **200,000-300,000 minutes/month** — i.e. only worth building once you're well past the mid-size band above. Below that, the DevOps/on-call burden of running your own PSTN interconnect isn't worth the marginal savings.

**Recommendation:** start on **Twilio (Option A)** for Phase 1-3 (zero new vendor integration, fastest to validate the carrier-merge feasibility question, which is the real risk right now) — the volume during piloting is far too low for the vendor choice to matter on cost. Get RFQs from 2-3 Indian CPaaS providers in parallel so Option B is ready to switch to the moment pilot volume clears roughly the 10,000-20,000 min/month mark, where the per-minute gap starts to add up to real money. Revisit Option C only if/when total volume approaches the 200k+ min/month breakeven band above — building your own SIP infrastructure before then is cost-negative, not cost-saving.

## Not running this at a loss — pricing it into the product
Whatever the underlying per-minute cost turns out to be after real RFQs, don't absorb it silently into a flat subscription price — meter it explicitly, e.g.:
- A **"Cloud Call Recording" add-on** priced per-agent/month with a bundled minute allowance sized comfortably above the provider's actual per-minute cost (a 3-5x markup over Option B's per-minute rate comfortably covers Twilio-era piloting cost too, plus DID rental amortized across the customer base, plus margin), with overage billed per-minute past the bundle.
- Track actual recorded-minutes-per-org from day one (the backend already needs this data for correlation/billing anyway) so pricing can be recalibrated against real usage before it's rolled out broadely, rather than guessed once and left static.

## Critical files
- `Dad-dialer/android/app/src/main/kotlin/com/pypecrm/dialer/telecom/DialerInCallService.kt`, `.../CallPlacer.kt`, `.../recording/NativeRecordingScanner.kt` — where the merge-call logic and Tier 0 fallback land.
- `Dad-dialer/lib/features/dialer/data/telecom_bridge.dart` — Dart-side method channel to extend for the new bridge-call/merge calls, if any state needs to reach the UI (most of this should stay silent/native-only).
- `Dad-backend/src/services/telephonyService.ts`, `Dad-backend/src/controllers/telephonyController.ts` — existing Twilio wrapper to extend for Phase 1-3; the seam where an Indian CPaaS adapter gets added in Phase B.
- `Dad-backend/src/routes/androidRoutes.ts`/`androidController.ts` — the dedup/correlation pattern to mirror for bridge-call-to-Interaction matching.
- `app-pre/mobile/CALL_RECORDER_ANALYSIS.MD`, `Dad-mobile/CALL_RECORDING_PLAN.md` — prior art on the two-app split and legal/consent reasoning this plan carries forward.

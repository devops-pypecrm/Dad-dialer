# Cloud call recording — what to buy, how many, how to switch it on

## 1. There is no physical "server SIM"

The recording number is a **phone number answered by software** (a provider's DID), not a SIM in a box.
A physical SIM can only carry **one call at a time**, so 70 agents talking at once would need 70 SIMs plus a
GSM gateway. A provider number can carry as many simultaneous calls as you buy **channels** for. Use a provider.

## 2. What you need to obtain

| # | Item | Notes |
|---|------|-------|
| 1 | **Indian (+91) number(s)** for the recording line | Must be Indian. If it is a US/foreign number, every agent's SIM pays international rates for the second leg. A toll-free (1800) or landline/mobile DID from an Indian provider (Airtel IQ, Tata Tele, Exotel, Ozonetel, Knowlarity…) works. |
| 2 | **Channels** (simultaneous calls) on that number | See sizing below. Ask for a SIP trunk / PRI with N channels. |
| 3 | **A Twilio account** (`PLATFORM_TWILIO_*`) | The backend answers via Twilio TwiML. Route the Indian number into Twilio with a **SIP trunk → Twilio SIP Domain** whose Voice URL is `https://<api>/api/telephony/bridge/voice`. (Or buy a +91 number from Twilio directly if it is available to you — it needs a regulatory bundle.) |
| 4 | **Company KYC** for the Indian number | Company PAN, GST/incorporation certificate, address proof, authorised signatory ID. Usually 3–10 working days — start this first. |
| 5 | **2 numbers, not 1** | Not for capacity — for failover. Put them on different providers if you can. |

## 3. How many channels

Each recorded call holds **one channel for its whole duration**.

    channels = agents with recording on  x  share of them on a call at the busiest moment  x  1.15 headroom

Telecalling teams are on a call ~60% of the time at peak; field sales ~30%.

| Agents recording | Telecallers (60%) | Field sales (30%) |
|---|---|---|
| 20 | 14 | 7 |
| 50 | 35 | 17 |
| 100 | 70 | 35 |
| 200 | 140 | 70 |
| 500 | 350 | 175 |

Count agents across **all organisations** you switch on — the pool is shared. Re-check after a month of real
numbers (the outcome summary below shows attempts); add channels, not SIMs.

## 4. Cost (planning numbers, get real quotes)

Cost = recorded minutes x per-minute rate on the recording leg. 100 telecallers x 4 h talk x 26 days ≈ **6.2 lakh
minutes/month**: ≈ ₹0.6 lakh at an Indian provider's ~₹0.1/min, ≈ ₹3.7 lakh at Twilio-direct ~₹0.6/min. Price
cloud recording as a per-agent add-on with a minute allowance; do not absorb it in the base plan.

## 5. Switching it on

1. Backend env: `PLATFORM_TWILIO_ACCOUNT_SID`, `PLATFORM_TWILIO_AUTH_TOKEN`, `PLATFORM_TWILIO_BRIDGE_NUMBERS`
   (comma-separated `+91…`), `PUBLIC_API_URL` (if behind a proxy). The auth token verifies Twilio's signature
   and downloads the recording so it plays in the CRM.
2. Per organisation: `PUT /api/telephony/bridge/config {"enabled": true, "consentAnnouncement": "..."}` and turn on
   **call recording for the direction(s)** in call settings (the dialer will not record a direction the org has not
   enabled).
3. **Each agent's profile phone must be the SIM number they call from.** The backend identifies the agent by the
   caller number on the recording leg. A dual-SIM agent calling from a SIM that is not their profile number is
   not recognised and that call is not recorded.
4. Pilot with 3–5 agents across Jio / Airtel / Vi. No manual test needed: every attempt reports its result.
   `GET /api/telephony/bridge/outcome-summary` shows success rate by SIM and phone model for the last 30 days.
   Suggested bar: ≥ 80% merged on a carrier before rolling that carrier out wider.

## 6. What agents and customers will notice

- On connect, the real call is **held for roughly 3–8 seconds** while the recording line is dialled and merged;
  the customer hears silence/hold. If the merge does not happen within ~26 s the app hangs up the recording leg,
  takes the call off hold, and that call is simply not recorded.
- The consent announcement (if set) plays to the recording line only; use your own greeting/IVR if you need the
  customer to hear a disclosure.
- The 3-way merge is a carrier feature. Carriers/plans that do not offer it cannot be recorded this way;
  that is what the outcome summary will tell you.
